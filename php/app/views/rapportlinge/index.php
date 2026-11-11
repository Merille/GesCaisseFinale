<?php
$titre = 'Rapport des dépôts de linge';
$params = rapportlinge_params($f);
$badge = fn(string $s) => ['En cours' => 'bg-warning text-dark', 'Prêt' => 'bg-info text-dark', 'Retiré' => 'bg-success', 'Annulé' => 'bg-secondary'][$s] ?? 'bg-secondary';
$sansPeriode = in_array($f['statut'], ['À retirer', 'En retard'], true);
?>
<form method="get" action="index.php" class="card shadow-sm border-0 mb-3">
    <input type="hidden" name="r" value="rapportlinge/index">
    <div class="card-body d-flex flex-wrap align-items-end gap-3">
        <div><label class="form-label small fw-semibold text-muted mb-1" for="du">Déposés du</label><input type="date" class="form-control" id="du" name="du" value="<?= h($f['du']) ?>"<?= $sansPeriode ? ' disabled' : '' ?>></div>
        <div><label class="form-label small fw-semibold text-muted mb-1" for="au">Au</label><input type="date" class="form-control" id="au" name="au" value="<?= h($f['au']) ?>"<?= $sansPeriode ? ' disabled' : '' ?>></div>
        <div>
            <label class="form-label small fw-semibold text-muted mb-1" for="statut">Statut</label>
            <select class="form-select" id="statut" name="statut" onchange="['du', 'au'].forEach(i => document.getElementById(i).disabled = this.value === 'À retirer' || this.value === 'En retard')">
                <option value="">Tous</option>
                <?php foreach (RAPPORT_LINGE_FILTRES as $s): ?><option <?= $f['statut'] === $s ? 'selected' : '' ?>><?= h($s) ?></option><?php endforeach; ?>
            </select>
        </div>
        <button class="btn btn-primary"><i class="fa fa-search"></i> Filtrer</button>
        <div class="ms-auto d-flex flex-wrap gap-2">
            <a class="btn btn-outline-primary" href="<?= h(url('rapportlinge/imprimer', $params)) ?>" target="_blank"><i class="fa fa-print"></i> Imprimer / PDF</a>
            <a class="btn btn-success" href="<?= h(url('rapportlinge/excel', $params)) ?>"><i class="fa fa-file-excel"></i> Exporter Excel</a>
        </div>
    </div>
</form>
<p class="small text-muted"><?= h(rapportlinge_periode($f)) ?>.</p>

<div class="row g-3 mb-3">
    <?php foreach ([['Dépôts', $total['Nombre'], 'fa-shirt', false], ['À retirer', $parStatut['En cours']['Nombre'] + $parStatut['Prêt']['Nombre'], 'fa-hourglass-half', false],
                    ['En retard', $total['EnRetard'], 'fa-triangle-exclamation', false], ['Montant des dépôts', $total['Montant'], 'fa-cart-shopping', true],
                    ['Acomptes versés', $total['Acomptes'], 'fa-hand-holding-dollar', true], ['Reste à encaisser', $total['Reste'], 'fa-coins', true]] as [$lib, $val, $ico, $montant]): ?>
        <div class="col-6 col-lg"><div class="card border-0 shadow-sm h-100"><div class="card-body">
            <div class="small text-muted"><i class="fa <?= $ico ?>"></i> <?= $lib ?></div>
            <div class="fs-5 fw-bold<?= $lib === 'En retard' && $val > 0 ? ' text-danger' : '' ?>"><?= $montant ? fcfa($val) . ' <small class="fs-6 fw-normal text-muted">FCFA</small>' : (int) $val ?></div>
        </div></div></div>
    <?php endforeach; ?>
</div>

