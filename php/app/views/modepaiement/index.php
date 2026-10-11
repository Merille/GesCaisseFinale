<?php $titre = 'Modes de paiement'; ?>
<div class="d-flex justify-content-between align-items-center mb-3">
    <h4 class="mb-0">Modes de paiement</h4>
    <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalMode" data-id="" data-actif="1"><i class="fa fa-plus"></i> Nouveau mode</button>
</div>
<div class="card shadow-sm border-0">
    <div class="card-body">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Code</th><th>Libellé</th><th>Statut</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php if (!$modes): ?><tr><td colspan="4" class="text-center text-muted py-4">Aucun mode de paiement.</td></tr><?php endif; ?>
            <?php foreach ($modes as $m): ?>
                <tr>
                    <td><?= h($m['Code']) ?></td>
                    <td><?= h($m['Libelle']) ?></td>
                    <td><?= $m['Actif'] ? '<span class="badge bg-success">Actif</span>' : '<span class="badge bg-secondary">Inactif</span>' ?></td>
                    <td class="text-center table-actions">
                        <button class="btn btn-warning btn-sm" data-bs-toggle="modal" data-bs-target="#modalMode"
                                data-id="<?= (int) $m['Id'] ?>" data-code="<?= h($m['Code']) ?>" data-libelle="<?= h($m['Libelle']) ?>" data-actif="<?= $m['Actif'] ? '1' : '0' ?>">Modifier</button>
                        <form method="post" action="<?= h(url('modepaiement/delete')) ?>" onsubmit="return confirm('Supprimer ce mode de paiement ?');">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $m['Id'] ?>">
                            <button class="btn btn-danger btn-sm">Supprimer</button>
                        </form>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<div class="modal fade" id="modalMode" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-brand text-white">
                <h5 class="modal-title" id="modeTitre">Mode de paiement</h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>
            </div>
            <form method="post" action="<?= h(url('modepaiement/save')) ?>">
                <?= csrf_field() ?>
                <input type="hidden" name="Id" id="modeId">
                <div class="modal-body">
                    <div class="mb-3"><label class="form-label" for="modeCode">Code</label><input id="modeCode" name="Code" class="form-control" placeholder="Ex : ESP"></div>
                    <div class="mb-3"><label class="form-label" for="modeLibelle">Libellé</label><input id="modeLibelle" name="Libelle" class="form-control" placeholder="Ex : Espèces" required></div>
                    <div class="form-check"><input class="form-check-input" type="checkbox" value="1" name="Actif" id="modeActif"><label class="form-check-label" for="modeActif">Actif (proposé lors de la saisie des opérations)</label></div>
                </div>
                <div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Annuler</button><button class="btn btn-primary">Enregistrer</button></div>
            </form>
        </div>
    </div>
</div>
<?php ob_start(); ?>
<script>
    document.getElementById('modalMode').addEventListener('show.bs.modal', function (e) {
        const d = e.relatedTarget.dataset;
        document.getElementById('modeTitre').textContent = d.id ? 'Modifier le mode de paiement' : 'Nouveau mode de paiement';
        document.getElementById('modeId').value = d.id || '';
        document.getElementById('modeCode').value = d.code || '';
        document.getElementById('modeLibelle').value = d.libelle || '';
        document.getElementById('modeActif').checked = d.actif === '1';
    });
</script>
<?php $scripts = ob_get_clean(); ?>
