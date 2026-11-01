<?php
$titre = $combo ? 'Modifier le combo' : 'Nouveau combo';
$entete = $titre;
$largeur = '760px';
$retour = url('combo/index');
$action = !empty($modale) ? url('combo/create') : null;
require __DIR__ . '/../partials/form_debut.php';
?>
            <div class="row g-3">
                <div class="col-md-8"><label class="form-label" for="Nom">Nom du combo</label>
                    <input class="form-control" id="Nom" name="Nom" maxlength="50" value="<?= h($valeurs['Nom']) ?>" placeholder="Ex : Plats, Boissons, Desserts" required></div>
                <div class="col-md-4"><label class="form-label" for="Quantite">Articles à choisir</label>
                    <input class="form-control" id="Quantite" name="Quantite" type="number" min="1" max="10" value="<?= (int) $valeurs['Quantite'] ?>"></div>
                <div class="col-12">
                    <label class="form-label">Produits proposés</label>
                    <input type="hidden" name="choix" id="combo-json">
                    <div id="combo-editeur"></div>
                    <script id="combo-donnees" type="application/json"><?= json_encode($donnees, JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_AMP) ?></script>
                    <div class="form-text">Le supplément s'ajoute au prix du produit combo quand ce produit est choisi.</div>
                </div>
            </div>
<?php require __DIR__ . '/../partials/form_fin.php'; ?>
<?php if (empty($modale)): ?>
<?php ob_start(); ?>
<script src="<?= asset('assets/js/combo.js') ?>"></script>
<?php $scripts = ob_get_clean(); ?>
<?php endif; ?>
