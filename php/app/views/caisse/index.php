<?php $titre = 'Caisses'; ?>
<div class="d-flex justify-content-end gap-2 mb-3">
    <a href="<?= h(url('caisse/print')) ?>" class="btn btn-outline-primary"><i class="fa fa-print"></i> Imprimer</a>
    <a href="<?= h(url('caisse/create')) ?>" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalCreation"><i class="fa fa-plus"></i> Nouvelle caisse</a>
</div>
<div class="card shadow-sm border-0">
    <div class="card-body">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark">
            <tr><th>Code</th><th>Description</th><th>StCode</th><th>Caissier par défaut</th><th>Compte comptable</th><th class="text-center">Actions</th></tr>
            </thead>
            <tbody>
            <?php if (!$caisses): ?>
                <tr><td colspan="6" class="text-center text-muted py-4">Aucune caisse.</td></tr>
            <?php endif; ?>
            <?php foreach ($caisses as $c): ?>
                <tr>
                    <td class="fw-semibold"><?= h($c['ChkCode']) ?></td>
                    <td><?= h($c['ChkDescription']) ?></td>
                    <td><?= h($c['StCode']) ?></td>
                    <td><?= $c['Caissier'] ? h($c['Caissier']) : '<span class="text-muted">—</span>' ?></td>
                    <td><?= h($c['CompteComptable']) ?></td>
                    <td class="text-center table-actions">
                        <a href="<?= h(url('caisse/details', ['id' => $c['ID']])) ?>" class="btn btn-primary btn-sm">Journées</a>
                        <a href="<?= h(url('caisse/edit', ['id' => $c['ID']])) ?>" class="btn btn-warning btn-sm">Modifier</a>
                        <form method="post" action="<?= h(url('caisse/delete')) ?>" onsubmit="return confirm('Supprimer cette caisse ?');">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $c['ID'] ?>">
                            <button class="btn btn-danger btn-sm">Supprimer</button>
                        </form>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<?= partial('caisse/form', ['caisse' => [], 'utilisateurs' => $utilisateurs, 'modale' => true]) ?>
