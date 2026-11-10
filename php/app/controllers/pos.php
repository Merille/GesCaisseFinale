<?php
// Point de vente : choix de la journée ouverte, puis écran de vente plein écran.
// Boutique : les tickets en cours sont gardés dans le navigateur jusqu'au paiement.
// Restaurant / bar : plan de salle ; la commande de chaque table est gardée sur le serveur
// (partagée entre serveurs et appareils) jusqu'au paiement.

require_once __DIR__ . '/../restaurant.php';

function pos_index(): void
{
    $id = (int) get('journee', 0);
    if ($id === 0) {
        pos_choix();
        return;
    }

    $journee = q1(
        'SELECT j.*, c.ChkCode, c.ChkDescription, c.TypePointVente, c.ImprimerBons
         FROM JourneesCaisses j JOIN Caisses c ON c.ID = j.CaisseId
         WHERE j.Id = ? AND ' . tf('j'),
        [$id]
    );
    if (!$journee) {
        not_found('Journée introuvable.');
    }
    if ($journee['Statut'] !== 'Ouverte') {
        flash('warning', 'Cette journée est clôturée : ouvrez une nouvelle journée pour vendre.');
        redirect('pos/index');
    }

    // Catalogue de la société de la journée (aussi pour le SuperAdmin en mode « toutes »).
    $tenant = (int) $journee['TenantId'];
    $combos = combos_societe($tenant);
    // Stock affiché : celui des dépôts de la caisse (principal et secondaires).
    $depotsVente = depots_caisse((int) $journee['CaisseId']);
    $stocksDepot = array_column(q('SELECT ProduitId, SUM(Quantite) AS Quantite FROM StocksDepots WHERE DepotId IN ('
        . implode(',', array_fill(0, count($depotsVente), '?')) . ') GROUP BY ProduitId', $depotsVente), 'Quantite', 'ProduitId');
    $produits = array_map(fn($p) => [
        'id' => (int) $p['Id'],
        'code' => $p['Code'],
        'codeBarres' => $p['CodeBarres'],
        'nom' => $p['Nom'],
        'categorieId' => $p['CategorieId'] === null ? null : (int) $p['CategorieId'],
        'prix' => (float) $p['PrixVente'],
        'tva' => (float) $p['TauxTVA'],
        'suivi' => (bool) $p['SuiviStock'],
        'stock' => (float) ($stocksDepot[$p['Id']] ?? 0),
        'seuil' => $p['SeuilAlerte'] === null ? null : (float) $p['SeuilAlerte'],
        'unite' => $p['Unite'],
        'image' => url_image_produit($p),
        'parentId' => $p['ParentId'] === null ? null : (int) $p['ParentId'],
        'modele' => (bool) $p['EstModele'],
        'variante' => $p['LibelleVariante'],
        'combo' => $p['EstCombo'] ? array_map(fn($g) => ['id' => $g['id'], 'nom' => $g['nom'], 'quantite' => $g['quantite'], 'choix' => $g['choix']], $combos[(int) $p['Id']] ?? []) : null,
    ], q('SELECT p.* FROM Produits p LEFT JOIN Produits m ON m.Id = p.ParentId
          WHERE p.Actif = 1 AND p.TenantId = ? AND (p.ParentId IS NULL OR m.Actif = 1) ORDER BY p.Nom', [$tenant]));

    $categories = array_map(fn($c) => [
        'id' => (int) $c['Id'], 'nom' => $c['Nom'], 'couleur' => $c['Couleur'],
    ], q('SELECT Id, Nom, Couleur FROM Categories WHERE TenantId = ? ORDER BY Ordre, Nom', [$tenant]));

    // Clients en compte : solde dû et plafond de crédit (contrôle de la vente par compte).
    $soldes = compte_soldes($tenant);
    $clients = array_map(fn($c) => [
        'id' => (int) $c['Id'], 'nom' => $c['NomSociete'], 'code' => $c['CodeClient'], 'telephone' => $c['Telephone'], 'adresse' => $c['Adresse'],
        'compte' => (bool) $c['EnCompte'], 'du' => $soldes[(int) $c['Id']] ?? 0.0,
        'plafond' => $c['PlafondCredit'] === null ? null : (float) $c['PlafondCredit'],
    ], q('SELECT Id, NomSociete, CodeClient, Telephone, Adresse, EnCompte, PlafondCredit FROM Clients WHERE TenantId = ? ORDER BY NomSociete', [$tenant]));
    $livreurs = array_map(fn($l) => [
        'id' => (int) $l['Id'], 'nom' => $l['Nom'], 'telephone' => $l['Telephone'], 'moyen' => $l['MoyenLivraison'],
    ], q('SELECT Id, Nom, Telephone, MoyenLivraison FROM Livreurs WHERE Actif = 1 AND TenantId = ? ORDER BY Nom', [$tenant]));

    // « Espèces » : le seul mode sur lequel on peut rendre la monnaie ; « compte » : vente à crédit.
    $modes = array_map(fn($m) => [
        'id' => (int) $m['Id'], 'libelle' => (string) $m['Libelle'], 'especes' => pos_est_especes($m), 'compte' => (bool) $m['EstCompte'],
    ], q('SELECT Id, Code, Libelle, EstCompte FROM ModesPaiement WHERE Actif = 1 AND TenantId = ? ORDER BY Libelle', [$tenant]));

    $u = user();
    $donnees = [
        'cle' => 'gescaisse-pos:' . $tenant . ':' . $journee['Id'],
        'journee' => [
            'id' => (int) $journee['Id'],
            'caisse' => $journee['ChkCode'],
            'type' => $journee['TypePointVente'] ?: 'Boutique',
            'libelle' => $journee['ChkDescription'] . ' · Journée du ' . date_fr($journee['DateJournee']) . ' (ouverte)',
        ],
        'produits' => $produits,
        'categories' => $categories,
        'clients' => $clients,
        'livreurs' => $livreurs,
        'utilisateur' => ['nom' => $u['nomComplet'] ?: $u['nom'], 'profil' => $u['profil']],
        'peutModifierPrix' => is_admin(),
        // Vente par compte au-delà du plafond de crédit : administrateurs seulement.
        'peutDepasserPlafond' => is_admin(),
        // Frais de livraison proposés par défaut (modifiables à chaque vente).
        'fraisLivraison' => (float) qv('SELECT FraisLivraisonDefaut FROM Tenants WHERE Id = ?', [$tenant]),
        'peutRemiseGlobale' => pos_peut_remise_globale(),
        'urlFermer' => url('journee/details', ['id' => $journee['Id']]),
        'modes' => $modes,
        'urlVendre' => url('pos/vendre'),
        'urlTicket' => url('pos/ticket') . '&id=',
        'urlVentes' => url('vente/index', ['journee' => $journee['Id']]),
        // Commandes en attente (partagées entre postes) et livraisons.
        'urlAttentes' => url('pos/attentes', ['journee' => $journee['Id']]),
        'urlMettreEnAttente' => url('pos/mettreenattente'),
        'urlReprendre' => url('pos/reprendre'),
        'urlSupprimerAttente' => url('pos/supprimerattente'),
        'urlLivree' => url('pos/livree'),
        'venteSansStock' => vente_sans_stock($tenant),
        'jeton' => ['nom' => '_csrf', 'valeur' => csrf_token()],
        'restaurant' => caisse_est_restaurant($journee) ? [
            'type' => $journee['TypePointVente'],
            'imprimerBons' => (bool) $journee['ImprimerBons'],
            'salles' => restaurant_plan((int) $journee['CaisseId'], (int) $journee['Id']),
            'urlPlan' => url('pos/plan', ['journee' => $journee['Id']]),
            'urlCommande' => url('pos/commande', ['journee' => $journee['Id']]),
            'urlEnregistrer' => url('pos/enregistrer'),
            'urlEnvoyer' => url('pos/envoyer'),
            'urlTransferer' => url('pos/transferer'),
            'urlAddition' => url('pos/addition') . '&id=',
            'urlBons' => url('pos/bon') . '&ids=',
            'urlCuisine' => url('cuisine/index', ['caisse' => $journee['CaisseId']]),
        ] : null,
    ];
    render('pos/ecran', ['donnees' => $donnees], false);
}

/** Liste des journées ouvertes, pour choisir où vendre. */
function pos_choix(): void
{
    $journees = q(
        "SELECT j.Id, j.NumeroJournee, j.DateJournee, j.DateOuverture, c.ChkCode, c.ChkDescription
         FROM JourneesCaisses j JOIN Caisses c ON c.ID = j.CaisseId
         WHERE j.Statut = 'Ouverte' AND " . tf('j') . '
         ORDER BY j.DateJournee DESC, c.ChkCode'
    );
    render('pos/choix', ['journees' => $journees]);
}

function pos_json(array $reponse, int $code = 200): never
{
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($reponse, JSON_UNESCAPED_UNICODE);
    exit;
}

/**
 * Enregistre une vente payée : commande, lignes, règlements, un encaissement par
 * règlement dans la journée (motif « Vente POS ») et sortie de stock.
 * Reçoit le ticket en JSON (champ « vente ») ; répond en JSON.
 */
function pos_vendre(): void
{
    if (!is_post()) {
        pos_json(['erreur' => 'Requête invalide.'], 405);
    }
    $v = json_decode((string) ($_POST['vente'] ?? ''), true);
    if (!is_array($v) || empty($v['lignes']) || empty($v['paiements']) || empty($v['cle'])) {
        pos_json(['erreur' => 'Vente incomplète.'], 400);
    }
    $cle = substr(preg_replace('/[^A-Za-z0-9-]/', '', (string) $v['cle']), 0, 64);

    $journee = q1(
        'SELECT j.*, c.ChkCode, c.TypePointVente FROM JourneesCaisses j JOIN Caisses c ON c.ID = j.CaisseId WHERE j.Id = ? AND ' . tf('j'),
        [(int) ($v['journeeId'] ?? 0)]
    );
    if (!$journee) {
        pos_json(['erreur' => 'Journée introuvable.'], 404);
    }
    $tenant = (int) $journee['TenantId'];

    // Vente déjà enregistrée (nouvel envoi après une coupure réseau) : on la renvoie telle quelle.
    $deja = q1('SELECT Id, Numero FROM CommandesPos WHERE TenantId = ? AND CleClient = ?', [$tenant, $cle]);
    if ($deja) {
        pos_json(['id' => (int) $deja['Id'], 'numero' => $deja['Numero']]);
    }
    if ($journee['Statut'] !== 'Ouverte') {
        pos_json(['erreur' => 'Cette journée est clôturée : la vente ne peut pas être enregistrée.'], 409);
    }

    // Lignes : prix et taxes repris du catalogue ; prix saisi accepté pour un administrateur seulement.
    $lignes = [];
    $ttc = $tva = 0.0;
    foreach ($v['lignes'] as $l) {
        $p = q1('SELECT p.* FROM Produits p LEFT JOIN Produits m ON m.Id = p.ParentId
                 WHERE p.Id = ? AND p.TenantId = ? AND p.Actif = 1 AND (p.ParentId IS NULL OR m.Actif = 1)', [(int) ($l['produitId'] ?? 0), $tenant]);
        $qte = round((float) ($l['qte'] ?? 0), 2);
        if (!$p || $qte <= 0) {
            pos_json(['erreur' => 'Un article du ticket est introuvable, inactif ou de quantité nulle.'], 400);
        }
        if ($p['EstModele']) {
            pos_json(['erreur' => 'Choisissez une variante de « ' . $p['Nom'] . ' ».'], 400);
        }
        // Combo : composants contrôlés, prix du combo plus les suppléments des articles choisis.
        $composants = null;
        $prixCatalogue = (float) $p['PrixVente'];
        if ($p['EstCombo']) {
            $r = combo_composants($p, (array) ($l['composants'] ?? []));
            if (is_string($r)) {
                pos_json(['erreur' => $r], 400);
            }
            [$composants, $supplements] = $r;
            $prixCatalogue += $supplements;
        }
        $prix = is_admin() && isset($l['prix']) ? max(0, round((float) $l['prix'], 2)) : $prixCatalogue;
        $remise = min(100, max(0, round((float) ($l['remise'] ?? 0), 2)));
        $total = round($qte * $prix * (1 - $remise / 100));
        $taux = (float) $p['TauxTVA'];
        $ttc += $total;
        $tva += $total - $total / (1 + $taux / 100);
        $note = mb_substr(trim((string) ($l['note'] ?? '')), 0, 200) ?: null;
        $lignes[] = ['produit' => $p, 'qte' => $qte, 'prix' => $prix, 'remise' => $remise, 'taux' => $taux, 'total' => $total, 'part' => 0.0, 'note' => $note,
                     'composants' => $composants];
    }

    // Remise globale (administrateurs et utilisateurs autorisés à valider) : en % ou en montant,
    // répartie sur les lignes au prorata ; les totaux et les taxes portent sur le net.
    $remiseGlobale = 0.0;
    $tauxRemise = null;
    $rg = $v['remiseGlobale'] ?? null;
    if (is_array($rg) && (float) ($rg['valeur'] ?? 0) > 0 && $ttc > 0) {
        if (!pos_peut_remise_globale()) {
            pos_json(['erreur' => "La remise globale est réservée aux administrateurs et aux utilisateurs autorisés à valider."], 403);
        }
        $valeur = (float) $rg['valeur'];
        if (($rg['type'] ?? '') === 'pct') {
            $tauxRemise = min(100, round($valeur, 2));
            $remiseGlobale = round($ttc * $tauxRemise / 100);
        } else {
            $remiseGlobale = min($ttc, round($valeur));
        }
        $reste = $remiseGlobale;
        foreach ($lignes as $i => &$l) {
            $part = $i === array_key_last($lignes) ? $reste : min($reste, round($remiseGlobale * $l['total'] / $ttc));
            $l['part'] = $part;
            $l['total'] -= $part;
            $reste -= $part;
        }
        unset($l);
        $ttc = $tva = 0.0;
        foreach ($lignes as $l) {
            $ttc += $l['total'];
            $tva += $l['total'] - $l['total'] / (1 + $l['taux'] / 100);
        }
    }
    $tva = round($tva);

    // Restaurant / bar : pourboire (en plus du total), table et couverts de la commande servie.
    $pourboire = max(0, round((float) ($v['pourboire'] ?? 0)));
    $ouverte = is_array($v['commandeOuverte'] ?? null) ? $v['commandeOuverte'] : null;
    $tableNom = null;
    $couverts = null;

    // Règlements : seuls les espèces peuvent dépasser le reste à payer (monnaie rendue).
    $modes = [];
    foreach (q('SELECT Id, Code, Libelle, EstCompte FROM ModesPaiement WHERE Actif = 1 AND TenantId = ?', [$tenant]) as $m) {
        $modes[(int) $m['Id']] = $m;
    }
    $paiements = [];
    $recu = $especes = $parCompte = 0.0;
    foreach ($v['paiements'] as $pm) {
        $mode = $modes[(int) ($pm['modeId'] ?? 0)] ?? null;
        $montant = round((float) ($pm['montant'] ?? 0));
        if (!$mode || $montant <= 0) {
            pos_json(['erreur' => 'Mode de paiement invalide ou montant nul.'], 400);
        }
        $paiements[] = ['mode' => $mode, 'recu' => $montant, 'especes' => pos_est_especes($mode), 'compte' => (bool) $mode['EstCompte']];
        $recu += $montant;
        if ($mode['EstCompte']) {
            $parCompte += $montant;
        }
        if (pos_est_especes($mode)) {
            $especes += $montant;
        }
    }
    // Frais de livraison (commande à livrer) : en plus du total, hors taxes, comme le pourboire.
    $fraisLivraison = is_array($v['livraison'] ?? null) ? max(0, round((float) ($v['livraison']['frais'] ?? 0))) : 0.0;
    if ($recu < $ttc + $pourboire + $fraisLivraison) {
        pos_json(['erreur' => 'Le montant payé est inférieur au total.'], 400);
    }
    $rendu = $recu - $ttc - $pourboire - $fraisLivraison;
    if ($rendu > $especes) {
        pos_json(['erreur' => 'Seule la monnaie sur les espèces peut être rendue : le montant payé par les autres modes dépasse le total.'], 400);
    }

    $client = int_or_null($v['clientId'] ?? null);
    if ($client && !q1('SELECT Id FROM Clients WHERE Id = ? AND TenantId = ?', [$client, $tenant])) {
        $client = null;
    }
    // Paiement par compte : client en compte obligatoire (plafond contrôlé sous verrou, plus bas).
    if ($parCompte > 0) {
        $fiche = $client ? q1('SELECT NomSociete, EnCompte FROM Clients WHERE Id = ?', [$client]) : null;
        if (!$fiche) {
            pos_json(['erreur' => 'Le paiement par compte demande un client : choisissez le client sur le ticket.'], 400);
        }
        if (!$fiche['EnCompte']) {
            pos_json(['erreur' => '« ' . $fiche['NomSociete'] . " » n'est pas un client en compte : cochez « Client en compte » sur sa fiche (Tiers)."], 400);
        }
    }
    // Commande à livrer : livreur, destinataire, payée maintenant ou à la livraison.
    [$livraison, $erreurLivraison] = pos_controler_livraison($v['livraison'] ?? null, $tenant);
    if ($erreurLivraison) {
        pos_json(['erreur' => $erreurLivraison], 400);
    }
    // Payée à la livraison : le livreur est revenu, la commande est livrée.
    $livree = $livraison && $livraison['paiement'] === 'livraison';

    db()->beginTransaction();
    try {
        // Les encaissements du point de vente sont validés d'office (vente payée et justifiée par le ticket).
        // Verrou sur la journée : numéros de ticket consécutifs même avec plusieurs caisses ouvertes.
        q('SELECT Id FROM JourneesCaisses WHERE Id = ? FOR UPDATE', [$journee['Id']]);
        // Vente sans stock interdite (option de la société) : contrôle sous verrou des produits.
        if (!vente_sans_stock($tenant)) {
            $parProduit = [];
            foreach ($lignes as $l) {
                foreach ($l['composants'] ?: [['produitId' => (int) $l['produit']['Id'], 'qte' => 1]] as $c) {
                    $parProduit[(int) $c['produitId']] = ($parProduit[(int) $c['produitId']] ?? 0) + $l['qte'] * (float) $c['qte'];
                }
            }
            // Stock des dépôts de la caisse (principal et secondaires).
            $depotsVente = depots_caisse((int) $journee['CaisseId']);
            foreach ($parProduit as $pid => $qte) {
                $p = q1('SELECT Nom, SuiviStock FROM Produits WHERE Id = ? FOR UPDATE', [$pid]);
                $dispo = stock_caisse((int) $pid, $depotsVente);
                if ($p['SuiviStock'] && $dispo < $qte - 0.001) {
                    db()->rollBack();
                    pos_json(['erreur' => 'Stock insuffisant pour « ' . $p['Nom'] . ' » : ' . quantite_fr($dispo) . ' disponible(s).'], 409);
                }
            }
        }
        // Vente par compte : plafond de crédit (sauf administrateur), sous verrou du client.
        if ($parCompte > 0) {
            $fiche = q1('SELECT NomSociete, PlafondCredit FROM Clients WHERE Id = ? FOR UPDATE', [$client]);
            $du = compte_solde($tenant, $client);
            if ($fiche['PlafondCredit'] !== null && !is_admin() && $du + $parCompte > (float) $fiche['PlafondCredit'] + 0.001) {
                db()->rollBack();
                pos_json(['erreur' => 'Plafond de crédit dépassé pour « ' . $fiche['NomSociete'] . ' » : solde dû ' . fcfa($du) . ' FCFA, plafond '
                    . fcfa($fiche['PlafondCredit']) . ' FCFA (encore ' . fcfa(max(0, (float) $fiche['PlafondCredit'] - $du)) . ' FCFA possibles).'], 409);
            }
        }
        // Commande de table : payée en entier (table libérée) ou en partie (addition partagée : le
        // reste des articles demeure sur la table).
        $commandeRestante = null;
        if ($ouverte) {
            $co = q1('SELECT co.*, t.Nom AS TableNom FROM CommandesOuvertes co LEFT JOIN TablesRestaurant t ON t.Id = co.TableId
                      WHERE co.Id = ? AND co.JourneeCaisseId = ? FOR UPDATE', [(int) ($ouverte['id'] ?? 0), $journee['Id']]);
            if (!$co || (int) $co['Version'] !== (int) ($ouverte['version'] ?? 0)) {
                db()->rollBack();
                pos_json(['erreur' => 'La commande de la table a été modifiée sur un autre appareil : rechargez la table puis recommencez.'], 409);
            }
            $tableNom = $co['TableNom'];
            $couverts = (int) $co['Couverts'];
            $avant = restaurant_contenu($co['Contenu']);
            $reste = restaurant_lignes_saisies((array) ($ouverte['reste'] ?? []), $avant['lignes']);
            if (!$reste) {
                run('UPDATE BonsPreparation SET CommandeOuverteId = NULL WHERE CommandeOuverteId = ?', [$co['Id']]);
                run('DELETE FROM CommandesOuvertes WHERE Id = ?', [$co['Id']]);
            } else {
                foreach ($reste as &$r) {
                    $r['envoye'] = min($r['envoye'], $r['qte']);
                }
                unset($r);
                $avant['lignes'] = $reste;
                run('UPDATE CommandesOuvertes SET Contenu = ?, Version = Version + 1, DateMaj = NOW(), AdditionImprimee = 0 WHERE Id = ?',
                    [json_encode($avant, JSON_UNESCAPED_UNICODE), $co['Id']]);
                $commandeRestante = (int) $co['Id'];
            }
        }

        $rang = (int) qv('SELECT COUNT(*) FROM CommandesPos WHERE JourneeCaisseId = ?', [$journee['Id']]) + 1;
        $numero = sprintf('POS-%s-%s-%04d', $journee['ChkCode'], date('Ymd', strtotime($journee['DateJournee'])), $rang);

        $commandeId = run(
            "INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande,
                TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut, RemiseGlobale, RemiseGlobaleTaux, TableNom, Couverts, Pourboire,
                LivreurId, NomLivraison, TelephoneLivraison, AdresseLivraison, StatutLivraison, DateLivraison, FraisLivraison)
             VALUES (?, ?, ?, ?, ?, ?, NOW(), ?, ?, ?, ?, ?, 'Payée', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, " . ($livree ? 'NOW()' : 'NULL') . ", ?)",
            [$tenant, $numero, $cle, $journee['Id'], $client, user()['id'], $ttc - $tva, $tva, $ttc, $recu, $rendu, $remiseGlobale, $tauxRemise, $tableNom, $couverts, $pourboire,
             $livraison['livreurId'] ?? null, $livraison['nom'] ?? null, $livraison['telephone'] ?? null, $livraison['adresse'] ?? null,
             $livraison ? ($livree ? 'Livrée' : 'À livrer') : null, $livraison ? $fraisLivraison : 0]
        );
        foreach ($lignes as $l) {
            $ligneId = run(
                'INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC, RemiseGlobale, Note, Composants)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [$tenant, $commandeId, $l['produit']['Id'], $l['produit']['Nom'], $l['qte'], $l['prix'], $l['remise'], $l['taux'], $l['total'], $l['part'], $l['note'],
                 $l['composants'] ? json_encode($l['composants'], JSON_UNESCAPED_UNICODE) : null]
            );
            ligne_enregistrer_taxes($ligneId, produit_taxes((int) $l['produit']['Id']), $l['total'], $tenant);
            ligne_sortie_stock(['ProduitId' => $l['produit']['Id'], 'Composants' => $l['composants'] ? json_encode($l['composants']) : null], $l['qte'], $numero, $commandeId,
                $depotsVente ??= depots_caisse((int) $journee['CaisseId']));
        }

        $motif = qv("SELECT ID FROM Motifs WHERE LibelleMotif = 'Vente POS' AND TenantId = ?", [$tenant])
            ?: run("INSERT INTO Motifs (LibelleMotif, TypeModif, TenantId) VALUES ('Vente POS', 'Client', ?)", [$tenant]);

        $aRendre = $rendu;
        foreach ($paiements as $pm) {
            $net = $pm['recu'];
            if ($pm['especes'] && $aRendre > 0) {
                $deduit = min($aRendre, $net);
                $net -= $deduit;
                $aRendre -= $deduit;
            }
            $operation = null;
            // Paiement par compte : pas d'encaissement en caisse, le montant s'ajoute au solde dû.
            if ($net > 0 && !$pm['compte']) {
                $operation = run(
                    "INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle,
                        ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
                     VALUES (?, ?, NOW(), 'Encaissement', ?, ?, ?, ?, ?, ?, 1, 'Validé', 'Point de vente')",
                    [$tenant, $journee['Id'], $net, 'Vente POS ' . $numero . ($pourboire > 0 ? ' (dont pourboire ' . fcfa($pourboire) . ')' : '')
                        . ($livraison && $fraisLivraison > 0 ? ' (dont frais de livraison ' . fcfa($fraisLivraison) . ')' : ''), $client, $motif, $pm['mode']['Id'], user()['id']]
                );
            }
            run(
                'INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
                 VALUES (?, ?, ?, ?, ?, ?, ?)',
                [$tenant, $commandeId, $pm['mode']['Id'], (string) $pm['mode']['Libelle'], $pm['recu'], $net, $operation]
            );
        }
        // Vente directe d'une caisse restaurant / bar : à l'encaissement, les articles partent en
        // préparation (un bon par poste, comme pour une table).
        $bons = [];
        if (!$ouverte && in_array($journee['TypePointVente'], RESTAURANT_TYPES, true)) {
            $contenu = ['lignes' => array_map(fn($l, $i) => [
                'uid' => (string) $i, 'produitId' => (int) $l['produit']['Id'], 'nom' => $l['produit']['Nom'], 'qte' => $l['qte'], 'envoye' => 0,
                'note' => $l['note'], 'composants' => $l['composants'] ?: [],
            ], $lignes, array_keys($lignes))];
            $bons = restaurant_envoyer(['TenantId' => $tenant, 'CaisseId' => $journee['CaisseId'], 'JourneeCaisseId' => $journee['Id'], 'Id' => null, 'Couverts' => null],
                $contenu, [], 'Vente directe · ticket ' . $rang, pos_serveur());
        }
        db()->commit();
    } catch (Throwable $e) {
        db()->rollBack();
        error_log('[GesCaisse POS] ' . $e->getMessage());
        pos_json(['erreur' => "La vente n'a pas pu être enregistrée. Réessayez."], 500);
    }

    pos_json(['id' => $commandeId, 'numero' => $numero, 'rendu' => $rendu, 'bons' => $bons,
              'commande' => !empty($commandeRestante) ? restaurant_commande_json(q1('SELECT * FROM CommandesOuvertes WHERE Id = ?', [$commandeRestante])) : null]);
}

/** Ticket de caisse 80 mm d'une vente (impression ou réimpression). */
function pos_ticket(): void
{
    $commande = q1(
        'SELECT cmd.*, j.DateJournee, c.ChkCode, c.ChkDescription, t.Nom AS Societe, t.Adresse, t.Ville, t.Pays,
                t.Email AS EmailSociete, t.Telephone, t.NIF, t.LogoMaj,
                u.NomComplet AS Vendeur, cl.NomSociete AS Client, o.Numero AS NumeroOrigine, lv.Nom AS Livreur, lv.MoyenLivraison AS MoyenLivreur
         FROM CommandesPos cmd
         LEFT JOIN Livreurs lv ON lv.Id = cmd.LivreurId
         LEFT JOIN CommandesPos o ON o.Id = cmd.CommandeOrigineId
         JOIN JourneesCaisses j ON j.Id = cmd.JourneeCaisseId
         JOIN Caisses c ON c.ID = j.CaisseId
         LEFT JOIN Tenants t ON t.Id = cmd.TenantId
         LEFT JOIN Utilisateurs u ON u.Id = cmd.UtilisateurId
         LEFT JOIN Clients cl ON cl.Id = cmd.ClientId
         WHERE cmd.Id = ? AND ' . tf('cmd'),
        [(int) get('id')]
    );
    if (!$commande) {
        not_found('Ticket introuvable.');
    }
    $lignes = q('SELECT l.*, p.Unite FROM LignesCommandePos l LEFT JOIN Produits p ON p.Id = l.ProduitId WHERE l.CommandePosId = ? ORDER BY l.Id', [$commande['Id']]);
    // En-tête : logo et coordonnées de la société.
    $societe = ['Id' => $commande['TenantId'], 'LogoMaj' => $commande['LogoMaj'], 'Adresse' => $commande['Adresse'], 'Ville' => $commande['Ville'],
                'Pays' => $commande['Pays'], 'Email' => $commande['EmailSociete'], 'Telephone' => $commande['Telephone'], 'NIF' => $commande['NIF']];
    render('pos/ticket', [
        'commande' => $commande,
        'lignes' => $lignes,
        'paiements' => q('SELECT * FROM PaiementsPos WHERE CommandePosId = ? ORDER BY Id', [$commande['Id']]),
        // Vente ou retour par compte : solde dû du client (à la date d'impression).
        'soldeCompte' => $commande['ClientId'] && qv('SELECT COUNT(*) FROM PaiementsPos p JOIN ModesPaiement m ON m.Id = p.ModePaiementId
                                                       WHERE p.CommandePosId = ? AND m.EstCompte = 1', [$commande['Id']])
            ? compte_solde((int) $commande['TenantId'], (int) $commande['ClientId']) : null,
        'taxes' => vente_taxes((int) $commande['Id']),
        'logo' => url_logo($societe),
        'coordonnees' => societe_coordonnees($societe),
        'imprimer' => get('imprimer') === '1',
    ], false);
}

// ---------------------------------------------------------------------------
// Restaurant / bar : commandes ouvertes sur les tables
// ---------------------------------------------------------------------------

/** Journée ouverte d'une caisse restaurant / bar (réponse JSON d'erreur sinon). */
function pos_journee_restaurant(int $id): array
{
    $journee = q1('SELECT j.*, c.ChkCode, c.TypePointVente, c.ImprimerBons FROM JourneesCaisses j JOIN Caisses c ON c.ID = j.CaisseId
                   WHERE j.Id = ? AND ' . tf('j'), [$id]);
    if (!$journee) {
        pos_json(['erreur' => 'Journée introuvable.'], 404);
    }
    if (!caisse_est_restaurant($journee)) {
        pos_json(['erreur' => "Cette caisse n'est pas de type Restaurant ou Bar."], 400);
    }
    if ($journee['Statut'] !== 'Ouverte') {
        pos_json(['erreur' => 'Cette journée est clôturée : ouvrez une nouvelle journée pour servir.'], 409);
    }
    return $journee;
}

/** Table d'une caisse (réponse JSON d'erreur sinon). */
function pos_table(int $id, int $caisseId): array
{
    $table = q1('SELECT t.* FROM TablesRestaurant t JOIN Salles s ON s.Id = t.SalleId WHERE t.Id = ? AND s.CaisseId = ? AND t.Actif = 1', [$id, $caisseId]);
    if (!$table) {
        pos_json(['erreur' => 'Table introuvable.'], 404);
    }
    return $table;
}

/** Données JSON envoyées par l'écran de vente (champ « commande »). */
function pos_saisie(): array
{
    if (!is_post()) {
        pos_json(['erreur' => 'Requête invalide.'], 405);
    }
    $c = json_decode((string) ($_POST['commande'] ?? ''), true);
    if (!is_array($c)) {
        pos_json(['erreur' => 'Commande illisible.'], 400);
    }
    return $c;
}

function pos_serveur(): string
{
    $u = user();
    return (string) ($u['nomComplet'] ?: $u['nom']);
}

/** État des tables (plan de salle), pour l'actualisation de l'écran de vente. */
function pos_plan(): void
{
    $journee = pos_journee_restaurant((int) get('journee'));
    pos_json(['salles' => restaurant_plan((int) $journee['CaisseId'], (int) $journee['Id'])]);
}

/** Commande en cours sur une table (null si la table est libre). */
function pos_commande(): void
{
    $journee = pos_journee_restaurant((int) get('journee'));
    $table = pos_table((int) get('table'), (int) $journee['CaisseId']);
    $co = q1('SELECT * FROM CommandesOuvertes WHERE TableId = ?', [$table['Id']]);
    pos_json(['commande' => $co ? restaurant_commande_json($co) : null]);
}

/**
 * Enregistre la commande d'une table : création à la première ligne, mise à jour ensuite
 * (refusée si la commande a changé entre-temps sur un autre appareil), suppression quand
 * elle est vidée. Avec $envoyer : bons de préparation des articles pas encore envoyés.
 * Renvoie [commande à jour ou null, Id des bons].
 */
function pos_enregistrer_commande(array $c, bool $envoyer): array
{
    $journee = pos_journee_restaurant((int) ($c['journeeId'] ?? 0));
    $table = pos_table((int) ($c['tableId'] ?? 0), (int) $journee['CaisseId']);
    $couverts = max(1, min(99, (int) ($c['couverts'] ?? 1)));
    $bons = [];
    db()->beginTransaction();
    try {
        $co = q1('SELECT * FROM CommandesOuvertes WHERE TableId = ? FOR UPDATE', [$table['Id']]);
        $id = (int) ($c['id'] ?? 0);
        if ($co && ((int) $co['Id'] !== $id || (int) $co['Version'] !== (int) ($c['version'] ?? 0))) {
            db()->rollBack();
            pos_json(['erreur' => 'La commande de ' . $table['Nom'] . ' a été modifiée sur un autre appareil : elle a été rechargée.',
                      'commande' => restaurant_commande_json($co)], 409);
        }
        if (!$co && $id > 0) {
            db()->rollBack();
            pos_json(['erreur' => 'La commande de ' . $table['Nom'] . " n'existe plus (encaissée ou transférée sur un autre appareil).", 'commande' => null], 409);
        }
        $avant = $co ? restaurant_contenu($co['Contenu']) : ['lignes' => []];
        $contenu = restaurant_contenu(restaurant_contenu_saisi($c, $avant));
        $vide = !$contenu['lignes'];
        if (!$co && $vide) {
            db()->commit();
            return [null, []];
        }
        if (!$co) {
            $id = run(
                'INSERT INTO CommandesOuvertes (TenantId, CaisseId, JourneeCaisseId, TableId, Couverts, UtilisateurId, DateOuverture, DateMaj, Version, Contenu)
                 VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW(), 0, ?)',
                [$journee['TenantId'], $journee['CaisseId'], $journee['Id'], $table['Id'], $couverts, user()['id'], json_encode($contenu, JSON_UNESCAPED_UNICODE)]
            );
            $co = q1('SELECT * FROM CommandesOuvertes WHERE Id = ?', [$id]);
        }
        // Commande vidée : annulation en préparation des articles déjà envoyés, puis table libérée.
        if ($vide) {
            $bons = restaurant_envoyer($co, $contenu, $avant['lignes'], $table['Nom'], pos_serveur());
            run('UPDATE BonsPreparation SET CommandeOuverteId = NULL WHERE CommandeOuverteId = ?', [$co['Id']]);
            run('DELETE FROM CommandesOuvertes WHERE Id = ?', [$co['Id']]);
            db()->commit();
            return [null, $bons];
        }
        if ($envoyer) {
            $bons = restaurant_envoyer($co, $contenu, $avant['lignes'], $table['Nom'], pos_serveur());
        }
        $json = json_encode($contenu, JSON_UNESCAPED_UNICODE);
        // L'addition imprimée n'est plus à jour quand les articles changent.
        $addition = $json === json_encode(restaurant_contenu($co['Contenu']), JSON_UNESCAPED_UNICODE) && (int) $co['Couverts'] === $couverts ? (int) $co['AdditionImprimee'] : 0;
        run('UPDATE CommandesOuvertes SET Contenu = ?, Couverts = ?, Version = Version + 1, DateMaj = NOW(), AdditionImprimee = ? WHERE Id = ?',
            [$json, $couverts, $addition, $co['Id']]);
        db()->commit();
    } catch (Throwable $e) {
        if (db()->inTransaction()) {
            db()->rollBack();
        }
        throw $e;
    }
    return [restaurant_commande_json(q1('SELECT * FROM CommandesOuvertes WHERE Id = ?', [$co['Id']])), $bons];
}

function pos_enregistrer(): void
{
    [$commande] = pos_enregistrer_commande(pos_saisie(), false);
    pos_json(['commande' => $commande]);
}

/** Enregistre la commande et envoie les nouveaux articles en cuisine / au bar. */
function pos_envoyer(): void
{
    [$commande, $bons] = pos_enregistrer_commande(pos_saisie(), true);
    pos_json(['commande' => $commande, 'bons' => $bons]);
}

/** Transfère la commande vers une autre table (fusionnée avec sa commande si elle est occupée). */
function pos_transferer(): void
{
    $c = pos_saisie();
    $journee = pos_journee_restaurant((int) ($c['journeeId'] ?? 0));
    $cible = pos_table((int) ($c['cibleId'] ?? 0), (int) $journee['CaisseId']);
    db()->beginTransaction();
    try {
        $co = q1('SELECT * FROM CommandesOuvertes WHERE Id = ? AND CaisseId = ? FOR UPDATE', [(int) ($c['id'] ?? 0), $journee['CaisseId']]);
        if (!$co || (int) $co['Version'] !== (int) ($c['version'] ?? 0)) {
            db()->rollBack();
            pos_json(['erreur' => 'La commande a été modifiée sur un autre appareil : rechargez la table puis recommencez.'], 409);
        }
        if ((int) $co['TableId'] === (int) $cible['Id']) {
            db()->rollBack();
            pos_json(['commande' => restaurant_commande_json($co)]);
        }
        $existante = q1('SELECT * FROM CommandesOuvertes WHERE TableId = ? FOR UPDATE', [$cible['Id']]);
        if ($existante) {
            // Fusion : les lignes et les couverts s'ajoutent à la commande de la table choisie.
            $a = restaurant_contenu($existante['Contenu']);
            $b = restaurant_contenu($co['Contenu']);
            $a['lignes'] = array_merge($a['lignes'], $b['lignes']);
            run('UPDATE CommandesOuvertes SET Contenu = ?, Couverts = Couverts + ?, Version = Version + 1, DateMaj = NOW(), AdditionImprimee = 0 WHERE Id = ?',
                [json_encode($a, JSON_UNESCAPED_UNICODE), $co['Couverts'], $existante['Id']]);
            run('UPDATE BonsPreparation SET CommandeOuverteId = ? WHERE CommandeOuverteId = ?', [$existante['Id'], $co['Id']]);
            run('DELETE FROM CommandesOuvertes WHERE Id = ?', [$co['Id']]);
            $id = (int) $existante['Id'];
        } else {
            run('UPDATE CommandesOuvertes SET TableId = ?, Version = Version + 1, DateMaj = NOW() WHERE Id = ?', [$cible['Id'], $co['Id']]);
            $id = (int) $co['Id'];
        }
        db()->commit();
    } catch (Throwable $e) {
        if (db()->inTransaction()) {
            db()->rollBack();
        }
        throw $e;
    }
    pos_json(['commande' => restaurant_commande_json(q1('SELECT * FROM CommandesOuvertes WHERE Id = ?', [$id]))]);
}

/** Addition (note provisoire) d'une table, avant le paiement ; la table passe en « addition demandée ». */
function pos_addition(): void
{
    $co = q1('SELECT co.*, t.Nom AS TableNom, u.NomComplet AS Serveur, c.ChkCode, c.ChkDescription,
                     s.Nom AS Societe, s.Adresse, s.Ville, s.Pays, s.Email AS EmailSociete, s.Telephone, s.NIF, s.LogoMaj
              FROM CommandesOuvertes co
              JOIN Caisses c ON c.ID = co.CaisseId
              LEFT JOIN TablesRestaurant t ON t.Id = co.TableId
              LEFT JOIN Utilisateurs u ON u.Id = co.UtilisateurId
              LEFT JOIN Tenants s ON s.Id = co.TenantId
              WHERE co.Id = ? AND ' . tf('co'), [(int) get('id')]);
    if (!$co) {
        not_found('Commande introuvable.');
    }
    run('UPDATE CommandesOuvertes SET AdditionImprimee = 1 WHERE Id = ?', [$co['Id']]);
    $contenu = restaurant_contenu($co['Contenu']);
    $societe = ['Id' => $co['TenantId'], 'LogoMaj' => $co['LogoMaj'], 'Adresse' => $co['Adresse'], 'Ville' => $co['Ville'],
                'Pays' => $co['Pays'], 'Email' => $co['EmailSociete'], 'Telephone' => $co['Telephone'], 'NIF' => $co['NIF']];
    render('pos/addition', [
        'co' => $co,
        'lignes' => $contenu['lignes'],
        'total' => restaurant_total($contenu),
        'brut' => restaurant_total(['lignes' => $contenu['lignes']]),
        'logo' => url_logo($societe),
        'coordonnees' => societe_coordonnees($societe),
    ], false);
}

/** Bons de préparation 80 mm (un par page), imprimés à l'envoi. */
function pos_bon(): void
{
    $ids = array_values(array_filter(array_map('intval', explode(',', (string) get('ids'))))) ?: [0];
    $marques = implode(',', array_fill(0, count($ids), '?'));
    $bons = q("SELECT * FROM BonsPreparation WHERE Id IN ($marques) AND " . tf() . ' ORDER BY Id', $ids);
    foreach ($bons as &$b) {
        $b['lignes'] = q('SELECT * FROM LignesBonPreparation WHERE BonPreparationId = ? ORDER BY Id', [$b['Id']]);
    }
    unset($b);
    render('pos/bon', ['bons' => $bons], false);
}

// ---------------------------------------------------------------------------
// Commandes en attente (gardées sur le serveur, visibles depuis tous les postes de la journée)
// et commandes à livrer (livreur, destinataire, payées maintenant ou à la livraison).
// Même fonctionnement que la version .NET (Controllers/PosController.Livraisons.cs).
// ---------------------------------------------------------------------------

/** Texte nettoyé et tronqué, null si vide. */
function pos_texte(mixed $valeur, int $max): ?string
{
    $t = trim((string) ($valeur ?? ''));
    return $t === '' ? null : mb_substr($t, 0, $max);
}

/** Livraison saisie : livreur actif de la société et adresse obligatoires. Renvoie [livraison, erreur]. */
function pos_controler_livraison(mixed $l, int $tenant): array
{
    if (!is_array($l)) {
        return [null, null];
    }
    $livreur = (int) ($l['livreurId'] ?? 0);
    if (!$livreur || !q1('SELECT Id FROM Livreurs WHERE Id = ? AND TenantId = ? AND Actif = 1', [$livreur, $tenant])) {
        return [null, 'Choisissez un livreur actif pour la livraison.'];
    }
    $adresse = pos_texte($l['adresse'] ?? null, 200);
    if ($adresse === null) {
        return [null, "Indiquez l'adresse de livraison."];
    }
    return [[
        'livreurId' => $livreur, 'nom' => pos_texte($l['nom'] ?? null, 100), 'telephone' => pos_texte($l['telephone'] ?? null, 30),
        'adresse' => $adresse, 'paiement' => ($l['paiement'] ?? '') === 'livraison' ? 'livraison' : 'maintenant',
        'frais' => max(0, round((float) ($l['frais'] ?? 0))),
    ], null];
}

/** Liste du bouton « Commandes en attente » : commandes en attente de la journée et ventes payées qui restent à livrer. */
function pos_attentes(): void
{
    $journee = q1('SELECT * FROM JourneesCaisses WHERE Id = ? AND ' . tf(), [(int) get('journee')]);
    if (!$journee) {
        pos_json(['erreur' => 'Journée introuvable.'], 404);
    }
    $livraison = fn($c) => $c['LivreurId'] !== null || $c['AdresseLivraison'] !== null ? [
        'livreur' => $c['Livreur'], 'moyen' => $c['MoyenLivreur'], 'nom' => $c['NomLivraison'], 'telephone' => $c['TelephoneLivraison'], 'adresse' => $c['AdresseLivraison'],
    ] : null;
    $attentes = array_map(fn($c) => [
        'id' => (int) $c['Id'], 'numero' => (int) $c['Numero'], 'heure' => date('H:i', strtotime($c['DateCreation'])),
        'client' => $c['Client'], 'articles' => (int) $c['NbArticles'], 'total' => (float) $c['Total'], 'utilisateur' => $c['Utilisateur'],
        'livraison' => $livraison($c),
    ], q(
        'SELECT a.*, l.Nom AS Livreur, l.MoyenLivraison AS MoyenLivreur, cl.NomSociete AS Client, u.NomComplet AS Utilisateur
         FROM CommandesAttente a LEFT JOIN Livreurs l ON l.Id = a.LivreurId LEFT JOIN Clients cl ON cl.Id = a.ClientId
         LEFT JOIN Utilisateurs u ON u.Id = a.UtilisateurId
         WHERE a.JourneeCaisseId = ? ORDER BY a.Numero',
        [$journee['Id']]
    ));
    $livraisons = array_map(fn($c) => [
        'id' => (int) $c['Id'], 'numero' => $c['Numero'], 'heure' => date('H:i', strtotime($c['DateCommande'])),
        'client' => $c['Client'], 'total' => (float) $c['TotalTTC'] + (float) $c['FraisLivraison'], 'livreur' => $c['Livreur'], 'moyen' => $c['MoyenLivreur'],
        'nom' => $c['NomLivraison'], 'telephone' => $c['TelephoneLivraison'], 'adresse' => $c['AdresseLivraison'],
    ], q(
        "SELECT c.*, l.Nom AS Livreur, l.MoyenLivraison AS MoyenLivreur, cl.NomSociete AS Client
         FROM CommandesPos c LEFT JOIN Livreurs l ON l.Id = c.LivreurId LEFT JOIN Clients cl ON cl.Id = c.ClientId
         WHERE c.JourneeCaisseId = ? AND c.StatutLivraison = 'À livrer' ORDER BY c.DateCommande, c.Id",
        [$journee['Id']]
    ));
    pos_json(['attentes' => $attentes, 'livraisons' => $livraisons]);
}

/**
 * « Mettre en attente » : le ticket est enregistré sur le serveur (avec sa livraison s'il est à
 * encaisser à la livraison) et quitte l'écran ; il se reprend depuis n'importe quel poste.
 */
function pos_mettreenattente(): void
{
    $s = pos_saisie();
    $journee = q1('SELECT * FROM JourneesCaisses WHERE Id = ? AND ' . tf(), [(int) ($s['journeeId'] ?? 0)]);
    if (!$journee) {
        pos_json(['erreur' => 'Journée introuvable.'], 404);
    }
    if ($journee['Statut'] !== 'Ouverte') {
        pos_json(['erreur' => 'Cette journée est clôturée : la commande ne peut pas être mise en attente.'], 409);
    }
    $tenant = (int) $journee['TenantId'];

    // Lignes : produits actifs de la société ; nom, taux et unité repris du catalogue.
    $lignes = [];
    foreach ((array) ($s['lignes'] ?? []) as $l) {
        if (!is_array($l)) {
            continue;
        }
        $qte = round((float) ($l['qte'] ?? 0), 2);
        $p = q1('SELECT Id, Nom, TauxTVA, Unite FROM Produits WHERE Id = ? AND TenantId = ? AND Actif = 1', [(int) ($l['produitId'] ?? 0), $tenant]);
        if (!$p || $qte <= 0) {
            continue;
        }
        $lignes[] = [
            'uid' => pos_texte($l['uid'] ?? null, 60) ?? bin2hex(random_bytes(8)), 'produitId' => (int) $p['Id'],
            'nom' => pos_texte($l['nom'] ?? null, 250) ?? $p['Nom'], 'qte' => $qte,
            'prix' => max(0, round((float) ($l['prix'] ?? 0), 2)), 'remise' => min(100, max(0, round((float) ($l['remise'] ?? 0), 2))),
            'tva' => (float) $p['TauxTVA'], 'unite' => $p['Unite'], 'note' => pos_texte($l['note'] ?? null, 200) ?? '',
            'composants' => $l['composants'] ?? null,
        ];
    }
    if (!$lignes) {
        pos_json(['erreur' => 'Le ticket est vide.'], 400);
    }
    $client = int_or_null($s['clientId'] ?? null);
    if ($client && !q1('SELECT Id FROM Clients WHERE Id = ? AND TenantId = ?', [$client, $tenant])) {
        $client = null;
    }
    [$livraison, $erreur] = pos_controler_livraison($s['livraison'] ?? null, $tenant);
    if ($erreur) {
        pos_json(['erreur' => $erreur], 400);
    }
    $r = $s['remise'] ?? null;
    $remise = is_array($r) && (float) ($r['valeur'] ?? 0) > 0 && pos_peut_remise_globale()
        ? ['type' => ($r['type'] ?? '') === 'pct' ? 'pct' : 'montant', 'valeur' => (float) $r['valeur']] : null;

    // Total affiché dans la liste (même calcul que l'écran de vente).
    $brut = array_sum(array_map(fn($l) => round($l['qte'] * $l['prix'] * (1 - $l['remise'] / 100)), $lignes));
    $montantRemise = !$remise || $brut <= 0 ? 0
        : ($remise['type'] === 'pct' ? round($brut * min(100, $remise['valeur']) / 100) : min($brut, round($remise['valeur'])));

    db()->beginTransaction();
    try {
        q('SELECT Id FROM JourneesCaisses WHERE Id = ? FOR UPDATE', [$journee['Id']]);
        $numero = (int) qv('SELECT COALESCE(MAX(Numero), 0) FROM CommandesAttente WHERE JourneeCaisseId = ?', [$journee['Id']]) + 1;
        $id = run(
            'INSERT INTO CommandesAttente (TenantId, JourneeCaisseId, Numero, DateCreation, UtilisateurId, ClientId, Contenu, Total, NbArticles,
                LivreurId, NomLivraison, TelephoneLivraison, AdresseLivraison)
             VALUES (?, ?, ?, NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [$tenant, $journee['Id'], $numero, user()['id'], $client,
             json_encode(['lignes' => $lignes, 'clientId' => $client, 'remise' => $remise, 'livraison' => $livraison], JSON_UNESCAPED_UNICODE),
             $brut - $montantRemise + ($livraison['frais'] ?? 0), count($lignes),
             $livraison['livreurId'] ?? null, $livraison['nom'] ?? null, $livraison['telephone'] ?? null, $livraison['adresse'] ?? null]
        );
        db()->commit();
    } catch (Throwable $e) {
        db()->rollBack();
        throw $e;
    }
    pos_json(['id' => (int) $id, 'numero' => $numero]);
}

/**
 * Reprise d'une commande en attente : elle est retirée de la liste (sous verrou : un seul poste la
 * reprend) et son contenu revient à l'écran de vente.
 */
function pos_reprendre(): void
{
    $s = pos_saisie();
    db()->beginTransaction();
    $c = q1('SELECT a.*, j.Statut AS StatutJournee FROM CommandesAttente a JOIN JourneesCaisses j ON j.Id = a.JourneeCaisseId
             WHERE a.Id = ? AND ' . tf('a') . ' FOR UPDATE', [(int) ($s['id'] ?? 0)]);
    if (!$c) {
        db()->rollBack();
        pos_json(['erreur' => 'Cette commande a déjà été reprise ou supprimée sur un autre poste.'], 404);
    }
    if ($c['StatutJournee'] !== 'Ouverte') {
        db()->rollBack();
        pos_json(['erreur' => 'Cette journée est clôturée.'], 409);
    }
    run('DELETE FROM CommandesAttente WHERE Id = ?', [$c['Id']]);
    db()->commit();
    pos_json(['numero' => (int) $c['Numero'], 'contenu' => json_decode($c['Contenu'], true)]);
}

function pos_supprimerattente(): void
{
    $s = pos_saisie();
    $c = q1('SELECT Id FROM CommandesAttente WHERE Id = ? AND ' . tf(), [(int) ($s['id'] ?? 0)]);
    if (!$c) {
        pos_json(['erreur' => 'Cette commande a déjà été reprise ou supprimée sur un autre poste.'], 404);
    }
    run('DELETE FROM CommandesAttente WHERE Id = ?', [$c['Id']]);
    pos_json(['ok' => true]);
}

/** Vente payée à la commande, livrée ensuite : le retour du livreur la marque « Livrée ». */
function pos_livree(): void
{
    $s = pos_saisie();
    $c = q1('SELECT Id, StatutLivraison FROM CommandesPos WHERE Id = ? AND ' . tf(), [(int) ($s['id'] ?? 0)]);
    if (!$c || $c['StatutLivraison'] === null) {
        pos_json(['erreur' => 'Livraison introuvable.'], 404);
    }
    if ($c['StatutLivraison'] !== 'Livrée') {
        run("UPDATE CommandesPos SET StatutLivraison = 'Livrée', DateLivraison = NOW() WHERE Id = ?", [$c['Id']]);
    }
    pos_json(['ok' => true]);
}
