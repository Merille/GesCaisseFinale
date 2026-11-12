<?php
$titre = 'Consommations';
$onglet = 'consommation';
require __DIR__ . '/_onglets.php';
$options = function () use ($produits): string {
    $html = '<option value="">-- Produit --</option>';
    foreach ($produits as $p) {
        $html .= '<option value="' . (int) $p['Id'] . '">' . h($p['Code'] . ' · ' . $p['Nom'] . ($p['Consommable'] ? ' (consommable)' : '') . ' — en magasin ' . quantite_fr($p['StockDepot']) . ' ' . $p['Unite']) . '</option>';
    }
    return $html;
};
$valeur = array_sum(array_column($synthese, 'Valeur'));
?>
<?php if ($produits): ?>
<form method="post" class="card border-0 shadow-sm mb-3">
    <div class="card-header bg-brand text-white">Produits utilisés (sortie du stock)</div>
    <div class="card-body">
        <?= csrf_field() ?>
        <div class="row g-3 mb-3">
            <div class="col-md-4"><label class="form-label" for="depot">Dépôt où les produits sont pris</label>
                <input class="form-control" id="depot" value="<?= h($depot ? $depot['Code'] . ' · ' . $depot['Nom'] : 'Dépôt des achats') ?>" readonly>
                <div class="form-text">Dépôt des achats : <a href="<?= h(url('achat/stock')) ?>">entrées, sorties et stock</a>.</div></div>
            <div class="col-md-8"><label class="form-label" for="commentaire">Commentaire</label><input class="form-control" id="commentaire" name="commentaire" maxlength="300" placeholder="Ex : lavages de la semaine"></div>
        </div>
        <table class="table align-middle" id="lignesConsommation">
            <thead><tr><th>Produit</th><th style="width:160px">Quantité utilisée</th><th style="width:50px"></th></tr></thead>
            <tbody>
            <?php for ($i = 0; $i < 3; $i++): ?>
                <tr>
                    <td><select class="form-select" name="produit[]" aria-label="Produit"><?= $options() ?></select></td>
                    <td><input class="form-control text-end" name="qte[]" inputmode="decimal" aria-label="Quantité utilisée"></td>
                    <td><button type="button" class="btn btn-sm btn-outline-danger retirer" aria-label="Retirer la ligne"><i class="fa fa-xmark"></i></button></td>
                </tr>
            <?php endfor; ?>
            </tbody>
        </table>
        <button type="button" class="btn btn-sm btn-outline-secondary" id="ajouterLigne"><i class="fa fa-plus"></i> Ajouter une ligne</button>
    </div>
    <div class="card-footer bg-white"><button class="btn btn-success"><i class="fa fa-check"></i> Enregistrer la consommation</button></div>
</form>
<?php endif; ?>

<form method="get" action="index.php" class="card shadow-sm border-0 mb-3">
    <input type="hidden" name="r" value="achat/consommation">
    <div class="card-body d-flex flex-wrap align-items-end gap-3">
        <div><label class="form-label small fw-semibold text-muted mb-1" for="du">Consommations du</label><input type="date" class="form-control" id="du" name="du" value="<?= h($f['du']) ?>"></div>
        <div><label class="form-label small fw-semibold text-muted mb-1" for="au">Au</label><input type="date" class="form-control" id="au" name="au" value="<?= h($f['au']) ?>"></div>
        <button class="btn btn-primary"><i class="fa fa-search"></i> Filtrer</button>
        <div class="ms-auto text-end"><div class="small text-muted">Valeur consommée (au coût)</div><div class="fs-5 fw-bold"><?= fcfa($valeur) ?> <small class="fs-6 fw-normal text-muted">FCFA</small></div></div>
    </div>
</form>

<div class="row g-3">
    <div class="col-lg-5">
        <div class="card shadow-sm border-0 h-100">
            <div class="card-header bg-white fw-semibold">Par produit</div>
            <div class="card-body table-responsive">
                <table class="table align-middle mb-0 small">
                    <thead class="table-dark"><tr><th>Produit</th><th class="text-end">Quantité</th><th class="text-end">Valeur</th></tr></thead>
                    <tbody>
                    <?php foreach ($synthese as $s): ?>
                        <tr><td><?= h($s['Code'] . ' · ' . $s['Nom']) ?></td><td class="text-end text-nowrap"><?= quantite_fr($s['Quantite']) ?> <?= h($s['Unite']) ?></td><td class="text-end text-nowrap"><?= fcfa($s['Valeur']) ?></td></tr>
                    <?php endforeach; ?>
                    <?php if (!$synthese): ?><tr><td colspan="3" class="text-muted">Aucune consommation sur la période.</td></tr><?php endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
    <div class="col-lg-7">
        <div class="card shadow-sm border-0 h-100">
            <div class="card-header bg-white fw-semibold">Détail</div>
            <div class="card-body table-responsive">
                <table id="consommationsTable" class="table align-middle mb-0 small">
                    <thead class="table-dark"><tr><th>Date</th><th>Produit</th><th>Dépôt</th><th class="text-end">Quantité</th><th>Commentaire</th><th>Par</th></tr></thead>
                    <tbody>
                    <?php foreach ($mouvements as $i => $m): ?>
                        <tr><td class="text-nowrap" data-order="<?= sprintf('%06d', count($mouvements) - $i) ?>"><?= date_fr($m['DateMouvement'], 'd/m/Y H:i') ?></td><td><?= h($m['Nom']) ?></td><td><?= h((string) $m['Depot']) ?></td>
                            <td class="text-end text-nowrap"><?= quantite_fr(-(float) $m['Quantite']) ?> <?= h($m['Unite']) ?></td><td><?= h((string) $m['Commentaire']) ?></td><td><?= h((string) $m['Utilisateur']) ?></td></tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>
<p class="small text-muted mt-2">Valeur : quantité consommée × coût actuel du produit (coût moyen pondéré des achats).</p>
<?php ob_start(); ?>
<script src="<?= asset('assets/js/achats.js') ?>"></script>
<script>
    listeDataTable('#consommationsTable', { pageLength: 20, lengthMenu: [20, 50, 100], order: [[0, 'desc']] });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
