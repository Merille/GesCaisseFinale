<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>Société suspendue - GesCaisse</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { margin: 0; font-family: 'Segoe UI', Arial, sans-serif; background: #f5f7fb; }
        .container { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 16px; }
        .box { max-width: 480px; background: #fff; border-radius: 12px; padding: 36px; text-align: center;
               box-shadow: 0 8px 30px rgba(0, 0, 0, .08); border-top: 6px solid #195d84; }
        h1 { color: #0f1b33; font-size: 24px; }
        p { color: #333; font-size: 15px; line-height: 1.5; }
        a { display: inline-block; margin-top: 20px; padding: 10px 20px; background: #195d84; color: #fff;
            border-radius: 6px; text-decoration: none; }
    </style>
</head>
<body>
<div class="container">
    <div class="box">
        <h1>Accès suspendu</h1>
        <p>L'accès de votre société à GesCaisse est actuellement suspendu
           (société désactivée, ou licence / abonnement expiré).</p>
        <p>Contactez votre administrateur pour le renouvellement.</p>
        <a href="<?= h(url('auth/logout')) ?>">Retour à la connexion</a>
    </div>
</div>
</body>
</html>
