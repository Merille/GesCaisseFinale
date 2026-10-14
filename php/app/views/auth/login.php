<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>Connexion - GesCaisse</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            margin: 0;
            font-family: 'Segoe UI', Arial, sans-serif;
            min-height: 100vh;
            background: #0b2f44 url('<?= asset('assets/img/login-caisse.svg') ?>') center / cover no-repeat;
        }
        body::before {
            content: '';
            position: fixed;
            inset: 0;
            background: rgba(11, 47, 68, .25);
        }
        .container {
            position: relative;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 16px;
            box-sizing: border-box;
        }
        .login-box {
            width: 100%;
            max-width: 380px;
            background: rgba(25, 93, 132, .92); /* bleu du logo M-ITECH AFRICA */
            padding: 40px;
            border-radius: 12px;
            border: 1px solid rgba(255, 255, 255, .25);
            box-shadow: 0 12px 40px rgba(0, 0, 0, .45);
            backdrop-filter: blur(4px);
            box-sizing: border-box;
        }
        h1 { text-align: center; margin: 0 0 25px; color: #fff; font-size: 28px; letter-spacing: 1px; }
        .form-group { margin-bottom: 18px; }
        label { display: block; margin-bottom: 6px; color: #fff; font-size: 14px; }
        input {
            width: 100%;
            padding: 11px;
            border: 1px solid #ddd;
            border-radius: 6px;
            box-sizing: border-box;
            font-size: 14px;
        }
        input:focus { outline: none; border-color: #999997; box-shadow: 0 0 0 3px rgba(153, 153, 151, .35); }
        button {
            width: 100%;
            padding: 12px;
            border: none;
            background: #0b2f44;
            color: #fff;
            border-radius: 6px;
            cursor: pointer;
            font-size: 15px;
            margin-top: 5px;
        }
        button:hover { background: #12445f; }
        .error-msg {
            background: #fff3f3;
            color: #b02a37;
            border: 1px solid #f5c6cb;
            border-radius: 6px;
            padding: 10px;
            margin-bottom: 15px;
            font-size: 14px;
        }
    </style>
</head>
<body>
<div class="container">
    <div class="login-box">
        <h1>GESCAISSE</h1>
        <form method="post" action="<?= h(url('auth/login')) ?>">
            <?= csrf_field() ?>
            <?php if (!empty($erreur)): ?>
                <div class="error-msg"><?= h($erreur) ?></div>
            <?php endif; ?>
            <div class="form-group">
                <label for="username">Utilisateur</label>
                <input id="username" name="username" autocomplete="username" required autofocus
                       value="<?= h($_POST['username'] ?? '') ?>">
            </div>
            <div class="form-group">
                <label for="password">Mot de passe</label>
                <input id="password" name="password" type="password" autocomplete="current-password" required>
            </div>
            <button type="submit">Se connecter</button>
        </form>
    </div>
</div>
</body>
</html>
