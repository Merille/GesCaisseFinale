<?php
// Laverie : dépôts de linge payés au retrait (table DepotsLinge). Au dépôt, la commande est
// enregistrée avec un numéro, le client, son téléphone, la date de retrait prévue et un acompte
// facultatif (encaissé dans la journée du dépôt) ; un ticket « NON PAYÉ » est imprimé en deux
// exemplaires (client et souche jointe au linge). Le dépôt ne bloque pas la clôture de la journée.
// Au retrait, il est encaissé dans la journée du jour comme une vente (acompte déduit).
// Statuts : En cours → Prêt → Retiré ; ou Annulé (acompte remboursé).

const DEPOT_LINGE_ACTIFS = ['En cours', 'Prêt'];

/**
 * Lignes d'un ticket reçu de l'écran de vente, reprises du catalogue : nom, taux et prix du produit
 * actif (prix du combo plus les suppléments choisis) ; prix saisi accepté pour un administrateur
 * seulement, comme à l'encaissement. Les composants gardent leur groupe (contrôlés à l'encaissement).
 */
function pos_lignes_catalogue(array $saisies, int $tenant): array
{
    $lignes = [];
    foreach (restaurant_lignes_saisies($saisies, []) as $l) {
        $p = q1('SELECT * FROM Produits WHERE Id = ? AND TenantId = ? AND Actif = 1', [$l['produitId'], $tenant]);
        if (!$p || $l['qte'] <= 0 || $p['EstModele']) {
            continue;
        }
        $prix = (float) $p['PrixVente'];
        if ($p['EstCombo']) {
            $r = combo_composants($p, $l['composants']);
            if (is_array($r)) {
                $prix += $r[1];
            }
        }
        $l['nom'] = $p['Nom'];
        $l['tva'] = (float) $p['TauxTVA'];
        $l['unite'] = (string) ($p['Unite'] ?? '');
        $l['prix'] = is_admin() ? $l['prix'] : $prix;
        $lignes[] = $l;
    }
    return $lignes;
}

/** Remise globale saisie, si l'utilisateur y a droit : { type: pct|montant, valeur } ou null. */
function pos_remise_saisie(mixed $r): ?array
{
    return is_array($r) && (float) ($r['valeur'] ?? 0) > 0 && pos_peut_remise_globale()
        ? ['type' => ($r['type'] ?? '') === 'pct' ? 'pct' : 'montant', 'valeur' => (float) $r['valeur']] : null;
}

/** Motif des acomptes de laverie (créé au besoin). */
function laverie_motif(int $tenant): int
{
    return (int) (qv("SELECT ID FROM Motifs WHERE LibelleMotif = 'Acompte laverie' AND TenantId = ?", [$tenant])
        ?: run("INSERT INTO Motifs (LibelleMotif, TypeModif, TenantId) VALUES ('Acompte laverie', 'Client', ?)", [$tenant]));
}

/** Journée ouverte d'une caisse Laverie, pour un dépôt (sinon réponse d'erreur). */
function laverie_journee(int $id): array
{
    $journee = q1('SELECT j.*, c.TypePointVente FROM JourneesCaisses j JOIN Caisses c ON c.ID = j.CaisseId WHERE j.Id = ? AND ' . tf('j'), [$id]);
    if (!$journee) {
        pos_json(['erreur' => 'Journée introuvable.'], 404);
    }
    if ($journee['TypePointVente'] !== 'Laverie') {
        pos_json(['erreur' => 'Les dépôts de linge sont réservés aux caisses de type Laverie.'], 400);
    }
    if ($journee['Statut'] !== 'Ouverte') {
        pos_json(['erreur' => 'Cette journée est clôturée : ouvrez une nouvelle journée.'], 409);
    }
    return $journee;
}

