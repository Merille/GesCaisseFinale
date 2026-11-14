<?php
$titre = 'Profils et droits';
$plat = droits_catalogue_plat();
$total = count($plat);
?>
<div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-3">
    <div>
        <h4 class="mb-0">Profils et droits d'accès</h4>
        <div class="text-muted small">Créez des profils, cochez leurs droits, puis attribuez un profil à chaque utilisateur.</div>
    </div>
    <div class="d-flex gap-2">
        <a href="<?= h(url('utilisateur/index')) ?>" class="btn btn-outline-primary"><i class="fa fa-users"></i> Utilisateurs</a>
        <?php if (tenant_id() > 0): ?>
            <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalProfil" data-profil=""><i class="fa fa-plus"></i> Nouveau profil</button>
        <?php endif; ?>
    </div>
</div>
<?php if (tenant_id() === 0): ?>
    <div class="alert alert-info">Pour créer un profil, consultez d'abord la société concernée (Sociétés › Consulter).</div>
<?php endif; ?>

<div class="row g-3" id="listeProfils">
    <div class="col-md-6 col-xl-4">
        <div class="card h-100 border-0 shadow-sm">
            <div class="card-body">
                <div class="d-flex justify-content-between align-items-start">
                    <h5 class="card-title mb-1"><i class="fa fa-user-shield text-primary"></i> Administrateur</h5>
                    <span class="badge bg-dark">Tous les droits</span>
                </div>
                <div class="text-muted small mb-2">Profil fixe : toutes les pages, y compris les utilisateurs, les profils et « Ma société ».</div>
                <div class="small"><b><?= $admins ?></b> utilisateur<?= $admins > 1 ? 's' : '' ?></div>
            </div>
        </div>
    </div>
    <?php foreach ($profils as $p):
        $droits = array_values(array_intersect(array_keys($plat), array_filter(explode(',', (string) $p['Droits'])))); ?>
        <div class="col-md-6 col-xl-4">
            <div class="card h-100 border-0 shadow-sm carte-profil" data-nom="<?= h($p['Nom']) ?>">
                <div class="card-body d-flex flex-column">
                    <div class="d-flex justify-content-between align-items-start">
                        <h5 class="card-title mb-1"><i class="fa fa-id-badge text-primary"></i> <?= h($p['Nom']) ?></h5>
                        <span class="badge bg-info text-dark"><?= count($droits) ?> / <?= $total ?> droits</span>
                    </div>
                    <?php if (is_super_admin() && tenant_id() === 0): ?><div class="small text-muted"><?= h($p['Societe']) ?></div><?php endif; ?>
                    <?php if ($p['Description']): ?><div class="text-muted small mb-2"><?= h($p['Description']) ?></div><?php endif; ?>
                    <div class="mb-2">
                        <?php foreach ($droits as $d): ?><span class="badge text-bg-light border me-1 mb-1"><?= h($plat[$d][0]) ?></span><?php endforeach; ?>
                        <?php if (!$droits): ?><span class="text-danger small">Aucun droit : ses utilisateurs ne peuvent ouvrir aucune page.</span><?php endif; ?>
                    </div>
                    <div class="small mt-auto mb-2"><b><?= (int) $p['Utilisateurs'] ?></b> utilisateur<?= $p['Utilisateurs'] > 1 ? 's' : '' ?></div>
                    <div class="d-flex gap-2">
                        <button class="btn btn-warning btn-sm" data-bs-toggle="modal" data-bs-target="#modalProfil"
                                data-profil="<?= h(json_encode(['Id' => (int) $p['Id'], 'Nom' => $p['Nom'], 'Description' => $p['Description'] ?? '', 'Droits' => $droits])) ?>">Modifier</button>
                        <form method="post" action="<?= h(url('profil/delete')) ?>" onsubmit="return confirm('Supprimer ce profil ?');">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $p['Id'] ?>">
                            <button class="btn btn-outline-danger btn-sm" <?= $p['Utilisateurs'] ? 'disabled title="Attribué à des utilisateurs"' : '' ?>>Supprimer</button>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    <?php endforeach; ?>
