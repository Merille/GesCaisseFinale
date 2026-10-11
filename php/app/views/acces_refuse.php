<?php $titre = 'Accès refusé'; ?>
<div class="alert alert-warning">
    <strong>Accès refusé.</strong>
    Cette page est réservée <?= h($reserveA ?? 'aux administrateurs (profils Admin et SuperAdmin)') ?>.
    Si vous pensez devoir y accéder, contactez votre administrateur.
</div>
<a class="btn btn-outline-primary" href="<?= h(url('dashboard/index')) ?>">Retour au tableau de bord</a>