/** Enregistre un dépôt de linge (articles, client, retrait prévu, acompte). Répond { id, numero }. */
function pos_deposer(): void
{
    $s = pos_saisie();
    $journee = laverie_journee((int) ($s['journeeId'] ?? 0));
    $tenant = (int) $journee['TenantId'];
    // Nouvel envoi après une coupure réseau : le dépôt déjà enregistré est renvoyé.
    $cle = substr(preg_replace('/[^A-Za-z0-9-]/', '', (string) ($s['cle'] ?? '')), 0, 64) ?: null;
    if ($cle && ($deja = q1('SELECT Id, Numero FROM DepotsLinge WHERE TenantId = ? AND CleClient = ?', [$tenant, $cle]))) {
        pos_json(['id' => (int) $deja['Id'], 'numero' => (int) $deja['Numero']]);
    }
    $lignes = pos_lignes_catalogue((array) ($s['lignes'] ?? []), $tenant);
    if (!$lignes) {
        pos_json(['erreur' => 'Le ticket est vide.'], 400);
    }
    $remise = pos_remise_saisie($s['remise'] ?? null);
    $total = restaurant_total(['lignes' => $lignes, 'remise' => $remise]);
    $nom = pos_texte($s['nom'] ?? null, 100);
    $telephone = pos_texte($s['telephone'] ?? null, 30);
    if (!$nom || !$telephone) {
        pos_json(['erreur' => 'Indiquez le nom et le téléphone du client.'], 400);
    }
    $retrait = (string) ($s['retrait'] ?? '');
    $retrait = DateTime::createFromFormat('!Y-m-d', $retrait) ? $retrait : null;
    if ($retrait !== null && $retrait < date('Y-m-d')) {
        pos_json(['erreur' => 'La date de retrait prévue est déjà passée.'], 400);
    }
    $client = int_or_null($s['clientId'] ?? null);
    if ($client && !q1('SELECT Id FROM Clients WHERE Id = ? AND TenantId = ?', [$client, $tenant])) {
        $client = null;
    }
    $acompte = max(0, round((float) ($s['acompte'] ?? 0)));
    if ($acompte > $total) {
        pos_json(['erreur' => "L'acompte dépasse le total du dépôt (" . fcfa($total) . ' FCFA).'], 400);
    }
    $mode = null;
    if ($acompte > 0) {
        $mode = q1('SELECT Id, Libelle FROM ModesPaiement WHERE Id = ? AND TenantId = ? AND Actif = 1 AND EstCompte = 0', [(int) ($s['modeId'] ?? 0), $tenant]);
        if (!$mode) {
            pos_json(['erreur' => "Choisissez le mode de paiement de l'acompte."], 400);
        }
    }

    db()->beginTransaction();
    try {
        q('SELECT Id FROM JourneesCaisses WHERE Id = ? FOR UPDATE', [$journee['Id']]);
        $numero = (int) qv('SELECT COALESCE(MAX(Numero), 0) FROM DepotsLinge WHERE TenantId = ?', [$tenant]) + 1;
        $operation = null;
        if ($acompte > 0) {
            $operation = run(
                "INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle,
                    ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
                 VALUES (?, ?, NOW(), 'Encaissement', ?, ?, ?, ?, ?, ?, 1, 'Validé', 'Point de vente')",
                [$tenant, $journee['Id'], $acompte, 'Acompte dépôt de linge n° ' . $numero . ' (' . $nom . ')', $client, laverie_motif($tenant), $mode['Id'], user()['id']]
            );
        }
        $id = run(
            "INSERT INTO DepotsLinge (TenantId, CaisseId, JourneeCaisseId, Numero, CleClient, DateDepot, DateRetraitPrevue, NomClient, TelephoneClient,
                ClientId, UtilisateurId, Contenu, Total, NbArticles, Acompte, AcompteModePaiementId, AcompteOperationId, Statut)
             VALUES (?, ?, ?, ?, ?, NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'En cours')",
            [$tenant, $journee['CaisseId'], $journee['Id'], $numero, $cle, $retrait, $nom, $telephone, $client, user()['id'],
             json_encode(['lignes' => $lignes, 'clientId' => $client, 'remise' => $remise], JSON_UNESCAPED_UNICODE),
             $total, array_sum(array_column($lignes, 'qte')), $acompte, $mode['Id'] ?? null, $operation]
        );
        db()->commit();
    } catch (Throwable $e) {
        db()->rollBack();
        throw $e;
    }
    pos_json(['id' => (int) $id, 'numero' => $numero]);
}

/** Dépôt de linge au format de l'écran de vente. */
function laverie_depot_json(array $d): array
{
    $actif = in_array($d['Statut'], DEPOT_LINGE_ACTIFS, true);
    return [
        'id' => (int) $d['Id'], 'numero' => (int) $d['Numero'], 'nom' => $d['NomClient'], 'telephone' => $d['TelephoneClient'],
        'depose' => date('d/m/Y H:i', strtotime($d['DateDepot'])),
        'retrait' => $d['DateRetraitPrevue'] ? date('d/m/Y', strtotime($d['DateRetraitPrevue'])) : null,
        'enRetard' => $actif && $d['DateRetraitPrevue'] && $d['DateRetraitPrevue'] < date('Y-m-d'),
        'jours' => (int) floor((time() - strtotime(substr($d['DateDepot'], 0, 10))) / 86400),
        'articles' => (float) $d['NbArticles'], 'total' => (float) $d['Total'], 'acompte' => (float) $d['Acompte'],
        'reste' => max(0, (float) $d['Total'] - (float) $d['Acompte']), 'statut' => $d['Statut'],
        'retire' => $d['DateRetrait'] ? date('d/m/Y H:i', strtotime($d['DateRetrait'])) : null,
        'venteId' => $d['CommandePosId'] !== null ? (int) $d['CommandePosId'] : null,
        'contenu' => $actif ? json_decode((string) $d['Contenu'], true) : null,
    ];
}

