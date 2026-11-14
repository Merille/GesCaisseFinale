<?php
$titre = 'Profils et droits';
$plat = droits_catalogue_plat();
$total = count(droits_codes());
$noms = ['c' => 'Consulter', 'a' => 'Ajouter', 'm' => 'Modifier', 's' => 'Supprimer'];
// Résumé d'un droit sur la carte : « Tiers : C A M S » (lettres des opérations accordées).
$resume = function (array $droits, string $code) use ($plat): string {
    $lettres = '';
    foreach (array_keys($plat[$code][2]) as $op) {
        if (in_array($op === 'c' ? $code : "$code.$op", $droits, true)) {
            $lettres .= strtoupper($op === 'c' ? 'c' : $op);
        }
    }
    return count($plat[$code][2]) > 1 ? ' <span class="opacity-75">' . implode(' ', str_split($lettres)) . '</span>' : '';
};
?>
<div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-3">
    <div>
        <h4 class="mb-0">Profils et droits d'accès</h4>
        <div class="text-muted small">Créez des profils, cochez leurs droits, puis attribuez un profil à chaque utilisateur.</div>
    </div>
    <div class="d-flex gap-2">
        <div class="btn-group" role="group" aria-label="Affichage">
            <button type="button" class="btn btn-outline-primary" data-vue="cartes" title="Affichage en cartes"><i class="fa fa-grip"></i> Cartes</button>
            <button type="button" class="btn btn-outline-primary" data-vue="liste" title="Affichage en liste"><i class="fa fa-list"></i> Liste</button>
        </div>
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
        $droits = droits_lire((string) $p['Droits']);
        $modules = array_values(array_filter(array_keys($plat), fn($c) => in_array($c, $droits, true))); ?>
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
                        <?php foreach ($modules as $d): ?><span class="badge text-bg-light border me-1 mb-1"><?= h($plat[$d][0]) ?><?= $resume($droits, $d) ?></span><?php endforeach; ?>
                        <?php if (!$droits): ?><span class="text-danger small">Aucun droit : ses utilisateurs ne peuvent ouvrir aucune page.</span><?php endif; ?>
                    </div>
                    <?php if ($modules): ?><div class="small text-muted mb-2">C consulter · A ajouter · M modifier · S supprimer</div><?php endif; ?>
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

