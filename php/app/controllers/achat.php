<?php
// Achats (laverie : lessive, javel, assouplissant…) et consommations internes.
// - Achat : un fournisseur (tiers de type Fournisseur), un dépôt, des lignes produit × quantité ×
//   prix d'achat. À l'enregistrement, les quantités entrent en stock (mouvement « Achat ») et le
//   coût du produit est recalculé (coût moyen pondéré).
// - Règlement : par la caisse (décaissement dans une journée ouverte), hors caisse (virement,
//   chèque…) ou plus tard : l'achat reste dû au fournisseur (achat à crédit).
// - Annulation : les quantités ressortent du stock (refus si elles ont déjà été consommées ou
//   vendues) ; les règlements passés par une caisse dont la journée est encore ouverte y sont
//   remboursés (encaissement) ; journée clôturée : refus.
// - Consommation : sortie du stock des produits utilisés pour le service (mouvement « Consommation »).
// Achats et consommations se font dans le dépôt des achats (« Magasin des produits d'entretien »,
// créé au besoin), qui ne sert à aucune caisse ; l'onglet « Dépôt des achats » en suit les entrées,
// les sorties et le stock.
// Réservé aux profils Admin et SuperAdmin.

const ACHAT_STATUTS = ['Validé', 'Annulé'];
const ACHAT_PAIEMENTS = ['credit' => 'À crédit (à régler plus tard)', 'caisse' => 'Payé par la caisse (décaissement)', 'hors' => 'Payé hors caisse (virement, chèque…)'];

/** Filtres de la liste (par défaut : du 1er du mois à aujourd'hui). */
function achat_filtres(): array
{
    $d = fn($v) => ($v && DateTime::createFromFormat('!Y-m-d', (string) $v)) ? (string) $v : null;
    $statut = (string) get('statut', '');
    $f = [
        'du' => $d(get('du')) ?? date('Y-m-01'),
        'au' => $d(get('au')) ?? date('Y-m-d'),
        'fournisseur' => (int) get('fournisseur', 0),
        'statut' => in_array($statut, [...ACHAT_STATUTS, 'Non soldé'], true) ? $statut : '',
    ];
    if ($f['au'] < $f['du']) {
        [$f['du'], $f['au']] = [$f['au'], $f['du']];
    }
    return $f;
}

/** Tiers de type Fournisseur de la société. */
function achat_fournisseurs(): array
{
    return q("SELECT Id, CodeClient, NomSociete FROM Clients WHERE Type = 'Fournisseur' AND " . tf() . ' ORDER BY NomSociete');
}

/**
 * Produits achetables (suivis en stock, hors modèles et combos), les consommables en premier ;
 * StockDepot = quantité dans le dépôt donné.
 */
