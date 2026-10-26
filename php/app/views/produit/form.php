<?php
$titre = $edition ? 'Modifier le produit' : 'Nouveau produit';
$entete = $titre;
$largeur = '860px';
$action = !empty($modale) ? url('produit/create') : null;
$retour = url('produit/index');
$v = fn(string $k) => h($produit[$k] ?? '');
$nombre = fn(string $k) => isset($produit[$k]) && $produit[$k] !== null && $produit[$k] !== '' ? h(quantite_fr($produit[$k], false)) : '';
require __DIR__ . '/../partials/form_debut.php';
?>
            <div class="row g-3">
                <div class="col-md-3"><label class="form-label" for="Code">Code</label><input class="form-control" id="Code" name="Code" value="<?= $v('Code') ?>" placeholder="Ex : RIZ5" required></div>
                <div class="col-md-5"><label class="form-label" for="Nom">Nom</label><input class="form-control" id="Nom" name="Nom" value="<?= $v('Nom') ?>" placeholder="Ex : Riz parfumé 5 kg" required></div>
                <div class="col-md-4">
                    <label class="form-label" for="CategorieId">Catégorie</label>
                    <select class="form-select" id="CategorieId" name="CategorieId">
                        <option value="">-- Sans catégorie --</option>
                        <?php foreach ($categories as $c): ?>
                            <option value="<?= (int) $c['Id'] ?>" <?= (int) ($produit['CategorieId'] ?? 0) === (int) $c['Id'] ? 'selected' : '' ?>><?= h($c['Nom']) ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="CodeBarres">Code-barres</label>
                    <div class="input-group">
                        <span class="input-group-text"><i class="fa fa-barcode"></i></span>
                        <input class="form-control" id="CodeBarres" name="CodeBarres" value="<?= $v('CodeBarres') ?>" placeholder="Scannez ou saisissez"
                               onkeydown="if (event.key === 'Enter') event.preventDefault();">
                    </div>
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="PrixVente">Prix de vente TTC (FCFA)</label>
                    <input class="form-control" id="PrixVente" name="PrixVente" inputmode="decimal" value="<?= $nombre('PrixVente') ?>" required>
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="TauxTVA">TVA (%)</label>
                    <input class="form-control" id="TauxTVA" name="TauxTVA" inputmode="decimal" value="<?= $nombre('TauxTVA') ?>">
                    <div class="form-text">Comprise dans le prix TTC.</div>
                </div>
            </div>
            <h6 class="text-muted text-uppercase small mt-4 mb-3">Stock</h6>
            <div class="row g-3 align-items-end">
                <div class="col-md-4">
                    <div class="form-check mb-2">
                        <input class="form-check-input" type="checkbox" value="1" id="SuiviStock" name="SuiviStock" <?= !empty($produit['SuiviStock']) ? 'checked' : '' ?>>
                        <label class="form-check-label" for="SuiviStock">Suivre le stock de ce produit</label>
                    </div>
                    <div class="form-text mt-0">Décochez pour un service (photocopie, recharge…).</div>
                </div>
                <?php if ($edition): ?>
                    <div class="col-md-4">
                        <div class="form-label">Quantité en stock</div>
                        <div class="form-control-plaintext fw-bold py-1"><?= quantite_fr($produit['StockActuel'] ?? 0) ?>
                            <a class="small fw-normal ms-2" href="<?= h(url('stock/index', ['produit' => $produit['Id'] ?? 0])) ?>">Historique</a></div>
                        <div class="form-text mt-0">Modifiée par les entrées, inventaires et ventes (menu Stock).</div>
                    </div>
                <?php else: ?>
                    <div class="col-md-4"><label class="form-label" for="StockActuel">Stock initial</label><input class="form-control" id="StockActuel" name="StockActuel" inputmode="decimal" value="<?= $nombre('StockActuel') ?: '0' ?>"></div>
                <?php endif; ?>
                <div class="col-md-4"><label class="form-label" for="SeuilAlerte">Seuil d'alerte</label><input class="form-control" id="SeuilAlerte" name="SeuilAlerte" inputmode="decimal" value="<?= $nombre('SeuilAlerte') ?>" placeholder="Ex : 5"></div>
                <div class="col-12">
                    <div class="form-check">
                        <input class="form-check-input" type="checkbox" value="1" id="Actif" name="Actif" <?= !empty($produit['Actif']) ? 'checked' : '' ?>>
                        <label class="form-check-label" for="Actif">Produit actif (proposé à la vente)</label>
                    </div>
                </div>
            </div>
<?php require __DIR__ . '/../partials/form_fin.php'; ?>
