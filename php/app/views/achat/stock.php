<?php
$titre = 'Dépôt des achats';
$onglet = 'stock';
require __DIR__ . '/_onglets.php';
$valeur = array_sum(array_column($produits, 'Valeur'));
$alertes = count(array_filter($produits, fn($p) => $p['Alerte']));
$badge = ['Achat' => 'bg-success', 'Consommation' => 'bg-danger', 'Annulation' => 'bg-info text-dark', 'Transfert' => 'bg-dark', 'Inventaire' => 'bg-warning text-dark'];
?>
<div class="d-flex flex-wrap align-items-center gap-2 mb-3">
    <h2 class="h5 mb-0"><i class="fa fa-warehouse text-muted"></i> <?= h($depot ? $depot['Code'] . ' · ' . $depot['Nom'] : 'Dépôt des achats') ?></h2>
    <span class="small text-muted">Les achats y entrent, les consommations en sortent ; il ne sert à aucune caisse.</span>
    <div class="ms-auto d-flex gap-2">
        <a class="btn btn-sm btn-outline-primary" href="<?= h(url('stock/inventaire', $depot ? ['depot' => $depot['Id']] : [])) ?>"><i class="fa fa-clipboard-check"></i> Inventaire</a>
        <a class="btn btn-sm btn-outline-secondary" href="<?= h(url('stock/transfert', $depot ? ['depot' => $depot['Id']] : [])) ?>"><i class="fa fa-right-left"></i> Transfert</a>
    </div>
</div>

<form method="get" action="index.php" class="card shadow-sm border-0 mb-3">
    <input type="hidden" name="r" value="achat/stock">
    <div class="card-body d-flex flex-wrap align-items-end gap-3">
        <div><label class="form-label small fw-semibold text-muted mb-1" for="du">Mouvements du</label><input type="date" class="form-control" id="du" name="du" value="<?= h($f['du']) ?>"></div>
        <div><label class="form-label small fw-semibold text-muted mb-1" for="au">Au</label><input type="date" class="form-control" id="au" name="au" value="<?= h($f['au']) ?>"></div>
        <button class="btn btn-primary"><i class="fa fa-search"></i> Filtrer</button>
        <div class="ms-auto d-flex gap-4 text-end">
            <div><div class="small text-muted">Produits en alerte</div><div class="fs-5 fw-bold<?= $alertes ? ' text-danger' : '' ?>"><?= $alertes ?></div></div>
            <div><div class="small text-muted">Valeur du stock (au coût)</div><div class="fs-5 fw-bold"><?= fcfa($valeur) ?> <small class="fs-6 fw-normal text-muted">FCFA</small></div></div>
        </div>
    </div>
</form>

<div class="card shadow-sm border-0 mb-3">
    <div class="card-header bg-white fw-semibold">Stock et mouvements de la période par produit</div>
    <div class="card-body table-responsive">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Produit</th><th class="text-end">Entrées</th><th class="text-end">Sorties</th><th class="text-end">En stock</th>
                <th class="text-end">Seuil d'alerte</th><th class="text-end">Coût</th><th class="text-end">Valeur</th></tr></thead>
            <tbody>
            <?php foreach ($produits as $p): ?>
                <tr class="<?= $p['Alerte'] ? 'table-danger' : '' ?>">
                    <td><?= h($p['Code'] . ' · ' . $p['Nom']) ?><?php if ($p['Consommable']): ?> <span class="badge text-bg-info">Consommable</span><?php endif; ?></td>
                    <td class="text-end text-nowrap"><?= $p['Entrees'] ? '+' . quantite_fr($p['Entrees']) : '<span class="text-muted">—</span>' ?></td>
                    <td class="text-end text-nowrap"><?= $p['Sorties'] ? '−' . quantite_fr($p['Sorties']) : '<span class="text-muted">—</span>' ?></td>
                    <td class="text-end text-nowrap fw-semibold"><?= quantite_fr($p['Stock']) ?> <?= h($p['Unite']) ?></td>
                    <td class="text-end"><?= $p['SeuilAlerte'] === null ? '<span class="text-muted">—</span>' : quantite_fr($p['SeuilAlerte']) ?></td>
                    <td class="text-end text-nowrap"><?= $p['Cout'] === null ? '<span class="text-muted">—</span>' : quantite_fr($p['Cout']) ?></td>
                    <td class="text-end text-nowrap"><?= fcfa($p['Valeur']) ?></td>
                </tr>
            <?php endforeach; ?>
            <?php if (!$produits): ?><tr><td colspan="7" class="text-muted">Aucun produit : créez vos produits d'entretien en cochant « Consommable », puis enregistrez un achat.</td></tr><?php endif; ?>
            </tbody>
        </table>
    </div>
</div>

<div class="card shadow-sm border-0">
    <div class="card-header bg-white fw-semibold">Entrées et sorties</div>
    <div class="card-body table-responsive">
        <table id="mouvementsAchatsTable" class="table align-middle mb-0 small">
            <thead class="table-dark"><tr><th>Date</th><th>Produit</th><th>Type</th><th class="text-end">Quantité</th><th class="text-end">Stock après</th><th>Référence</th><th>Commentaire</th><th>Par</th></tr></thead>
            <tbody>
            <?php foreach ($mouvements as $i => $m): ?>
                <tr><td class="text-nowrap" data-order="<?= sprintf('%06d', count($mouvements) - $i) ?>"><?= date_fr($m['DateMouvement'], 'd/m/Y H:i') ?></td><td><?= h($m['Nom']) ?></td>
                    <td><span class="badge <?= $badge[$m['TypeMouvement']] ?? 'bg-secondary' ?>"><?= h($m['TypeMouvement']) ?></span></td>
                    <td class="text-end text-nowrap fw-semibold <?= (float) $m['Quantite'] < 0 ? 'text-danger' : 'text-success' ?>"><?= ((float) $m['Quantite'] > 0 ? '+' : '') . quantite_fr($m['Quantite']) ?></td>
                    <td class="text-end text-nowrap"><?= quantite_fr($m['StockApres']) ?></td><td><?= h((string) $m['Reference']) ?></td><td><?= h((string) $m['Commentaire']) ?></td><td><?= h((string) $m['Utilisateur']) ?></td></tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
<p class="small text-muted mt-2">Entrées : achats, transferts reçus, écarts d'inventaire positifs ; sorties : consommations, annulations d'achats, transferts, écarts négatifs. Une ligne rouge signale un produit au niveau ou sous son seuil d'alerte.</p>
<?php ob_start(); ?>
<script>
    listeDataTable('#mouvementsAchatsTable', { pageLength: 20, lengthMenu: [20, 50, 100], order: [[0, 'desc']] });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
