<?php // Onglets du module Stock. Variable : $onglet. ?>
<ul class="nav nav-tabs mb-3">
    <li class="nav-item"><a class="nav-link <?= $onglet === 'index' ? 'active' : '' ?>" href="<?= h(url('stock/index')) ?>"><i class="fa fa-clock-rotate-left"></i> Mouvements</a></li>
    <li class="nav-item"><a class="nav-link <?= $onglet === 'depots' ? 'active' : '' ?>" href="<?= h(url('stock/depots')) ?>"><i class="fa fa-warehouse"></i> Stock par dépôt</a></li>
    <li class="nav-item"><a class="nav-link <?= $onglet === 'entree' ? 'active' : '' ?>" href="<?= h(url('stock/entree')) ?>"><i class="fa fa-truck-ramp-box"></i> Entrée de marchandises</a></li>
    <li class="nav-item"><a class="nav-link <?= $onglet === 'transfert' ? 'active' : '' ?>" href="<?= h(url('stock/transfert')) ?>"><i class="fa fa-right-left"></i> Transfert</a></li>
    <li class="nav-item"><a class="nav-link <?= $onglet === 'inventaire' ? 'active' : '' ?>" href="<?= h(url('stock/inventaire')) ?>"><i class="fa fa-clipboard-check"></i> Inventaire</a></li>
</ul>
