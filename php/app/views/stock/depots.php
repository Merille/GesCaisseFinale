<?php
$titre = 'Stock par dépôt';
$onglet = 'depots';
require __DIR__ . '/_onglets.php';
?>
<form method="get" action="index.php" class="d-flex gap-2 mb-3">
    <input type="hidden" name="r" value="stock/depots">
    <select name="categorie" class="form-select" style="width:auto;" onchange="this.form.submit()" aria-label="Catégorie">
        <option value="">Toutes les catégories</option>
        <?php foreach ($categories as $c): ?><option value="<?= (int) $c['Id'] ?>" <?= $categorie === (int) $c['Id'] ? 'selected' : '' ?>><?= h($c['Nom']) ?></option><?php endforeach; ?>
    </select>
</form>
<div class="card shadow-sm border-0">
    <div class="card-body table-responsive">
        <table id="stockDepotsTable" class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Code</th><th>Produit</th><th>Catégorie</th>
                <?php foreach ($depots as $d): ?><th class="text-end" title="<?= h($d['Nom']) ?>"><?= h($d['Code']) ?><?= $d['Actif'] ? '' : ' (inactif)' ?></th><?php endforeach; ?>
                <th class="text-end">Total</th></tr></thead>
            <tbody>
            <?php foreach ($produits as $p): $alerte = $p['SeuilAlerte'] !== null && (float) $p['StockActuel'] <= (float) $p['SeuilAlerte']; ?>
                <tr>
                    <td class="fw-semibold"><?= h($p['Code']) ?></td>
                    <td><?= h($p['Nom']) ?></td>
                    <td><?= h($p['Categorie']) ?></td>
                    <?php foreach ($depots as $d): $q = $quantites[(int) $p['Id']][(int) $d['Id']] ?? 0.0; ?>
                        <td class="text-end <?= $q < 0 ? 'text-danger' : ($q == 0 ? 'text-muted' : '') ?>" data-order="<?= $q ?>"><?= quantite_fr($q) ?></td>
                    <?php endforeach; ?>
                    <td class="text-end fw-bold" data-order="<?= (float) $p['StockActuel'] ?>"><span class="<?= $alerte ? 'badge bg-danger' : '' ?>"><?= quantite_fr($p['StockActuel']) ?></span></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
<?php ob_start(); ?>
<script>
    listeDataTable('#stockDepotsTable', {
        pageLength: 20,
        lengthMenu: [20, 50, 100],
        order: [[1, 'asc']]
    });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
