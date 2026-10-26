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
                    <?php $cochees = array_map('intval', $produit['TaxeIds'] ?? []); $totalTaxes = 0.0; ?>
                    <div class="form-label">Taxes</div>
                    <div class="d-flex flex-wrap gap-2" role="group" aria-label="Taxes du produit">
                        <?php foreach ($taxes as $t): $coche = in_array((int) $t['Id'], $cochees, true); $totalTaxes += $coche ? (float) $t['Taux'] : 0; ?>
                            <input type="checkbox" class="btn-check" name="Taxes[]" value="<?= (int) $t['Id'] ?>" id="taxe<?= (int) $t['Id'] ?><?= !empty($modale) ? 'm' : '' ?>"
                                   data-taux="<?= h((string) (float) $t['Taux']) ?>" <?= $coche ? 'checked' : '' ?> autocomplete="off"
                                   onchange="let t = 0; this.closest('form').querySelectorAll('[name=&quot;Taxes[]&quot;]:checked').forEach((c) => t += +c.dataset.taux); this.closest('form').querySelector('.taux-total').textContent = t.toLocaleString('fr-FR');">
                            <label class="btn btn-outline-primary btn-sm" for="taxe<?= (int) $t['Id'] ?><?= !empty($modale) ? 'm' : '' ?>" title="<?= h($t['Libelle']) ?>"><?= h($t['Code']) ?> <?= quantite_fr($t['Taux']) ?> %</label>
                        <?php endforeach; ?>
                    </div>
                    <div class="form-text">
                        <?php if (!$taxes): ?>Aucune taxe : créez-en dans Paramètres &gt; Taxes.
                        <?php else: ?>Total <strong class="taux-total"><?= quantite_fr($totalTaxes) ?></strong> %, compris dans le prix TTC.<?php endif; ?>
                    </div>
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
