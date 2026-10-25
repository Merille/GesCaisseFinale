<?php
// Catégories de produits du point de vente (couleur des tuiles, ordre d'affichage).

function categorie_index(): void
{
    $categories = q(
        'SELECT c.*, (SELECT COUNT(*) FROM Produits p WHERE p.CategorieId = c.Id) AS NbProduits
         FROM Categories c WHERE ' . tf('c') . ' ORDER BY c.Ordre, c.Nom'
    );
    render('categorie/index', ['categories' => $categories]);
}

/** Couleur au format #rrggbb, sinon la couleur de la marque. */
function categorie_couleur(mixed $v): string
{
    $v = strtolower(trim((string) $v));
    return preg_match('/^#[0-9a-f]{6}$/', $v) ? $v : '#195d84';
}

/** Création (sans Id) ou modification (avec Id). */
function categorie_save(): void
{
    if (is_post()) {
        $nom = (string) post('Nom', '');
        if ($nom === '') {
            flash('danger', 'Le nom de la catégorie est obligatoire.');
            redirect('categorie/index');
        }
        $valeurs = [$nom, categorie_couleur(post('Couleur')), (int) post('Ordre', 0)];
        $id = int_or_null(post('Id'));
        if ($id) {
            if (!q1('SELECT Id FROM Categories WHERE Id = ? AND ' . tf(), [$id])) {
                not_found('Catégorie introuvable.');
            }
            run('UPDATE Categories SET Nom = ?, Couleur = ?, Ordre = ? WHERE Id = ?', [...$valeurs, $id]);
            flash('success', 'Catégorie modifiée.');
        } else {
            run('INSERT INTO Categories (Nom, Couleur, Ordre, TenantId) VALUES (?, ?, ?, ?)', [...$valeurs, tenant_insert()]);
            flash('success', 'Catégorie créée.');
        }
    }
    redirect('categorie/index');
}

function categorie_delete(): void
{
    if (is_post()) {
        $id = (int) post('id');
        $nb = (int) qv('SELECT COUNT(*) FROM Produits WHERE CategorieId = ? AND ' . tf(), [$id]);
        if ($nb > 0) {
            flash('danger', "Cette catégorie contient $nb produit(s) : changez-les de catégorie avant de la supprimer.");
        } else {
            run('DELETE FROM Categories WHERE Id = ? AND ' . tf(), [$id]);
            flash('success', 'Catégorie supprimée.');
        }
    }
    redirect('categorie/index');
}
