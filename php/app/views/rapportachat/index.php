<?php
$titre = 'Rapport des achats';
$params = rapportachat_params($f);
$badge = fn(string $s) => ['Annulé' => 'bg-secondary', 'Non soldé' => 'bg-warning text-dark', 'Soldé' => 'bg-success'][$s];
?>
<form method="get" action="index.php" class="card shadow-sm border-0 mb-3">
    <input type="hidden" name="r" value="rapportachat/index">
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
        <button class="btn btn-primary"><i class="fa fa-search"></i> Filtrer</button>
        <div class="ms-auto d-flex flex-wrap gap-2">
            <a class="btn btn-outline-primary" href="<?= h(url('rapportachat/imprimer', $params)) ?>" target="_blank"><i class="fa fa-print"></i> Imprimer / PDF</a>
            <a class="btn btn-success" href="<?= h(url('rapportachat/excel', $params)) ?>"><i class="fa fa-file-excel"></i> Exporter Excel</a>
        </div>
    </div>
</form>
<p class="small text-muted"><?= h($periode) ?>.</p>

<div class="row g-3 mb-3">
    <?php foreach ([['Achats', $total['Nombre'], 'fa-cart-flatbed', false], ['Montant des achats', $total['Montant'], 'fa-coins', true],
                    ['Réglé', $total['Regle'], 'fa-hand-holding-dollar', true], ['Reste à payer', $total['Reste'], 'fa-hourglass-half', true],
                    ['Valeur consommée', $totalProduits['ValeurConsommee'], 'fa-bottle-droplet', true]] as [$lib, $val, $ico, $montant]): ?>
        <div class="col-6 col-lg"><div class="card border-0 shadow-sm h-100"><div class="card-body">
            <div class="small text-muted"><i class="fa <?= $ico ?>"></i> <?= $lib ?></div>
            <div class="fs-5 fw-bold<?= $lib === 'Reste à payer' && $val > 0 ? ' text-danger' : '' ?>"><?= $montant ? fcfa($val) . ' <small class="fs-6 fw-normal text-muted">FCFA</small>' : (int) $val ?></div>
        </div></div></div>
    <?php endforeach; ?>
</div>

<div class="card shadow-sm border-0 mb-3">
    <div class="card-header bg-white fw-semibold">Par fournisseur</div>
    <div class="card-body table-responsive">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Fournisseur</th><th class="text-end">Achats</th><th class="text-end">Montant</th><th class="text-end">Réglé</th><th class="text-end">Reste à payer</th></tr></thead>
            <tbody>
            <?php foreach ($parFournisseur as $nom => $s): ?>
                <tr><td><?= h($nom) ?></td><td class="text-end"><?= (int) $s['Nombre'] ?></td><td class="text-end text-nowrap"><?= fcfa($s['Montant']) ?></td>
                    <td class="text-end text-nowrap"><?= fcfa($s['Regle']) ?></td><td class="text-end text-nowrap fw-semibold<?= $s['Reste'] > 0 ? ' text-danger' : '' ?>"><?= fcfa($s['Reste']) ?></td></tr>
            <?php endforeach; ?>
            <?php if (!$parFournisseur): ?><tr><td colspan="5" class="text-muted">Aucun achat sur la période.</td></tr><?php endif; ?>
            </tbody>
            <tfoot><tr class="table-light fw-bold"><td>Total (hors annulés)</td><td class="text-end"><?= (int) $total['Nombre'] ?></td><td class="text-end text-nowrap"><?= fcfa($total['Montant']) ?></td>
                <td class="text-end text-nowrap"><?= fcfa($total['Regle']) ?></td><td class="text-end text-nowrap"><?= fcfa($total['Reste']) ?></td></tr></tfoot>
        </table>
    </div>
</div>

