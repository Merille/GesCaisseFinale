<?php
$titre = 'Inventaire';
$onglet = 'inventaire';
require __DIR__ . '/_onglets.php';
?>
<form method="get" action="index.php" class="d-flex gap-2 mb-3">
    <input type="hidden" name="r" value="stock/inventaire">
    <select name="categorie" class="form-select" style="width:auto;" onchange="this.form.submit()" aria-label="Catégorie">
        <option value="">Toutes les catégories</option>
        <?php foreach ($categories as $c): ?><option value="<?= (int) $c['Id'] ?>" <?= $categorie === (int) $c['Id'] ? 'selected' : '' ?>><?= h($c['Nom']) ?></option><?php endforeach; ?>
    </select>
</form>
<?php if (!$produits): ?>
    <div class="alert alert-info">Aucun produit avec suivi de stock dans cette sélection.</div>
<?php else: ?>
<form method="post" onsubmit="return confirm('Enregistrer l\'inventaire ? Les écarts mettront le stock à jour.');">
    <?= csrf_field() ?>
    <div class="card shadow-sm border-0">
        <div class="card-body table-responsive">
            <p class="small text-muted">Saisissez la quantité comptée en rayon. Laissez vide les produits non comptés. Chaque écart devient un mouvement « Inventaire ».</p>
            <table class="table align-middle mb-0">
                <thead class="table-dark"><tr><th>Code</th><th>Produit</th><th>Catégorie</th><th class="text-end">Stock théorique</th><th style="width:160px">Stock compté</th><th class="text-end" style="width:110px">Écart</th></tr></thead>
                <tbody>
                <?php foreach ($produits as $p): ?>
                    <tr>
                        <td class="fw-semibold"><?= h($p['Code']) ?></td>
                        <td><?= h($p['Nom']) ?></td>
                        <td><?= h($p['Categorie']) ?></td>
                        <td class="text-end"><?= quantite_fr($p['StockActuel']) ?></td>
                        <td><input class="form-control form-control-sm text-end compte" name="compte[<?= (int) $p['Id'] ?>]" inputmode="decimal"
                                   data-theorique="<?= h((string) (float) $p['StockActuel']) ?>" aria-label="Stock compté : <?= h($p['Nom']) ?>"></td>
                        <td class="text-end fw-semibold ecart"></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
        <div class="card-footer bg-white d-flex flex-wrap gap-2 align-items-center">
            <input class="form-control" name="commentaire" placeholder="Commentaire (ex : inventaire de fin de mois)" style="max-width:360px;" aria-label="Commentaire">
            <button class="btn btn-success"><i class="fa fa-check"></i> Enregistrer l'inventaire</button>
        </div>
    </div>
</form>
<?php ob_start(); ?>
<script>
    document.querySelectorAll('.compte').forEach(function (champ) {
        champ.addEventListener('input', function () {
            const cellule = champ.closest('tr').querySelector('.ecart');
            const v = champ.value.trim().replace(/\s/g, '').replace(',', '.');
            if (v === '' || isNaN(Number(v))) { cellule.textContent = ''; return; }
            const ecart = Math.round((Number(v) - Number(champ.dataset.theorique)) * 100) / 100;
            cellule.textContent = (ecart > 0 ? '+' : '') + ecart.toLocaleString('fr-FR');
            cellule.className = 'text-end fw-semibold ecart ' + (ecart < 0 ? 'text-danger' : ecart > 0 ? 'text-success' : 'text-muted');
        });
    });
</script>
<?php $scripts = ob_get_clean(); ?>
<?php endif; ?>
