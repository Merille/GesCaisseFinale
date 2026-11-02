<?php $titre = 'Factures'; ?>
<div class="d-flex justify-content-between align-items-center mb-3">
    <h4 class="mb-0">Factures</h4>
    <a href="<?= h(url('facture/create')) ?>" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalCreation"><i class="fa fa-plus"></i> Nouvelle facture</a>
</div>
<div class="card shadow-sm border-0">
    <div class="card-body table-responsive">
        <table id="facturesTable" class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Numéro</th><th>Date</th><th>Client</th><th class="text-end">HT</th><th class="text-end">TVA</th><th class="text-end">TTC</th><th>Statut</th><th></th></tr></thead>
            <tbody>
            <?php foreach ($factures as $f): ?>
                <tr>
                    <td class="fw-semibold"><?= h($f['Numero']) ?></td>
                    <td data-order="<?= h($f['DateFacture']) ?>-<?= sprintf('%09d', $f['Id']) ?>"><?= date_fr($f['DateFacture']) ?></td>
                    <td><?= h($f['NomSociete']) ?></td>
                    <td class="text-end" data-order="<?= (float) $f['MontantHT'] ?>"><?= fcfa($f['MontantHT']) ?></td>
                    <td class="text-end" data-order="<?= (float) $f['MontantTVA'] ?>"><?= fcfa($f['MontantTVA']) ?></td>
                    <td class="text-end fw-bold" data-order="<?= (float) $f['MontantTTC'] ?>"><?= fcfa($f['MontantTTC']) ?></td>
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

<?= partial('facture/create', $creation + ['modale' => true]) ?>
<?php ob_start(); ?>
<script>
    listeDataTable('#facturesTable', {
        pageLength: 20,
        lengthMenu: [20, 50, 100],
        order: [[1, 'desc']],
        columnDefs: [{ orderable: false, targets: -1 }],
        dom: '<"d-flex justify-content-between align-items-center mb-3"lf>rtip'
    });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
