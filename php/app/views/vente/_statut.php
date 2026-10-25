<?php
// Badge du statut d'une vente. Variable : $statut.
$classe = [
    'Payée' => 'bg-success', 'Annulée' => 'bg-danger', 'Retour' => 'bg-warning text-dark',
    'Remboursée' => 'bg-secondary', 'Remboursée en partie' => 'bg-info text-dark',
][$statut] ?? 'bg-secondary';
?><span class="badge <?= $classe ?>"><?= h($statut) ?></span>
