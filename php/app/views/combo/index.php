<?php $titre = 'Combos'; ?>
<div class="d-flex justify-content-between align-items-center mb-3">
    <h4 class="mb-0">Combos</h4>
    <a href="<?= h(url('combo/create')) ?>" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalCreation"><i class="fa fa-plus"></i> Nouveau combo</a>
</div>
<p class="small text-muted">Comme dans Odoo, un combo regroupe les produits proposés au choix (ex. <strong>Plats</strong> : Poulet, Poisson + 500 ;
    <strong>Boissons</strong> : Coca, Eau). Un produit combo (ex. <strong>Menu midi</strong>) se compose ensuite de plusieurs combos, choisis sur sa fiche
    (Configuration › Produits). À la caisse, le serveur choisit un article dans chaque combo.</p>
<div class="card shadow-sm border-0">
    <div class="card-body">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Combo</th><th class="text-center">À choisir</th><th>Produits proposés</th><th>Utilisé dans</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php if (!$combos): ?><tr><td colspan="5" class="text-center text-muted py-4">Aucun combo. Créez-en un, par exemple « Plats » ou « Boissons ».</td></tr><?php endif; ?>
            <?php foreach ($combos as $c): ?>
                <tr>
                    <td class="fw-semibold"><?= h($c['Nom']) ?></td>
                    <td class="text-center"><?= (int) $c['Quantite'] ?></td>
                    <td><?= h(implode(', ', array_map(fn($ch) => $ch['Nom'] . ((float) $ch['Supplement'] > 0 ? ' (+' . fcfa($ch['Supplement']) . ')' : ''), $c['choix']))) ?></td>
                    <td><?= $c['produits'] ? h(implode(', ', $c['produits'])) : '<span class="text-muted">—</span>' ?></td>
                    <td class="text-center table-actions">
                        <a href="<?= h(url('combo/edit', ['id' => $c['Id']])) ?>" class="btn btn-warning btn-sm">Modifier</a>
                        <form method="post" action="<?= h(url('combo/delete')) ?>" onsubmit="return confirm('Supprimer ce combo ?');">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $c['Id'] ?>">
                            <button class="btn btn-danger btn-sm">Supprimer</button>
                        </form>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<?= partial('combo/form', ['combo' => null, 'valeurs' => ['Nom' => '', 'Quantite' => 1], 'donnees' => ['produits' => $produits, 'choix' => []], 'modale' => true]) ?>
<?php ob_start(); ?>
<script src="<?= asset('assets/js/combo.js') ?>"></script>
<?php $scripts = ob_get_clean(); ?>
