<?php
$titre = 'Ma société';
$v = fn(string $k) => h($t[$k] ?? '');
$logo = url_logo($t);
$expiration = $t['DateExpiration'] ? date('d/m/Y', strtotime($t['DateExpiration'])) : 'Sans limite';
?>
<div class="row g-4" style="max-width: 1100px;">
    <div class="col-lg-8">
        <div class="card shadow-sm border-0">
            <div class="card-header bg-brand text-white"><h5 class="mb-0">Coordonnées de la société</h5></div>
            <div class="card-body">
                <p class="small text-muted">Elles figurent en en-tête des tickets, des factures et des impressions.</p>
                <form method="post" enctype="multipart/form-data">
                    <?= csrf_field() ?>
                    <div class="row g-3">
                        <div class="col-12"><label class="form-label" for="Adresse">Adresse</label><input class="form-control" id="Adresse" name="Adresse" value="<?= $v('Adresse') ?>" placeholder="Ex : Boulevard Triomphal, BP 1234" maxlength="250"></div>
                        <div class="col-md-6"><label class="form-label" for="Ville">Ville</label><input class="form-control" id="Ville" name="Ville" value="<?= $v('Ville') ?>" placeholder="Ex : Libreville" maxlength="100"></div>
                        <div class="col-md-6"><label class="form-label" for="Pays">Pays</label><input class="form-control" id="Pays" name="Pays" value="<?= $v('Pays') ?>" placeholder="Ex : Gabon" maxlength="100"></div>
                        <div class="col-md-6"><label class="form-label" for="Email">E-mail</label><input class="form-control" type="email" id="Email" name="Email" value="<?= $v('Email') ?>" placeholder="contact@societe.ga" maxlength="150"></div>
                        <div class="col-md-6"><label class="form-label" for="Telephone">Téléphone</label><input class="form-control" type="tel" id="Telephone" name="Telephone" value="<?= $v('Telephone') ?>" placeholder="+241 01 23 45 67" maxlength="50"></div>
                        <div class="col-md-6"><label class="form-label" for="NIF">NIF</label><input class="form-control" id="NIF" name="NIF" value="<?= $v('NIF') ?>" placeholder="Numéro d'identification fiscale" maxlength="50"></div>
                        <div class="col-md-6">
                            <label class="form-label" for="Logo">Logo</label>
                            <div class="d-flex align-items-center gap-3">
                                <?php if ($logo): ?><img src="<?= h($logo) ?>" alt="Logo actuel" class="vignette-image"><?php endif; ?>
                                <input class="form-control" type="file" id="Logo" name="Logo" accept="image/png,image/jpeg,image/webp,image/gif">
                            </div>
                            <div class="form-text">JPG, PNG, WEBP ou GIF, 1 Mo au plus.</div>
                            <?php if ($logo): ?>
                                <div class="form-check mt-1"><input class="form-check-input" type="checkbox" value="1" id="SupprimerLogo" name="SupprimerLogo"><label class="form-check-label" for="SupprimerLogo">Retirer le logo</label></div>
                            <?php endif; ?>
                        </div>
                    </div>
                    <div class="mt-4"><button class="btn btn-primary"><i class="fas fa-floppy-disk"></i> Enregistrer</button></div>
                </form>
            </div>
        </div>
    </div>
    <div class="col-lg-4">
        <div class="card shadow-sm border-0">
            <div class="card-header bg-brand text-white"><h5 class="mb-0">Compte</h5></div>
            <div class="card-body">
                <dl class="mb-0">
                    <dt class="small text-muted">Nom</dt><dd class="fw-semibold"><?= h($t['Nom']) ?></dd>
                    <dt class="small text-muted">Code</dt><dd><?= h($t['Code']) ?></dd>
                    <dt class="small text-muted">Mode d'accès</dt><dd><?= h($t['ModeAcces']) ?></dd>
                    <dt class="small text-muted">Expiration</dt><dd><?= h($expiration) ?></dd>
                    <dt class="small text-muted">Point de vente</dt><dd><?= !empty($t['ModulePointVente']) ? '<span class="badge text-bg-success">Activé</span>' : '<span class="badge text-bg-secondary">Non activé</span>' ?></dd>
                </dl>
                <div class="form-text mt-3">Pour changer ces informations, contactez votre fournisseur (super-administrateur).</div>
            </div>
        </div>
    </div>
</div>
