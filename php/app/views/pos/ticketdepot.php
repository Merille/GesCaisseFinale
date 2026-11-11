<?php
// Ticket de dépôt de linge 80 mm « NON PAYÉ » : exemplaire client, puis souche à joindre au linge
// (une page chacun). Ouvre la fenêtre d'impression.
$reste = $d['Statut'] === 'Retiré' ? 0.0 : max(0, (float) $d['Total'] - (float) $d['Acompte']);
$annule = $d['Statut'] === 'Annulé';
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>Dépôt n° <?= (int) $d['Numero'] ?></title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="<?= asset('assets/css/ticket.css') ?>">
</head>
<body>
<div class="ticket saut">
    <?php if ($logo): ?><div class="c"><img src="<?= h($logo) ?>" alt="" class="logo"></div><?php endif; ?>
    <div class="c b grand"><?= h($d['Societe'] ?: 'GesCaisse') ?></div>
    <?php foreach ($coordonnees as $ligne): ?><div class="c petit"><?= h($ligne) ?></div><?php endforeach; ?>
    <hr>
    <div class="c b tres-grand">DÉPÔT N° <?= (int) $d['Numero'] ?></div>
    <div class="non-paye"><?= $annule ? 'ANNULÉ' : ($d['Statut'] === 'Retiré' ? 'RETIRÉ' : 'NON PAYÉ') ?></div>
    <div class="c petit">Exemplaire client</div>
    <div>Déposé le : <?= date('d/m/Y H:i', strtotime($d['DateDepot'])) ?></div>
    <?php if ($d['DateRetraitPrevue']): ?><div class="b">Retrait   : à partir du <?= date('d/m/Y', strtotime($d['DateRetraitPrevue'])) ?></div><?php endif; ?>
    <div>Client    : <?= h($d['NomClient']) ?></div>
    <div>Téléphone : <?= h($d['TelephoneClient'] ?? '') ?></div>
    <div>Reçu par  : <?= h($d['Utilisateur'] ?? '') ?></div>
    <hr>
    <?php foreach ($lignes as $l):
        $totalLigne = round((float) $l['qte'] * (float) $l['prix'] * (1 - (float) ($l['remise'] ?? 0) / 100)); ?>
        <div class="b"><?= h($l['nom']) ?></div>
        <?php foreach ((array) ($l['composants'] ?? []) as $comp): ?>
            <div class="ind petit">· <?= quantite_fr($comp['qte']) ?> x <?= h($comp['nom']) ?></div>
        <?php endforeach; ?>
        <?php if (!empty($l['note'])): ?><div class="ind petit note"><?= h($l['note']) ?></div><?php endif; ?>
        <div class="r ind">
            <span><?= quantite_fr($l['qte']) ?> x <?= fcfa($l['prix']) ?><?= (float) ($l['remise'] ?? 0) > 0 ? ' -' . quantite_fr($l['remise']) . '%' : '' ?></span>
            <span><?= fcfa($totalLigne) ?></span>
        </div>
    <?php endforeach; ?>
    <hr>
    <?php if ($brut != (float) $d['Total']): ?>
        <div class="r"><span>Sous-total</span><span><?= fcfa($brut) ?></span></div>
        <div class="r"><span>Remise globale</span><span>-<?= fcfa($brut - (float) $d['Total']) ?></span></div>
    <?php endif; ?>
    <div class="r b grand"><span>TOTAL TTC</span><span><?= fcfa($d['Total']) ?> FCFA</span></div>
    <?php if ((float) $d['Acompte'] > 0): ?>
        <div class="r"><span>Acompte versé<?= $d['ModeAcompte'] ? ' (' . h($d['ModeAcompte']) . ')' : '' ?></span><span>-<?= fcfa($d['Acompte']) ?></span></div>
    <?php endif; ?>
    <div class="r b grand"><span>RESTE À PAYER</span><span><?= fcfa($reste) ?> FCFA</span></div>
    <hr>
    <div class="c">Présentez ce ticket pour retirer votre linge.<br>Le paiement se fait au retrait.</div>
</div>
<div class="ticket">
    <div class="c b grand"><?= h($d['Societe'] ?: 'GesCaisse') ?></div>
    <div class="c petit">Souche à joindre au linge</div>
    <hr>
    <div class="c b tres-grand">DÉPÔT N° <?= (int) $d['Numero'] ?></div>
    <div class="c b grand"><?= h($d['NomClient']) ?></div>
    <div class="c b"><?= h($d['TelephoneClient'] ?? '') ?></div>
    <hr>
    <div>Déposé le : <?= date('d/m/Y H:i', strtotime($d['DateDepot'])) ?></div>
    <?php if ($d['DateRetraitPrevue']): ?><div class="b">Retrait   : <?= date('d/m/Y', strtotime($d['DateRetraitPrevue'])) ?></div><?php endif; ?>
    <hr>
    <?php foreach ($lignes as $l): ?>
        <div class="r"><span><?= h($l['nom']) ?></span><span>x <?= quantite_fr($l['qte']) ?></span></div>
        <?php if (!empty($l['note'])): ?><div class="ind petit note"><?= h($l['note']) ?></div><?php endif; ?>
    <?php endforeach; ?>
    <hr>
    <div class="r b"><span>Articles</span><span><?= quantite_fr($d['NbArticles']) ?></span></div>
    <div class="r b"><span><?= $reste > 0 ? 'Reste à payer' : 'Payé' ?></span><span><?= $reste > 0 ? fcfa($reste) . ' FCFA' : '' ?></span></div>
</div>
<script>window.addEventListener('load', function () { window.print(); });</script>
</body>
</html>
