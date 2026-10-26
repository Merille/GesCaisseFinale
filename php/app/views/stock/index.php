<?php
$titre = 'Stock';
$onglet = 'index';
require __DIR__ . '/_onglets.php';
$badge = ['Entrée' => 'bg-success', 'Retour' => 'bg-info text-dark', 'Annulation' => 'bg-info text-dark', 'Vente' => 'bg-primary',
          'Inventaire' => 'bg-warning text-dark', 'Stock initial' => 'bg-secondary'];
?>
<div class="row g-3 mb-3">
    <div class="col-lg-8">
        <div class="card border-0 shadow-sm h-100">
            <div class="card-header bg-warning"><i class="fa fa-triangle-exclamation"></i> Produits au niveau ou sous le seuil d'alerte (<?= count($alertes) ?>)</div>
            <?php if (!$alertes): ?>
                <div class="card-body text-muted">Aucun produit sous son seuil d'alerte.</div>
            <?php else: ?>
                <div class="card-body p-2 table-responsive" style="max-height: 220px;">
                    <table class="table table-sm align-middle mb-0">
                        <thead><tr><th>Produit</th><th class="text-end">Stock</th><th class="text-end">Seuil</th><th></th></tr></thead>
                        <tbody>
                        <?php foreach ($alertes as $a): ?>
                            <tr>
                                <td><?= h($a['Code'] . ' · ' . $a['Nom']) ?></td>
                                <td class="text-end fw-bold text-danger"><?= quantite_fr($a['StockActuel']) ?></td>
                                <td class="text-end"><?= quantite_fr($a['SeuilAlerte']) ?></td>
                                <td class="text-end"><a class="btn btn-sm btn-outline-success" href="<?= h(url('stock/entree', ['produit' => $a['Id']])) ?>">Réapprovisionner</a></td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        </div>
    </div>
    <div class="col-lg-4">
        <div class="card border-0 shadow-sm h-100"><div class="card-body">
            <h6 class="fw-bold">Vente quand le stock est épuisé</h6>
            <?php if ($venteSansStock === null): ?>
                <p class="small text-muted mb-0">Choisissez une société dans « Société consultée » pour régler cette option.</p>
            <?php else: ?>
                <form method="post" action="<?= h(url('stock/option')) ?>">
                    <?= csrf_field() ?>
                    <div class="form-check"><input class="form-check-input" type="radio" name="venteSansStock" id="vssOui" value="1" <?= $venteSansStock ? 'checked' : '' ?>>
                        <label class="form-check-label" for="vssOui">Autorisée, avec un avertissement</label></div>
                    <div class="form-check mb-2"><input class="form-check-input" type="radio" name="venteSansStock" id="vssNon" value="0" <?= $venteSansStock ? '' : 'checked' ?>>
                        <label class="form-check-label" for="vssNon">Interdite (le point de vente refuse l'article)</label></div>
                    <button class="btn btn-sm btn-primary">Enregistrer</button>
                </form>
            <?php endif; ?>
        </div></div>
    </div>
</div>

<form method="get" action="index.php" class="d-flex flex-wrap gap-2 mb-3 align-items-end">
    <input type="hidden" name="r" value="stock/index">
    <div><label class="form-label small mb-1" for="fProduit">Produit</label>
        <select id="fProduit" name="produit" class="form-select" style="min-width:240px;">
            <option value="">Tous les produits</option>
            <?php foreach ($produits as $p): ?><option value="<?= (int) $p['Id'] ?>" <?= $filtres['produit'] === (int) $p['Id'] ? 'selected' : '' ?>><?= h($p['Code'] . ' · ' . $p['Nom']) ?></option><?php endforeach; ?>
        </select></div>
    <div><label class="form-label small mb-1" for="fType">Type</label>
        <select id="fType" name="type" class="form-select">
            <option value="">Tous les types</option>
            <?php foreach (STOCK_TYPES as $t): ?><option <?= $filtres['type'] === $t ? 'selected' : '' ?>><?= h($t) ?></option><?php endforeach; ?>
        </select></div>
    <div><label class="form-label small mb-1" for="fDu">Du</label><input id="fDu" type="date" name="du" class="form-control" value="<?= h($filtres['du']) ?>"></div>
    <div><label class="form-label small mb-1" for="fAu">Au</label><input id="fAu" type="date" name="au" class="form-control" value="<?= h($filtres['au']) ?>"></div>
    <button class="btn btn-outline-primary"><i class="fa fa-filter"></i> Filtrer</button>
</form>

<div class="card shadow-sm border-0">
    <div class="card-body table-responsive">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Date</th><th>Produit</th><th>Type</th><th class="text-end">Quantité</th><th class="text-end">Stock après</th><th>Référence</th><th>Par</th><th>Commentaire</th></tr></thead>
            <tbody>
            <?php if (!$mouvements): ?><tr><td colspan="8" class="text-center text-muted py-4">Aucun mouvement.</td></tr><?php endif; ?>
            <?php foreach ($mouvements as $m): $q = (float) $m['Quantite']; ?>
                <tr>
                    <td class="text-nowrap"><?= date_fr($m['DateMouvement'], 'd/m/Y H:i') ?></td>
                    <td><?= h($m['Code'] . ' · ' . $m['Nom']) ?></td>
                    <td><span class="badge <?= $badge[$m['TypeMouvement']] ?? 'bg-secondary' ?>"><?= h($m['TypeMouvement']) ?></span></td>
                    <td class="text-end fw-semibold <?= $q < 0 ? 'text-danger' : 'text-success' ?>"><?= ($q > 0 ? '+' : '') . quantite_fr($q) ?></td>
                    <td class="text-end"><?= quantite_fr($m['StockApres']) ?></td>
                    <td><?php if ($m['CommandePosId']): ?><a href="<?= h(url('vente/details', ['id' => $m['CommandePosId']])) ?>"><?= h($m['Reference']) ?></a><?php else: ?><?= h($m['Reference']) ?><?php endif; ?></td>
                    <td><?= h($m['Utilisateur']) ?></td>
                    <td class="small"><?= h($m['Commentaire']) ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
<?= partial('partials/pagination', $pagination) ?>
