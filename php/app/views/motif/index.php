<?php $titre = 'Motifs'; $types = ['Client', 'Fournisseur', 'Salarié', 'Autre']; ?>
<div class="d-flex justify-content-between align-items-center mb-3">
    <h4 class="mb-0">Liste des motifs</h4>
    <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalMotif" data-id=""><i class="fa fa-plus"></i> Nouveau motif</button>
</div>
<div class="card shadow-sm border-0">
    <div class="card-body">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Libellé</th><th>Type</th><th>CG Num</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php if (!$motifs): ?><tr><td colspan="4" class="text-center text-muted py-4">Aucun motif.</td></tr><?php endif; ?>
            <?php foreach ($motifs as $m):
                $badge = ['Client' => 'bg-primary', 'Fournisseur' => 'bg-orange', 'Salarié' => 'bg-success', 'Autre' => 'bg-danger'][$m['TypeModif']] ?? 'bg-secondary'; ?>
                <tr>
                    <td><?= h($m['LibelleMotif']) ?></td>
                    <td><?php if ($m['TypeModif']): ?><span class="badge <?= $badge ?>"><?= h($m['TypeModif']) ?></span><?php endif; ?></td>
                    <td><?= h($m['CG_Num']) ?></td>
                    <td class="text-center table-actions">
                        <button class="btn btn-warning btn-sm" data-bs-toggle="modal" data-bs-target="#modalMotif"
                                data-id="<?= (int) $m['ID'] ?>" data-libelle="<?= h($m['LibelleMotif']) ?>" data-type="<?= h($m['TypeModif']) ?>" data-cg="<?= h($m['CG_Num']) ?>">Modifier</button>
                        <form method="post" action="<?= h(url('motif/delete')) ?>" onsubmit="return confirm('Supprimer ce motif ?');">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $m['ID'] ?>">
                            <button class="btn btn-danger btn-sm">Supprimer</button>
                        </form>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<div class="modal fade" id="modalMotif" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-brand text-white">
                <h5 class="modal-title" id="motifTitre">Motif</h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>
            </div>
            <form method="post" action="<?= h(url('motif/save')) ?>">
                <?= csrf_field() ?>
                <input type="hidden" name="ID" id="motifId">
                <div class="modal-body">
                    <div class="mb-3"><label class="form-label" for="motifLibelle">Libellé</label><input id="motifLibelle" name="LibelleMotif" class="form-control" placeholder="Ex : Remboursement" required></div>
                    <div class="mb-3"><label class="form-label" for="motifType">Type</label>
                        <select id="motifType" name="TypeModif" class="form-select"><option value="">-- Choisir un type --</option>
                            <?php foreach ($types as $t): ?><option value="<?= $t ?>"><?= $t ?></option><?php endforeach; ?></select></div>
                    <div class="mb-3"><label class="form-label" for="motifCg">Compte général (CG Num)</label><input id="motifCg" name="CG_Num" class="form-control" placeholder="Ex : 401000"></div>
                </div>
                <div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Annuler</button><button class="btn btn-primary">Enregistrer</button></div>
            </form>
        </div>
    </div>
</div>
<?php ob_start(); ?>
<script>
    document.getElementById('modalMotif').addEventListener('show.bs.modal', function (e) {
        const d = e.relatedTarget.dataset;
        document.getElementById('motifTitre').textContent = d.id ? 'Modifier le motif' : 'Nouveau motif';
        document.getElementById('motifId').value = d.id || '';
        document.getElementById('motifLibelle').value = d.libelle || '';
        document.getElementById('motifType').value = d.type || '';
        document.getElementById('motifCg').value = d.cg || '';
    });
</script>
<?php $scripts = ob_get_clean(); ?>
