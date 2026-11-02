<?php
// Formulaire d'un tiers : page (modification sans JavaScript), modale de création, ou modale
// de modification ($modification = true) remplie en JavaScript depuis la liste des tiers.
$modification = !empty($modification);
$edition = $edition || $modification;
$titre = $edition ? 'Modifier le tiers' : 'Nouveau tiers';
$v = fn(string $k) => h($client[$k] ?? '');
// Identifiants des champs : distincts entre la modale de création et celle de modification.
$sfx = $modification ? 'E' : '';
$champ = function (string $nom, string $libelle, string $attrs = '') use ($v, $sfx) {
    return '<label class="form-label" for="' . $nom . $sfx . '">' . $libelle . '</label><input class="form-control" id="' . $nom . $sfx . '" name="' . $nom . '" value="' . $v($nom) . '" ' . $attrs . '>';
};
if ($modification) {
    $idModale = 'modalModification';
}
$entete = $titre;
$tailleModale = 'modal-xl';
$action = !empty($modale) ? ($modification ? url('client/index') : url('client/create')) : null;
$retour = url('client/index');
require __DIR__ . '/../partials/form_debut.php';
?>
            <h6 class="text-muted text-uppercase small mb-3">Société</h6>
            <div class="row g-3 mb-4">
                <div class="col-md-3"><?= $champ('CodeClient', 'Code', 'required') ?></div>
                <div class="col-md-5"><?= $champ('NomSociete', 'Nom de la société', 'required') ?></div>
                <div class="col-md-4">
                    <label class="form-label" for="Type<?= $sfx ?>">Type</label>
                    <select class="form-select" id="Type<?= $sfx ?>" name="Type">
                        <option value="">--</option>
                        <?php foreach (['Client', 'Fournisseur', 'Salarié', 'Autre'] as $t): ?>
                            <option <?= ($client['Type'] ?? '') === $t ? 'selected' : '' ?>><?= $t ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="col-md-6"><?= $champ('Adresse', 'Adresse') ?></div>
                <div class="col-md-3"><?= $champ('Telephone', 'Téléphone') ?></div>
                <div class="col-md-3"><?= $champ('Email', 'Email', 'type="email"') ?></div>
                <div class="col-md-3"><?= $champ('CompteGeneral', 'Compte général (Sage)', 'placeholder="Ex : 411000"') ?></div>
            </div>
            <h6 class="text-muted text-uppercase small mb-3">Contact</h6>
            <div class="row g-3">
                <div class="col-md-3"><?= $champ('NomContact', 'Nom') ?></div>
                <div class="col-md-3"><?= $champ('FonctionContact', 'Fonction') ?></div>
                <div class="col-md-3"><?= $champ('TelephoneContact', 'Téléphone') ?></div>
                <div class="col-md-3"><?= $champ('EmailContact', 'Email', 'type="email"') ?></div>
            </div>
<?php require __DIR__ . '/../partials/form_fin.php'; ?>
