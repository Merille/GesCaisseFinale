<?php
$titre = $edition ? 'Modifier le produit' : 'Nouveau produit';
$entete = $titre;
$avecVariantes = $edition && empty($modale) && empty($produit['ParentId']);
// En modification, la fiche est à gauche et les variantes à droite (l'une sous l'autre sur écran étroit).
$largeur = $avecVariantes ? '100%' : '860px';
$action = !empty($modale) ? url('produit/create') : null;
$retour = url('produit/index');
$attrsForm = 'enctype="multipart/form-data"';
$suffixe = !empty($modale) ? 'M' : '';
$v = fn(string $k) => h($produit[$k] ?? '');
$nombre = fn(string $k) => isset($produit[$k]) && $produit[$k] !== null && $produit[$k] !== '' ? h(quantite_fr($produit[$k], false)) : '';
if ($avecVariantes) {
    echo '<div class="row g-4 align-items-start"><div class="col-xl-7">';
}
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
                    <label class="form-label" for="Unite<?= $suffixe ?>">Unité de vente</label>
                    <?php $uniteProduit = $produit['Unite'] ?? null; $unitesListe = unites_actives();
                    // Nouveau produit : l'unité par défaut doit être active.
                    if (!$edition && $unitesListe && !in_array($uniteProduit, $unitesListe, true)) { $uniteProduit = $unitesListe[0]; } ?>
                    <select class="form-select" id="Unite<?= $suffixe ?>" name="Unite">
                        <?php if ($uniteProduit !== null && $uniteProduit !== '' && !in_array($uniteProduit, $unitesListe, true)): ?>
                            <option value="<?= h($uniteProduit) ?>" selected><?= h($uniteProduit) ?> (désactivée)</option>
                        <?php endif; ?>
                        <?php foreach ($unitesListe as $u): ?><option value="<?= h($u) ?>" <?= $u === $uniteProduit ? 'selected' : '' ?>><?= h($u) ?></option><?php endforeach; ?>
                    </select>
                    <div class="form-text">Le prix TTC s'entend pour une unité.<?php if (is_admin()): ?> <a href="<?= h(url('unite/index')) ?>">Gérer les unités</a><?php endif; ?></div>
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="Cout<?= $suffixe ?>">Coût d'achat HT (FCFA)</label>
                    <input class="form-control" id="Cout<?= $suffixe ?>" name="Cout" inputmode="decimal" value="<?= $nombre('Cout') ?>" placeholder="Facultatif">
                    <?php if (isset($produit['Cout']) && $produit['Cout'] !== null && $produit['Cout'] !== '' && (float) ($produit['PrixVente'] ?? 0) > 0):
                        $ht = (float) $produit['PrixVente'] / (1 + (float) ($produit['TauxTVA'] ?? 0) / 100);
                        $marge = $ht - (float) $produit['Cout']; ?>
                        <div class="form-text">Marge : <strong class="<?= $marge < 0 ? 'text-danger' : '' ?>"><?= fcfa($marge) ?> FCFA</strong> par unité (<?= $ht > 0 ? quantite_fr(round($marge * 100 / $ht, 1)) : 0 ?> % du prix HT).</div>
                    <?php else: ?><div class="form-text">Sert au calcul de la marge.</div><?php endif; ?>
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="Image<?= $suffixe ?>">Image du produit</label>
                    <div class="d-flex align-items-center gap-2">
                        <?php if ($image = url_image_produit($produit)): ?><img src="<?= h($image) ?>" alt="Image actuelle" class="vignette-image"><?php endif; ?>
                        <input class="form-control" type="file" id="Image<?= $suffixe ?>" name="Image" accept="image/png,image/jpeg,image/webp,image/gif">
                    </div>
                    <?php if ($image): ?>
                        <div class="form-check mt-1"><input class="form-check-input" type="checkbox" value="1" id="SupprimerImage" name="SupprimerImage"><label class="form-check-label" for="SupprimerImage">Retirer l'image</label></div>
                    <?php else: ?><div class="form-text">JPG, PNG, WEBP ou GIF, 1 Mo au plus.</div><?php endif; ?>
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
                <?php if ($edition && !empty($produit['EstModele'])): ?>
                    <div class="col-md-4">
                        <div class="form-label">Quantité en stock</div>
                        <div class="form-control-plaintext fw-bold py-1"><?= quantite_fr(array_sum(array_map(fn($v) => $v['Actif'] ? (float) $v['StockActuel'] : 0, $variantes ?? []))) ?>
                            <a class="small fw-normal ms-2" href="#variantes">par variante</a></div>
                        <div class="form-text mt-0">Total des variantes actives : le stock se gère sur chaque variante.</div>
                    </div>
                <?php elseif ($edition): ?>
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
<?php if ($avecVariantes):
    $attributs = $attributs ?? [];
    $variantes = $variantes ?? [];
    $lignesAttributs = $attributs ?: [['Nom' => '', 'valeurs' => []]]; ?>
