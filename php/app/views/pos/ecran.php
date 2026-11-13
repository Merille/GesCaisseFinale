<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>Point de vente - GesCaisse</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css" rel="stylesheet">
    <link rel="stylesheet" href="<?= asset('assets/css/pos.css') ?>">
    <link rel="manifest" href="manifest.json">
    <meta name="theme-color" content="#1b5e84">
    <link rel="apple-touch-icon" href="assets/icones/icone-192.png">
</head>
<body class="pos-body">
<div id="pos" class="pos"></div>
<script id="pos-donnees" type="application/json"><?= json_encode($donnees, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_UNESCAPED_UNICODE) ?></script>
<script src="<?= asset('assets/js/hors-ligne.js') ?>" data-sw="sw.js" data-rapport="<?= h(url('synchro/rapport')) ?>" data-jeton="<?= h(url('pos/jeton')) ?>"></script>
<script src="<?= asset('assets/js/pos.js') ?>"></script>
</body>
</html>
