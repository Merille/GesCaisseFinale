<?php
// Stock du point de vente : historique des mouvements, entrées de marchandises,
// inventaire et option « vente sans stock ». Réservé aux profils Admin et SuperAdmin.

const STOCK_TYPES = ['Stock initial', 'Entrée', 'Inventaire', 'Vente', 'Retour', 'Annulation'];

function stock_produits_suivis(int $categorie = 0): array
{
    return q(
        'SELECT p.Id, p.Code, p.Nom, p.StockActuel, p.SeuilAlerte, c.Nom AS Categorie
         FROM Produits p LEFT JOIN Categories c ON c.Id = p.CategorieId
         WHERE p.SuiviStock = 1 AND p.Actif = 1 AND ' . tf('p') . ($categorie ? ' AND p.CategorieId = ' . $categorie : '') . '
         ORDER BY p.Nom'
    );
}

function stock_index(): void
{
    $produit = (int) get('produit', 0);
    $type = (string) get('type', '');
    $du = (string) get('du', '');
    $au = (string) get('au', '');
    $where = tf('m');
    $params = [];
    if ($produit) {
        $where .= ' AND m.ProduitId = ?';
        $params[] = $produit;
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
              LEFT JOIN Utilisateurs u ON u.Id = m.UtilisateurId WHERE ' . $where;
    $pagination = paginer((int) qv('SELECT COUNT(*)' . $from, $params), 'stock/index',
        ['produit' => $produit ?: null, 'type' => $type, 'du' => $du, 'au' => $au], 'Mouvements');
    render('stock/index', [
        'mouvements' => q('SELECT m.*, p.Code, p.Nom, u.NomComplet AS Utilisateur' . $from
            . ' ORDER BY m.DateMouvement DESC, m.Id DESC' . $pagination['limite'], $params),
        'pagination' => $pagination,
        'produits' => q('SELECT Id, Code, Nom FROM Produits WHERE SuiviStock = 1 AND ' . tf() . ' ORDER BY Nom'),
        'filtres' => ['produit' => $produit, 'type' => $type, 'du' => $du, 'au' => $au],
        'alertes' => q(
            'SELECT Id, Code, Nom, StockActuel, SeuilAlerte FROM Produits
             WHERE SuiviStock = 1 AND Actif = 1 AND SeuilAlerte IS NOT NULL AND StockActuel <= SeuilAlerte AND ' . tf() . '
             ORDER BY StockActuel - SeuilAlerte, Nom'
        ),
        'venteSansStock' => tenant_id() ? vente_sans_stock(tenant_id()) : null,
    ]);
}

/** Entrée de marchandises : plusieurs produits reçus en une fois (bon de livraison). */
function stock_entree(): void
{
    if (is_post()) {
        $tenant = tenant_insert();
        $reference = trim((string) post('reference', '')) ?: null;
        $commentaire = trim((string) post('commentaire', '')) ?: null;
        $produits = (array) ($_POST['produit'] ?? []);
        $quantites = (array) ($_POST['qte'] ?? []);
        $lignes = [];
        foreach ($produits as $i => $id) {
            $q = round(montant($quantites[$i] ?? 0), 2);
            if ((int) $id && $q > 0) {
                if (!q1('SELECT Id FROM Produits WHERE Id = ? AND TenantId = ? AND SuiviStock = 1', [(int) $id, $tenant])) {
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
                mouvement_stock($id, $q, 'Entrée', $reference, null, $commentaire);
            }
            db()->commit();
        } catch (Throwable $e) {
            db()->rollBack();
            throw $e;
        }
        flash('success', count($lignes) . ' produit(s) entré(s) en stock.');
        redirect('stock/index', ['type' => 'Entrée']);
    }
    render('stock/entree', ['produits' => stock_produits_suivis()]);
}

/** Inventaire : stock compté saisi par produit ; l'écart devient un mouvement « Inventaire ». */
function stock_inventaire(): void
{
    if (is_post()) {
        tenant_insert();
        $comptes = (array) ($_POST['compte'] ?? []);
        $reference = 'INV-' . date('Ymd-Hi');
        $nb = 0;
        db()->beginTransaction();
        try {
            foreach ($comptes as $id => $valeur) {
                if (trim((string) $valeur) === '') {
                    continue;
                }
                $p = q1('SELECT Id, StockActuel FROM Produits WHERE Id = ? AND SuiviStock = 1 AND ' . tf() . ' FOR UPDATE', [(int) $id]);
                if (!$p) {
                    continue;
                }
                $ecart = round(montant($valeur) - (float) $p['StockActuel'], 2);
                if (abs($ecart) >= 0.01) {
                    mouvement_stock((int) $p['Id'], $ecart, 'Inventaire', $reference, null, trim((string) post('commentaire', '')) ?: null);
                    $nb++;
                }
            }
            db()->commit();
        } catch (Throwable $e) {
            db()->rollBack();
            throw $e;
        }
        flash('success', $nb ? "Inventaire $reference enregistré : $nb produit(s) ajusté(s)." : 'Inventaire enregistré : aucun écart.');
        redirect('stock/index', ['type' => 'Inventaire']);
    }
    $categorie = (int) get('categorie', 0);
    render('stock/inventaire', [
        'produits' => stock_produits_suivis($categorie),
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
