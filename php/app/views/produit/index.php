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
    <div class="d-flex flex-wrap gap-2">
        <div class="btn-group" role="group" aria-label="Affichage" data-vues="produits">
            <button type="button" class="btn btn-outline-secondary" data-vue="liste" title="Affichage en liste"><i class="fa fa-list"></i> Liste</button>
            <button type="button" class="btn btn-outline-secondary" data-vue="cartes" title="Affichage en cartes"><i class="fa fa-grip"></i> Cartes</button>
        </div>
        <form method="post" action="<?= h(url('produit/import')) ?>" enctype="multipart/form-data">
            <?= csrf_field() ?>
            <input type="file" name="file" accept=".xlsx" id="importProduits" class="d-none" onchange="this.form.submit()">
            <button type="button" class="btn btn-outline-primary" onclick="document.getElementById('importProduits').click()"><i class="fa fa-file-import"></i> Importer Excel</button>
        </form>
        <a href="<?= h(url('produit/export', ['search' => $search, 'categorie' => $categorie ?: null])) ?>" class="btn btn-success"><i class="fa fa-file-excel"></i> Exporter Excel</a>
        <a href="<?= h(url('produit/create')) ?>" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalCreation"><i class="fa fa-plus"></i> Nouveau produit</a>
    </div>
