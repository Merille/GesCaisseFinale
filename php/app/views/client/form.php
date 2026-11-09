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
            <h6 class="text-muted text-uppercase small mb-3">Identité</h6>
            <div class="row g-3 mb-4">
                <div class="col-12">
                    <span class="form-label d-block">Genre</span>
                    <?php foreach (['Entreprise' => 'Entreprise (société, association…)', 'Particulier' => 'Particulier (personne physique)'] as $g => $libelleGenre): ?>
                        <div class="form-check form-check-inline">
                            <input class="form-check-input" type="radio" name="Genre" id="Genre<?= $g . $sfx ?>" value="<?= $g ?>" <?= ($client['Genre'] ?? 'Entreprise') === $g ? 'checked' : '' ?>>
                            <label class="form-check-label" for="Genre<?= $g . $sfx ?>"><?= $libelleGenre ?></label>
                        </div>
                    <?php endforeach; ?>
                </div>
                <div class="col-md-3"><?= $champ('CodeClient', 'Code', 'required') ?></div>
                <div class="col-md-5"><?= $champ('NomSociete', 'Nom (société ou particulier)', 'required') ?></div>
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
            <?php $plafond = $client['PlafondCredit'] ?? null; ?>
            <h6 class="text-muted text-uppercase small mb-3 mt-4">Compte client</h6>
            <div class="row g-3 align-items-end">
                <div class="col-md-6">
                    <div class="form-check">
                        <input class="form-check-input" type="checkbox" value="1" name="EnCompte" id="EnCompte<?= $sfx ?>" <?= !empty($client['EnCompte']) ? 'checked' : '' ?>>
                        <label class="form-check-label" for="EnCompte<?= $sfx ?>">Client en compte
                            <span class="d-block small text-muted">Peut payer « par compte » au point de vente (vente à crédit) et régler plus tard.</span></label>
                    </div>
                </div>
                <div class="col-md-3">
                    <label class="form-label" for="PlafondCredit<?= $sfx ?>">Plafond de crédit (FCFA)</label>
                    <input class="form-control" id="PlafondCredit<?= $sfx ?>" name="PlafondCredit" inputmode="decimal" placeholder="Sans plafond"
                           value="<?= $plafond === null || $plafond === '' ? '' : h((string) round((float) $plafond)) ?>">
                </div>
                <div class="col-md-3 small text-muted">Au-delà du plafond, la vente par compte est refusée (sauf pour un administrateur).</div>
            </div>
<?php require __DIR__ . '/../partials/form_fin.php'; ?>