/** Dépôts de linge de la société : en cours et prêts, puis retirés ou annulés depuis 30 jours. */
function pos_depots(): void
{
    $journee = q1('SELECT TenantId FROM JourneesCaisses WHERE Id = ? AND ' . tf(), [(int) get('journee')]);
    if (!$journee) {
        pos_json(['erreur' => 'Journée introuvable.'], 404);
    }
    $depots = q("SELECT * FROM DepotsLinge WHERE TenantId = ? AND (Statut IN ('En cours', 'Prêt')
                    OR COALESCE(DateRetrait, DateAnnulation) >= DATE_SUB(CURDATE(), INTERVAL 30 DAY))
                 ORDER BY Statut IN ('En cours', 'Prêt') DESC, Numero DESC LIMIT 300", [$journee['TenantId']]);
    pos_json(['depots' => array_map('laverie_depot_json', $depots)]);
}

/** Dépôt de linge actif de la société, verrouillé (dans une transaction), sinon réponse d'erreur. */
function laverie_depot_actif(int $id): array
{
    $d = q1('SELECT * FROM DepotsLinge WHERE Id = ? AND ' . tf() . ' FOR UPDATE', [$id]);
    if (!$d || !in_array($d['Statut'], DEPOT_LINGE_ACTIFS, true)) {
        if (db()->inTransaction()) {
            db()->rollBack();
        }
        pos_json(['erreur' => 'Ce dépôt a déjà été retiré ou annulé.'], 409);
    }
    return $d;
}

/** Linge prêt (client à prévenir), ou remis « En cours ». */
function pos_depotpret(): void
{
    $s = pos_saisie();
    db()->beginTransaction();
    $d = laverie_depot_actif((int) ($s['id'] ?? 0));
    if ($d['Statut'] === 'En cours') {
        run("UPDATE DepotsLinge SET Statut = 'Prêt', DatePret = NOW() WHERE Id = ?", [$d['Id']]);
    } else {
        run("UPDATE DepotsLinge SET Statut = 'En cours', DatePret = NULL WHERE Id = ?", [$d['Id']]);
    }
    db()->commit();
    pos_json(['statut' => $d['Statut'] === 'En cours' ? 'Prêt' : 'En cours']);
}

/**
 * Annulation d'un dépôt (administrateurs et utilisateurs autorisés à valider) : l'acompte éventuel
 * est remboursé par un décaissement dans la journée ouverte du poste.
 */
function pos_depotannuler(): void
{
    $s = pos_saisie();
    if (!pos_peut_remise_globale()) {
        pos_json(['erreur' => "L'annulation d'un dépôt est réservée aux administrateurs et aux utilisateurs autorisés à valider."], 403);
    }
    $journee = laverie_journee((int) ($s['journeeId'] ?? 0));
    db()->beginTransaction();
    $d = laverie_depot_actif((int) ($s['id'] ?? 0));
    if ((float) $d['Acompte'] > 0) {
        run(
            "INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle,
                ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
             VALUES (?, ?, NOW(), 'Décaissement', ?, ?, ?, ?, ?, ?, 1, 'Validé', 'Point de vente')",
            [$d['TenantId'], $journee['Id'], $d['Acompte'], 'Remboursement acompte dépôt de linge n° ' . $d['Numero'] . ' (' . $d['NomClient'] . ')',
             $d['ClientId'], laverie_motif((int) $d['TenantId']), $d['AcompteModePaiementId'], user()['id']]
        );
    }
    run("UPDATE DepotsLinge SET Statut = 'Annulé', DateAnnulation = NOW() WHERE Id = ?", [$d['Id']]);
    db()->commit();
    pos_json(['ok' => true, 'rembourse' => (float) $d['Acompte']]);
}

/** Ticket de dépôt 80 mm « NON PAYÉ » : exemplaire client et souche jointe au linge. */
function pos_ticketdepot(): void
{
    $d = q1('SELECT dl.*, s.Nom AS Societe, u.NomComplet AS Utilisateur, m.Libelle AS ModeAcompte
             FROM DepotsLinge dl LEFT JOIN Tenants s ON s.Id = dl.TenantId LEFT JOIN Utilisateurs u ON u.Id = dl.UtilisateurId
             LEFT JOIN ModesPaiement m ON m.Id = dl.AcompteModePaiementId
             WHERE dl.Id = ? AND ' . tf('dl'), [(int) get('id')]);
    if (!$d) {
        not_found('Dépôt introuvable.');
    }
    $contenu = json_decode((string) $d['Contenu'], true) ?: [];
    $societe = q1('SELECT * FROM Tenants WHERE Id = ?', [$d['TenantId']]);
    render('pos/ticketdepot', [
        'd' => $d,
        'lignes' => (array) ($contenu['lignes'] ?? []),
        'brut' => restaurant_total(['lignes' => (array) ($contenu['lignes'] ?? [])]),
        'logo' => $societe ? url_logo($societe) : null,
        'coordonnees' => $societe ? societe_coordonnees($societe) : [],
    ], false);
}
