<?php
$titre = 'Nouvel achat';
$onglet = 'nouveau';
require __DIR__ . '/_onglets.php';
$options = function () use ($produits): string {
    $html = '<option value="">-- Produit --</option>';
    foreach ($produits as $p) {
        $html .= '<option value="' . (int) $p['Id'] . '" data-cout="' . h($p['Cout'] === null ? '' : quantite_fr($p['Cout'], false)) . '">'
            . h($p['Code'] . ' · ' . $p['Nom'] . ($p['Consommable'] ? ' (consommable)' : '') . ' — en magasin ' . quantite_fr($p['StockDepot']) . ' ' . $p['Unite']) . '</option>';
    }
    return $html;
};
?>
<?php if (!$produits): ?>
    <div class="alert alert-info">Aucun produit avec suivi de stock. Créez vos produits (lessive, javel…) dans Configuration › Produits,
        en cochant « Suivre le stock » et, pour un produit utilisé sans être vendu, « Consommable ».</div>
<?php else: ?>
<form method="post" class="card border-0 shadow-sm" id="formAchat">
    <div class="card-header bg-brand text-white">Achat chez un fournisseur</div>
    <div class="card-body">
        <?= csrf_field() ?>
        <div class="row g-3 mb-3">
            <div class="col-md-3"><label class="form-label" for="fournisseur">Fournisseur</label>
                <select class="form-select" id="fournisseur" name="fournisseur">
                    <option value="">-- Sans fournisseur --</option>
                    <?php foreach ($fournisseurs as $fo): ?><option value="<?= (int) $fo['Id'] ?>"><?= h($fo['NomSociete']) ?></option><?php endforeach; ?>
                </select>
                <div class="form-text"><a href="<?= h(url('client/create')) ?>">Nouveau tiers</a> de type « Fournisseur ».</div></div>
            <div class="col-md-2"><label class="form-label" for="date">Date d'achat</label><input type="date" class="form-control" id="date" name="date" value="<?= date('Y-m-d') ?>" max="<?= date('Y-m-d') ?>" required></div>
            <div class="col-md-3"><label class="form-label" for="depot">Dépôt qui reçoit</label>
                <input class="form-control" id="depot" value="<?= h($depot ? $depot['Code'] . ' · ' . $depot['Nom'] : 'Dépôt des achats') ?>" readonly>
                <div class="form-text">Dépôt des achats : <a href="<?= h(url('achat/stock')) ?>">entrées, sorties et stock</a>.</div></div>
            <div class="col-md-4"><label class="form-label" for="reference">Référence (facture, bon de livraison)</label><input class="form-control" id="reference" name="reference" maxlength="100" placeholder="Ex : FAC-2026-0412"></div>
        </div>
        <table class="table align-middle" id="lignesAchat">
            <thead><tr><th>Produit</th><th style="width:140px">Quantité</th><th style="width:170px">Prix d'achat unitaire</th><th style="width:150px" class="text-end">Montant</th><th style="width:50px"></th></tr></thead>
            <tbody>
            <?php for ($i = 0; $i < 4; $i++): ?>
                <tr>
                    <td><select class="form-select" name="produit[]" aria-label="Produit"><?= $options() ?></select></td>
                    <td><input class="form-control text-end" name="qte[]" inputmode="decimal" aria-label="Quantité"></td>
                    <td><input class="form-control text-end" name="prix[]" inputmode="decimal" aria-label="Prix d'achat unitaire"></td>
                    <td class="text-end text-nowrap montant">—</td>
                    <td><button type="button" class="btn btn-sm btn-outline-danger retirer" aria-label="Retirer la ligne"><i class="fa fa-xmark"></i></button></td>
                </tr>
            <?php endfor; ?>
            </tbody>
            <tfoot><tr class="fw-bold"><td colspan="3" class="text-end">Total de l'achat</td><td class="text-end text-nowrap" id="totalAchat">0 FCFA</td><td></td></tr></tfoot>
        </table>
        <button type="button" class="btn btn-sm btn-outline-secondary" id="ajouterLigne"><i class="fa fa-plus"></i> Ajouter une ligne</button>

        <hr>
        <div class="row g-3">
            <div class="col-md-4"><label class="form-label" for="paiement">Règlement</label>
                <select class="form-select" id="paiement" name="paiement">
                    <?php foreach (ACHAT_PAIEMENTS as $code => $lib): ?><option value="<?= $code ?>"><?= h($lib) ?></option><?php endforeach; ?>
                </select></div>
            <div class="col-md-2 regle"><label class="form-label" for="montantRegle">Montant réglé</label><input class="form-control text-end" id="montantRegle" name="montantRegle" inputmode="decimal"></div>
            <div class="col-md-3 regle"><label class="form-label" for="mode">Mode de paiement</label>
                <select class="form-select" id="mode" name="mode">
                    <?php foreach ($modes as $m): ?><option value="<?= (int) $m['Id'] ?>"><?= h($m['Libelle']) ?></option><?php endforeach; ?>
                </select></div>
            <div class="col-md-3 regle-caisse"><label class="form-label" for="journee">Journée de caisse</label>
                <select class="form-select" id="journee" name="journee">
                    <?php if (!$journees): ?><option value="">Aucune journée ouverte</option><?php endif; ?>
                    <?php foreach ($journees as $j): ?><option value="<?= (int) $j['Id'] ?>"><?= h($j['ChkCode'] . ' · ' . $j['NumeroJournee']) ?></option><?php endforeach; ?>
                </select></div>
            <div class="col-12"><label class="form-label" for="commentaire">Commentaire</label><input class="form-control" id="commentaire" name="commentaire" maxlength="300"></div>
        </div>
        <p class="small text-muted mt-2 mb-0">Les quantités entrent dans le dépôt des achats et le coût des produits est recalculé (coût moyen pondéré).
            Payé par la caisse : un décaissement est enregistré dans la journée ouverte choisie. À crédit : réglez plus tard depuis le détail de l'achat.</p>
    </div>
    <div class="card-footer bg-white d-flex gap-2">
        <button class="btn btn-success"><i class="fa fa-check"></i> Enregistrer l'achat</button>
        <a href="<?= h(url('achat/index')) ?>" class="btn btn-outline-secondary">Annuler</a>
    </div>
</form>
<?php ob_start(); ?>
<script src="<?= asset('assets/js/achats.js') ?>"></script>
<?php $scripts = ob_get_clean(); ?>
<?php endif; ?>
