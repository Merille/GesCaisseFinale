<?php $titre = $titre ?? 'Erreur'; ?>
<div class="alert alert-danger"><?= h($message ?? 'Une erreur est survenue.') ?></div>
<a class="btn btn-outline-primary" href="<?= h(url('dashboard/index')) ?>">Retour au tableau de bord</a>
