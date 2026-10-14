<?php $titre = 'Utilisateurs'; ?>
<div class="d-flex justify-content-between align-items-center mb-3">
    <h4 class="mb-0">Utilisateurs</h4>
    <a href="<?= h(url('utilisateur/create')) ?>" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalCreation"><i class="fa fa-plus"></i> Nouvel utilisateur</a>
</div>
<div class="card shadow-sm border-0">
    <div class="card-body table-responsive">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Nom utilisateur</th><th>Nom complet</th><th>Profil</th><?php if (is_super_admin()): ?><th>Société</th><?php endif; ?><th>Droits</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php foreach ($users as $u): ?>
                <tr>
                    <td><?= h($u['NomUtilisateur']) ?></td>
                    <td><?= h($u['NomComplet']) ?></td>
                    <td><span class="badge bg-info text-dark"><?= h($u['Profil']) ?></span></td>
                    <?php if (is_super_admin()): ?><td><?= $u['Societe'] ? h($u['Societe']) : '<span class="text-muted">Toutes</span>' ?></td><?php endif; ?>
                    <td><?= $u['PeutValiderOperations'] ? '<span class="badge bg-success">Peut valider / rejeter</span>' : '' ?></td>
                    <td class="text-center table-actions">
                        <a href="<?= h(url('utilisateur/edit', ['id' => $u['Id']])) ?>" class="btn btn-warning btn-sm">Modifier</a>
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
