<?php
$titre = 'Rapport des livraisons';
$params = rapportlivraison_params($f);
$badge = fn(string $s) => ['Livrée' => 'bg-success', 'À livrer' => 'bg-warning text-dark', 'À encaisser' => 'bg-info text-dark'][$s] ?? 'bg-secondary';
?>
<form method="get" action="index.php" class="card shadow-sm border-0 mb-3">
    <input type="hidden" name="r" value="rapportlivraison/index">
    <div class="card-body d-flex flex-wrap align-items-end gap-3">
        <div><label class="form-label small fw-semibold text-muted mb-1" for="du">Du</label><input type="date" class="form-control" id="du" name="du" value="<?= h($f['du']) ?>"></div>
        <div><label class="form-label small fw-semibold text-muted mb-1" for="au">Au</label><input type="date" class="form-control" id="au" name="au" value="<?= h($f['au']) ?>"></div>
        <div>
            <label class="form-label small fw-semibold text-muted mb-1" for="livreur">Livreur</label>
            <select class="form-select" id="livreur" name="livreur">
                <option value="">Tous</option>
                <?php foreach ($livreurs as $l): ?><option value="<?= (int) $l['Id'] ?>" <?= $f['livreur'] === (int) $l['Id'] ? 'selected' : '' ?>><?= h($l['Nom']) ?></option><?php endforeach; ?>
            </select>
        </div>
        <div>
            <label class="form-label small fw-semibold text-muted mb-1" for="statut">Statut</label>
            <select class="form-select" id="statut" name="statut">
                <option value="">Tous</option>
                <?php foreach (RAPPORT_LIVRAISON_STATUTS as $s): ?><option <?= $f['statut'] === $s ? 'selected' : '' ?>><?= h($s) ?></option><?php endforeach; ?>
            </select>
        </div>
        <button class="btn btn-primary"><i class="fa fa-search"></i> Filtrer</button>
        <div class="ms-auto d-flex flex-wrap gap-2">
            <a class="btn btn-outline-primary" href="<?= h(url('rapportlivraison/imprimer', $params)) ?>" target="_blank"><i class="fa fa-print"></i> Imprimer / PDF</a>
            <a class="btn btn-success" href="<?= h(url('rapportlivraison/excel', $params)) ?>"><i class="fa fa-file-excel"></i> Exporter Excel</a>
        </div>
    </div>
</form>

<div class="row g-3 mb-3">
    <?php foreach ([['Livraisons', $total['Livraisons'], 'fa-truck-fast', false], ['Livrées', $total['Livrees'], 'fa-circle-check', false],
                    ['En cours', $total['ALivrer'] + $total['AEncaisser'], 'fa-hourglass-half', false],
                    ['Montant des ventes', $total['Montant'], 'fa-cart-shopping', true], ['Frais de livraison', $total['Frais'], 'fa-coins', true]] as [$lib, $val, $ico, $montant]): ?>
        <div class="col-6 col-lg"><div class="card border-0 shadow-sm h-100"><div class="card-body">
            <div class="small text-muted"><i class="fa <?= $ico ?>"></i> <?= $lib ?></div>
            <div class="fs-5 fw-bold"><?= $montant ? fcfa($val) . ' <small class="fs-6 fw-normal text-muted">FCFA</small>' : (int) $val ?></div>
        </div></div></div>
    <?php endforeach; ?>
</div>

