<?php
// En-tête commun des pages imprimables (remplacent les PDF Rotativa de la version .NET).
// Le bouton « Imprimer / PDF » ouvre l'impression du navigateur, qui permet aussi
// d'enregistrer la page au format PDF.
$infosSociete = $infosSociete ?? societe_courante();
$societe = $infosSociete['Nom'] ?? (user()['tenantNom'] ?? '');
$logoSociete = url_logo($infosSociete);
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title><?= h($titreImpression ?? 'Impression') ?> - GesCaisse</title>
    <style>
        body { font-family: Arial, sans-serif; font-size: 13px; color: #111; margin: 24px; }
        h1 { font-size: 20px; margin: 18px 0 12px; }
        h2 { font-size: 16px; margin: 24px 0 8px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #999; padding: 5px 7px; }
        th { background: #195d84; color: #fff; text-align: left; }
        .r { text-align: right; }
        .entete { display: flex; justify-content: space-between; border-bottom: 3px solid #999997; padding-bottom: 10px; }
        .entete strong { font-size: 18px; color: #195d84; }
        .barre { margin-bottom: 16px; }
        .barre button { background: #195d84; color: #fff; border: 0; padding: 8px 16px; border-radius: 6px; cursor: pointer; }
        .total td { font-weight: bold; background: #eef1f6; }
        .muted { color: #666; }
        @media print { .barre { display: none; } body { margin: 0; } }
    </style>
</head>
<body>
<div class="barre">
    <button type="button" onclick="window.print()">Imprimer / enregistrer en PDF</button>
    <a href="javascript:history.back()" style="margin-left:10px;">Retour</a>
</div>
<div class="entete">
    <div style="display:flex; gap:12px; align-items:center;">
        <?php if ($logoSociete): ?><img src="<?= h($logoSociete) ?>" alt="" style="max-height:64px; max-width:140px;"><?php endif; ?>
        <div>
            <strong><?= h($societe ?: 'GesCaisse') ?></strong><br>
            <?php foreach (societe_coordonnees($infosSociete) as $ligne): ?><span class="muted"><?= h($ligne) ?></span><br><?php endforeach; ?>
        </div>
    </div>
    <div style="text-align:right;">
        Édité le <?= date('d/m/Y à H:i') ?><br>
        par <?= h(user()['nomComplet'] ?? '') ?>
    </div>
</div>
