<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>Écran cuisine / bar - GesCaisse</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="<?= asset('assets/vendor/fontawesome/css/all.min.css') ?>">
    <link rel="stylesheet" href="<?= asset('assets/css/cuisine.css') ?>">
</head>
<body class="cui-body">
<div class="cui-choix">
    <h2><i class="fas fa-fire-burner"></i> Écran cuisine / bar</h2>
    <?php if (!$caisses): ?>
        <p>Aucune caisse de type Restaurant ou Bar. Changez le type d'une caisse dans <a href="<?= h(url('caisse/index')) ?>" style="display:inline;padding:0;border:0">Caisses</a>.</p>
    <?php else: ?>
        <p>Choisissez la caisse dont vous préparez les commandes :</p>
        <?php foreach ($caisses as $c): ?>
            <a href="<?= h(url('cuisine/index', ['caisse' => $c['ID']])) ?>"><i class="fas <?= $c['TypePointVente'] === 'Bar' ? 'fa-martini-glass' : 'fa-utensils' ?>"></i>
                <?= h($c['ChkCode']) ?> · <?= h($c['ChkDescription']) ?></a>
        <?php endforeach; ?>
    <?php endif; ?>
    <a href="<?= h(url('accueil')) ?>"><i class="fas fa-arrow-left"></i> Retour</a>
</div>
</body>
</html>
