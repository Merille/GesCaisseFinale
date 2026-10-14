<?php $titre = $titre ?? 'Erreur'; ?>
<div class="alert alert-danger"><?= nl2br(h($message ?? 'Une erreur est survenue.')) ?></div>
<a class="btn btn-outline-primary" href="<?= h(url('dashboard/index')) ?>">Retour au tableau de bord</a>
