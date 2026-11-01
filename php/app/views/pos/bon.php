<?php
// Bons de préparation 80 mm (cuisine / bar), un par page. Ouvre la fenêtre d'impression.
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>Bon de préparation</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="<?= asset('assets/css/ticket.css') ?>">
</head>
<body>
<?php foreach ($bons as $i => $b): ?>
<div class="ticket<?= $i < count($bons) - 1 ? ' saut' : '' ?>">
    <div class="c b tres-grand"><?= h(mb_strtoupper($b['Poste'])) ?> · N° <?= (int) $b['Numero'] ?></div>
    <div class="c b grand"><?= h($b['TableNom'] ?? 'Vente directe') ?><?= $b['Couverts'] ? ' · ' . (int) $b['Couverts'] . ' couv.' : '' ?></div>
    <div class="c"><?= date_fr($b['DateEnvoi'], 'd/m/Y H:i') ?> · <?= h($b['Serveur'] ?? '') ?></div>
    <hr>
    <?php foreach ($b['lignes'] as $l): $annule = (float) $l['Quantite'] < 0; ?>
        <div class="bon-ligne<?= $annule ? ' annule' : '' ?>"><?= quantite_fr(abs((float) $l['Quantite'])) ?> x <?= h($l['Libelle']) ?></div>
        <?php if ($annule): ?><div class="ind b">*** ANNULÉ ***</div><?php endif; ?>
        <?php if ($l['Note']): ?><div class="ind note">» <?= h($l['Note']) ?></div><?php endif; ?>
    <?php endforeach; ?>
    <hr>
</div>
<?php endforeach; ?>
<?php if (!$bons): ?><div class="ticket c">Aucun bon.</div><?php endif; ?>
<script>window.addEventListener('load', function () { window.print(); });</script>
</body>
</html>
