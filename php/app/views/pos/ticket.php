<?php
// Ticket de caisse 80 mm. $imprimer : ouvre la fenêtre d'impression au chargement.
$c = $commande;
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>Ticket <?= h($c['Numero']) ?></title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="<?= asset('assets/css/ticket.css') ?>">
</head>
<body>
<div class="ticket">
    <div class="c b grand"><?= h($c['Societe'] ?: 'GesCaisse') ?></div>
    <div class="c"><?= h($c['ChkDescription']) ?></div>
    <?php if ($c['CommandeOrigineId']): ?>
        <div class="c b grand">RETOUR / REMBOURSEMENT</div>
    <?php elseif ($c['Statut'] === 'Annulée'): ?>
        <div class="c b grand">*** VENTE ANNULÉE ***</div>
    <?php endif; ?>
    <hr>
    <div>Ticket : <?= h($c['Numero']) ?></div>
    <?php if ($c['NumeroOrigine']): ?><div>Vente  : <?= h($c['NumeroOrigine']) ?></div><?php endif; ?>
    <div>Date   : <?= date_fr($c['DateCommande'], 'd/m/Y H:i') ?></div>
    <div>Caisse : <?= h($c['ChkCode']) ?> · Vendeur : <?= h($c['Vendeur']) ?></div>
    <?php if ($c['Client']): ?><div>Client : <?= h($c['Client']) ?></div><?php endif; ?>
    <hr>
    <?php foreach ($lignes as $l): ?>
        <div class="b"><?= h($l['Libelle']) ?></div>
        <div class="r ind">
            <span><?= quantite_fr($l['Quantite']) ?> x <?= fcfa($l['PrixUnitaire']) ?><?= (float) $l['Remise'] > 0 ? ' -' . quantite_fr($l['Remise']) . '%' : '' ?></span>
            <span><?= fcfa($l['TotalTTC']) ?></span>
        </div>
    <?php endforeach; ?>
    <hr>
    <div class="r b grand"><span>TOTAL TTC</span><span><?= fcfa($c['TotalTTC']) ?> FCFA</span></div>
    <div class="r"><span>Total HT</span><span><?= fcfa($c['TotalHT']) ?></span></div>
    <?php foreach ($taxes as $libelle => $montant): ?>
        <div class="r"><span><?= h($libelle) ?></span><span><?= fcfa($montant) ?></span></div>
    <?php endforeach; ?>
    <hr>
    <?php foreach ($paiements as $p): ?>
        <div class="r"><span><?= $c['CommandeOrigineId'] ? 'Remboursé · ' : '' ?><?= h($p['Libelle']) ?></span><span><?= fcfa($p['MontantRecu']) ?></span></div>
    <?php endforeach; ?>
    <?php if ((float) $c['MonnaieRendue'] > 0): ?>
        <div class="r b"><span>Monnaie rendue</span><span><?= fcfa($c['MonnaieRendue']) ?></span></div>
    <?php endif; ?>
    <hr>
    <?php if ($c['Motif']): ?><div>Motif : <?= h($c['Motif']) ?></div><hr><?php endif; ?>
    <div class="c">Merci de votre visite !</div>
    <div class="c petit"><?= h($c['Numero']) ?></div>
</div>
<?php if ($imprimer): ?>
<script>window.addEventListener('load', function () { window.print(); });</script>
<?php endif; ?>
</body>
</html>