</div>

<div class="modal fade" id="modalProfil" tabindex="-1">
    <div class="modal-dialog modal-lg modal-dialog-scrollable">
        <div class="modal-content">
            <div class="modal-header bg-brand text-white">
                <h5 class="modal-title" id="profilTitre">Profil</h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>
            </div>
            <form method="post" action="<?= h(url('profil/save')) ?>" id="formProfil">
                <?= csrf_field() ?>
                <input type="hidden" name="Id" id="profilId">
                <div class="modal-body">
                    <div class="row g-3 mb-2">
                        <div class="col-md-5"><label class="form-label" for="profilNom">Nom du profil</label>
                            <input id="profilNom" name="Nom" class="form-control" maxlength="50" placeholder="Ex : Serveur" required></div>
                        <div class="col-md-7"><label class="form-label" for="profilDescription">Description</label>
                            <input id="profilDescription" name="Description" class="form-control" maxlength="200" placeholder="Facultatif"></div>
                    </div>
                    <div class="d-flex justify-content-between align-items-center mt-3 mb-2">
                        <h6 class="mb-0">Droits d'accès</h6>
                        <div class="btn-group btn-group-sm">
                            <button type="button" class="btn btn-outline-secondary" data-tout="1">Tout cocher</button>
                            <button type="button" class="btn btn-outline-secondary" data-tout="0">Tout décocher</button>
                        </div>
                    </div>
                    <?php foreach ($catalogue as $rubrique => $droits): ?>
                        <fieldset class="border rounded p-2 px-3 mb-2 rubrique-droits">
                            <legend class="float-none w-auto px-1 fs-6 fw-semibold mb-0"><?= h($rubrique) ?></legend>
                            <div class="row">
                                <?php foreach ($droits as $code => [$libelle, $detail]): ?>
                                    <div class="col-md-6">
                                        <div class="form-check my-1">
                                            <input class="form-check-input" type="checkbox" name="Droits[]" value="<?= h($code) ?>" id="droit_<?= h($code) ?>">
                                            <label class="form-check-label" for="droit_<?= h($code) ?>"><?= h($libelle) ?>
                                                <span class="d-block small text-muted"><?= h($detail) ?></span></label>
                                        </div>
                                    </div>
                                <?php endforeach; ?>
                            </div>
                        </fieldset>
                    <?php endforeach; ?>
                    <div class="form-text">Les utilisateurs, les profils et « Ma société » restent réservés aux administrateurs. Le droit de valider les opérations et le droit de remise se règlent sur la fiche de chaque utilisateur.</div>
                </div>
                <div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Annuler</button><button class="btn btn-primary">Enregistrer</button></div>
            </form>
        </div>
    </div>
</div>
<?php ob_start(); ?>
<script>
    document.getElementById('modalProfil').addEventListener('show.bs.modal', function (e) {
        const brut = e.relatedTarget && e.relatedTarget.dataset.profil;
        const p = brut ? JSON.parse(brut) : { Id: '', Nom: '', Description: '', Droits: [] };
        document.getElementById('profilTitre').textContent = p.Id ? 'Modifier le profil' : 'Nouveau profil';
        document.getElementById('profilId').value = p.Id;
        document.getElementById('profilNom').value = p.Nom;
        document.getElementById('profilDescription').value = p.Description || '';
        document.querySelectorAll('#formProfil input[name="Droits[]"]').forEach(c => { c.checked = p.Droits.includes(c.value); });
    });
    document.getElementById('modalProfil').addEventListener('shown.bs.modal', () => document.getElementById('profilNom').focus());
    document.querySelectorAll('[data-tout]').forEach(b => b.addEventListener('click', () => {
        document.querySelectorAll('#formProfil input[name="Droits[]"]').forEach(c => { c.checked = b.dataset.tout === '1'; });
    }));
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