<div class="card shadow-sm border-0 mb-3">
    <div class="card-header bg-white fw-semibold">Par livreur</div>
    <div class="card-body table-responsive">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Livreur</th><th>Moyen</th><th class="text-end">Livraisons</th><th class="text-end">Livrées</th><th class="text-end">À livrer</th>
                <th class="text-end">À encaisser</th><th class="text-end">Montant des ventes</th><th class="text-end">Frais de livraison</th></tr></thead>
            <tbody>
            <?php foreach ($parLivreur as $l): ?>
                <tr>
                    <td class="fw-semibold"><?= h((string) $l['Livreur']) ?></td>
                    <td><i class="fa <?= livreur_icone($l['Moyen']) ?> text-muted me-1"></i><?= h((string) $l['Moyen']) ?></td>
                    <td class="text-end"><?= (int) $l['Livraisons'] ?></td>
                    <td class="text-end"><?= (int) $l['Livrees'] ?></td>
                    <td class="text-end"><?= (int) $l['ALivrer'] ?></td>
                    <td class="text-end"><?= (int) $l['AEncaisser'] ?></td>
                    <td class="text-end text-nowrap"><?= fcfa($l['Montant']) ?></td>
                    <td class="text-end text-nowrap fw-semibold"><?= fcfa($l['Frais']) ?></td>
                </tr>
            <?php endforeach; ?>
            <?php if (!$parLivreur): ?><tr><td colspan="8" class="text-center text-muted">Aucune livraison sur la période.</td></tr><?php endif; ?>
            </tbody>
            <tfoot>
                <tr class="table-light fw-bold"><td colspan="2">Total</td><td class="text-end"><?= (int) $total['Livraisons'] ?></td><td class="text-end"><?= (int) $total['Livrees'] ?></td>
                    <td class="text-end"><?= (int) $total['ALivrer'] ?></td><td class="text-end"><?= (int) $total['AEncaisser'] ?></td>
                    <td class="text-end text-nowrap"><?= fcfa($total['Montant']) ?></td><td class="text-end text-nowrap"><?= fcfa($total['Frais']) ?></td></tr>
            </tfoot>
        </table>
    </div>
</div>

<div class="card shadow-sm border-0">
    <div class="card-header bg-white fw-semibold">Détail des livraisons</div>
    <div class="card-body table-responsive">
        <table id="livraisonsTable" class="table table-hover align-middle mb-0 small">
            <thead class="table-dark"><tr><th>Date</th><th>N°</th><th>Livreur</th><th>Destinataire</th><th>Adresse</th><th class="text-end">Montant</th><th class="text-end">Frais</th><th>Statut</th><th>Livrée le</th></tr></thead>
            <tbody>
            <?php foreach ($lignes as $i => $l): ?>
                <tr>
                    <td class="text-nowrap" data-order="<?= sprintf('%06d', $i) ?>"><?= date_fr($l['Date'], 'd/m/Y H:i') ?></td>
                    <td class="text-nowrap"><?php if ($l['Source'] === 'vente'): ?><a href="<?= h(url('vente/details', ['id' => $l['Id']])) ?>"><?= h($l['Numero']) ?></a><?php else: ?><?= h($l['Numero']) ?><?php endif; ?></td>
                    <td class="text-nowrap"><i class="fa <?= livreur_icone($l['Moyen']) ?> text-muted me-1" title="<?= h((string) $l['Moyen']) ?>"></i><?= h((string) $l['Livreur']) ?></td>
                    <td><?= h((string) ($l['NomLivraison'] ?: $l['Client'])) ?><?php if ($l['TelephoneLivraison']): ?><small class="d-block text-muted"><?= h($l['TelephoneLivraison']) ?></small><?php endif; ?></td>
                    <td><?= h((string) $l['AdresseLivraison']) ?></td>
                    <td class="text-end text-nowrap" data-order="<?= (float) $l['Montant'] ?>"><?= fcfa($l['Montant']) ?></td>
                    <td class="text-end text-nowrap" data-order="<?= (float) $l['Frais'] ?>"><?= fcfa($l['Frais']) ?></td>
                    <td><span class="badge <?= $badge($l['Statut']) ?>"><?= h($l['Statut']) ?></span></td>
                    <td class="text-nowrap" data-order="<?= h((string) $l['DateLivraison']) ?>"><?= $l['DateLivraison'] ? date_fr($l['DateLivraison'], 'd/m/Y H:i') : '<span class="text-muted">—</span>' ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
        <p class="small text-muted mt-2 mb-0">Montant : articles de la vente (TTC), frais de livraison en plus. « À encaisser » : commande confiée au livreur, encaissée à son retour.
            Les ventes annulées ne sont pas comptées.</p>
    </div>
</div>
<?php ob_start(); ?>
<script>
    listeDataTable('#livraisonsTable', {
        pageLength: 20,
        lengthMenu: [20, 50, 100],
        order: [[0, 'desc']]
    });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
