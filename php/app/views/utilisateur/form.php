<?php
// Formulaire d'un utilisateur : page (sans JavaScript), modale de création, ou modale de
// modification ($modification = true) remplie en JavaScript depuis la liste des utilisateurs.
$modification = !empty($modification);
$edition = !empty($edition) || $modification;
$titre = $edition ? "Modifier l'utilisateur" : 'Nouvel utilisateur';
$entete = $titre;
$attrsForm = 'autocomplete="off"';
$action = !empty($modale) ? ($modification ? url('utilisateur/index') : url('utilisateur/create')) : null;
$retour = url('utilisateur/index');
// Identifiants des champs : distincts entre la modale de création et celle de modification.
$sfx = $modification ? 'E' : '';
if ($modification) {
    $idModale = 'modalModification';
}
require __DIR__ . '/../partials/form_debut.php';
?>
            <div class="row g-3">
                <div class="col-md-6">
                    <label class="form-label" for="NomUtilisateur<?= $sfx ?>">Nom d'utilisateur (connexion)</label>
                    <input class="form-control" id="NomUtilisateur<?= $sfx ?>" name="NomUtilisateur" value="<?= h($u['NomUtilisateur'] ?? '') ?>" required>
                </div>
                <div class="col-md-6">
                    <label class="form-label" for="NomComplet<?= $sfx ?>">Nom complet</label>
                    <input class="form-control" id="NomComplet<?= $sfx ?>" name="NomComplet" value="<?= h($u['NomComplet'] ?? '') ?>" required>
                </div>
                <div class="col-md-6">
                    <label class="form-label" for="MotPasse<?= $sfx ?>">Mot de passe</label>
                    <input class="form-control" type="password" id="MotPasse<?= $sfx ?>" name="MotPasse" autocomplete="new-password" <?= $edition ? '' : 'required' ?>>
                    <?php if ($edition): ?><div class="form-text">Laisser vide pour ne pas le changer.</div><?php endif; ?>
                </div>
                <div class="col-md-6">
                    <label class="form-label" for="Profil<?= $sfx ?>">Profil</label>
                    <?php $valeurProfil = utilisateur_valeur_profil($u); ?>
                    <select class="form-select" id="Profil<?= $sfx ?>" name="Profil" required>
                        <option value="">-- Choisir --</option>
                        <?php foreach ($profils as [$valeur, $libelle, $societe]): ?>
                            <option value="<?= h($valeur) ?>"<?= $societe ? ' data-societe="' . $societe . '"' : '' ?> <?= $valeurProfil === $valeur ? 'selected' : '' ?>><?= h($libelle) ?></option>
                        <?php endforeach; ?>
                    </select>
                    <div class="form-text">Les droits de chaque profil se règlent dans <a href="<?= h(url('profil/index')) ?>">Paramètres › Profils et droits</a>.</div>
                </div>
                <?php if (is_super_admin()): ?>
                    <div class="col-md-6">
                        <label class="form-label" for="TenantId<?= $sfx ?>">Société</label>
                        <select class="form-select" id="TenantId<?= $sfx ?>" name="TenantId">
                            <option value="">-- Aucune (SuperAdmin) --</option>
                            <?php foreach ($societes as $s): ?>
                                <option value="<?= (int) $s['Id'] ?>" <?= (int) ($u['TenantId'] ?? 0) === (int) $s['Id'] ? 'selected' : '' ?>><?= h($s['Nom']) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                <?php endif; ?>
                <div class="col-12">
                    <div class="form-check">
                        <input class="form-check-input" type="checkbox" value="1" id="PeutValiderOperations<?= $sfx ?>" name="PeutValiderOperations" <?= !empty($u['PeutValiderOperations']) ? 'checked' : '' ?>>
                        <label class="form-check-label" for="PeutValiderOperations<?= $sfx ?>">Peut valider / rejeter les opérations de caisse</label>
                    </div>
                </div>
                <?php // Remises au point de vente (sur un article et globale) ; les administrateurs les font toujours, sans limite. ?>
                <div class="col-md-6">
                    <div class="form-check">
                        <input class="form-check-input" type="checkbox" value="1" id="PeutRemise<?= $sfx ?>" name="PeutRemise" <?= !empty($u['PeutRemise']) ? 'checked' : '' ?>
                               onchange="this.form.elements.RemiseMax.disabled = !this.checked">
                        <label class="form-check-label" for="PeutRemise<?= $sfx ?>">Peut accorder des remises au point de vente</label>
                    </div>
                    <div class="form-text">Remise sur un article et remise globale du ticket. Les administrateurs ont toujours ce droit.</div>
                </div>
                <div class="col-md-6">
                    <label class="form-label" for="RemiseMax<?= $sfx ?>">Remise maximale (%)</label>
                    <input class="form-control" id="RemiseMax<?= $sfx ?>" name="RemiseMax" inputmode="decimal" placeholder="Sans limite"
                           value="<?= isset($u['RemiseMax']) && $u['RemiseMax'] !== null ? h(quantite_fr((float) $u['RemiseMax'])) : '' ?>"<?= empty($u['PeutRemise']) ? ' disabled' : '' ?>>
                    <div class="form-text">Laissez vide pour ne pas limiter.</div>
                </div>
            </div>
<?php require __DIR__ . '/../partials/form_fin.php'; ?>
