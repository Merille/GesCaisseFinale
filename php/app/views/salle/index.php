<?php $titre = 'Plan de salle'; ?>
<div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-3">
    <div>
        <h4 class="mb-0"><i class="fa <?= $caisse['TypePointVente'] === 'Bar' ? 'fa-martini-glass' : 'fa-utensils' ?>"></i> Plan de salle · <?= h($caisse['ChkCode']) ?></h4>
        <div class="small text-muted"><?= h($caisse['ChkDescription']) ?> · <?= h($caisse['TypePointVente']) ?></div>
    </div>
    <a href="<?= h(url('caisse/index')) ?>" class="btn btn-outline-secondary"><i class="fa fa-arrow-left"></i> Caisses</a>
</div>
<p class="small text-muted">Créez les salles (salle principale, terrasse…) puis placez les tables comme dans le restaurant. À la caisse,
    le serveur choisit la table sur ce plan ; la commande y reste jusqu'au paiement.</p>
<div class="card shadow-sm border-0"><div class="card-body" id="plan-salle"></div></div>
<script id="plan-donnees" type="application/json"><?= json_encode($donnees, JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_AMP) ?></script>
<?php ob_start(); ?>
<script src="<?= asset('assets/js/plan-salle.js') ?>"></script>
<?php $scripts = ob_get_clean(); ?>
