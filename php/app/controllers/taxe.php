<?php
// Taxes appliquées aux produits du point de vente (TVA, CSS…). Un produit peut en porter
// plusieurs : elles s'additionnent sur le HT et sont comprises dans le prix TTC.

function taxe_index(): void
{
    render('taxe/index', ['taxes' => q(
        'SELECT t.*, (SELECT COUNT(*) FROM ProduitTaxes pt WHERE pt.TaxeId = t.Id) AS NbProduits
         FROM Taxes t WHERE ' . tf('t') . ' ORDER BY t.ParDefaut DESC, t.Taux DESC, t.Code'
    )]);
}

/** Création (sans Id) ou modification (avec Id) ; le taux total des produits concernés suit. */
function taxe_save(): void
{
    if (is_post()) {
        $code = mb_strtoupper(trim((string) post('Code', '')));
        $taux = montant(post('Taux'));
        $id = int_or_null(post('Id'));
        if ($code === '' || trim((string) post('Libelle', '')) === '') {
            flash('danger', 'Le code et le libellé de la taxe sont obligatoires.');
            redirect('taxe/index');
        }
        if ($taux < 0 || $taux > 100) {
            flash('danger', 'Le taux doit être compris entre 0 et 100 %.');
            redirect('taxe/index');
        }
        if (qv('SELECT COUNT(*) FROM Taxes WHERE Code = ? AND Id <> ? AND ' . tf(), [$code, (int) $id])) {
            flash('danger', "Le code « $code » est déjà utilisé par une autre taxe.");
            redirect('taxe/index');
        }
        $valeurs = [$code, trim((string) post('Libelle')), $taux, post('ParDefaut') ? 1 : 0];
        db()->beginTransaction();
        try {
            if ($id) {
                if (!q1('SELECT Id FROM Taxes WHERE Id = ? AND ' . tf(), [$id])) {
                    not_found('Taxe introuvable.');
                }
                run('UPDATE Taxes SET Code = ?, Libelle = ?, Taux = ?, ParDefaut = ? WHERE Id = ?', [...$valeurs, $id]);
                taxes_recalculer('p.Id IN (SELECT ProduitId FROM ProduitTaxes WHERE TaxeId = ?)', [$id]);
                flash('success', 'Taxe modifiée ; le taux total des produits concernés a été mis à jour.');
            } else {
                run('INSERT INTO Taxes (Code, Libelle, Taux, ParDefaut, TenantId) VALUES (?, ?, ?, ?, ?)', [...$valeurs, tenant_insert()]);
                flash('success', 'Taxe créée.');
            }
            db()->commit();
        } catch (Throwable $e) {
            db()->rollBack();
            throw $e;
        }
    }
    redirect('taxe/index');
}

function taxe_delete(): void
{
    if (is_post()) {
        $id = (int) post('id');
        $nb = (int) qv('SELECT COUNT(*) FROM ProduitTaxes WHERE TaxeId = ?', [$id]);
        if ($nb > 0) {
            flash('danger', "Cette taxe est appliquée à $nb produit(s) : retirez-la de ces produits avant de la supprimer.");
        } else {
            run('DELETE FROM Taxes WHERE Id = ? AND ' . tf(), [$id]);
            flash('success', 'Taxe supprimée.');
        }
    }
    redirect('taxe/index');
}
