<?php $titre = 'Sociétés'; ?>
<div class="d-flex justify-content-between align-items-center mb-3">
    <h4 class="mb-0">Sociétés</h4>
    <a href="<?= h(url('tenant/create')) ?>" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalCreation"><i class="fa fa-plus"></i> Nouvelle société</a>
</div>
<div class="card shadow-sm border-0">
    <div class="card-body table-responsive">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Code</th><th>Nom</th><th>Mode d'accès</th><th>Expiration</th><th>Statut</th><th>Créée le</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php foreach ($tenants as $t): $bloquee = societe_bloquee($t); ?>
                <tr>
                    <td><?= h($t['Code']) ?></td>
                    <td class="fw-semibold"><?= h($t['Nom']) ?></td>
                    <td><?= h($t['ModeAcces']) ?></td>
                    <td><?= $t['DateExpiration'] ? date_fr($t['DateExpiration']) : '<span class="text-muted">Illimitée</span>' ?></td>
                    <td>
                        <?php if (!$t['Actif']): ?><span class="badge bg-secondary">Inactive</span>
                        <?php elseif ($bloquee): ?><span class="badge bg-danger">Expirée</span>
                        <?php else: ?><span class="badge bg-success">Active</span><?php endif; ?>
                    </td>
                    <td><?= date_fr($t['DateCreation']) ?></td>
                    <td class="text-center table-actions">
                        <a href="<?= h(url('tenant/edit', ['id' => $t['Id']])) ?>" class="btn btn-warning btn-sm">Modifier</a>
                        <?php foreach ([1 => '+1 mois', 12 => '+1 an'] as $mois => $lib): ?>
                            <form method="post" action="<?= h(url('tenant/prolonger')) ?>">
                                <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $t['Id'] ?>"><input type="hidden" name="mois" value="<?= $mois ?>">
                                <button class="btn btn-outline-primary btn-sm"><?= $lib ?></button>
                            </form>
                        <?php endforeach; ?>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<?= partial('tenant/form', ['t' => ['Actif' => 1, 'ModeAcces' => 'Licence'], 'edition' => false, 'modale' => true]) ?>
