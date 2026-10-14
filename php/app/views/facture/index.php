<?php $titre = 'Factures'; ?>
<div class="d-flex justify-content-between align-items-center mb-3">
    <h4 class="mb-0">Factures</h4>
    <a href="<?= h(url('facture/create')) ?>" class="btn btn-primary"><i class="fa fa-plus"></i> Nouvelle facture</a>
</div>
<div class="card shadow-sm border-0">
    <div class="card-body table-responsive">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Numéro</th><th>Date</th><th>Client</th><th class="text-end">HT</th><th class="text-end">TVA</th><th class="text-end">TTC</th><th>Statut</th><th></th></tr></thead>
            <tbody>
            <?php if (!$factures): ?><tr><td colspan="8" class="text-center text-muted py-4">Aucune facture.</td></tr><?php endif; ?>
            <?php foreach ($factures as $f): ?>
                <tr>
                    <td class="fw-semibold"><?= h($f['Numero']) ?></td>
                    <td><?= date_fr($f['DateFacture']) ?></td>
                    <td><?= h($f['NomSociete']) ?></td>
                    <td class="text-end"><?= fcfa($f['MontantHT']) ?></td>
                    <td class="text-end"><?= fcfa($f['MontantTVA']) ?></td>
                    <td class="text-end fw-bold"><?= fcfa($f['MontantTTC']) ?></td>
                    <td><span class="badge <?= $f['Statut'] === 'Validée' ? 'bg-success' : 'bg-secondary' ?>"><?= h($f['Statut']) ?></span></td>
                    <td class="text-end table-actions">
                        <a href="<?= h(url('facture/edit', ['id' => $f['Id']])) ?>" class="btn btn-primary btn-sm">Ouvrir</a>
                        <a href="<?= h(url('facture/print', ['id' => $f['Id']])) ?>" class="btn btn-outline-primary btn-sm"><i class="fa fa-print"></i></a>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
<?= partial('partials/pagination', $pagination) ?>
