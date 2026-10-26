<?php
$titre = 'Entrée de marchandises';
$onglet = 'entree';
require __DIR__ . '/_onglets.php';
$choisi = (int) get('produit', 0);
$options = function (int $selection) use ($produits): string {
    $html = '<option value="">-- Produit --</option>';
    foreach ($produits as $p) {
        $html .= '<option value="' . (int) $p['Id'] . '"' . ($selection === (int) $p['Id'] ? ' selected' : '') . '>'
            . h($p['Code'] . ' · ' . $p['Nom'] . ' (stock ' . quantite_fr($p['StockActuel']) . ')') . '</option>';
    }
    return $html;
};
?>
<?php if (!$produits): ?>
    <div class="alert alert-info">Aucun produit avec suivi de stock. Cochez « Suivre le stock » dans la fiche d'un produit.</div>
<?php else: ?>
<form method="post" class="card border-0 shadow-sm" style="max-width: 900px;">
    <div class="card-header bg-brand text-white">Marchandises reçues</div>
    <div class="card-body">
        <?= csrf_field() ?>
        <div class="row g-3 mb-3">
            <div class="col-md-5"><label class="form-label" for="reference">Référence (bon de livraison, facture fournisseur)</label><input class="form-control" id="reference" name="reference" placeholder="Ex : BL-2026-118"></div>
            <div class="col-md-7"><label class="form-label" for="commentaire">Commentaire</label><input class="form-control" id="commentaire" name="commentaire" placeholder="Ex : livraison du fournisseur SODIBA"></div>
        </div>
        <table class="table align-middle" id="lignesEntree">
            <thead><tr><th>Produit</th><th style="width:160px">Quantité reçue</th><th style="width:50px"></th></tr></thead>
            <tbody>
            <?php for ($i = 0; $i < 5; $i++): ?>
                <tr>
                    <td><select class="form-select" name="produit[]" aria-label="Produit"><?= $options($i === 0 ? $choisi : 0) ?></select></td>
                    <td><input class="form-control text-end" name="qte[]" inputmode="decimal" aria-label="Quantité reçue"></td>
                    <td><button type="button" class="btn btn-sm btn-outline-danger" onclick="this.closest('tr').remove()" aria-label="Retirer la ligne"><i class="fa fa-xmark"></i></button></td>
                </tr>
            <?php endfor; ?>
            </tbody>
        </table>
        <button type="button" class="btn btn-sm btn-outline-secondary" id="ajouterLigne"><i class="fa fa-plus"></i> Ajouter une ligne</button>
    </div>
    <div class="card-footer bg-white d-flex gap-2">
        <button class="btn btn-success"><i class="fa fa-check"></i> Enregistrer l'entrée</button>
        <a href="<?= h(url('stock/index')) ?>" class="btn btn-outline-secondary">Annuler</a>
    </div>
</form>
<?php ob_start(); ?>
<script>
    document.getElementById('ajouterLigne').addEventListener('click', function () {
        const corps = document.querySelector('#lignesEntree tbody');
        const ligne = corps.rows[0].cloneNode(true);
        ligne.querySelector('select').value = '';
        ligne.querySelector('input').value = '';
        corps.appendChild(ligne);
    });
</script>
<?php $scripts = ob_get_clean(); ?>
<?php endif; ?>
