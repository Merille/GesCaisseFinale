<?php $titre = 'Tiers';
$champsModale = ['CodeClient', 'NomSociete', 'Genre', 'Type', 'Adresse', 'Telephone', 'Email', 'CompteGeneral', 'NomContact', 'FonctionContact', 'TelephoneContact', 'EmailContact']; ?>
<div class="d-flex flex-wrap justify-content-end align-items-end gap-2 mb-3">
    <div class="d-flex gap-2">
        <form method="post" action="<?= h(url('client/import')) ?>" enctype="multipart/form-data">
            <?= csrf_field() ?>
            <input type="file" name="file" accept=".xlsx" id="importFile" class="d-none" onchange="this.form.submit()">
            <button type="button" class="btn btn-outline-primary" onclick="document.getElementById('importFile').click()"><i class="fa fa-file-import"></i> Importer Excel</button>
        </form>
        <a href="<?= h(url('client/export')) ?>" class="btn btn-success"><i class="fa fa-file-excel"></i> Exporter Excel</a>
        <a href="<?= h(url('client/create')) ?>" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalCreation"><i class="fa fa-plus"></i> Nouveau tiers</a>
    </div>
</div>
<p class="small text-muted">Import : la première ligne du fichier est un en-tête ; colonnes dans l'ordre Code, Société, Contact, Téléphone, EmailContact, Adresse, Email, Type, FonctionContact, TelephoneContact, CompteGeneral, Genre (Entreprise ou Particulier ; vide = Entreprise). Le plus simple est de partir d'un export.</p>
<div class="card shadow-sm border-0">
    <div class="card-body table-responsive">
        <table id="clientsTable" class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Code</th><th>Nom</th><th>Genre</th><th>Adresse</th><th>Contact</th><th>Fonction</th><th>Téléphone</th><th class="text-center">Type</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php foreach ($clients as $c):
                $badge = ['Client' => 'bg-primary', 'Fournisseur' => 'bg-orange', 'Salarié' => 'bg-success', 'Autre' => 'bg-danger'][$c['Type']] ?? 'bg-secondary'; ?>
                <tr>
                    <td><?= h($c['CodeClient']) ?></td>
                    <td class="fw-semibold"><?= h($c['NomSociete']) ?></td>
                    <td class="text-nowrap"><i class="fa <?= $c['Genre'] === 'Particulier' ? 'fa-user' : 'fa-building' ?> text-muted me-1"></i><?= h($c['Genre']) ?></td>
                    <td><?= h($c['Adresse']) ?></td>
                    <td><?= h($c['NomContact']) ?></td>
                    <td><?= h($c['FonctionContact']) ?></td>
                    <td><?= h($c['Telephone']) ?></td>
                    <td class="text-center"><?php if ($c['Type']): ?><span class="badge <?= $badge ?>"><?= h($c['Type']) ?></span><?php endif; ?></td>
                    <td class="text-center table-actions">
                        <a href="<?= h(url('client/edit', ['id' => $c['Id']])) ?>" class="btn btn-warning btn-sm"
                           data-tiers="<?= h(json_encode(['action' => url('client/edit', ['id' => $c['Id']])] + array_intersect_key($c, array_flip($champsModale)))) ?>">Modifier</a>
                        <form method="post" action="<?= h(url('client/delete')) ?>" onsubmit="return confirm('Supprimer ce tiers ?');">
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

<?= partial('client/form', ['client' => [], 'edition' => false, 'modale' => true]) ?>
<?= partial('client/form', ['client' => [], 'edition' => false, 'modale' => true, 'modification' => true]) ?>
<?php ob_start(); ?>
<script>
    listeDataTable('#clientsTable', {
        pageLength: 20,
        lengthMenu: [20, 50, 100],
        order: [[1, 'asc']],
        columnDefs: [{ orderable: false, targets: -1 }]
    });

    // « Modifier » : ouvre la modale de modification, remplie avec le tiers de la ligne.
    document.addEventListener('click', function (e) {
        const lien = e.target.closest('a[data-tiers]');
        if (!lien || e.ctrlKey || e.metaKey || e.shiftKey || e.button !== 0) return;
        e.preventDefault();
        const t = JSON.parse(lien.dataset.tiers);
        const modale = document.getElementById('modalModification');
        const form = modale.querySelector('form');
        form.action = t.action;
        Object.keys(t).forEach(function (nom) {
            const champ = form.elements[nom];
            if (champ && nom !== 'action') champ.value = t[nom] == null ? '' : t[nom];
        });
        bootstrap.Modal.getOrCreateInstance(modale).show();
    });
    document.getElementById('modalModification').addEventListener('shown.bs.modal', function () {
        document.getElementById('CodeClientE').focus();
    });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
