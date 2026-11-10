<?php $titre = 'Caisses'; ?>
<div class="d-flex justify-content-end gap-2 mb-3">
    <a href="<?= h(url('caisse/print')) ?>" class="btn btn-outline-primary"><i class="fa fa-print"></i> Imprimer</a>
    <a href="<?= h(url('caisse/create')) ?>" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalCreation"><i class="fa fa-plus"></i> Nouvelle caisse</a>
</div>
<div class="card shadow-sm border-0">
    <div class="card-body">
        <table id="caissesTable" class="table table-hover align-middle mb-0">
            <thead class="table-dark">
            <tr><th>Code</th><th>Description</th><th>Type</th><th>Caissier par défaut</th><th>Compte comptable</th><?php if (module_pos_actif()): ?><th>Dépôts</th><?php endif; ?><th class="text-center">Actions</th></tr>
            </thead>
            <tbody>
            <?php foreach ($caisses as $c): ?>
                <tr>
                    <td><span class="fw-semibold"><?= h($c['ChkCode']) ?></span><?php if ($c['StCode']): ?><div class="small text-muted" title="StCode"><?= h($c['StCode']) ?></div><?php endif; ?></td>
                    <td><?= h($c['ChkDescription']) ?></td>
                    <td><?php $type = $c['TypePointVente'] ?? 'Boutique'; ?>
                        <span class="badge <?= CAISSE_TYPE_BADGES[$type] ?? 'bg-secondary' ?>">
                            <i class="fa <?= CAISSE_TYPE_ICONES[$type] ?? 'fa-store' ?>"></i> <?= h(caisse_type_libelle($type)) ?></span></td>
                    <td><?= $c['Caissier'] ? h($c['Caissier']) : '<span class="text-muted">—</span>' ?></td>
                    <td><?= h($c['CompteComptable']) ?></td>
                    <?php if (module_pos_actif()): ?>
                    <td><?php // Dépôt de la caisse (sinon dépôt par défaut de la société), puis ses dépôts secondaires. ?>
                        <?= h((string) $c['DepotCode']) ?><?php if (!$c['DepotId']): ?> <span class="small text-muted text-nowrap">(par défaut)</span><?php endif; ?>
                        <?php $sec = array_map(fn($id) => $codesDepots[$id] ?? '', array_keys($secondaires[(int) $c['ID']] ?? [])); ?>
                        <?php if ($sec): ?><div class="small text-muted">+ <?= h(implode(', ', $sec)) ?></div><?php endif; ?></td>
                    <?php endif; ?>
                    <td class="text-center table-actions">
                        <a href="<?= h(url('caisse/details', ['id' => $c['ID']])) ?>" class="btn btn-primary btn-sm">Journées</a>
                        <?php if (in_array($type, ['Restaurant', 'Bar'], true) && is_admin() && module_pos_actif()): ?>
                            <a href="<?= h(url('salle/index', ['caisse' => $c['ID']])) ?>" class="btn btn-info btn-sm" title="Plan de salle" aria-label="Plan de salle"><i class="fa fa-chair"></i></a>
                        <?php endif; ?>
                        <a href="<?= h(url('caisse/edit', ['id' => $c['ID']])) ?>" class="btn btn-warning btn-sm"
                           data-caisse="<?= h(json_encode([
                               'action' => url('caisse/edit', ['id' => $c['ID']]),
                               'ChkCode' => $c['ChkCode'], 'ChkDescription' => $c['ChkDescription'], 'StCode' => $c['StCode'],
                               'CashierDefault' => $c['CashierDefault'], 'CompteComptable' => $c['CompteComptable'],
                               'TypePointVente' => $c['TypePointVente'] ?? 'Boutique', 'ImprimerBons' => (bool) ($c['ImprimerBons'] ?? 1), 'DepotId' => $c['DepotId'],
                               'Secondaires' => (object) ($secondaires[(int) $c['ID']] ?? []),
                           ])) ?>">Modifier</a>
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

<?= partial('caisse/form', ['caisse' => [], 'utilisateurs' => $utilisateurs, 'depots' => $depots, 'modale' => true]) ?>
<?= partial('caisse/form', ['caisse' => [], 'utilisateurs' => $utilisateurs, 'depots' => $depots, 'modale' => true, 'modification' => true]) ?>
<?php ob_start(); ?>
<script>
    listeDataTable('#caissesTable', {
        pageLength: 10,
        lengthMenu: [10, 25, 50, 100],
        order: [[1, 'asc']],
        columnDefs: [{ orderable: false, targets: -1 }]
    });

    // « Modifier » : ouvre la modale de modification, remplie avec la caisse de la ligne.
    document.addEventListener('click', function (e) {
        const lien = e.target.closest('a[data-caisse]');
        if (!lien || e.ctrlKey || e.metaKey || e.shiftKey || e.button !== 0) return;
        e.preventDefault();
        const c = JSON.parse(lien.dataset.caisse);
        const modale = document.getElementById('modalModification');
        const form = modale.querySelector('form');
        form.action = c.action;
        ['ChkCode', 'ChkDescription', 'StCode', 'CashierDefault', 'CompteComptable', 'TypePointVente', 'DepotId'].forEach(function (nom) {
            const champ = form.elements[nom];
            if (champ) champ.value = c[nom] == null ? '' : c[nom];
        });
        // Dépôts secondaires : cochés avec leur ordre ; les autres gardent l'ordre proposé.
        form.querySelectorAll('.depots-secondaires [data-depot]').forEach(function (ligne, i) {
            const ordre = c.Secondaires[ligne.dataset.depot];
            ligne.querySelector('[type="checkbox"]').checked = ordre !== undefined;
            ligne.querySelector('[type="number"]').value = ordre !== undefined ? ordre : i + 1;
        });
        const bons = form.querySelector('[name="ImprimerBons"]');
        if (bons && bons.type === 'checkbox') bons.checked = c.ImprimerBons;
        else if (bons) bons.disabled = !c.ImprimerBons;
        bootstrap.Modal.getOrCreateInstance(modale).show();
    });
    document.getElementById('modalModification').addEventListener('shown.bs.modal', function () {
        document.getElementById('ChkCodeE').focus();
    });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
