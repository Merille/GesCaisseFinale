<?php
// Stock du point de vente, suivi par dépôt : historique des mouvements, stock par dépôt, entrées
// de marchandises, transferts entre dépôts, inventaire et option « vente sans stock ».
// Réservé aux profils Admin et SuperAdmin.

const STOCK_TYPES = ['Stock initial', 'Entrée', 'Inventaire', 'Vente', 'Retour', 'Annulation', 'Transfert'];

/** Produits suivis ; StockDepot = quantité dans le dépôt donné (0 = pas de dépôt). */
function stock_produits_suivis(int $categorie = 0, int $depot = 0): array
{
    return q(
        'SELECT p.Id, p.Code, p.Nom, p.StockActuel, p.SeuilAlerte, c.Nom AS Categorie, COALESCE(sd.Quantite, 0) AS StockDepot
         FROM Produits p LEFT JOIN Categories c ON c.Id = p.CategorieId
         LEFT JOIN StocksDepots sd ON sd.ProduitId = p.Id AND sd.DepotId = ?
         WHERE p.SuiviStock = 1 AND p.Actif = 1 AND p.EstModele = 0 AND ' . tf('p') . ($categorie ? ' AND p.CategorieId = ' . $categorie : '') . '
         ORDER BY p.Nom',
        [$depot]
    );
}

/** Dépôts actifs de la société, le dépôt par défaut en premier. */
function stock_depots_actifs(): array
{
    if (tenant_id() > 0) {
        depot_par_defaut(tenant_id());
    }
    return q('SELECT Id, Code, Nom, ParDefaut FROM Depots WHERE Actif = 1 AND ' . tf() . ' ORDER BY ParDefaut DESC, Code');
}

/**
 * Dépôt actif de la société saisi dans le champ donné, sinon null. Champ vide et $parDefaut :
 * dépôt par défaut de la société (comme pour une caisse sans dépôt choisi).
 */
function stock_depot_saisi(string $champ, int $tenant, bool $parDefaut = false): ?array
{
    $id = (int) post($champ, 0);
    if (!$id && $parDefaut) {
        $id = depot_par_defaut($tenant);
    }
    return q1('SELECT * FROM Depots WHERE Id = ? AND TenantId = ? AND Actif = 1', [$id, $tenant]);
}

/** Dépôt choisi dans l'adresse (?depot=), sinon le premier dépôt actif (le dépôt par défaut). */
function stock_depot_choisi(array $depots): int
{
    $id = (int) get('depot', 0);
    foreach ($depots as $d) {
        if ((int) $d['Id'] === $id) {
            return $id;
        }
    }
    return $depots ? (int) $depots[0]['Id'] : 0;
}

function stock_index(): void
{
    $produit = (int) get('produit', 0);
    $depot = (int) get('depot', 0);
    $type = (string) get('type', '');
    $du = (string) get('du', '');
    $au = (string) get('au', '');
    $where = tf('m');
    $params = [];
    if ($produit) {
        $where .= ' AND m.ProduitId = ?';
        $params[] = $produit;
    }
    if ($depot) {
        $where .= ' AND m.DepotId = ?';
        $params[] = $depot;
    }
    if (in_array($type, STOCK_TYPES, true)) {
        $where .= ' AND m.TypeMouvement = ?';
        $params[] = $type;
    }
    if (DateTime::createFromFormat('!Y-m-d', $du)) {
        $where .= ' AND m.DateMouvement >= ?';
        $params[] = $du;
    }
    if (DateTime::createFromFormat('!Y-m-d', $au)) {
        $where .= ' AND m.DateMouvement < DATE_ADD(?, INTERVAL 1 DAY)';
        $params[] = $au;
    }
    $from = ' FROM MouvementsStock m JOIN Produits p ON p.Id = m.ProduitId
              LEFT JOIN Depots d ON d.Id = m.DepotId
              LEFT JOIN Utilisateurs u ON u.Id = m.UtilisateurId WHERE ' . $where;
    render('stock/index', [
        'mouvements' => q('SELECT m.*, p.Code, p.Nom, d.Code AS DepotCode, d.Nom AS DepotNom, u.NomComplet AS Utilisateur' . $from
            . ' ORDER BY m.DateMouvement DESC, m.Id DESC LIMIT 2000', $params),
        'produits' => q('SELECT Id, Code, Nom FROM Produits WHERE SuiviStock = 1 AND EstModele = 0 AND ' . tf() . ' ORDER BY Nom'),
        'depots' => q('SELECT Id, Code, Nom FROM Depots WHERE ' . tf() . ' ORDER BY ParDefaut DESC, Code'),
        'filtres' => ['produit' => $produit, 'depot' => $depot, 'type' => $type, 'du' => $du, 'au' => $au],
        'alertes' => q(
            'SELECT Id, Code, Nom, StockActuel, SeuilAlerte FROM Produits
             WHERE SuiviStock = 1 AND Actif = 1 AND EstModele = 0 AND SeuilAlerte IS NOT NULL AND StockActuel <= SeuilAlerte AND ' . tf() . '
             ORDER BY StockActuel - SeuilAlerte, Nom'
        ),
        'venteSansStock' => tenant_id() ? vente_sans_stock(tenant_id()) : null,
    ]);
}

