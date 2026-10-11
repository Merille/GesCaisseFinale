<?php
// Modes de paiement (espèces, chèque, mobile money...).

function modepaiement_index(): void
{
    render('modepaiement/index', ['modes' => q('SELECT * FROM ModesPaiement WHERE ' . tf() . ' ORDER BY Libelle')]);
}

/** Création (sans Id) ou modification (avec Id). */
function modepaiement_save(): void
{
    if (is_post()) {
        $valeurs = [post('Code', ''), post('Libelle', ''), post('Actif') ? 1 : 0];
        $id = int_or_null(post('Id'));
        if ($id) {
            if (!q1('SELECT Id FROM ModesPaiement WHERE Id = ? AND ' . tf(), [$id])) {
                not_found('Mode de paiement introuvable.');
            }
            run('UPDATE ModesPaiement SET Code = ?, Libelle = ?, Actif = ? WHERE Id = ?', [...$valeurs, $id]);
            flash('success', 'Mode de paiement modifié avec succès.');
        } else {
            run('INSERT INTO ModesPaiement (Code, Libelle, Actif, TenantId) VALUES (?, ?, ?, ?)', [...$valeurs, tenant_insert()]);
            flash('success', 'Mode de paiement créé avec succès.');
        }
    }
    redirect('modepaiement/index');
}

function modepaiement_delete(): void
{
    if (is_post()) {
        $id = (int) post('id');
        if (qv('SELECT COUNT(*) FROM OperationsCaisses WHERE ModePaiementId = ?', [$id])) {
            flash('danger', 'Ce mode de paiement est utilisé par des opérations : désactivez-le plutôt que de le supprimer.');
        } else {
            run('DELETE FROM ModesPaiement WHERE Id = ? AND ' . tf(), [$id]);
            flash('success', 'Mode de paiement supprimé.');
        }
    }
    redirect('modepaiement/index');
}
