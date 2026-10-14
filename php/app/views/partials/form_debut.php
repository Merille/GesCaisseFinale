<?php
// Ouverture d'un formulaire de saisie, affiché en carte (page) ou en fenêtre modale.
// Variables : $modale (bool), $entete, $action (adresse d'envoi, obligatoire en modale),
// $largeur (carte), $tailleModale, $attrsForm, $idModale.
$modale = !empty($modale);
$idModale = $idModale ?? 'modalCreation';
?>
<?php if ($modale): ?>
<div class="modal fade" id="<?= h($idModale) ?>" tabindex="-1" aria-labelledby="<?= h($idModale) ?>Titre" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-dialog-scrollable <?= h($tailleModale ?? 'modal-lg') ?>">
        <form class="modal-content" method="post" action="<?= h($action) ?>" <?= $attrsForm ?? '' ?>>
            <div class="modal-header bg-brand text-white">
                <h5 class="modal-title" id="<?= h($idModale) ?>Titre"><?= h($entete) ?></h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>
            </div>
            <div class="modal-body">
<?php else: ?>
<div class="card shadow-sm border-0" style="max-width: <?= h($largeur ?? '760px') ?>;">
    <div class="card-header bg-brand text-white"><h5 class="mb-0"><?= h($entete) ?></h5></div>
    <div class="card-body">
        <form method="post" <?= isset($action) ? 'action="' . h($action) . '"' : '' ?> <?= $attrsForm ?? '' ?>>
<?php endif; ?>
            <?= csrf_field() ?>
