<?php
$titre = $edition ? 'Modifier la société' : 'Nouvelle société';
$entete = $titre;
$largeur = '720px';
$action = !empty($modale) ? url('tenant/create') : null;
$retour = url('tenant/index');
require __DIR__ . '/../partials/form_debut.php';
?>
            <div class="row g-3">
                <div class="col-md-8"><label class="form-label" for="Nom">Nom</label><input class="form-control" id="Nom" name="Nom" value="<?= h($t['Nom'] ?? '') ?>" required></div>
                <div class="col-md-4"><label class="form-label" for="Code">Code</label><input class="form-control" id="Code" name="Code" value="<?= h($t['Code'] ?? '') ?>" required></div>
                <div class="col-md-4">
                    <label class="form-label" for="ModeAcces">Mode d'accès</label>
                    <select class="form-select" id="ModeAcces" name="ModeAcces">
                        <?php foreach (['Licence', 'Abonnement'] as $m): ?><option <?= ($t['ModeAcces'] ?? '') === $m ? 'selected' : '' ?>><?= $m ?></option><?php endforeach; ?>
                    </select>
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="DateExpiration">Date d'expiration</label>
                    <input class="form-control" type="date" id="DateExpiration" name="DateExpiration" value="<?= h($t['DateExpiration'] ?? '') ?>">
                    <div class="form-text">Vide = sans limite.</div>
                </div>
                <div class="col-md-4 d-flex align-items-center">
                    <div class="form-check mt-3">
                        <input class="form-check-input" type="checkbox" value="1" id="Actif" name="Actif" <?= !empty($t['Actif']) ? 'checked' : '' ?>>
                        <label class="form-check-label" for="Actif">Société active</label>
                    </div>
                </div>
            </div>
<?php require __DIR__ . '/../partials/form_fin.php'; ?>
