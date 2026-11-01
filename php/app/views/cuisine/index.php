<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>Écran cuisine / bar - GesCaisse</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css" rel="stylesheet">
    <link rel="stylesheet" href="<?= asset('assets/css/cuisine.css') ?>">
</head>
<body class="cui-body">
<div id="cuisine" class="cui"></div>
<script id="cuisine-donnees" type="application/json"><?= json_encode($donnees, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_UNESCAPED_UNICODE) ?></script>
<script src="<?= asset('assets/js/cuisine.js') ?>"></script>
</body>
</html>