</div>
<p class="small text-muted mb-2">Import : un produit dont le code existe déjà est mis à jour, sinon il est créé ; une catégorie inconnue est créée ; la colonne Taxes contient les codes séparés par « + » (ex. TVA + CSS), vide = taxes par défaut ; la colonne Stock ne sert qu'à la création (stock initial). Colonnes dans l'ordre : <?= h(implode(', ', PRODUIT_COLONNES_EXCEL)) ?> (le plus simple est de partir d'un export).</p>
<?php if ($nbAlertes > 0): ?>
    <div class="alert alert-warning py-2"><i class="fa fa-triangle-exclamation"></i> <?= $nbAlertes ?> produit(s) au niveau ou sous le seuil d'alerte de stock. <a href="<?= h(url('stock/index')) ?>">Voir le stock</a></div>
<?php endif; ?>
<div class="card shadow-sm border-0" data-vue-de="produits" data-vue="liste">
    <div class="card-body table-responsive">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Code</th><th>Produit</th><th>Catégorie</th><th>Code-barres</th><th class="text-end">Prix TTC</th><th>Taxes</th><th class="text-end">Stock</th><th class="text-center">Statut</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php if (!$produits): ?><tr><td colspan="9" class="text-center text-muted py-4">Aucun produit.</td></tr><?php endif; ?>
            <?php foreach ($produits as $p):
                // Modèle à variantes : stock total de ses variantes actives.
                if ($p['EstModele']) { $p['StockActuel'] = $p['StockVariantes']; }
                $alerte = !$p['EstModele'] && $p['SuiviStock'] && $p['SeuilAlerte'] !== null && (float) $p['StockActuel'] <= (float) $p['SeuilAlerte'];
                $badgeVariantes = $p['EstModele'] ? ' <span class="badge text-bg-light border">' . (int) $p['NbVariantes'] . ' variante' . ((int) $p['NbVariantes'] > 1 ? 's' : '') . '</span>' : ''; ?>
                <tr>
                    <td class="fw-semibold"><?= h($p['Code']) ?></td>
                    <td><div class="d-flex align-items-center gap-2"><?php if ($img = url_image_produit($p)): ?><img src="<?= h($img) ?>" alt="" class="vignette-image vignette-petite" loading="lazy"><?php endif; ?><span><?= h($p['Nom']) ?><?= $badgeVariantes ?></span></div></td>
                    <td><?php if ($p['Categorie']): ?><span class="pastille-categorie" style="background: <?= h($p['Couleur']) ?>"></span> <?= h($p['Categorie']) ?><?php else: ?><span class="text-muted">—</span><?php endif; ?></td>
                    <td class="text-muted small"><?= h($p['CodeBarres']) ?></td>
                    <td class="text-end fw-semibold text-nowrap"><?= fcfa($p['PrixVente']) ?><?php if ($p['Unite'] !== 'Unité'): ?> <span class="small fw-normal text-muted">/ <?= h($p['Unite']) ?></span><?php endif; ?></td>
                    <td class="text-nowrap"><?php if ($p['Taxes']): ?><?= h($p['Taxes']) ?> <span class="text-muted small">· <?= quantite_fr($p['TauxTVA']) ?> %</span><?php else: ?><span class="text-muted">Aucune</span><?php endif; ?></td>
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

<div class="d-none" data-vue-de="produits" data-vue="cartes">
    <?php if (!$produits): ?><div class="card shadow-sm border-0"><div class="card-body text-center text-muted py-4">Aucun produit.</div></div><?php endif; ?>
    <div class="row row-cols-1 row-cols-sm-2 row-cols-lg-3 row-cols-xxl-4 g-3">
        <?php foreach ($produits as $p):
            if ($p['EstModele']) { $p['StockActuel'] = $p['StockVariantes']; }
            $alerte = !$p['EstModele'] && $p['SuiviStock'] && $p['SeuilAlerte'] !== null && (float) $p['StockActuel'] <= (float) $p['SeuilAlerte'];
            $badgeVariantes = $p['EstModele'] ? ' <span class="badge text-bg-light border">' . (int) $p['NbVariantes'] . ' variante' . ((int) $p['NbVariantes'] > 1 ? 's' : '') . '</span>' : ''; ?>
            <div class="col">
                <article class="carte-liste h-100 d-flex flex-column" style="--couleur: <?= h($p['Couleur'] ?: '#999997') ?>">
                    <div class="p-3 d-flex flex-column gap-2 flex-grow-1">
                        <div class="d-flex justify-content-between align-items-start gap-2">
                            <div>
                                <h3 class="h6 fw-bold mb-1"><?= h($p['Nom']) ?><?= $badgeVariantes ?></h3>
                                <div class="small text-muted"><?= h($p['Code']) ?><?= $p['CodeBarres'] ? ' · <i class="fa fa-barcode"></i> ' . h($p['CodeBarres']) : '' ?></div>
                            </div>
                            <span class="badge <?= $p['Actif'] ? 'bg-success' : 'bg-secondary' ?>"><?= $p['Actif'] ? 'Actif' : 'Inactif' ?></span>
                        </div>
                        <div class="small"><?php if ($p['Categorie']): ?><span class="pastille-categorie" style="background: <?= h($p['Couleur']) ?>"></span> <?= h($p['Categorie']) ?><?php else: ?><span class="text-muted">Sans catégorie</span><?php endif; ?></div>
                        <div class="d-flex justify-content-between align-items-end gap-2 mt-auto">
                            <div>
                                <div class="carte-prix"><?= fcfa($p['PrixVente']) ?> <span class="small fw-normal text-muted">FCFA TTC<?= $p['Unite'] !== 'Unité' ? ' / ' . h($p['Unite']) : '' ?></span></div>
                                <div class="small text-muted"><?= $p['Taxes'] ? h($p['Taxes']) . ' · ' . quantite_fr($p['TauxTVA']) . ' %' : 'Sans taxe' ?><?= $p['Cout'] !== null ? ' · coût ' . fcfa($p['Cout']) : '' ?></div>
                            </div>
                            <div class="text-end small">
                                <?php if (!$p['SuiviStock']): ?><span class="text-muted">Stock non suivi</span>
                                <?php else: ?><div class="text-muted">Stock</div><span class="fw-bold <?= $alerte ? 'badge bg-danger' : '' ?>" <?= $alerte ? 'title="Stock au niveau ou sous le seuil d\'alerte"' : '' ?>><?= quantite_fr($p['StockActuel']) ?></span><?php endif; ?>
                            </div>
                        </div>
                    </div>
                    <div class="carte-actions px-3 py-2 d-flex gap-2 justify-content-end">
                        <a href="<?= h(url('produit/edit', ['id' => $p['Id']])) ?>" class="btn btn-warning btn-sm">Modifier</a>
                        <form method="post" action="<?= h(url('produit/delete')) ?>" onsubmit="return confirm('Supprimer ce produit ?');">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $p['Id'] ?>">
                            <button class="btn btn-danger btn-sm">Supprimer</button>
                        </form>
                    </div>
                </article>
            </div>
        <?php endforeach; ?>
    </div>
</div>
<?= partial('partials/pagination', $pagination) ?>

<?= partial('produit/form', ['produit' => ['SuiviStock' => 1, 'Actif' => 1, 'Unite' => 'Unité', 'TaxeIds' => taxes_par_defaut()], 'edition' => false, 'categories' => $categories, 'taxes' => $taxes, 'modale' => true]) ?>
