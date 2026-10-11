<?php
// Motifs d'opération (avec compte général pour l'export Sage).

function motif_index(): void
{
    render('motif/index', ['motifs' => q('SELECT * FROM Motifs WHERE ' . tf() . ' ORDER BY LibelleMotif')]);
}

/** Création (sans ID) ou modification (avec ID). */
function motif_save(): void
{
    if (is_post()) {
        $valeurs = [post('LibelleMotif', ''), post('TypeModif') ?: null, post('CG_Num') ?: null];
        $id = int_or_null(post('ID'));
        if ($id) {
            if (!q1('SELECT ID FROM Motifs WHERE ID = ? AND ' . tf(), [$id])) {
                not_found('Motif introuvable.');
            }
            run('UPDATE Motifs SET LibelleMotif = ?, TypeModif = ?, CG_Num = ? WHERE ID = ?', [...$valeurs, $id]);
            flash('success', 'Motif modifié avec succès.');
        } else {
            run('INSERT INTO Motifs (LibelleMotif, TypeModif, CG_Num, TenantId) VALUES (?, ?, ?, ?)', [...$valeurs, tenant_insert()]);
            flash('success', 'Motif créé avec succès.');
        }
    }
    redirect('motif/index');
}

function motif_delete(): void
{
    if (is_post()) {
        $id = (int) post('id');
        if (qv('SELECT COUNT(*) FROM OperationsCaisses WHERE MotifId = ?', [$id])) {
            flash('danger', 'Ce motif est utilisé par des opérations : il ne peut pas être supprimé.');
        } else {
            run('DELETE FROM Motifs WHERE ID = ? AND ' . tf(), [$id]);
            flash('success', 'Motif supprimé.');
        }
    }
    redirect('motif/index');
}
