<?php
// Restaurant et bar : plan de salle, commandes ouvertes sur les tables, bons de préparation.
// Commun au point de vente (pos.php), à l'éditeur de plan (salle.php) et à l'écran cuisine (cuisine.php).

const RESTAURANT_TYPES = ['Restaurant', 'Bar'];

function caisse_est_restaurant(array $caisse): bool
{
    return in_array($caisse['TypePointVente'] ?? 'Boutique', RESTAURANT_TYPES, true);
}

/**
 * Salles et tables actives d'une caisse. Avec $journee : état de chaque table (commande ouverte,
 * total, couverts, addition imprimée, articles pas encore envoyés en préparation).
 */
function restaurant_plan(int $caisseId, ?int $journee = null): array
{
    $salles = q('SELECT Id, Nom FROM Salles WHERE CaisseId = ? ORDER BY Ordre, Id', [$caisseId]);
    $tables = q('SELECT t.* FROM TablesRestaurant t JOIN Salles s ON s.Id = t.SalleId WHERE s.CaisseId = ? AND t.Actif = 1 ORDER BY t.Id', [$caisseId]);
    $commandes = [];
    if ($journee !== null) {
        foreach (q('SELECT co.*, u.NomComplet FROM CommandesOuvertes co LEFT JOIN Utilisateurs u ON u.Id = co.UtilisateurId
                    WHERE co.CaisseId = ? AND co.TableId IS NOT NULL', [$caisseId]) as $co) {
            $commandes[(int) $co['TableId']] = $co;
        }
    }
    $parSalle = [];
    foreach ($tables as $t) {
        $table = [
            'id' => (int) $t['Id'], 'nom' => $t['Nom'], 'places' => (int) $t['Places'], 'forme' => $t['Forme'],
            'x' => (int) $t['PosX'], 'y' => (int) $t['PosY'], 'l' => (int) $t['Largeur'], 'h' => (int) $t['Hauteur'],
        ];
        if ($journee !== null) {
            $co = $commandes[(int) $t['Id']] ?? null;
            $table['commande'] = $co ? restaurant_resume($co) : null;
        }
        $parSalle[(int) $t['SalleId']][] = $table;
    }
    return array_map(fn($s) => ['id' => (int) $s['Id'], 'nom' => $s['Nom'], 'tables' => $parSalle[(int) $s['Id']] ?? []], $salles);
}

/** Contenu JSON d'une commande ouverte : { lignes, clientId, remise }. */
function restaurant_contenu(?string $json): array
{
    $c = json_decode((string) $json, true);
    $c = is_array($c) ? $c : [];
    $c['lignes'] = array_values(array_filter((array) ($c['lignes'] ?? []), 'is_array'));
    return $c;
}

/** Total TTC d'un contenu (lignes, remises comprises), comme l'écran de vente. */
function restaurant_total(array $contenu): float
{
    $brut = 0.0;
    foreach ($contenu['lignes'] as $l) {
        $brut += round((float) ($l['qte'] ?? 0) * (float) ($l['prix'] ?? 0) * (1 - min(100, (float) ($l['remise'] ?? 0)) / 100));
    }
    $r = $contenu['remise'] ?? null;
    $remise = 0.0;
    if (is_array($r) && (float) ($r['valeur'] ?? 0) > 0 && $brut > 0) {
        $remise = ($r['type'] ?? '') === 'pct' ? round($brut * min(100, (float) $r['valeur']) / 100) : min($brut, round((float) $r['valeur']));
    }
    return $brut - $remise;
}

/** Résumé d'une commande ouverte pour le plan de salle. */
function restaurant_resume(array $co): array
{
    $contenu = restaurant_contenu($co['Contenu']);
    $aEnvoyer = 0.0;
    foreach ($contenu['lignes'] as $l) {
        $aEnvoyer += max(0, (float) ($l['qte'] ?? 0) - (float) ($l['envoye'] ?? 0));
    }
    return [
        'id' => (int) $co['Id'], 'version' => (int) $co['Version'], 'couverts' => (int) $co['Couverts'],
        'total' => restaurant_total($contenu), 'articles' => count($contenu['lignes']),
        'addition' => (bool) $co['AdditionImprimee'], 'aEnvoyer' => $aEnvoyer > 0,
        'serveur' => $co['NomComplet'] ?? null, 'depuis' => $co['DateOuverture'],
    ];
}

/** Commande ouverte complète, telle que l'écran de vente la manipule. */
function restaurant_commande_json(array $co): array
{
    $contenu = restaurant_contenu($co['Contenu']);
    return [
        'id' => (int) $co['Id'], 'version' => (int) $co['Version'], 'tableId' => $co['TableId'] === null ? null : (int) $co['TableId'],
        'couverts' => (int) $co['Couverts'], 'addition' => (bool) $co['AdditionImprimee'],
        'lignes' => $contenu['lignes'], 'clientId' => $contenu['clientId'] ?? null, 'remise' => $contenu['remise'] ?? null,
    ];
}

/**
 * Lignes reçues de l'écran de vente, nettoyées. La quantité déjà envoyée en préparation
 * (« envoye ») vient toujours de la version enregistrée, jamais du navigateur.
 */
function restaurant_lignes_saisies(array $lignes, array $avant): array
{
    $envoye = [];
    foreach ($avant as $l) {
        if (isset($l['uid'])) {
            $envoye[(string) $l['uid']] = (float) ($l['envoye'] ?? 0);
        }
    }
    $resultat = [];
    foreach (array_slice($lignes, 0, 300) as $l) {
        if (!is_array($l) || empty($l['uid']) || empty($l['produitId'])) {
            continue;
        }
        $uid = substr(preg_replace('/[^A-Za-z0-9-]/', '', (string) $l['uid']), 0, 40);
        $resultat[] = [
            'uid' => $uid,
            'produitId' => (int) $l['produitId'],
            'nom' => mb_substr((string) ($l['nom'] ?? ''), 0, 200),
            'qte' => max(0, round((float) ($l['qte'] ?? 0), 2)),
            'prix' => max(0, round((float) ($l['prix'] ?? 0), 2)),
            'remise' => min(100, max(0, round((float) ($l['remise'] ?? 0), 2))),
            'tva' => (float) ($l['tva'] ?? 0),
            'unite' => mb_substr((string) ($l['unite'] ?? ''), 0, 20),
            'note' => mb_substr(trim((string) ($l['note'] ?? '')), 0, 200),
            'envoye' => $envoye[$uid] ?? 0.0,
            // Combo : articles choisis (contrôlés à l'encaissement).
            'composants' => array_values(array_map(fn($c) => [
                'produitId' => (int) ($c['produitId'] ?? 0), 'groupeId' => (int) ($c['groupeId'] ?? 0),
                'nom' => mb_substr((string) ($c['nom'] ?? ''), 0, 200), 'qte' => max(0, round((float) ($c['qte'] ?? 1), 2)),
                'supplement' => max(0, round((float) ($c['supplement'] ?? 0), 2)),
            ], array_slice(array_filter((array) ($l['composants'] ?? []), 'is_array'), 0, 30))),
        ];
    }
    return $resultat;
}

/** Contenu à enregistrer (lignes, client, remise) en JSON. */
function restaurant_contenu_saisi(array $saisi, array $avant): string
{
    $remise = $saisi['remise'] ?? null;
    $remise = is_array($remise) && (float) ($remise['valeur'] ?? 0) > 0
        ? ['type' => ($remise['type'] ?? '') === 'pct' ? 'pct' : 'montant', 'valeur' => (float) $remise['valeur']] : null;
    return json_encode([
        'lignes' => restaurant_lignes_saisies((array) ($saisi['lignes'] ?? []), $avant['lignes'] ?? []),
        'clientId' => int_or_null($saisi['clientId'] ?? null),
        'remise' => $remise,
    ], JSON_UNESCAPED_UNICODE);
}

/** Poste de préparation (Cuisine, Bar ou Aucun) de chaque produit. */
function restaurant_postes(array $produitIds): array
{
    if (!$produitIds) {
        return [];
    }
    $marques = implode(',', array_fill(0, count($produitIds), '?'));
    $postes = [];
    foreach (q("SELECT p.Id, COALESCE(c.Preparation, 'Cuisine') AS Poste FROM Produits p LEFT JOIN Categories c ON c.Id = p.CategorieId
                WHERE p.Id IN ($marques)", array_values($produitIds)) as $r) {
        $postes[(int) $r['Id']] = $r['Poste'];
    }
    return $postes;
}

/**
 * Bons de préparation des articles pas encore envoyés (et des annulations) d'une commande :
 * un bon par poste. Met à jour « envoye » dans le contenu. Renvoie les Id des bons créés.
 */
function restaurant_envoyer(array $co, array &$contenu, array $avant, string $tableNom, string $serveur): array
{
    $actuelles = [];
    foreach ($contenu['lignes'] as $l) {
        $actuelles[$l['uid']] = true;
    }
    $parPoste = [];
    $ids = [];
    foreach (array_merge($contenu['lignes'], $avant) as $l) {
        $ids[] = (int) ($l['produitId'] ?? 0);
        foreach ((array) ($l['composants'] ?? []) as $c) {
            $ids[] = (int) ($c['produitId'] ?? 0);
        }
    }
    $postes = restaurant_postes(array_values(array_unique($ids)));
    // Un combo part en préparation article par article, chacun vers son poste.
    $ajouter = function (array $l, float $qte, ?string $note) use (&$parPoste, $postes): void {
        $articles = !empty($l['composants'])
            ? array_map(fn($c) => ['id' => (int) $c['produitId'], 'libelle' => $c['nom'] . ' (' . $l['nom'] . ')', 'qte' => $qte * (float) $c['qte']], $l['composants'])
            : [['id' => (int) $l['produitId'], 'libelle' => $l['nom'], 'qte' => $qte]];
        foreach ($articles as $a) {
            $poste = $postes[$a['id']] ?? 'Cuisine';
            if ($poste !== 'Aucun') {
                $parPoste[$poste][] = ['libelle' => mb_substr($a['libelle'], 0, 200), 'qte' => $a['qte'], 'note' => $note];
            }
        }
    };
    foreach ($contenu['lignes'] as &$l) {
        $delta = round($l['qte'] - $l['envoye'], 2);
        if (abs($delta) >= 0.01) {
            $ajouter($l, $delta, $l['note'] ?: null);
        }
        $l['envoye'] = $l['qte'];
    }
    unset($l);
    // Lignes supprimées après l'envoi : annulation.
    foreach ($avant as $l) {
        if (!isset($actuelles[$l['uid'] ?? '']) && (float) ($l['envoye'] ?? 0) > 0) {
            $ajouter($l, -(float) $l['envoye'], null);
        }
    }
    $ids = [];
    foreach ($parPoste as $poste => $lignes) {
        $numero = (int) qv('SELECT COUNT(*) FROM BonsPreparation WHERE JourneeCaisseId = ?', [$co['JourneeCaisseId']]) + 1;
        $id = run(
            'INSERT INTO BonsPreparation (TenantId, CaisseId, JourneeCaisseId, CommandeOuverteId, Numero, Poste, TableNom, Couverts, Serveur, DateEnvoi)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())',
            [$co['TenantId'], $co['CaisseId'], $co['JourneeCaisseId'], $co['Id'] ?: null, $numero, $poste, $tableNom, $co['Couverts'] ?: null, $serveur]
        );
        foreach ($lignes as $l) {
            run('INSERT INTO LignesBonPreparation (BonPreparationId, Libelle, Quantite, Note) VALUES (?, ?, ?, ?)', [$id, $l['libelle'], $l['qte'], $l['note']]);
        }
        $ids[] = $id;
    }
    return $ids;
}
