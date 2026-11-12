<?php // Onglets du module Achats. Variable : $onglet. ?>
<ul class="nav nav-tabs mb-3">
    <li class="nav-item"><a class="nav-link <?= $onglet === 'index' ? 'active' : '' ?>" href="<?= h(url('achat/index')) ?>"><i class="fa fa-list"></i> Achats</a></li>
    <li class="nav-item"><a class="nav-link <?= $onglet === 'nouveau' ? 'active' : '' ?>" href="<?= h(url('achat/nouveau')) ?>"><i class="fa fa-cart-plus"></i> Nouvel achat</a></li>
    <li class="nav-item"><a class="nav-link <?= $onglet === 'consommation' ? 'active' : '' ?>" href="<?= h(url('achat/consommation')) ?>"><i class="fa fa-bottle-droplet"></i> Consommations</a></li>
    <li class="nav-item"><a class="nav-link <?= $onglet === 'stock' ? 'active' : '' ?>" href="<?= h(url('achat/stock')) ?>"><i class="fa fa-warehouse"></i> Dépôt des achats</a></li>
</ul>
<?php if ($alertes = entretien_en_alerte()): ?>
    <div class="alert alert-warning d-flex flex-wrap align-items-center gap-2" id="alerteEntretien">
        <i class="fa fa-triangle-exclamation"></i>
        <strong><?= count($alertes) ?> produit<?= count($alertes) > 1 ? 's' : '' ?> d'entretien à racheter :</strong>
        <span><?= implode(' · ', array_map(fn($a) => h($a['Nom']) . ' (' . quantite_fr($a['Stock']) . ' ' . h($a['Unite']) . ', seuil ' . quantite_fr($a['SeuilAlerte']) . ')', $alertes)) ?></span>
        <?php if ($onglet !== 'nouveau' || !get('racheter')): ?>
            <a class="btn btn-sm btn-warning ms-auto" href="<?= h(url('achat/nouveau', ['racheter' => 1])) ?>"><i class="fa fa-cart-plus"></i> Racheter</a>
        <?php endif; ?>
    </div>
<?php endif; ?>
