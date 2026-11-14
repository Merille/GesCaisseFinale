<?php $titre = 'Accès refusé'; ?>
<div class="alert alert-warning">
    <strong>Accès refusé.</strong>
    <?php if (isset($reserveA)): ?>Cette page est réservée <?= h($reserveA) ?>.<?php else: ?>Votre profil ne donne pas accès à cette page.<?php endif; ?>
    Si vous pensez devoir y accéder, contactez votre administrateur.
</div>
<a class="btn btn-outline-primary" href="<?= h(url('accueil')) ?>">Retour à l'accueil</a>