<div class="card shadow-sm border-0 mb-3">
    <div class="card-header bg-white fw-semibold">Par produit : achats et consommations</div>
    <div class="card-body table-responsive">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Produit</th><th class="text-end">Qté achetée</th><th class="text-end">Montant acheté</th><th class="text-end">Prix moyen</th>
                <th class="text-end">Qté consommée</th><th class="text-end">Valeur consommée</th><th class="text-end">Stock</th></tr></thead>
            <tbody>
            <?php foreach ($produits as $p): ?>
                <tr><td><?= h($p['Code'] . ' · ' . $p['Nom']) ?></td>
                    <td class="text-end text-nowrap"><?= $p['QteAchetee'] ? quantite_fr($p['QteAchetee']) . ' ' . h($p['Unite']) : '<span class="text-muted">—</span>' ?></td>
                    <td class="text-end text-nowrap"><?= $p['MontantAchete'] ? fcfa($p['MontantAchete']) : '<span class="text-muted">—</span>' ?></td>
                    <td class="text-end text-nowrap"><?= $p['QteAchetee'] > 0 ? quantite_fr($p['MontantAchete'] / $p['QteAchetee']) : '<span class="text-muted">—</span>' ?></td>
                    <td class="text-end text-nowrap"><?= $p['QteConsommee'] ? quantite_fr($p['QteConsommee']) . ' ' . h($p['Unite']) : '<span class="text-muted">—</span>' ?></td>
                    <td class="text-end text-nowrap"><?= $p['ValeurConsommee'] ? fcfa($p['ValeurConsommee']) : '<span class="text-muted">—</span>' ?></td>
                    <td class="text-end text-nowrap fw-semibold"><?= quantite_fr($p['Stock']) ?> <?= h($p['Unite']) ?></td></tr>
            <?php endforeach; ?>
            <?php if (!$produits): ?><tr><td colspan="7" class="text-muted">Aucun achat ni consommation sur la période.</td></tr><?php endif; ?>
            </tbody>
            <tfoot><tr class="table-light fw-bold"><td>Total</td><td></td><td class="text-end text-nowrap"><?= fcfa($totalProduits['MontantAchete']) ?></td><td></td><td></td>
                <td class="text-end text-nowrap"><?= fcfa($totalProduits['ValeurConsommee']) ?></td><td></td></tr></tfoot>
        </table>
    </div>
</div>

<div class="card shadow-sm border-0">
    <div class="card-header bg-white fw-semibold">Détail des achats</div>
    <div class="card-body table-responsive">
        <table id="rapportAchatsTable" class="table table-hover align-middle mb-0 small">
            <thead class="table-dark"><tr><th>N°</th><th>Date</th><th>Fournisseur</th><th>Référence</th><th class="text-end">Montant</th><th class="text-end">Réglé</th><th class="text-end">Reste</th><th>Statut</th></tr></thead>
            <tbody>
            <?php foreach ($achats as $a): $statut = rapportachat_statut($a); ?>
                <tr class="<?= $statut === 'Annulé' ? 'text-muted' : '' ?>">
                    <td class="fw-semibold" data-order="<?= (int) $a['Numero'] ?>"><a href="<?= h(url('achat/details', ['id' => $a['Id']])) ?>"><?= (int) $a['Numero'] ?></a></td>
                    <td class="text-nowrap" data-order="<?= h($a['DateAchat']) . sprintf('%08d', $a['Numero']) ?>"><?= date_fr($a['DateAchat']) ?></td>
                    <td><?= h((string) ($a['Fournisseur'] ?? '')) ?></td><td><?= h((string) $a['Reference']) ?></td>
                    <td class="text-end text-nowrap" data-order="<?= (float) $a['Total'] ?>"><?= fcfa($a['Total']) ?></td>
                    <td class="text-end text-nowrap" data-order="<?= (float) $a['Regle'] ?>"><?= fcfa($a['Regle']) ?></td>
                    <td class="text-end text-nowrap fw-semibold" data-order="<?= (float) $a['Reste'] ?>"><?= $a['Reste'] > 0 ? fcfa($a['Reste']) : '<span class="text-muted">—</span>' ?></td>
                    <td><span class="badge <?= $badge($statut) ?>"><?= $statut ?></span></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
        <p class="small text-muted mt-2 mb-0">Les totaux ne comptent pas les achats annulés. Réglé : règlements de l'achat, quelle que soit leur date.
            Consommations : sorties de la période, valorisées au coût actuel du produit (coût moyen pondéré) ; avec un fournisseur choisi, seuls ses produits sont présentés.
            Stock : quantité actuelle dans le dépôt des achats.</p>
    </div>
</div>
<?php ob_start(); ?>
<script>
    listeDataTable('#rapportAchatsTable', { pageLength: 20, lengthMenu: [20, 50, 100], order: [[1, 'desc']] });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
