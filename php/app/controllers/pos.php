<?php
// Point de vente : choix de la journée ouverte, puis écran de vente plein écran.
// Les tickets en cours sont gardés dans le navigateur jusqu'au paiement.

function pos_index(): void
{
    $id = (int) get('journee', 0);
    if ($id === 0) {
        pos_choix();
        return;
    }

    $journee = q1(
        'SELECT j.*, c.ChkCode, c.ChkDescription
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
    $produits = array_map(fn($p) => [
        'id' => (int) $p['Id'],
        'code' => $p['Code'],
        'codeBarres' => $p['CodeBarres'],
        'nom' => $p['Nom'],
        'categorieId' => $p['CategorieId'] === null ? null : (int) $p['CategorieId'],
        'prix' => (float) $p['PrixVente'],
        'tva' => (float) $p['TauxTVA'],
        'suivi' => (bool) $p['SuiviStock'],
        'stock' => (float) $p['StockActuel'],
        'seuil' => $p['SeuilAlerte'] === null ? null : (float) $p['SeuilAlerte'],
    ], q('SELECT * FROM Produits WHERE Actif = 1 AND TenantId = ? ORDER BY Nom', [$tenant]));

    $categories = array_map(fn($c) => [
        'id' => (int) $c['Id'], 'nom' => $c['Nom'], 'couleur' => $c['Couleur'],
    ], q('SELECT Id, Nom, Couleur FROM Categories WHERE TenantId = ? ORDER BY Ordre, Nom', [$tenant]));

    $clients = array_map(fn($c) => [
        'id' => (int) $c['Id'], 'nom' => $c['NomSociete'], 'code' => $c['CodeClient'],
    ], q('SELECT Id, NomSociete, CodeClient FROM Clients WHERE TenantId = ? ORDER BY NomSociete', [$tenant]));

    // « Espèces » : le seul mode sur lequel on peut rendre la monnaie.
    $modes = array_map(fn($m) => [
        'id' => (int) $m['Id'], 'libelle' => (string) $m['Libelle'], 'especes' => pos_est_especes($m),
    ], q('SELECT Id, Code, Libelle FROM ModesPaiement WHERE Actif = 1 AND TenantId = ? ORDER BY Libelle', [$tenant]));

    $u = user();
    $donnees = [
        'cle' => 'gescaisse-pos:' . $tenant . ':' . $journee['Id'],
        'journee' => [
            'id' => (int) $journee['Id'],
            'caisse' => $journee['ChkCode'],
            'libelle' => $journee['ChkDescription'] . ' · Journée du ' . date_fr($journee['DateJournee']) . ' (ouverte)',
        ],
        'produits' => $produits,
        'categories' => $categories,
        'clients' => $clients,
        'utilisateur' => ['nom' => $u['nomComplet'] ?: $u['nom'], 'profil' => $u['profil']],
        'peutModifierPrix' => is_admin(),
        'urlFermer' => url('journee/details', ['id' => $journee['Id']]),
        'modes' => $modes,
        'urlVendre' => url('pos/vendre'),
        'urlTicket' => url('pos/ticket') . '&id=',
        'urlVentes' => url('vente/index', ['journee' => $journee['Id']]),
        'venteSansStock' => vente_sans_stock($tenant),
        'jeton' => ['nom' => '_csrf', 'valeur' => csrf_token()],
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
        'SELECT j.*, c.ChkCode FROM JourneesCaisses j JOIN Caisses c ON c.ID = j.CaisseId WHERE j.Id = ? AND ' . tf('j'),
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
        $p = q1('SELECT * FROM Produits WHERE Id = ? AND TenantId = ? AND Actif = 1', [(int) ($l['produitId'] ?? 0), $tenant]);
        $qte = round((float) ($l['qte'] ?? 0), 2);
        if (!$p || $qte <= 0) {
            pos_json(['erreur' => 'Un article du ticket est introuvable, inactif ou de quantité nulle.'], 400);
        }
        $prix = is_admin() ? max(0, round((float) ($l['prix'] ?? $p['PrixVente']), 2)) : (float) $p['PrixVente'];
        $remise = min(100, max(0, round((float) ($l['remise'] ?? 0), 2)));
        $total = round($qte * $prix * (1 - $remise / 100));
        $taux = (float) $p['TauxTVA'];
        $ttc += $total;
        $tva += $total - $total / (1 + $taux / 100);
        $lignes[] = ['produit' => $p, 'qte' => $qte, 'prix' => $prix, 'remise' => $remise, 'taux' => $taux, 'total' => $total];
    }
    $tva = round($tva);

    // Règlements : seuls les espèces peuvent dépasser le reste à payer (monnaie rendue).
    $modes = [];
    foreach (q('SELECT Id, Code, Libelle FROM ModesPaiement WHERE Actif = 1 AND TenantId = ?', [$tenant]) as $m) {
        $modes[(int) $m['Id']] = $m;
    }
    $paiements = [];
    $recu = $especes = 0.0;
    foreach ($v['paiements'] as $pm) {
        $mode = $modes[(int) ($pm['modeId'] ?? 0)] ?? null;
        $montant = round((float) ($pm['montant'] ?? 0));
        if (!$mode || $montant <= 0) {
            pos_json(['erreur' => 'Mode de paiement invalide ou montant nul.'], 400);
        }
        $paiements[] = ['mode' => $mode, 'recu' => $montant, 'especes' => pos_est_especes($mode)];
        $recu += $montant;
        if (pos_est_especes($mode)) {
            $especes += $montant;
        }
    }
    if ($recu < $ttc) {
        pos_json(['erreur' => 'Le montant payé est inférieur au total.'], 400);
    }
    $rendu = $recu - $ttc;
    if ($rendu > $especes) {
        pos_json(['erreur' => 'Seule la monnaie sur les espèces peut être rendue : le montant payé par les autres modes dépasse le total.'], 400);
    }

    $client = int_or_null($v['clientId'] ?? null);
    if ($client && !q1('SELECT Id FROM Clients WHERE Id = ? AND TenantId = ?', [$client, $tenant])) {
        $client = null;
    }

    db()->beginTransaction();
    try {
        // Les encaissements du point de vente sont validés d'office (vente payée et justifiée par le ticket).
        // Verrou sur la journée : numéros de ticket consécutifs même avec plusieurs caisses ouvertes.
        q('SELECT Id FROM JourneesCaisses WHERE Id = ? FOR UPDATE', [$journee['Id']]);
        // Vente sans stock interdite (option de la société) : contrôle sous verrou des produits.
        if (!vente_sans_stock($tenant)) {
            $parProduit = [];
            foreach ($lignes as $l) {
                if ($l['produit']['SuiviStock']) {
                    $parProduit[(int) $l['produit']['Id']] = ($parProduit[(int) $l['produit']['Id']] ?? 0) + $l['qte'];
                }
            }
            foreach ($parProduit as $pid => $qte) {
                $p = q1('SELECT Nom, StockActuel FROM Produits WHERE Id = ? FOR UPDATE', [$pid]);
                if ((float) $p['StockActuel'] < $qte - 0.001) {
                    db()->rollBack();
                    pos_json(['erreur' => 'Stock insuffisant pour « ' . $p['Nom'] . ' » : ' . quantite_fr($p['StockActuel']) . ' disponible(s).'], 409);
                }
            }
        }
        $rang = (int) qv('SELECT COUNT(*) FROM CommandesPos WHERE JourneeCaisseId = ?', [$journee['Id']]) + 1;
        $numero = sprintf('POS-%s-%s-%04d', $journee['ChkCode'], date('Ymd', strtotime($journee['DateJournee'])), $rang);

        $commandeId = run(
            "INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande,
                TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
             VALUES (?, ?, ?, ?, ?, ?, NOW(), ?, ?, ?, ?, ?, 'Payée')",
            [$tenant, $numero, $cle, $journee['Id'], $client, user()['id'], $ttc - $tva, $tva, $ttc, $recu, $rendu]
        );
        foreach ($lignes as $l) {
            $ligneId = run(
                'INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [$tenant, $commandeId, $l['produit']['Id'], $l['produit']['Nom'], $l['qte'], $l['prix'], $l['remise'], $l['taux'], $l['total']]
            );
            ligne_enregistrer_taxes($ligneId, produit_taxes((int) $l['produit']['Id']), $l['total'], $tenant);
            mouvement_stock((int) $l['produit']['Id'], -$l['qte'], 'Vente', $numero, $commandeId);
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
            if ($net > 0) {
                $operation = run(
                    "INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle,
                        ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
                     VALUES (?, ?, NOW(), 'Encaissement', ?, ?, ?, ?, ?, ?, 1, 'Validé', 'Point de vente')",
                    [$tenant, $journee['Id'], $net, 'Vente POS ' . $numero, $client, $motif, $pm['mode']['Id'], user()['id']]
                );
            }
            run(
                'INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
                 VALUES (?, ?, ?, ?, ?, ?, ?)',
                [$tenant, $commandeId, $pm['mode']['Id'], (string) $pm['mode']['Libelle'], $pm['recu'], $net, $operation]
            );
        }
        db()->commit();
    } catch (Throwable $e) {
        db()->rollBack();
        error_log('[GesCaisse POS] ' . $e->getMessage());
        pos_json(['erreur' => "La vente n'a pas pu être enregistrée. Réessayez."], 500);
    }

    pos_json(['id' => $commandeId, 'numero' => $numero, 'rendu' => $rendu]);
}

/** Ticket de caisse 80 mm d'une vente (impression ou réimpression). */
function pos_ticket(): void
{
    $commande = q1(
        'SELECT cmd.*, j.DateJournee, c.ChkCode, c.ChkDescription, t.Nom AS Societe,
                u.NomComplet AS Vendeur, cl.NomSociete AS Client, o.Numero AS NumeroOrigine
         FROM CommandesPos cmd
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
    $lignes = q('SELECT * FROM LignesCommandePos WHERE CommandePosId = ? ORDER BY Id', [$commande['Id']]);
    render('pos/ticket', [
        'commande' => $commande,
        'lignes' => $lignes,
        'paiements' => q('SELECT * FROM PaiementsPos WHERE CommandePosId = ? ORDER BY Id', [$commande['Id']]),
        'taxes' => vente_taxes((int) $commande['Id']),
        'imprimer' => get('imprimer') === '1',
    ], false);
}
