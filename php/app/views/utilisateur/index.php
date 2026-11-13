<?php $titre = 'Utilisateurs'; ?>
<div class="d-flex justify-content-between align-items-center mb-3">
    <h4 class="mb-0">Utilisateurs</h4>
    <a href="<?= h(url('utilisateur/create')) ?>" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalCreation"><i class="fa fa-plus"></i> Nouvel utilisateur</a>
</div>
<div class="card shadow-sm border-0">
    <div class="card-body table-responsive">
        <table id="UsersTable" class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Nom utilisateur</th><th>Nom complet</th><th>Profil</th><?php if (is_super_admin()): ?><th>Société</th><?php endif; ?><th>Droits</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php foreach ($users as $u): ?>
                <tr>
                    <td><?= h($u['NomUtilisateur']) ?></td>
                    <td><?= h($u['NomComplet']) ?></td>
                    <td><span class="badge bg-info text-dark"><?= h($u['Profil']) ?></span></td>
                    <?php if (is_super_admin()): ?><td><?= $u['Societe'] ? h($u['Societe']) : '<span class="text-muted">Toutes</span>' ?></td><?php endif; ?>
                    <td><?= $u['PeutValiderOperations'] ? '<span class="badge bg-success">Peut valider / rejeter</span>' : '' ?>
                        <?php if (in_array($u['Profil'], ['Admin', 'SuperAdmin'], true)): ?><span class="badge text-bg-light border">Remises sans limite</span>
                        <?php elseif (!empty($u['PeutRemise'])): ?><span class="badge bg-primary">Remises<?= $u['RemiseMax'] !== null ? ' jusqu\'à ' . h(quantite_fr((float) $u['RemiseMax'])) . ' %' : '' ?></span><?php endif; ?></td>
                    <td class="text-center table-actions">
                        <a href="<?= h(url('utilisateur/edit', ['id' => $u['Id']])) ?>" class="btn btn-warning btn-sm"
                           data-utilisateur="<?= h(json_encode([
                               'action' => url('utilisateur/edit', ['id' => $u['Id']]),
                               'NomUtilisateur' => $u['NomUtilisateur'], 'NomComplet' => $u['NomComplet'], 'Profil' => $u['Profil'], 'TenantId' => $u['TenantId'],
                               'PeutValiderOperations' => (bool) $u['PeutValiderOperations'], 'PeutRemise' => (bool) ($u['PeutRemise'] ?? false),
                               'RemiseMax' => isset($u['RemiseMax']) && $u['RemiseMax'] !== null ? quantite_fr((float) $u['RemiseMax']) : '',
                           ])) ?>">Modifier</a>
                        <form method="post" action="<?= h(url('utilisateur/delete')) ?>" onsubmit="return confirm('Supprimer cet utilisateur ?');">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $u['Id'] ?>">
                            <button class="btn btn-danger btn-sm">Supprimer</button>
                        </form>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<?= partial('utilisateur/form', ['u' => ['Profil' => 'Caissier', 'TenantId' => tenant_id() ?: null], 'edition' => false, 'societes' => $societes, 'profils' => $profils, 'modale' => true]) ?>
<?= partial('utilisateur/form', ['u' => [], 'societes' => $societes, 'profils' => $profils, 'modale' => true, 'modification' => true]) ?>
<?php ob_start(); ?>
<script>
    listeDataTable('#UsersTable', {
        pageLength: 10,
        lengthMenu: [10, 25, 50, 100],
        order: [[1, 'asc']],
        columnDefs: [{ orderable: false, targets: -1 }]
    });

    // « Modifier » : ouvre la modale de modification, remplie avec l'utilisateur de la ligne.
    document.addEventListener('click', function (e) {
        const lien = e.target.closest('a[data-utilisateur]');
        if (!lien || e.ctrlKey || e.metaKey || e.shiftKey || e.button !== 0) return;
        e.preventDefault();
        const u = JSON.parse(lien.dataset.utilisateur);
        const modale = document.getElementById('modalModification');
        const form = modale.querySelector('form');
        form.action = u.action;
        ['NomUtilisateur', 'NomComplet', 'Profil', 'TenantId', 'RemiseMax'].forEach(function (nom) {
            const champ = form.elements[nom];
            if (champ) champ.value = u[nom] == null ? '' : u[nom];
        });
        form.elements.MotPasse.value = '';
        form.elements.PeutValiderOperations.checked = u.PeutValiderOperations;
        form.elements.PeutRemise.checked = u.PeutRemise;
        form.elements.RemiseMax.disabled = !u.PeutRemise;
        bootstrap.Modal.getOrCreateInstance(modale).show();
    });
    document.getElementById('modalModification').addEventListener('shown.bs.modal', function () {
        document.getElementById('NomUtilisateurE').focus();
    });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