</div>
<div class="col-xl-5">
<div class="card shadow-sm border-0" id="variantes">
    <div class="card-header bg-brand text-white d-flex align-items-center gap-2">
        <h5 class="mb-0 flex-grow-1">Variantes</h5>
        <?php if ($variantes): ?><span class="badge bg-light text-dark"><?= count(array_filter($variantes, fn($v) => $v['Actif'])) ?> active(s)</span><?php endif; ?>
    </div>
    <div class="card-body">
        <p class="small text-muted">Ajoutez des attributs (ex. <strong>Taille</strong> : S, M, L ; <strong>Couleur</strong> : Rouge, Bleu) : une variante est créée pour
            chaque combinaison, avec son code, son code-barres, son stock et un supplément de prix. Le produit devient alors un modèle :
            à la vente, on choisit la variante. Retirer une valeur désactive les variantes concernées (l'historique est gardé).</p>
        <form method="post" action="<?= h(url('produit/genvariantes')) ?>">
            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $produit['Id'] ?>">
            <datalist id="nomsAttributs"><?php foreach ($nomsAttributs ?? [] as $n): ?><option value="<?= h($n) ?>"><?php endforeach; ?></datalist>
            <table class="table align-middle mb-2" id="tableAttributs">
                <thead class="table-dark"><tr><th style="width:30%">Attribut</th><th>Valeurs (séparées par des virgules)</th><th style="width:1%"></th></tr></thead>
                <tbody>
                <?php foreach ($lignesAttributs as $i => $a): ?>
                    <tr>
                        <td><input class="form-control" name="attribut[<?= $i ?>][nom]" value="<?= h($a['Nom']) ?>" list="nomsAttributs" placeholder="Ex : Taille" maxlength="50" aria-label="Attribut"></td>
                        <td><input class="form-control" name="attribut[<?= $i ?>][valeurs]" value="<?= h(implode(', ', $a['valeurs'])) ?>" placeholder="Ex : S, M, L, XL" aria-label="Valeurs"></td>
                        <td><button type="button" class="btn btn-outline-danger btn-sm" onclick="this.closest('tr').remove()" aria-label="Retirer cet attribut"><i class="fa fa-xmark"></i></button></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
            <div class="d-flex flex-wrap gap-2">
                <button type="button" class="btn btn-outline-primary btn-sm" onclick="ajouterAttribut()"><i class="fa fa-plus"></i> Ajouter un attribut</button>
                <button class="btn btn-primary btn-sm"><i class="fa fa-wand-magic-sparkles"></i> Enregistrer et générer les variantes</button>
            </div>
        </form>

        <?php if ($variantes): ?>
            <hr class="my-4">
            <form method="post" action="<?= h(url('produit/majvariantes')) ?>">
                <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $produit['Id'] ?>">
                <div class="table-responsive">
                    <table class="table align-middle small mb-2">
                        <thead class="table-dark"><tr><th>Variante</th><th class="text-end">Prix TTC</th><th class="text-end">Quantité</th><th class="text-center" title="Active">Active</th></tr></thead>
                        <tbody>
                        <?php foreach ($variantes as $v): $id = (int) $v['Id']; ?>
                            <tr class="<?= $v['Actif'] ? '' : 'text-muted' ?>">
                                <td class="fw-semibold border-bottom-0"><?= h($v['LibelleVariante'] ?: $v['Nom']) ?></td>
                                <td class="border-bottom-0"><input class="form-control form-control-sm text-end" name="variante[<?= $id ?>][Prix]" value="<?= h(quantite_fr($v['PrixVente'], false)) ?>" inputmode="decimal" required style="width:95px; margin-left:auto" aria-label="Prix TTC"></td>
                                <td class="border-bottom-0"><?php if ($v['SuiviStock']): ?>
                                    <input class="form-control form-control-sm text-end" name="variante[<?= $id ?>][Quantite]" value="<?= h(quantite_fr($v['StockActuel'], false)) ?>" inputmode="decimal" style="width:80px; margin-left:auto" aria-label="Quantité en stock">
                                <?php else: ?><span class="d-block text-end text-muted">—</span><?php endif; ?></td>
                                <td class="text-center border-bottom-0"><input class="form-check-input" type="checkbox" value="1" name="variante[<?= $id ?>][Actif]" <?= $v['Actif'] ? 'checked' : '' ?> aria-label="Variante active"></td>
                            </tr>
                            <tr class="<?= $v['Actif'] ? '' : 'text-muted' ?>">
                                <td colspan="4" class="pt-0">
                                    <div class="d-flex gap-2">
                                        <input class="form-control form-control-sm" name="variante[<?= $id ?>][Code]" value="<?= h($v['Code']) ?>" required placeholder="Code" title="Code" aria-label="Code">
                                        <input class="form-control form-control-sm" name="variante[<?= $id ?>][CodeBarres]" value="<?= h($v['CodeBarres']) ?>" placeholder="Code-barres" title="Code-barres" aria-label="Code-barres"
                                               onkeydown="if (event.key === 'Enter') event.preventDefault();">
                                    </div>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
                <div class="d-flex flex-wrap gap-2 align-items-center">
                    <button class="btn btn-primary btn-sm"><i class="fa fa-floppy-disk"></i> Enregistrer les variantes</button>
                    <a class="btn btn-outline-secondary btn-sm" href="<?= h(url('stock/entree')) ?>"><i class="fa fa-truck-ramp-box"></i> Entrée de stock</a>
                    <span class="small text-muted">Une quantité modifiée est enregistrée comme un ajustement d'inventaire. Le nom, la catégorie, les taxes, l'unité et le coût suivent le modèle ; l'écart de prix avec le modèle est gardé quand son prix change.</span>
                </div>
            </form>
        <?php endif; ?>
    </div>
</div>
</div>
</div>
<script>
    function ajouterAttribut() {
        const corps = document.querySelector('#tableAttributs tbody');
        const n = Date.now();
        const tr = document.createElement('tr');
        tr.innerHTML = '<td><input class="form-control" name="attribut[' + n + '][nom]" list="nomsAttributs" placeholder="Ex : Couleur" maxlength="50" aria-label="Attribut"></td>'
            + '<td><input class="form-control" name="attribut[' + n + '][valeurs]" placeholder="Ex : Rouge, Bleu" aria-label="Valeurs"></td>'
            + '<td><button type="button" class="btn btn-outline-danger btn-sm" onclick="this.closest(\'tr\').remove()" aria-label="Retirer cet attribut"><i class="fa fa-xmark"></i></button></td>';
        corps.appendChild(tr);
        tr.querySelector('input').focus();
    }
</script>
<?php endif; ?>
