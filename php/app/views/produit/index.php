<?php $titre = 'Produits'; ?>
<div class="d-flex flex-wrap justify-content-between align-items-end gap-2 mb-3">
    <form method="get" action="index.php" class="d-flex flex-wrap gap-2">
        <input type="hidden" name="r" value="produit/index">
        <input name="search" class="form-control" placeholder="Rechercher (nom, code, code-barres)" value="<?= h($search) ?>" style="min-width:280px;">
        <select name="categorie" class="form-select" style="width:auto;" onchange="this.form.submit()">
            <option value="">Toutes les catégories</option>
            <?php foreach ($categories as $c): ?>
                <option value="<?= (int) $c['Id'] ?>" <?= $categorie === (int) $c['Id'] ? 'selected' : '' ?>><?= h($c['Nom']) ?></option>
            <?php endforeach; ?>
        </select>
        <button class="btn btn-outline-primary" aria-label="Rechercher"><i class="fa fa-search"></i></button>
    </form>
    <div class="d-flex gap-2">
        <form method="post" action="<?= h(url('produit/import')) ?>" enctype="multipart/form-data">
            <?= csrf_field() ?>
            <input type="file" name="file" accept=".xlsx" id="importProduits" class="d-none" onchange="this.form.submit()">
            <button type="button" class="btn btn-outline-primary" onclick="document.getElementById('importProduits').click()"><i class="fa fa-file-import"></i> Importer Excel</button>
        </form>
        <a href="<?= h(url('produit/export', ['search' => $search, 'categorie' => $categorie ?: null])) ?>" class="btn btn-success"><i class="fa fa-file-excel"></i> Exporter Excel</a>
        <a href="<?= h(url('produit/create')) ?>" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalCreation"><i class="fa fa-plus"></i> Nouveau produit</a>
    </div>
</div>
<p class="small text-muted mb-2">Import : un produit dont le code existe déjà est mis à jour, sinon il est créé ; une catégorie inconnue est créée. Colonnes dans l'ordre : <?= h(implode(', ', PRODUIT_COLONNES_EXCEL)) ?> (le plus simple est de partir d'un export).</p>
<?php if ($nbAlertes > 0): ?>
    <div class="alert alert-warning py-2"><i class="fa fa-triangle-exclamation"></i> <?= $nbAlertes ?> produit(s) au niveau ou sous le seuil d'alerte de stock.</div>
<?php endif; ?>
<div class="card shadow-sm border-0">
    <div class="card-body table-responsive">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Code</th><th>Produit</th><th>Catégorie</th><th>Code-barres</th><th class="text-end">Prix TTC</th><th class="text-end">TVA</th><th class="text-end">Stock</th><th class="text-center">Statut</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php if (!$produits): ?><tr><td colspan="9" class="text-center text-muted py-4">Aucun produit.</td></tr><?php endif; ?>
            <?php foreach ($produits as $p):
                $alerte = $p['SuiviStock'] && $p['SeuilAlerte'] !== null && (float) $p['StockActuel'] <= (float) $p['SeuilAlerte']; ?>
                <tr>
                    <td class="fw-semibold"><?= h($p['Code']) ?></td>
                    <td><?= h($p['Nom']) ?></td>
                    <td><?php if ($p['Categorie']): ?><span class="pastille-categorie" style="background: <?= h($p['Couleur']) ?>"></span> <?= h($p['Categorie']) ?><?php else: ?><span class="text-muted">—</span><?php endif; ?></td>
                    <td class="text-muted small"><?= h($p['CodeBarres']) ?></td>
                    <td class="text-end fw-semibold text-nowrap"><?= fcfa($p['PrixVente']) ?></td>
                    <td class="text-end"><?= quantite_fr($p['TauxTVA']) ?> %</td>
                    <td class="text-end text-nowrap">
                        <?php if (!$p['SuiviStock']): ?><span class="text-muted small">Non suivi</span>
                        <?php else: ?><span class="<?= $alerte ? 'badge bg-danger' : '' ?>" <?= $alerte ? 'title="Stock au niveau ou sous le seuil d\'alerte"' : '' ?>><?= quantite_fr($p['StockActuel']) ?></span><?php endif; ?>
                    </td>
                    <td class="text-center"><span class="badge <?= $p['Actif'] ? 'bg-success' : 'bg-secondary' ?>"><?= $p['Actif'] ? 'Actif' : 'Inactif' ?></span></td>
                    <td class="text-center table-actions">
                        <a href="<?= h(url('produit/edit', ['id' => $p['Id']])) ?>" class="btn btn-warning btn-sm">Modifier</a>
                        <form method="post" action="<?= h(url('produit/delete')) ?>" onsubmit="return confirm('Supprimer ce produit ?');">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $p['Id'] ?>">
                            <button class="btn btn-danger btn-sm">Supprimer</button>
                        </form>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
<?= partial('partials/pagination', $pagination) ?>

<?= partial('produit/form', ['produit' => ['TauxTVA' => 18, 'SuiviStock' => 1, 'Actif' => 1], 'edition' => false, 'categories' => $categories, 'modale' => true]) ?>
