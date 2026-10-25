<?php $titre = 'Ventes'; ?>
<div class="d-flex flex-wrap justify-content-between align-items-end gap-2 mb-3">
    <form method="get" action="index.php" class="d-flex flex-wrap gap-2">
        <input type="hidden" name="r" value="vente/index">
        <?php if ($journee): ?><input type="hidden" name="journee" value="<?= (int) $journee ?>"><?php endif; ?>
        <input name="search" class="form-control" placeholder="Rechercher (n° de ticket, client)" value="<?= h($search) ?>" style="min-width:260px;">
        <button class="btn btn-outline-primary" aria-label="Rechercher"><i class="fa fa-search"></i></button>
    </form>
    <?php if ($infoJournee): ?>
        <div class="d-flex align-items-center gap-2">
            <span class="text-muted small">Journée <?= h($infoJournee['ChkCode']) ?> du <?= date_fr($infoJournee['DateJournee']) ?></span>
            <a class="btn btn-sm btn-outline-secondary" href="<?= h(url('vente/index', ['search' => $search])) ?>">Toutes les ventes</a>
            <?php if ($infoJournee['Statut'] === 'Ouverte'): ?>
                <a class="btn btn-sm btn-success" href="<?= h(url('pos/index', ['journee' => $journee])) ?>"><i class="fa fa-store"></i> Retour au POS</a>
            <?php endif; ?>
        </div>
    <?php endif; ?>
</div>
<div class="card shadow-sm border-0">
    <div class="card-body table-responsive">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Ticket</th><th>Date</th><th>Caisse</th><th>Client</th><th>Vendeur</th><th class="text-end">Total TTC</th><th class="text-center">Statut</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php if (!$ventes): ?><tr><td colspan="8" class="text-center text-muted py-4">Aucune vente.</td></tr><?php endif; ?>
            <?php foreach ($ventes as $v): ?>
                <tr>
                    <td class="fw-semibold"><?= h($v['Numero']) ?></td>
                    <td class="text-nowrap"><?= date_fr($v['DateCommande'], 'd/m/Y H:i') ?></td>
                    <td><?= h($v['ChkCode']) ?></td>
                    <td><?= $v['Client'] ? h($v['Client']) : '<span class="text-muted">—</span>' ?></td>
                    <td><?= h($v['Vendeur']) ?></td>
                    <td class="text-end fw-semibold text-nowrap <?= (float) $v['TotalTTC'] < 0 ? 'text-danger' : '' ?>"><?= fcfa($v['TotalTTC']) ?></td>
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
<?= partial('partials/pagination', $pagination) ?>
