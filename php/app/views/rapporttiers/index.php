<?php
$titre = 'Rapport des tiers';
$params = rapporttiers_params($f);
?>
<form method="get" action="index.php" class="card shadow-sm border-0 mb-3">
    <input type="hidden" name="r" value="rapporttiers/index">
    <div class="card-body d-flex flex-wrap align-items-end gap-3">
        <div><label class="form-label small fw-semibold text-muted mb-1" for="du">Du</label><input type="date" class="form-control" id="du" name="du" value="<?= h($f['du']) ?>"></div>
        <div><label class="form-label small fw-semibold text-muted mb-1" for="au">Au</label><input type="date" class="form-control" id="au" name="au" value="<?= h($f['au']) ?>"></div>
        <div>
            <label class="form-label small fw-semibold text-muted mb-1" for="type">Type</label>
            <select class="form-select" id="type" name="type">
                <option value="">Tous</option>
                <?php foreach (RAPPORT_TIERS_TYPES as $t): ?><option <?= $f['type'] === $t ? 'selected' : '' ?>><?= h($t) ?></option><?php endforeach; ?>
            </select>
        </div>
        <div>
            <label class="form-label small fw-semibold text-muted mb-1" for="genre">Genre</label>
            <select class="form-select" id="genre" name="genre">
                <option value="">Tous</option>
                <?php foreach (['Entreprise', 'Particulier'] as $g): ?><option <?= $f['genre'] === $g ? 'selected' : '' ?>><?= $g ?></option><?php endforeach; ?>
            </select>
        </div>
        <div class="form-check mb-2">
            <input class="form-check-input" type="checkbox" value="1" id="tous" name="tous" <?= $f['tous'] ? 'checked' : '' ?>>
            <label class="form-check-label" for="tous">Inclure les tiers sans mouvement</label>
        </div>
        <button class="btn btn-primary"><i class="fa fa-search"></i> Filtrer</button>
        <div class="ms-auto d-flex flex-wrap gap-2">
            <a class="btn btn-outline-primary" href="<?= h(url('rapporttiers/imprimer', $params)) ?>" target="_blank"><i class="fa fa-print"></i> Imprimer / PDF</a>
            <a class="btn btn-success" href="<?= h(url('rapporttiers/excel', $params)) ?>"><i class="fa fa-file-excel"></i> Exporter Excel</a>
        </div>
    </div>
</form>

<div class="row g-3 mb-3">
    <?php foreach ([['Tiers', count($lignes), 'fa-address-book', false], ['Ventes nettes', $totaux['Ventes'], 'fa-cart-shopping', true],
                    ['Encaissements', $totaux['Encaissements'], 'fa-arrow-down', true], ['Décaissements', $totaux['Decaissements'], 'fa-arrow-up', true],
                    ['Solde', $totaux['Solde'], 'fa-scale-balanced', true]] as [$lib, $val, $ico, $montant]): ?>
        <div class="col-6 col-lg"><div class="card border-0 shadow-sm h-100"><div class="card-body">
            <div class="small text-muted"><i class="fa <?= $ico ?>"></i> <?= $lib ?></div>
            <div class="fs-5 fw-bold"><?= $montant ? fcfa($val) . ' <small class="fs-6 fw-normal text-muted">FCFA</small>' : (int) $val ?></div>
        </div></div></div>
    <?php endforeach; ?>
</div>

<div class="card shadow-sm border-0">
    <div class="card-body table-responsive">
        <table id="tiersRapportTable" class="table table-hover align-middle mb-0 small">
            <thead class="table-dark"><tr><th>Code</th><th>Tiers</th><th>Genre</th><th>Type</th><th class="text-end">Ventes</th><th class="text-end">Ventes nettes</th>
                <th class="text-end">Encaissements</th><th class="text-end">Décaissements</th><th class="text-end">Solde</th><th>Dernier mouvement</th><th class="text-center"></th></tr></thead>
            <tbody>
            <?php foreach ($lignes as $l): ?>
                <tr>
                    <td><?= h($l['CodeClient']) ?></td>
                    <td class="fw-semibold"><?= h($l['NomSociete']) ?></td>
                    <td class="text-nowrap"><i class="fa <?= $l['Genre'] === 'Particulier' ? 'fa-user' : 'fa-building' ?> text-muted me-1"></i><?= h($l['Genre']) ?></td>
                    <td><?= h((string) $l['Type']) ?></td>
                    <td class="text-end"><?= (int) $l['NbVentes'] ?></td>
                    <td class="text-end text-nowrap" data-order="<?= (float) $l['Ventes'] ?>"><?= fcfa($l['Ventes']) ?></td>
                    <td class="text-end text-nowrap text-success" data-order="<?= (float) $l['Encaissements'] ?>"><?= fcfa($l['Encaissements']) ?></td>
                    <td class="text-end text-nowrap text-danger" data-order="<?= (float) $l['Decaissements'] ?>"><?= fcfa($l['Decaissements']) ?></td>
                    <td class="text-end text-nowrap fw-semibold" data-order="<?= $l['Solde'] ?>"><?= fcfa($l['Solde']) ?></td>
                    <td class="text-nowrap" data-order="<?= h((string) $l['Dernier']) ?>"><?= $l['Dernier'] ? '<span title="' . h(date_fr($l['Dernier'], 'd/m/Y H:i')) . '">' . date_fr($l['Dernier'], 'd/m/Y') . '</span>' : '<span class="text-muted">—</span>' ?></td>
                    <td class="text-center text-nowrap"><a class="btn btn-outline-primary btn-sm" href="<?= h(url('rapporttiers/releve', $params + ['id' => $l['Id']])) ?>" target="_blank" title="Relevé du tiers" aria-label="Relevé du tiers"><i class="fa fa-file-lines"></i></a></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
            <tfoot>
                <tr class="table-light fw-bold"><td colspan="4">Total (<?= count($lignes) ?> tiers)</td><td class="text-end text-nowrap"><?= (int) $totaux['NbVentes'] ?></td>
                    <td class="text-end text-nowrap"><?= fcfa($totaux['Ventes']) ?></td><td class="text-end text-nowrap"><?= fcfa($totaux['Encaissements']) ?></td>
                    <td class="text-end text-nowrap"><?= fcfa($totaux['Decaissements']) ?></td><td class="text-end text-nowrap"><?= fcfa($totaux['Solde']) ?></td><td colspan="2"></td></tr>
            </tfoot>
        </table>
        <p class="small text-muted mt-2 mb-0">Ventes : tickets du point de vente (retours déduits). Les ventes payées apparaissent aussi dans les encaissements.
            Les opérations rejetées et les ventes annulées ne sont pas comptées.</p>
    </div>
</div>
<?php ob_start(); ?>
<script>
    listeDataTable('#tiersRapportTable', {
        pageLength: 20,
        lengthMenu: [20, 50, 100],
        order: [[1, 'asc']],
        columnDefs: [{ orderable: false, targets: -1 }]
    });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
