<?php
$titre = $edition ? 'Modifier la société' : 'Nouvelle société';
$entete = $titre;
$largeur = '720px';
$action = !empty($modale) ? url('tenant/create') : null;
$retour = url('tenant/index');
$attrsForm = 'enctype="multipart/form-data"';
$v = fn(string $k) => h($t[$k] ?? '');
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
            <h6 class="text-muted text-uppercase small mt-4 mb-3">Coordonnées (en-tête des tickets, factures et impressions)</h6>
            <div class="row g-3">
                <div class="col-12"><label class="form-label" for="Adresse">Adresse</label><input class="form-control" id="Adresse" name="Adresse" value="<?= $v('Adresse') ?>" placeholder="Ex : Boulevard Triomphal, BP 1234" maxlength="250"></div>
                <div class="col-md-6"><label class="form-label" for="Ville">Ville</label><input class="form-control" id="Ville" name="Ville" value="<?= $v('Ville') ?>" placeholder="Ex : Libreville" maxlength="100"></div>
                <div class="col-md-6"><label class="form-label" for="Pays">Pays</label><input class="form-control" id="Pays" name="Pays" value="<?= $v('Pays') ?>" placeholder="Ex : Gabon" maxlength="100"></div>
                <div class="col-md-6"><label class="form-label" for="Email">E-mail</label><input class="form-control" type="email" id="Email" name="Email" value="<?= $v('Email') ?>" placeholder="contact@societe.ga" maxlength="150"></div>
                <div class="col-md-6"><label class="form-label" for="Telephone">Téléphone</label><input class="form-control" type="tel" id="Telephone" name="Telephone" value="<?= $v('Telephone') ?>" placeholder="+241 01 23 45 67" maxlength="50"></div>
                <div class="col-md-6"><label class="form-label" for="NIF">NIF</label><input class="form-control" id="NIF" name="NIF" value="<?= $v('NIF') ?>" placeholder="Numéro d'identification fiscale" maxlength="50"></div>
                <div class="col-md-6">
                    <label class="form-label" for="Logo<?= !empty($modale) ? 'M' : '' ?>">Logo</label>
                    <div class="d-flex align-items-center gap-3">
                        <?php if ($logo = url_logo($t)): ?><img src="<?= h($logo) ?>" alt="Logo actuel" class="vignette-image"><?php endif; ?>
                        <input class="form-control" type="file" id="Logo<?= !empty($modale) ? 'M' : '' ?>" name="Logo" accept="image/png,image/jpeg,image/webp,image/gif">
                    </div>
                    <div class="form-text">JPG, PNG, WEBP ou GIF, 1 Mo au plus.</div>
                    <?php if ($logo): ?>
                        <div class="form-check mt-1"><input class="form-check-input" type="checkbox" value="1" id="SupprimerLogo" name="SupprimerLogo"><label class="form-check-label" for="SupprimerLogo">Retirer le logo</label></div>
                    <?php endif; ?>
                </div>
            </div>
<?php require __DIR__ . '/../partials/form_fin.php'; ?>