<div class="card shadow-sm border-0 mb-3">
    <div class="card-header bg-white fw-semibold">Par statut</div>
    <div class="card-body table-responsive">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Statut</th><th class="text-end">Dépôts</th><th class="text-end">Articles</th><th class="text-end">Montant</th>
                <th class="text-end">Acomptes</th><th class="text-end">Reste à encaisser</th><th class="text-end">En retard</th></tr></thead>
            <tbody>
            <?php foreach ($parStatut as $statut => $s): ?>
                <tr class="<?= $statut === 'Annulé' ? 'text-muted' : '' ?>">
                    <td><span class="badge <?= $badge($statut) ?>"><?= h($statut) ?></span></td>
                    <td class="text-end"><?= (int) $s['Nombre'] ?></td>
                    <td class="text-end"><?= quantite_fr($s['Articles']) ?></td>
                    <td class="text-end text-nowrap"><?= fcfa($s['Montant']) ?></td>
                    <td class="text-end text-nowrap"><?= fcfa($s['Acomptes']) ?></td>
                    <td class="text-end text-nowrap fw-semibold"><?= fcfa($s['Reste']) ?></td>
                    <td class="text-end"><?= (int) $s['EnRetard'] ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
            <tfoot>
                <tr class="table-light fw-bold"><td>Total (hors annulés)</td><td class="text-end"><?= (int) $total['Nombre'] ?></td><td class="text-end"><?= quantite_fr($total['Articles']) ?></td>
                    <td class="text-end text-nowrap"><?= fcfa($total['Montant']) ?></td><td class="text-end text-nowrap"><?= fcfa($total['Acomptes']) ?></td>
                    <td class="text-end text-nowrap"><?= fcfa($total['Reste']) ?></td><td class="text-end"><?= (int) $total['EnRetard'] ?></td></tr>
            </tfoot>
        </table>
    </div>
</div>

<div class="card shadow-sm border-0">
    <div class="card-header bg-white fw-semibold">Détail des dépôts</div>
    <div class="card-body table-responsive">
        <table id="depotsLingeTable" class="table table-hover align-middle mb-0 small">
            <thead class="table-dark"><tr><th>N°</th><th>Déposé le</th><th>Client</th><th class="text-end">Articles</th><th class="text-end">Montant</th><th class="text-end">Acompte</th>
                <th class="text-end">Reste</th><th>Retrait prévu</th><th>Statut</th></tr></thead>
            <tbody>
            <?php foreach ($lignes as $i => $l): $fin = $l['DateRetrait'] ?: $l['DateAnnulation']; ?>
                <tr>
                    <td class="fw-semibold" data-order="<?= (int) $l['Numero'] ?>"><?= (int) $l['Numero'] ?></td>
                    <td class="text-nowrap" data-order="<?= sprintf('%06d', $i) ?>"><?= date_fr($l['DateDepot'], 'd/m/Y H:i') ?><small class="d-block text-muted"><?= h((string) $l['ChkCode']) ?></small></td>
                    <td><?= h($l['NomClient']) ?><?php if ($l['TelephoneClient']): ?><small class="d-block text-muted"><?= h($l['TelephoneClient']) ?></small><?php endif; ?></td>
                    <td class="text-end"><?= quantite_fr($l['NbArticles']) ?></td>
                    <td class="text-end text-nowrap" data-order="<?= (float) $l['Total'] ?>"><?= fcfa($l['Total']) ?></td>
                    <td class="text-end text-nowrap" data-order="<?= (float) $l['Acompte'] ?>"><?= (float) $l['Acompte'] > 0 ? fcfa($l['Acompte']) : '<span class="text-muted">—</span>' ?></td>
                    <td class="text-end text-nowrap fw-semibold" data-order="<?= (float) $l['Reste'] ?>"><?= $l['Reste'] > 0 ? fcfa($l['Reste']) : '<span class="text-muted">—</span>' ?></td>
                    <td class="text-nowrap<?= $l['EnRetard'] ? ' text-danger fw-semibold' : '' ?>" data-order="<?= h((string) $l['DateRetraitPrevue']) ?>"><?= $l['DateRetraitPrevue'] ? date_fr($l['DateRetraitPrevue']) . ($l['EnRetard'] ? ' (en retard)' : '') : '<span class="text-muted">—</span>' ?></td>
                    <td class="text-nowrap"><span class="badge <?= $badge($l['Statut']) ?>"><?= h($l['Statut']) ?></span><?php if ($fin): ?><small class="d-block text-muted">le <?= date_fr($fin, 'd/m/Y H:i') ?></small><?php endif; ?>
                        <?php if ($l['CommandePosId']): ?><a class="small" href="<?= h(url('vente/details', ['id' => $l['CommandePosId']])) ?>" title="<?= h((string) $l['NumeroVente']) ?>"><i class="fa fa-receipt"></i> voir la vente</a><?php endif; ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
        <p class="small text-muted mt-2 mb-0">Montant : articles du dépôt (TTC). Acompte : versé au dépôt, encaissé dans la journée du dépôt (remboursé si le dépôt est annulé).
            Reste à encaisser : montant moins acompte, pour les dépôts en cours ou prêts. Les totaux ne comptent pas les dépôts annulés.</p>
    </div>
</div>
<?php ob_start(); ?>
<script>
    listeDataTable('#depotsLingeTable', {
        pageLength: 20,
        lengthMenu: [20, 50, 100],
        order: [[1, 'desc']]
    });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