function achat_produits(int $depot = 0): array
{
    return q('SELECT p.Id, p.Code, p.Nom, p.Unite, p.Cout, p.StockActuel, p.Consommable, COALESCE(sd.Quantite, 0) AS StockDepot
              FROM Produits p LEFT JOIN StocksDepots sd ON sd.ProduitId = p.Id AND sd.DepotId = ?
              WHERE p.SuiviStock = 1 AND p.Actif = 1 AND p.EstModele = 0 AND p.EstCombo = 0 AND ' . tf('p') . ' ORDER BY p.Consommable DESC, p.Nom', [$depot]);
}

/** Journées de caisse ouvertes de la société (règlement par la caisse). */
function achat_journees(): array
{
    return q("SELECT j.Id, j.NumeroJournee, c.ChkCode, c.ChkDescription FROM JourneesCaisses j JOIN Caisses c ON c.ID = j.CaisseId
              WHERE j.Statut = 'Ouverte' AND " . tf('j') . ' ORDER BY c.ChkCode, j.Id');
}

/** Modes de paiement utilisables pour régler un fournisseur (hors « compte »). */
function achat_modes(): array
{
    return q('SELECT Id, Libelle FROM ModesPaiement WHERE Actif = 1 AND EstCompte = 0 AND ' . tf() . ' ORDER BY Libelle');
}

/** Motif des décaissements d'achat (créé au besoin). */
function achat_motif(int $tenant): int
{
    return (int) (qv("SELECT ID FROM Motifs WHERE LibelleMotif = 'Achat fournisseur' AND TenantId = ?", [$tenant])
        ?: run("INSERT INTO Motifs (LibelleMotif, TypeModif, TenantId) VALUES ('Achat fournisseur', 'Fournisseur', ?)", [$tenant]));
}

/** Achat de la société (sinon page introuvable), avec fournisseur, dépôt et montant réglé. */
function achat_charger(int $id, bool $verrou = false): array
{
    $a = q1('SELECT a.*, f.NomSociete AS Fournisseur, f.CodeClient AS CodeFournisseur, d.Nom AS Depot, u.NomComplet AS Utilisateur,
                (SELECT COALESCE(SUM(r.Montant), 0) FROM ReglementsAchats r WHERE r.AchatId = a.Id) AS Regle
             FROM Achats a LEFT JOIN Clients f ON f.Id = a.FournisseurId LEFT JOIN Depots d ON d.Id = a.DepotId
             LEFT JOIN Utilisateurs u ON u.Id = a.UtilisateurId WHERE a.Id = ? AND ' . tf('a') . ($verrou ? ' FOR UPDATE' : ''), [$id]);
    if (!$a) {
        not_found('Achat introuvable.');
    }
    return $a;
}

/**
 * Règlement d'un achat. $mode : 'caisse' (décaissement dans la journée $journee) ou 'hors'.
 * Renvoie un message d'erreur, ou null si le règlement est enregistré.
 */
function achat_regler(array $a, float $montant, string $mode, int $journeeId, int $modeId): ?string
{
    $tenant = (int) $a['TenantId'];
    $modePaiement = q1('SELECT * FROM ModesPaiement WHERE Id = ? AND TenantId = ? AND Actif = 1 AND EstCompte = 0', [$modeId, $tenant]);
    if (!$modePaiement) {
        return 'Choisissez le mode de paiement du règlement.';
    }
    $operation = null;
    if ($mode === 'caisse') {
        $journee = q1("SELECT * FROM JourneesCaisses WHERE Id = ? AND TenantId = ? AND Statut = 'Ouverte'", [$journeeId, $tenant]);
        if (!$journee) {
            return 'Choisissez la journée de caisse ouverte qui paie le fournisseur.';
        }
        $statut = peut_valider() ? 'Validé' : 'En attente';
        $operation = run(
            "INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle,
                ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
             VALUES (?, ?, NOW(), 'Décaissement', ?, ?, ?, ?, ?, ?, 1, ?, ?)",
            [$tenant, $journee['Id'], $montant, 'Achat n° ' . $a['Numero'] . ($a['Fournisseur'] ? ' — ' . $a['Fournisseur'] : ''),
             $a['FournisseurId'], achat_motif($tenant), $modePaiement['Id'], user()['id'], $statut, $statut === 'Validé' ? user()['nomComplet'] : null]
        );
    }
    run('INSERT INTO ReglementsAchats (AchatId, DateReglement, Montant, ModePaiementId, OperationCaisseId, UtilisateurId) VALUES (?, NOW(), ?, ?, ?, ?)',
        [$a['Id'], $montant, $modePaiement['Id'], $operation, user()['id']]);
    return null;
}

/** Liste des achats avec totaux. */
function achat_index(): void
{
    $f = achat_filtres();
    $sql = 'SELECT a.*, f.NomSociete AS Fournisseur, d.Nom AS Depot,
                (SELECT COALESCE(SUM(r.Montant), 0) FROM ReglementsAchats r WHERE r.AchatId = a.Id) AS Regle
            FROM Achats a LEFT JOIN Clients f ON f.Id = a.FournisseurId LEFT JOIN Depots d ON d.Id = a.DepotId
            WHERE a.DateAchat BETWEEN ? AND ? AND ' . tf('a');
    $p = [$f['du'], $f['au']];
    if ($f['fournisseur']) {
        $sql .= ' AND a.FournisseurId = ?';
        $p[] = $f['fournisseur'];
    }
    if (in_array($f['statut'], ACHAT_STATUTS, true)) {
        $sql .= ' AND a.Statut = ?';
        $p[] = $f['statut'];
    }
    $achats = q($sql . ' ORDER BY a.DateAchat DESC, a.Numero DESC', $p);
    foreach ($achats as $i => $a) {
        $achats[$i]['Reste'] = $a['Statut'] === 'Validé' ? max(0, round((float) $a['Total'] - (float) $a['Regle'], 2)) : 0.0;
        if ($f['statut'] === 'Non soldé' && ($a['Statut'] !== 'Validé' || $achats[$i]['Reste'] <= 0)) {
            unset($achats[$i]);
        }
    }
    $valides = array_filter($achats, fn($a) => $a['Statut'] === 'Validé');
    $totaux = [
        'Nombre' => count($valides),
        'Montant' => array_sum(array_column($valides, 'Total')),
        'Regle' => array_sum(array_column($valides, 'Regle')),
        'Reste' => array_sum(array_column($valides, 'Reste')),
    ];
    // Dette fournisseurs : tous les achats validés non soldés, quelle que soit leur date.
    $dette = (float) qv('SELECT COALESCE(SUM(a.Total - (SELECT COALESCE(SUM(r.Montant), 0) FROM ReglementsAchats r WHERE r.AchatId = a.Id)), 0)
                         FROM Achats a WHERE a.Statut = \'Validé\' AND ' . tf('a'));
    render('achat/index', ['f' => $f, 'achats' => array_values($achats), 'totaux' => $totaux, 'dette' => max(0, $dette), 'fournisseurs' => achat_fournisseurs()]);
}

/** Nouvel achat : saisie et enregistrement (entrée en stock, coût, règlement éventuel). */
function achat_nouveau(): void
{
    $depot = achat_depot();
    if (!is_post()) {
        render('achat/form', [
            'fournisseurs' => achat_fournisseurs(), 'produits' => achat_produits((int) ($depot['Id'] ?? 0)), 'depot' => $depot,
            'journees' => achat_journees(), 'modes' => achat_modes(),
        ]);
        return;
    }
    $tenant = tenant_insert();
    $retour = fn(string $m) => [flash('danger', $m), redirect('achat/nouveau')];
    $depot = depot_des_achats($tenant);
    $fournisseur = (int) post('fournisseur', 0);
    if ($fournisseur && !qv("SELECT Id FROM Clients WHERE Id = ? AND TenantId = ? AND Type = 'Fournisseur'", [$fournisseur, $tenant])) {
        $retour('Fournisseur introuvable.');
    }
    $date = (string) post('date', '');
    if (!DateTime::createFromFormat('!Y-m-d', $date)) {
        $date = date('Y-m-d');
    }
    if ($date > date('Y-m-d')) {
        $retour("La date d'achat ne peut pas être dans le futur.");
    }
    $reference = mb_substr(trim((string) post('reference', '')), 0, 100) ?: null;
    $produits = (array) ($_POST['produit'] ?? []);
    $quantites = (array) ($_POST['qte'] ?? []);
    $prix = (array) ($_POST['prix'] ?? []);
    $lignes = [];
    foreach ($produits as $i => $id) {
        $q = round(montant($quantites[$i] ?? 0), 2);
        $pu = round(montant($prix[$i] ?? 0), 2);
        if (!(int) $id || $q <= 0) {
            continue;
        }
        if ($pu < 0) {
            $retour("Le prix d'achat ne peut pas être négatif.");
        }
        if (!q1('SELECT Id FROM Produits WHERE Id = ? AND TenantId = ? AND SuiviStock = 1 AND EstModele = 0 AND EstCombo = 0', [(int) $id, $tenant])) {
            $retour('Un produit de la liste est introuvable ou sans suivi de stock.');
        }
        $lignes[] = [(int) $id, $q, $pu, round($q * $pu, 2)];
    }
    if (!$lignes) {
        $retour('Indiquez au moins un produit, sa quantité et son prix d\'achat.');
    }
    $total = round(array_sum(array_column($lignes, 3)), 2);
    $paiement = array_key_exists((string) post('paiement'), ACHAT_PAIEMENTS) ? (string) post('paiement') : 'credit';
    $regle = $paiement === 'credit' ? 0.0 : round(montant(post('montantRegle', $total)), 2);
    if ($paiement !== 'credit' && ($regle <= 0 || $regle > $total)) {
        $retour("Le montant réglé doit être compris entre 1 et le total de l'achat (" . fcfa($total) . ' FCFA).');
    }

    db()->beginTransaction();
    try {
        $numero = (int) qv('SELECT COALESCE(MAX(Numero), 0) + 1 FROM Achats WHERE TenantId = ? FOR UPDATE', [$tenant]);
        $id = run('INSERT INTO Achats (TenantId, Numero, DateAchat, FournisseurId, DepotId, Reference, Commentaire, Total, Statut, UtilisateurId, DateCreation)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, \'Validé\', ?, NOW())',
            [$tenant, $numero, $date, $fournisseur ?: null, $depot['Id'], $reference,
             mb_substr(trim((string) post('commentaire', '')), 0, 300) ?: null, $total, user()['id']]);
        foreach ($lignes as [$pid, $q, $pu, $m]) {
            run('INSERT INTO LignesAchats (AchatId, ProduitId, Quantite, PrixUnitaire, Montant) VALUES (?, ?, ?, ?, ?)', [$id, $pid, $q, $pu, $m]);
            // Coût moyen pondéré : (stock existant × coût actuel + quantité achetée × prix) / stock après achat.
            $p = q1('SELECT StockActuel, Cout FROM Produits WHERE Id = ? FOR UPDATE', [$pid]);
            $stock = max(0.0, (float) $p['StockActuel']);
            $cout = ($p['Cout'] !== null && $stock > 0) ? ($stock * (float) $p['Cout'] + $q * $pu) / ($stock + $q) : $pu;
            run('UPDATE Produits SET Cout = ? WHERE Id = ?', [round($cout, 2), $pid]);
            mouvement_stock($pid, $q, 'Achat', 'Achat n° ' . $numero, null, $reference, (int) $depot['Id']);
        }
        if ($regle > 0) {
            $erreur = achat_regler(achat_charger($id), $regle, $paiement, (int) post('journee', 0), (int) post('mode', 0));
            if ($erreur) {
                db()->rollBack();
                $retour($erreur);
            }
        }
        db()->commit();
    } catch (Throwable $e) {
        if (db()->inTransaction()) {
            db()->rollBack();
        }
        throw $e;
    }
    flash('success', 'Achat n° ' . $numero . ' enregistré : ' . count($lignes) . ' produit(s) entré(s) en stock (' . $depot['Nom'] . ').');
    redirect('achat/details', ['id' => $id]);
}

/** Dépôt des achats de la société consultée (null en mode « toutes les sociétés »). */
function achat_depot(): ?array
{
    return tenant_id() > 0 ? depot_des_achats(tenant_id()) : null;
}

/** Détail d'un achat : lignes, règlements, formulaire de règlement, annulation. */
function achat_details(): void
{
    $a = achat_charger((int) get('id'));
    render('achat/details', [
        'a' => $a,
        'lignes' => q('SELECT l.*, p.Code, p.Nom, p.Unite FROM LignesAchats l JOIN Produits p ON p.Id = l.ProduitId WHERE l.AchatId = ? ORDER BY l.Id', [$a['Id']]),
        'reglements' => q('SELECT r.*, m.Libelle AS Mode, j.NumeroJournee, c.ChkCode, u.NomComplet AS Utilisateur
                           FROM ReglementsAchats r LEFT JOIN ModesPaiement m ON m.Id = r.ModePaiementId
                           LEFT JOIN OperationsCaisses o ON o.Id = r.OperationCaisseId LEFT JOIN JourneesCaisses j ON j.Id = o.JourneeCaisseId
                           LEFT JOIN Caisses c ON c.ID = j.CaisseId LEFT JOIN Utilisateurs u ON u.Id = r.UtilisateurId
                           WHERE r.AchatId = ? ORDER BY r.Id', [$a['Id']]),
        'journees' => achat_journees(), 'modes' => achat_modes(),
    ]);
}

/** Règlement (complément) d'un achat à crédit. */
function achat_reglement(): void
{
    $id = (int) post('id');
    db()->beginTransaction();
    $a = achat_charger($id, true);
    $reste = round((float) $a['Total'] - (float) $a['Regle'], 2);
    $montant = round(montant(post('montant')), 2);
    $erreur = match (true) {
        $a['Statut'] !== 'Validé' => 'Cet achat est annulé.',
        $reste <= 0 => 'Cet achat est déjà entièrement réglé.',
        $montant <= 0 || $montant > $reste => 'Le montant doit être compris entre 1 et le reste à payer (' . fcfa($reste) . ' FCFA).',
        default => achat_regler($a, $montant, post('paiement') === 'caisse' ? 'caisse' : 'hors', (int) post('journee', 0), (int) post('mode', 0)),
    };
    if ($erreur) {
        db()->rollBack();
        flash('danger', $erreur);
    } else {
        db()->commit();
        flash('success', 'Règlement de ' . fcfa($montant) . ' FCFA enregistré : reste à payer ' . fcfa($reste - $montant) . ' FCFA.');
    }
    redirect('achat/details', ['id' => $id]);
}

/** Annulation : sortie du stock et remboursement des règlements passés par une caisse ouverte. */
function achat_annuler(): void
{
    $id = (int) post('id');
    db()->beginTransaction();
    try {
        $a = achat_charger($id, true);
        if ($a['Statut'] !== 'Validé') {
            db()->rollBack();
            flash('warning', 'Cet achat est déjà annulé.');
            redirect('achat/details', ['id' => $id]);
        }
        $caisse = q('SELECT r.Montant, r.ModePaiementId, o.JourneeCaisseId, j.Statut, j.NumeroJournee FROM ReglementsAchats r
                     JOIN OperationsCaisses o ON o.Id = r.OperationCaisseId JOIN JourneesCaisses j ON j.Id = o.JourneeCaisseId WHERE r.AchatId = ?', [$id]);
        foreach ($caisse as $r) {
            if ($r['Statut'] !== 'Ouverte') {
                db()->rollBack();
                flash('danger', 'Annulation impossible : un règlement a été payé par la journée ' . $r['NumeroJournee'] . ', déjà clôturée.');
                redirect('achat/details', ['id' => $id]);
            }
        }
        $lignes = q('SELECT l.ProduitId, l.Quantite, p.Nom FROM LignesAchats l JOIN Produits p ON p.Id = l.ProduitId WHERE l.AchatId = ? ORDER BY l.Id', [$id]);
        foreach ($lignes as $l) {
            q1('SELECT Id FROM Produits WHERE Id = ? FOR UPDATE', [$l['ProduitId']]);
            $dispo = (float) qv('SELECT COALESCE(SUM(Quantite), 0) FROM StocksDepots WHERE DepotId = ? AND ProduitId = ?', [$a['DepotId'], $l['ProduitId']]);
            if ($dispo < (float) $l['Quantite'] - 0.001) {
                db()->rollBack();
                flash('danger', 'Annulation impossible : il ne reste que ' . quantite_fr($dispo) . ' « ' . $l['Nom'] . ' » dans ' . $a['Depot']
                    . ' (quantité déjà consommée ou vendue). Corrigez plutôt le stock par un inventaire.');
                redirect('achat/details', ['id' => $id]);
            }
        }
        foreach ($caisse as $r) {
            run("INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle,
                    ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
                 VALUES (?, ?, NOW(), 'Encaissement', ?, ?, ?, ?, ?, ?, 1, 'Validé', ?)",
                [$a['TenantId'], $r['JourneeCaisseId'], $r['Montant'], 'Annulation achat n° ' . $a['Numero'] . ($a['Fournisseur'] ? ' — ' . $a['Fournisseur'] : ''),
                 $a['FournisseurId'], achat_motif((int) $a['TenantId']), $r['ModePaiementId'], user()['id'], user()['nomComplet']]);
        }
        foreach ($lignes as $l) {
            mouvement_stock((int) $l['ProduitId'], -(float) $l['Quantite'], 'Annulation', 'Achat n° ' . $a['Numero'], null, 'Annulation de l\'achat', (int) $a['DepotId']);
        }
        run("UPDATE Achats SET Statut = 'Annulé', DateAnnulation = NOW() WHERE Id = ?", [$id]);
        db()->commit();
    } catch (Throwable $e) {
        if (db()->inTransaction()) {
            db()->rollBack();
        }
        throw $e;
    }
    flash('success', 'Achat n° ' . $a['Numero'] . ' annulé : les quantités sont sorties du stock' . ($caisse ? ', les paiements par la caisse remboursés' : '') . '.');
    redirect('achat/details', ['id' => $id]);
}

/** Consommation : sortie du stock des produits utilisés pour le service, valorisée au coût. */
function achat_consommation(): void
{
    if (is_post()) {
        $tenant = tenant_insert();
        $depot = depot_des_achats($tenant);
        $retour = fn(string $m) => [flash('danger', $m), redirect('achat/consommation')];
        $commentaire = mb_substr(trim((string) post('commentaire', '')), 0, 300) ?: null;
        $lignes = [];
        foreach ((array) ($_POST['produit'] ?? []) as $i => $id) {
            $q = round(montant($_POST['qte'][$i] ?? 0), 2);
            if ((int) $id && $q > 0) {
                if (!q1('SELECT Id FROM Produits WHERE Id = ? AND TenantId = ? AND SuiviStock = 1 AND EstModele = 0 AND EstCombo = 0', [(int) $id, $tenant])) {
                    $retour('Un produit de la liste est introuvable ou sans suivi de stock.');
                }
                $lignes[(int) $id] = ($lignes[(int) $id] ?? 0) + $q;
            }
        }
        if (!$lignes) {
            $retour('Indiquez au moins un produit et la quantité utilisée.');
        }
        db()->beginTransaction();
        try {
            foreach ($lignes as $id => $q) {
                $p = q1('SELECT Nom, Unite FROM Produits WHERE Id = ? FOR UPDATE', [$id]);
                $dispo = (float) qv('SELECT COALESCE(SUM(Quantite), 0) FROM StocksDepots WHERE DepotId = ? AND ProduitId = ?', [$depot['Id'], $id]);
                if ($dispo < $q - 0.001) {
                    db()->rollBack();
                    $retour('Stock insuffisant pour « ' . $p['Nom'] . ' » dans ' . $depot['Nom'] . ' : ' . quantite_fr($dispo) . ' disponible(s).');
                }
                mouvement_stock($id, -$q, 'Consommation', 'CONSO-' . date('Ymd'), null, $commentaire, (int) $depot['Id']);
            }
            db()->commit();
        } catch (Throwable $e) {
            if (db()->inTransaction()) {
                db()->rollBack();
            }
            throw $e;
        }
        flash('success', count($lignes) . ' produit(s) sorti(s) du stock (consommation, ' . $depot['Nom'] . ').');
        redirect('achat/consommation');
    }
    $f = achat_filtres();
    $mouvements = q("SELECT m.*, p.Code, p.Nom, p.Unite, p.Cout, d.Nom AS Depot, u.NomComplet AS Utilisateur
                     FROM MouvementsStock m JOIN Produits p ON p.Id = m.ProduitId LEFT JOIN Depots d ON d.Id = m.DepotId
                     LEFT JOIN Utilisateurs u ON u.Id = m.UtilisateurId
                     WHERE m.TypeMouvement = 'Consommation' AND m.DateMouvement >= ? AND m.DateMouvement < DATE_ADD(?, INTERVAL 1 DAY) AND " . tf('m') . '
                     ORDER BY m.DateMouvement DESC, m.Id DESC', [$f['du'], $f['au']]);
    // Synthèse par produit : quantité consommée et valeur au coût actuel.
    $synthese = [];
    foreach ($mouvements as $m) {
        $s = &$synthese[(int) $m['ProduitId']];
        $s ??= ['Code' => $m['Code'], 'Nom' => $m['Nom'], 'Unite' => $m['Unite'], 'Quantite' => 0.0, 'Valeur' => 0.0];
        $s['Quantite'] += -(float) $m['Quantite'];
        $s['Valeur'] += -(float) $m['Quantite'] * (float) $m['Cout'];
        unset($s);
    }
    usort($synthese, fn($x, $y) => $y['Valeur'] <=> $x['Valeur'] ?: strcmp($x['Nom'], $y['Nom']));
    $depot = achat_depot();
    render('achat/consommation', ['f' => $f, 'mouvements' => $mouvements, 'synthese' => $synthese, 'produits' => achat_produits((int) ($depot['Id'] ?? 0)), 'depot' => $depot]);
}

/**
 * Dépôt des achats : stock de chaque produit (valeur au coût, alerte), entrées et sorties de la
 * période par produit, et détail des mouvements du dépôt.
 */
function achat_stock(): void
{
    $f = achat_filtres();
    $depot = achat_depot();
    $id = (int) ($depot['Id'] ?? 0);
    $mouvements = q('SELECT m.*, p.Code, p.Nom, p.Unite, u.NomComplet AS Utilisateur
                     FROM MouvementsStock m JOIN Produits p ON p.Id = m.ProduitId LEFT JOIN Utilisateurs u ON u.Id = m.UtilisateurId
                     WHERE m.DepotId = ? AND m.DateMouvement >= ? AND m.DateMouvement < DATE_ADD(?, INTERVAL 1 DAY)
                     ORDER BY m.DateMouvement DESC, m.Id DESC', [$id, $f['du'], $f['au']]);
    $produits = [];
    foreach (q('SELECT p.Id, p.Code, p.Nom, p.Unite, p.Cout, p.SeuilAlerte, p.Consommable, COALESCE(sd.Quantite, 0) AS Stock
                FROM Produits p LEFT JOIN StocksDepots sd ON sd.ProduitId = p.Id AND sd.DepotId = ?
                WHERE p.SuiviStock = 1 AND p.EstModele = 0 AND ' . tf('p') . '
                  AND (p.Consommable = 1 AND p.Actif = 1 OR sd.Quantite <> 0 OR EXISTS (SELECT 1 FROM MouvementsStock x WHERE x.ProduitId = p.Id AND x.DepotId = ?))
                ORDER BY p.Consommable DESC, p.Nom', [$id, $id]) as $p) {
        $p['Entrees'] = $p['Sorties'] = 0.0;
        $p['Valeur'] = (float) $p['Stock'] * (float) $p['Cout'];
        $p['Alerte'] = $p['SeuilAlerte'] !== null && (float) $p['Stock'] <= (float) $p['SeuilAlerte'];
        $produits[(int) $p['Id']] = $p;
    }
    foreach ($mouvements as $m) {
        if (isset($produits[(int) $m['ProduitId']])) {
            $produits[(int) $m['ProduitId']][(float) $m['Quantite'] >= 0 ? 'Entrees' : 'Sorties'] += abs((float) $m['Quantite']);
        }
    }
    render('achat/stock', ['f' => $f, 'depot' => $depot, 'produits' => array_values($produits), 'mouvements' => $mouvements]);
}
