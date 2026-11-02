<?php
$titre = 'Transfert entre dépôts';
$onglet = 'transfert';
require __DIR__ . '/_onglets.php';
$options = function () use ($produits): string {
    $html = '<option value="">-- Produit --</option>';
    foreach ($produits as $p) {
        $html .= '<option value="' . (int) $p['Id'] . '">' . h($p['Code'] . ' · ' . $p['Nom'] . ' (dans le dépôt de départ : ' . quantite_fr($p['StockDepot']) . ')') . '</option>';
    }
    return $html;
};
?>
<?php if (count($depots) < 2): ?>
    <div class="alert alert-info">Un transfert demande au moins deux dépôts actifs. Créez-les dans <a href="<?= h(url('depot/index')) ?>">Paramètres › Dépôts</a>.</div>
<?php elseif (!$produits): ?>
    <div class="alert alert-info">Aucun produit avec suivi de stock. Cochez « Suivre le stock » dans la fiche d'un produit.</div>
<?php else: ?>
<form method="post" class="card border-0 shadow-sm">
    <div class="card-header bg-brand text-white">Marchandises transférées</div>
    <div class="card-body">
        <?= csrf_field() ?>
        <div class="row g-3 mb-3">
            <div class="col-md-6"><label class="form-label" for="depart">Dépôt de départ</label>
                <select class="form-select" id="depart" name="depart" required onchange="window.location.href = 'index.php?r=stock/transfert&depot=' + this.value">
                    <?php foreach ($depots as $d): ?><option value="<?= (int) $d['Id'] ?>" <?= $depart === (int) $d['Id'] ? 'selected' : '' ?>><?= h($d['Code'] . ' · ' . $d['Nom']) ?></option><?php endforeach; ?>
                </select></div>
            <div class="col-md-6"><label class="form-label" for="arrivee">Dépôt d'arrivée</label>
                <select class="form-select" id="arrivee" name="arrivee" required>
                    <?php $premier = true; foreach ($depots as $d): if ((int) $d['Id'] === $depart) { continue; } ?>
                        <option value="<?= (int) $d['Id'] ?>" <?= $premier ? 'selected' : '' ?>><?= h($d['Code'] . ' · ' . $d['Nom']) ?></option>
                    <?php $premier = false; endforeach; ?>
                </select></div>
            <div class="col-md-5"><label class="form-label" for="reference">Référence</label><input class="form-control" id="reference" name="reference" placeholder="Vide : TRF-date-heure"></div>
            <div class="col-md-7"><label class="form-label" for="commentaire">Commentaire</label><input class="form-control" id="commentaire" name="commentaire" placeholder="Ex : réassort de la boutique"></div>
        </div>
        <table class="table align-middle" id="lignesTransfert">
            <thead><tr><th>Produit</th><th style="width:160px">Quantité</th><th style="width:50px"></th></tr></thead>
            <tbody>
            <?php for ($i = 0; $i < 5; $i++): ?>
                <tr>
                    <td><select class="form-select" name="produit[]" aria-label="Produit"><?= $options() ?></select></td>
                    <td><input class="form-control text-end" name="qte[]" inputmode="decimal" aria-label="Quantité transférée"></td>
                    <td><button type="button" class="btn btn-sm btn-outline-danger" onclick="this.closest('tr').remove()" aria-label="Retirer la ligne"><i class="fa fa-xmark"></i></button></td>
                </tr>
            <?php endfor; ?>
            </tbody>
        </table>
        <button type="button" class="btn btn-sm btn-outline-secondary" id="ajouterLigne"><i class="fa fa-plus"></i> Ajouter une ligne</button>
    </div>
    <div class="card-footer bg-white d-flex gap-2">
        <button class="btn btn-success"><i class="fa fa-check"></i> Enregistrer le transfert</button>
        <a href="<?= h(url('stock/index')) ?>" class="btn btn-outline-secondary">Annuler</a>
    </div>
</form>
<?php ob_start(); ?>
<script>
    document.getElementById('ajouterLigne').addEventListener('click', function () {
        const corps = document.querySelector('#lignesTransfert tbody');
        const ligne = corps.rows[0].cloneNode(true);
        ligne.querySelector('select').value = '';
        ligne.querySelector('input').value = '';
        corps.appendChild(ligne);
    });
</script>
<?php $scripts = ob_get_clean(); ?>
<?php endif; ?>
