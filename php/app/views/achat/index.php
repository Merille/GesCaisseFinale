<?php
$titre = 'Achats';
$onglet = 'index';
require __DIR__ . '/_onglets.php';
?>
<form method="get" action="index.php" class="card shadow-sm border-0 mb-3">
    <input type="hidden" name="r" value="achat/index">
    <div class="card-body d-flex flex-wrap align-items-end gap-3">
        <div><label class="form-label small fw-semibold text-muted mb-1" for="du">Achats du</label><input type="date" class="form-control" id="du" name="du" value="<?= h($f['du']) ?>"></div>
        <div><label class="form-label small fw-semibold text-muted mb-1" for="au">Au</label><input type="date" class="form-control" id="au" name="au" value="<?= h($f['au']) ?>"></div>
        <div>
            <label class="form-label small fw-semibold text-muted mb-1" for="fournisseur">Fournisseur</label>
            <select class="form-select" id="fournisseur" name="fournisseur">
                <option value="">Tous</option>
                <?php foreach ($fournisseurs as $fo): ?><option value="<?= (int) $fo['Id'] ?>" <?= $f['fournisseur'] === (int) $fo['Id'] ? 'selected' : '' ?>><?= h($fo['NomSociete']) ?></option><?php endforeach; ?>
            </select>
        </div>
        <div>
            <label class="form-label small fw-semibold text-muted mb-1" for="statut">Statut</label>
            <select class="form-select" id="statut" name="statut">
                <option value="">Tous</option>
                <?php foreach (['Validé', 'Non soldé', 'Annulé'] as $s): ?><option <?= $f['statut'] === $s ? 'selected' : '' ?>><?= h($s) ?></option><?php endforeach; ?>
            </select>
        </div>
        <button class="btn btn-primary"><i class="fa fa-search"></i> Filtrer</button>
        <a class="btn btn-success ms-auto" href="<?= h(url('achat/nouveau')) ?>"><i class="fa fa-cart-plus"></i> Nouvel achat</a>
    </div>
</form>

<div class="row g-3 mb-3">
    <?php foreach ([['Achats', $totaux['Nombre'], 'fa-cart-flatbed', false, ''], ['Montant des achats', $totaux['Montant'], 'fa-coins', true, ''],
                    ['Réglé', $totaux['Regle'], 'fa-hand-holding-dollar', true, ''], ['Reste à payer (période)', $totaux['Reste'], 'fa-hourglass-half', true, ''],
                    ['Dû aux fournisseurs (total)', $dette, 'fa-file-invoice-dollar', true, $dette > 0 ? ' text-danger' : '']] as [$lib, $val, $ico, $montant, $classe]): ?>
        <div class="col-6 col-lg"><div class="card border-0 shadow-sm h-100"><div class="card-body">
            <div class="small text-muted"><i class="fa <?= $ico ?>"></i> <?= $lib ?></div>
            <div class="fs-5 fw-bold<?= $classe ?>"><?= $montant ? fcfa($val) . ' <small class="fs-6 fw-normal text-muted">FCFA</small>' : (int) $val ?></div>
        </div></div></div>
    <?php endforeach; ?>
</div>

<div class="card shadow-sm border-0">
    <div class="card-body table-responsive">
        <table id="achatsTable" class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>N°</th><th>Date</th><th>Fournisseur</th><th>Référence</th><th>Dépôt</th><th class="text-end">Montant</th>
                <th class="text-end">Réglé</th><th class="text-end">Reste</th><th>Statut</th><th></th></tr></thead>
            <tbody>
            <?php foreach ($achats as $a): ?>
                <tr class="<?= $a['Statut'] === 'Annulé' ? 'text-muted' : '' ?>">
                    <td class="fw-semibold" data-order="<?= (int) $a['Numero'] ?>"><?= (int) $a['Numero'] ?></td>
                    <td class="text-nowrap" data-order="<?= h($a['DateAchat']) . sprintf('%08d', $a['Numero']) ?>"><?= date_fr($a['DateAchat']) ?></td>
                    <td><?= $a['Fournisseur'] ? h($a['Fournisseur']) : '<span class="text-muted">—</span>' ?></td>
                    <td><?= h((string) $a['Reference']) ?></td>
                    <td><?= h((string) $a['Depot']) ?></td>
                    <td class="text-end text-nowrap" data-order="<?= (float) $a['Total'] ?>"><?= fcfa($a['Total']) ?></td>
                    <td class="text-end text-nowrap" data-order="<?= (float) $a['Regle'] ?>"><?= fcfa($a['Regle']) ?></td>
                    <td class="text-end text-nowrap fw-semibold<?= $a['Reste'] > 0 ? ' text-danger' : '' ?>" data-order="<?= (float) $a['Reste'] ?>"><?= $a['Reste'] > 0 ? fcfa($a['Reste']) : '<span class="text-muted">—</span>' ?></td>
                    <td><span class="badge <?= $a['Statut'] === 'Annulé' ? 'bg-secondary' : ($a['Reste'] > 0 ? 'bg-warning text-dark' : 'bg-success') ?>"><?= $a['Statut'] === 'Annulé' ? 'Annulé' : ($a['Reste'] > 0 ? 'Non soldé' : 'Soldé') ?></span></td>
                    <td class="text-end"><a class="btn btn-sm btn-outline-primary" href="<?= h(url('achat/details', ['id' => $a['Id']])) ?>" title="Détail de l'achat"><i class="fa fa-eye"></i></a></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
        <p class="small text-muted mt-2 mb-0">Les totaux ne comptent pas les achats annulés. « Dû aux fournisseurs » : reste à payer de tous les achats validés, quelle que soit leur date.
            Les fournisseurs sont les tiers de type « Fournisseur ».</p>
    </div>
</div>
<?php ob_start(); ?>
<script>
    listeDataTable('#achatsTable', { pageLength: 20, lengthMenu: [20, 50, 100], order: [[1, 'desc']], columnDefs: [{ orderable: false, targets: -1 }] });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
