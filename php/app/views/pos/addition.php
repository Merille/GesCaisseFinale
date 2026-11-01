<?php
// Addition (note provisoire) d'une table, imprimée avant le paiement. Ouvre la fenêtre d'impression.
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>Addition <?= h($co['TableNom'] ?? '') ?></title>
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
    <div class="c b grand"><?= h($co['TableNom'] ?? '') ?> · <?= (int) $co['Couverts'] ?> couvert(s)</div>
    <div>Date    : <?= date('d/m/Y H:i') ?></div>
    <div>Serveur : <?= h($co['Serveur'] ?? '') ?></div>
    <hr>
    <?php foreach ($lignes as $l):
        $total = round((float) $l['qte'] * (float) $l['prix'] * (1 - (float) $l['remise'] / 100)); ?>
        <div class="b"><?= h($l['nom']) ?></div>
        <?php foreach ((array) ($l['composants'] ?? []) as $comp): ?>
            <div class="ind petit">· <?= quantite_fr($comp['qte']) ?> x <?= h($comp['nom']) ?><?= (float) ($comp['supplement'] ?? 0) > 0 ? ' (+' . fcfa($comp['supplement']) . ')' : '' ?></div>
        <?php endforeach; ?>
        <div class="r ind">
            <span><?= quantite_fr($l['qte']) ?> x <?= fcfa($l['prix']) ?><?= (float) $l['remise'] > 0 ? ' -' . quantite_fr($l['remise']) . '%' : '' ?></span>
            <span><?= fcfa($total) ?></span>
        </div>
    <?php endforeach; ?>
    <hr>
    <?php if ($brut != $total): ?>
        <div class="r"><span>Sous-total</span><span><?= fcfa($brut) ?></span></div>
        <div class="r"><span>Remise globale</span><span>-<?= fcfa($brut - $total) ?></span></div>
    <?php endif; ?>
    <div class="r b grand"><span>TOTAL TTC</span><span><?= fcfa($total) ?> FCFA</span></div>
    <?php if ((int) $co['Couverts'] > 1): ?>
        <div class="r"><span>Soit par couvert</span><span><?= fcfa(round($total / (int) $co['Couverts'])) ?></span></div>
    <?php endif; ?>
    <hr>
    <div class="c">Note provisoire : le ticket de caisse est remis au paiement.</div>
</div>
<script>window.addEventListener('load', function () { window.print(); });</script>
</body>
</html>