<div class="card shadow-sm border-0 d-none" id="vueListeProfils">
    <div class="card-body table-responsive">
        <table class="table table-hover align-middle mb-0" id="tableProfils">
            <thead class="table-dark"><tr><th>Profil</th><?php if (is_super_admin() && tenant_id() === 0): ?><th>Société</th><?php endif; ?><th>Description</th><th>Droits</th><th class="text-center">Utilisateurs</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
                <tr data-nom="Administrateur">
                    <td><i class="fa fa-user-shield text-primary"></i> <b>Administrateur</b></td>
                    <?php if (is_super_admin() && tenant_id() === 0): ?><td></td><?php endif; ?>
                    <td class="text-muted small">Profil fixe : toutes les pages</td>
                    <td><span class="badge bg-dark">Tous les droits</span></td>
                    <td class="text-center"><?= $admins ?></td>
                    <td></td>
                </tr>
                <?php foreach ($profils as $p):
                    $droits = droits_lire((string) $p['Droits']);
                    $modules = array_values(array_filter(array_keys($plat), fn($c) => in_array($c, $droits, true))); ?>
                    <tr data-nom="<?= h($p['Nom']) ?>">
                        <td><i class="fa fa-id-badge text-primary"></i> <b><?= h($p['Nom']) ?></b>
                            <span class="badge bg-info text-dark ms-1"><?= count($droits) ?> / <?= $total ?></span></td>
                        <?php if (is_super_admin() && tenant_id() === 0): ?><td><?= h($p['Societe']) ?></td><?php endif; ?>
                        <td class="text-muted small"><?= h($p['Description'] ?? '') ?></td>
                        <td>
                            <?php foreach ($modules as $d): ?><span class="badge text-bg-light border me-1 mb-1"><?= h($plat[$d][0]) ?><?= $resume($droits, $d) ?></span><?php endforeach; ?>
                            <?php if (!$modules): ?><span class="text-danger small">Aucun droit</span><?php endif; ?>
                        </td>
                        <td class="text-center"><?= (int) $p['Utilisateurs'] ?></td>
                        <td class="text-center table-actions text-nowrap">
                            <button class="btn btn-warning btn-sm" data-bs-toggle="modal" data-bs-target="#modalProfil"
                                    data-profil="<?= h(json_encode(['Id' => (int) $p['Id'], 'Nom' => $p['Nom'], 'Description' => $p['Description'] ?? '', 'Droits' => $droits])) ?>">Modifier</button>
                            <form method="post" action="<?= h(url('profil/delete')) ?>" class="d-inline" onsubmit="return confirm('Supprimer ce profil ?');">
                                <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $p['Id'] ?>">
                                <button class="btn btn-outline-danger btn-sm" <?= $p['Utilisateurs'] ? 'disabled title="Attribué à des utilisateurs"' : '' ?>>Supprimer</button>
                            </form>
                        </td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
        <div class="small text-muted mt-2">C consulter · A ajouter · M modifier · S supprimer</div>
    </div>
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
                    <div class="table-responsive">
                    <table class="table table-sm align-middle mb-2" id="grilleDroits">
                        <thead class="table-light"><tr><th>Droit</th><?php foreach ($noms as $op => $nom): ?><th class="text-center" style="width:92px"><?= $nom ?></th><?php endforeach; ?></tr></thead>
                        <tbody>
                        <?php foreach ($catalogue as $rubrique => $droits): ?>
                            <tr class="table-secondary"><th colspan="5" class="small text-uppercase"><?= h($rubrique) ?></th></tr>
                            <?php foreach ($droits as $code => [$libelle, $detail, $ops]): ?>
                                <tr data-droit="<?= h($code) ?>">
                                    <td><?= h($libelle) ?><span class="d-block small text-muted"><?= h($detail) ?></span></td>
                                    <?php foreach (array_keys($noms) as $op): $val = $op === 'c' ? $code : "$code.$op"; ?>
                                        <td class="text-center">
                                            <?php if (isset($ops[$op])): ?>
                                                <input class="form-check-input" type="checkbox" name="Droits[]" value="<?= h($val) ?>" id="droit_<?= h(str_replace('.', '_', $val)) ?>"
                                                       data-op="<?= $op ?>" title="<?= h($ops[$op]) ?>" aria-label="<?= h($libelle . ' : ' . $ops[$op]) ?>">
                                            <?php else: ?><span class="text-muted">–</span><?php endif; ?>
                                        </td>
                                    <?php endforeach; ?>
                                </tr>
                            <?php endforeach; ?>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                    </div>
                    <div class="form-text mb-1">Passez la souris sur une case pour voir ce qu'elle permet. Ajouter, modifier ou supprimer exigent de pouvoir consulter : la case Consulter se coche toute seule.</div>
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
    // Affichage en cartes ou en liste (choix gardé sur ce poste).
    function vueProfils(vue) {
        document.getElementById('listeProfils').classList.toggle('d-none', vue === 'liste');
        document.getElementById('vueListeProfils').classList.toggle('d-none', vue !== 'liste');
        document.querySelectorAll('[data-vue]').forEach(b => { const actif = b.dataset.vue === vue; b.classList.toggle('btn-primary', actif); b.classList.toggle('btn-outline-primary', !actif); b.setAttribute('aria-pressed', actif); });
        try { localStorage.setItem('gc-vue-profils', vue); } catch (e) { }
    }
    document.querySelectorAll('[data-vue]').forEach(b => b.addEventListener('click', () => vueProfils(b.dataset.vue)));
    let vueGardee = 'cartes';
    try { vueGardee = localStorage.getItem('gc-vue-profils') || 'cartes'; } catch (e) { }
    vueProfils(vueGardee);
    document.getElementById('modalProfil').addEventListener('shown.bs.modal', () => document.getElementById('profilNom').focus());
    document.querySelectorAll('[data-tout]').forEach(b => b.addEventListener('click', () => {
        document.querySelectorAll('#formProfil input[name="Droits[]"]').forEach(c => { c.checked = b.dataset.tout === '1'; });
    }));
    // Ajouter / modifier / supprimer cochés : « Consulter » coché ; « Consulter » décoché : le reste aussi.
    document.getElementById('grilleDroits').addEventListener('change', function (e) {
        const c = e.target, ligne = c.closest('tr[data-droit]');
        if (!ligne) return;
        const consulter = ligne.querySelector('[data-op="c"]');
        if (c.dataset.op !== 'c' && c.checked) consulter.checked = true;
        if (c.dataset.op === 'c' && !c.checked) ligne.querySelectorAll('input').forEach(x => { x.checked = false; });
    });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
