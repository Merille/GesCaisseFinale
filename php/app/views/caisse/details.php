<?php $titre = 'Caisse ' . $caisse['ChkCode']; ?>
<div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-3">
    <h4 class="mb-0"><?= h($caisse['ChkCode'] . ' - ' . $caisse['ChkDescription']) ?></h4>
    <div class="d-flex gap-2">
        <a href="<?= h(url('journee/printjournees', ['caisseId' => $caisse['ID']])) ?>" class="btn btn-outline-primary"><i class="fa fa-print"></i> Imprimer les journées</a>
        <a href="<?= h(url('journee/create', ['id' => $caisse['ID']])) ?>" class="btn btn-success" data-bs-toggle="modal" data-bs-target="#modalCreation"><i class="fa fa-plus"></i> Ouvrir une journée</a>
        <a href="<?= h(url('caisse/index')) ?>" class="btn btn-dark">Retour</a>
    </div>
</div>
<div class="card shadow-sm border-0">
    <div class="card-body">
        <table id="journeesTable" class="table table-hover align-middle mb-0">
            <thead class="table-dark">
            <tr><th>Date</th><th>N° journée</th><th class="text-end">Initial</th><th class="text-end">Encaissé</th><th class="text-end">Décaissé</th><th class="text-end">Solde</th><th>Statut</th><th></th></tr>
            </thead>
            <tbody>
            <?php foreach ($journees as $j): ?>
                <tr>
                    <td data-order="<?= h($j['DateJournee']) ?>-<?= sprintf('%09d', $j['Id']) ?>"><?= date_fr($j['DateJournee']) ?></td>
                    <td><?= h($j['NumeroJournee']) ?></td>
                    <td class="text-end" data-order="<?= (float) $j['SoldeInitial'] ?>"><?= fcfa($j['SoldeInitial']) ?></td>
                    <td class="text-end text-success" data-order="<?= (float) $j['Encaisse'] ?>"><?= fcfa($j['Encaisse']) ?></td>
                    <td class="text-end text-danger" data-order="<?= (float) $j['Decaisse'] ?>"><?= fcfa($j['Decaisse']) ?></td>
                    <td class="text-end fw-bold" data-order="<?= (float) $j['Solde'] ?>"><?= fcfa($j['Solde']) ?></td>
                    <td><?= $j['Statut'] === 'Ouverte' ? '<span class="badge bg-success">Ouverte</span>' : '<span class="badge bg-secondary">Clôturée</span>' ?></td>
                    <td class="text-end"><a href="<?= h(url('journee/details', ['id' => $j['Id']])) ?>" class="btn btn-primary btn-sm">Ouvrir</a></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<?= partial('journee/create', ['caisse' => $caisse, 'soldeSuggere' => $soldeSuggere, 'modale' => true]) ?>
<?php ob_start(); ?>
<script>
    listeDataTable('#journeesTable', {
        pageLength: 20,
        lengthMenu: [20, 50, 100],
        order: [[0, 'desc']],
        columnDefs: [{ orderable: false, targets: -1 }],
        dom: '<"d-flex justify-content-between align-items-center mb-3"lf>rtip'
    });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
