<?php // Onglets du module Achats. Variable : $onglet. ?>
<ul class="nav nav-tabs mb-3">
    <li class="nav-item"><a class="nav-link <?= $onglet === 'index' ? 'active' : '' ?>" href="<?= h(url('achat/index')) ?>"><i class="fa fa-list"></i> Achats</a></li>
    <li class="nav-item"><a class="nav-link <?= $onglet === 'nouveau' ? 'active' : '' ?>" href="<?= h(url('achat/nouveau')) ?>"><i class="fa fa-cart-plus"></i> Nouvel achat</a></li>
    <li class="nav-item"><a class="nav-link <?= $onglet === 'consommation' ? 'active' : '' ?>" href="<?= h(url('achat/consommation')) ?>"><i class="fa fa-bottle-droplet"></i> Consommations</a></li>
</ul>