/** Stock par dépôt : quantité de chaque produit suivi dans chaque dépôt, et total. */
function stock_depots(): void
{
    $categorie = (int) get('categorie', 0);
    $depots = q('SELECT d.Id, d.Code, d.Nom, d.Actif FROM Depots d WHERE ' . tf('d') . '
                 AND (d.Actif = 1 OR EXISTS (SELECT 1 FROM StocksDepots s WHERE s.DepotId = d.Id AND s.Quantite <> 0))
                 ORDER BY d.ParDefaut DESC, d.Code');
    $quantites = [];
    foreach (q('SELECT s.DepotId, s.ProduitId, s.Quantite FROM StocksDepots s JOIN Depots d ON d.Id = s.DepotId WHERE ' . tf('d')) as $s) {
        $quantites[(int) $s['ProduitId']][(int) $s['DepotId']] = (float) $s['Quantite'];
    }
    render('stock/depots', [
        'produits' => stock_produits_suivis($categorie),
        'depots' => $depots,
        'quantites' => $quantites,
        'categories' => q('SELECT Id, Nom FROM Categories WHERE ' . tf() . ' ORDER BY Ordre, Nom'),
        'categorie' => $categorie,
    ]);
}

/** Entrée de marchandises : plusieurs produits reçus en une fois (bon de livraison), dans un dépôt. */
function stock_entree(): void
{
    if (is_post()) {
        $tenant = tenant_insert();
        $depot = stock_depot_saisi('depot', $tenant, true);
        if (!$depot) {
            flash('danger', 'Choisissez le dépôt qui reçoit les marchandises.');
            redirect('stock/entree');
        }
        $reference = trim((string) post('reference', '')) ?: null;
        $commentaire = trim((string) post('commentaire', '')) ?: null;
        $produits = (array) ($_POST['produit'] ?? []);
        $quantites = (array) ($_POST['qte'] ?? []);
        $lignes = [];
        foreach ($produits as $i => $id) {
            $q = round(montant($quantites[$i] ?? 0), 2);
            if ((int) $id && $q > 0) {
                if (!q1('SELECT Id FROM Produits WHERE Id = ? AND TenantId = ? AND SuiviStock = 1 AND EstModele = 0', [(int) $id, $tenant])) {
                    flash('danger', 'Un produit de la liste est introuvable ou sans suivi de stock.');
                    redirect('stock/entree');
                }
                $lignes[] = [(int) $id, $q];
            }
        }
        if (!$lignes) {
            flash('danger', 'Indiquez au moins un produit et une quantité reçue.');
            redirect('stock/entree');
        }
        db()->beginTransaction();
        try {
            foreach ($lignes as [$id, $q]) {
                mouvement_stock($id, $q, 'Entrée', $reference, null, $commentaire, (int) $depot['Id']);
            }
            db()->commit();
        } catch (Throwable $e) {
            db()->rollBack();
            throw $e;
        }
        flash('success', count($lignes) . ' produit(s) entré(s) en stock (' . $depot['Nom'] . ').');
        redirect('stock/index', ['type' => 'Entrée']);
    }
    render('stock/entree', ['produits' => stock_produits_suivis(), 'depots' => stock_depots_actifs()]);
}

/**
 * Transfert entre deux dépôts : chaque produit sort du dépôt de départ et entre dans le dépôt
 * d'arrivée (deux mouvements « Transfert ») ; le stock total ne change pas.
 */
function stock_transfert(): void
{
    if (is_post()) {
        $tenant = tenant_insert();
        $depart = stock_depot_saisi('depart', $tenant);
        $arrivee = stock_depot_saisi('arrivee', $tenant);
        if (!$depart || !$arrivee) {
            flash('danger', "Choisissez le dépôt de départ et le dépôt d'arrivée.");
            redirect('stock/transfert');
        }
        if ((int) $depart['Id'] === (int) $arrivee['Id']) {
            flash('danger', "Le dépôt d'arrivée doit être différent du dépôt de départ.");
            redirect('stock/transfert');
        }
        $reference = trim((string) post('reference', '')) ?: 'TRF-' . date('Ymd-Hi');
        $commentaire = trim((string) post('commentaire', '')) ?: null;
        $lignes = [];
        foreach ((array) ($_POST['produit'] ?? []) as $i => $id) {
            $q = round(montant($_POST['qte'][$i] ?? 0), 2);
            if ((int) $id && $q > 0) {
                if (!q1('SELECT Id FROM Produits WHERE Id = ? AND TenantId = ? AND SuiviStock = 1 AND EstModele = 0', [(int) $id, $tenant])) {
                    flash('danger', 'Un produit de la liste est introuvable ou sans suivi de stock.');
                    redirect('stock/transfert');
                }
                $lignes[(int) $id] = ($lignes[(int) $id] ?? 0) + $q;
            }
        }
        if (!$lignes) {
            flash('danger', 'Indiquez au moins un produit et une quantité à transférer.');
            redirect('stock/transfert');
        }
        db()->beginTransaction();
        try {
            foreach ($lignes as $id => $q) {
                $p = q1('SELECT Nom FROM Produits WHERE Id = ? FOR UPDATE', [$id]);
                $dispo = stock_depot($id, (int) $depart['Id']);
                if ($dispo < $q - 0.001) {
                    db()->rollBack();
                    flash('danger', 'Stock insuffisant dans « ' . $depart['Nom'] . ' » pour « ' . $p['Nom'] . ' » : ' . quantite_fr($dispo) . ' disponible(s).');
                    redirect('stock/transfert');
                }
                mouvement_stock($id, -$q, 'Transfert', $reference, null, $commentaire ?? 'Vers ' . $arrivee['Nom'], (int) $depart['Id']);
                mouvement_stock($id, $q, 'Transfert', $reference, null, $commentaire ?? 'Depuis ' . $depart['Nom'], (int) $arrivee['Id']);
            }
            db()->commit();
        } catch (Throwable $e) {
            if (db()->inTransaction()) {
                db()->rollBack();
            }
            throw $e;
        }
        flash('success', count($lignes) . ' produit(s) transféré(s) de « ' . $depart['Nom'] . ' » vers « ' . $arrivee['Nom'] . ' ».');
        redirect('stock/index', ['type' => 'Transfert']);
    }
    $depots = stock_depots_actifs();
    $depart = stock_depot_choisi($depots);
    render('stock/transfert', ['produits' => stock_produits_suivis(0, $depart), 'depots' => $depots, 'depart' => $depart]);
}

/** Inventaire : stock compté saisi par produit ; l'écart devient un mouvement « Inventaire ». */
function stock_inventaire(): void
{
    if (is_post()) {
        $tenant = tenant_insert();
        $depot = stock_depot_saisi('depot', $tenant, true);
        if (!$depot) {
            flash('danger', 'Choisissez le dépôt inventorié.');
            redirect('stock/inventaire');
        }
        $comptes = (array) ($_POST['compte'] ?? []);
        $reference = 'INV-' . date('Ymd-Hi');
        $nb = 0;
        db()->beginTransaction();
        try {
            foreach ($comptes as $id => $valeur) {
                if (trim((string) $valeur) === '') {
                    continue;
                }
                $p = q1('SELECT Id FROM Produits WHERE Id = ? AND SuiviStock = 1 AND EstModele = 0 AND ' . tf() . ' FOR UPDATE', [(int) $id]);
                if (!$p) {
                    continue;
                }
                $ecart = round(montant($valeur) - stock_depot((int) $p['Id'], (int) $depot['Id']), 2);
                if (abs($ecart) >= 0.01) {
                    mouvement_stock((int) $p['Id'], $ecart, 'Inventaire', $reference, null, trim((string) post('commentaire', '')) ?: null, (int) $depot['Id']);
                    $nb++;
                }
            }
            db()->commit();
        } catch (Throwable $e) {
            db()->rollBack();
            throw $e;
        }
        flash('success', $nb ? "Inventaire $reference ({$depot['Nom']}) enregistré : $nb produit(s) ajusté(s)." : 'Inventaire enregistré : aucun écart.');
        redirect('stock/index', ['type' => 'Inventaire']);
    }
    $categorie = (int) get('categorie', 0);
    $depots = stock_depots_actifs();
    $depot = stock_depot_choisi($depots);
    render('stock/inventaire', [
        'produits' => stock_produits_suivis($categorie, $depot),
        'depots' => $depots,
        'depot' => $depot,
        'categories' => q('SELECT Id, Nom FROM Categories WHERE ' . tf() . ' ORDER BY Ordre, Nom'),
        'categorie' => $categorie,
    ]);
}

/** Option de la société : autoriser ou non la vente quand le stock est épuisé. */
function stock_option(): void
{
    if (is_post()) {
        $tenant = tenant_insert();
        $autorise = post('venteSansStock') === '1' ? 1 : 0;
        run('UPDATE Tenants SET PosVenteSansStock = ? WHERE Id = ?', [$autorise, $tenant]);
        flash('success', $autorise
            ? 'Vente sans stock autorisée : le point de vente affiche seulement un avertissement.'
            : 'Vente sans stock interdite : un produit épuisé ne peut plus être vendu.');
    }
    redirect('stock/index');
}
