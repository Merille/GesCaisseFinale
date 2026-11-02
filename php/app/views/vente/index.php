<?php $titre = 'Ventes'; ?>
<?php if ($infoJournee): ?>
    <div class="d-flex flex-wrap align-items-center gap-2 mb-3">
        <span class="text-muted">Journée <?= h($infoJournee['ChkCode']) ?> du <?= date_fr($infoJournee['DateJournee']) ?></span>
        <a class="btn btn-sm btn-outline-secondary" href="<?= h(url('vente/index')) ?>">Toutes les ventes</a>
        <?php if ($infoJournee['Statut'] === 'Ouverte'): ?>
            <a class="btn btn-sm btn-success" href="<?= h(url('pos/index', ['journee' => $journee])) ?>"><i class="fa fa-store"></i> Retour au POS</a>
        <?php endif; ?>
    </div>
<?php endif; ?>
<div class="card shadow-sm border-0">
    <div class="card-body table-responsive">
        <table id="ventesTable" class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Ticket</th><th>Date</th><th>Caisse</th><th>Client</th><th>Vendeur</th><th class="text-end">Total TTC</th><th class="text-center">Statut</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php foreach ($ventes as $v): ?>
                <tr>
                    <td class="fw-semibold"><?= h($v['Numero']) ?></td>
                    <td class="text-nowrap" data-order="<?= h($v['DateCommande']) ?>"><?= date_fr($v['DateCommande'], 'd/m/Y H:i') ?></td>
                    <td><?= h($v['ChkCode']) ?></td>
                    <td><?= $v['Client'] ? h($v['Client']) : '<span class="text-muted">—</span>' ?></td>
                    <td><?= h($v['Vendeur']) ?></td>
                    <td class="text-end fw-semibold text-nowrap <?= (float) $v['TotalTTC'] < 0 ? 'text-danger' : '' ?>" data-order="<?= (float) $v['TotalTTC'] ?>"><?= fcfa($v['TotalTTC']) ?></td>
                    <td class="text-center"><?php $statut = $v['Statut']; require __DIR__ . '/_statut.php'; ?></td>
                    <td class="text-center table-actions">
                        <a href="<?= h(url('vente/details', ['id' => $v['Id']])) ?>" class="btn btn-primary btn-sm">Ouvrir</a>
                        <a href="<?= h(url('pos/ticket', ['id' => $v['Id']])) ?>" target="_blank" class="btn btn-outline-primary btn-sm" title="Ticket"><i class="fa fa-print"></i></a>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
<?php ob_start(); ?>
<script>
    listeDataTable('#ventesTable', {
        pageLength: 20,
        lengthMenu: [20, 50, 100],
        order: [[1, 'desc']],
        columnDefs: [{ orderable: false, targets: 7 }],
        dom: '<"d-flex justify-content-between align-items-center mb-3"lf>rtip'
    });
</script>
<?php $scripts = ob_get_clean(); ?>
