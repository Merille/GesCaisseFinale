<?php
// Addition (note provisoire, NON PAYÉE) d'une table ou d'un ticket, imprimée avant le paiement.
// Ouvre la fenêtre d'impression. $titre : table et couverts, ou numéro du ticket.
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>Addition <?= h($titre) ?></title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="<?= asset('assets/css/ticket.css') ?>">
</head>
<body>
<div class="ticket">
    <?php if ($logo): ?><div class="c"><img src="<?= h($logo) ?>" alt="" class="logo"></div><?php endif; ?>
    <div class="c b grand"><?= h($co['Societe'] ?: 'GesCaisse') ?></div>
    <?php foreach ($coordonnees as $ligne): ?><div class="c petit"><?= h($ligne) ?></div><?php endforeach; ?>
    <hr>
    <div class="c b tres-grand">ADDITION</div>
    <div class="non-paye">NON PAYÉ</div>
    <div class="c b grand"><?= h($titre) ?></div>
    <div>Date    : <?= date('d/m/Y H:i') ?></div>
    <div><?= $couverts ? 'Serveur' : 'Vendeur' ?> : <?= h($serveur) ?></div>
    <?php if ($client): ?><div>Client  : <?= h($client) ?></div><?php endif; ?>
    <hr>
    <?php foreach ($lignes as $l):
        $totalLigne = round((float) $l['qte'] * (float) $l['prix'] * (1 - (float) $l['remise'] / 100)); ?>
        <div class="b"><?= h($l['nom']) ?></div>
        <?php foreach ((array) ($l['composants'] ?? []) as $comp): ?>
            <div class="ind petit">· <?= quantite_fr($comp['qte']) ?> x <?= h($comp['nom']) ?><?= (float) ($comp['supplement'] ?? 0) > 0 ? ' (+' . fcfa($comp['supplement']) . ')' : '' ?></div>
        <?php endforeach; ?>
        <div class="r ind">
            <span><?= quantite_fr($l['qte']) ?> x <?= fcfa($l['prix']) ?><?= (float) $l['remise'] > 0 ? ' -' . quantite_fr($l['remise']) . '%' : '' ?></span>
            <span><?= fcfa($totalLigne) ?></span>
        </div>
    <?php endforeach; ?>
    <hr>
    <?php if ($brut != $total): ?>
        <div class="r"><span>Sous-total</span><span><?= fcfa($brut) ?></span></div>
        <div class="r"><span>Remise globale</span><span>-<?= fcfa($brut - $total) ?></span></div>
    <?php endif; ?>
    <?php if ($frais > 0): ?>
        <div class="r"><span>Total articles TTC</span><span><?= fcfa($total) ?></span></div>
        <div class="r"><span>Frais de livraison</span><span><?= fcfa($frais) ?></span></div>
    <?php endif; ?>
    <div class="r b grand"><span><?= $frais > 0 ? 'TOTAL À PAYER' : 'TOTAL TTC' ?></span><span><?= fcfa($total + $frais) ?> FCFA</span></div>
    <?php if ($couverts > 1): ?>
        <div class="r"><span>Soit par couvert</span><span><?= fcfa(round(($total + $frais) / $couverts)) ?></span></div>
    <?php endif; ?>
    <hr>
    <div class="non-paye">NON PAYÉ</div>
    <div class="c">Note provisoire, non payée : elle ne vaut pas ticket de caisse. Le ticket est remis au paiement.</div>
</div>
<script>window.addEventListener('load', function () { window.print(); });</script>
</body>
</html>
