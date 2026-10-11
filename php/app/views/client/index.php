<?php $titre = 'Tiers'; ?>
<div class="d-flex flex-wrap justify-content-between align-items-end gap-2 mb-3">
    <form method="get" action="index.php" class="d-flex gap-2">
        <input type="hidden" name="r" value="client/index">
        <input name="search" class="form-control" placeholder="Rechercher (code, société, contact, téléphone, type)" value="<?= h($search) ?>" style="min-width:320px;">
        <button class="btn btn-outline-primary"><i class="fa fa-search"></i></button>
    </form>
    <div class="d-flex gap-2">
        <form method="post" action="<?= h(url('client/import')) ?>" enctype="multipart/form-data">
            <?= csrf_field() ?>
            <input type="file" name="file" accept=".xlsx" id="importFile" class="d-none" onchange="this.form.submit()">
            <button type="button" class="btn btn-outline-primary" onclick="document.getElementById('importFile').click()"><i class="fa fa-file-import"></i> Importer Excel</button>
        </form>
        <a href="<?= h(url('client/export', ['search' => $search])) ?>" class="btn btn-success"><i class="fa fa-file-excel"></i> Exporter Excel</a>
        <a href="<?= h(url('client/create')) ?>" class="btn btn-primary"><i class="fa fa-plus"></i> Nouveau tiers</a>
    </div>
</div>
<p class="small text-muted">Import : la première ligne du fichier est un en-tête ; colonnes dans l'ordre Code, Société, Contact, Téléphone, EmailContact, Adresse, Email, Type, FonctionContact, TelephoneContact, CompteGeneral (le plus simple est de partir d'un export).</p>
<div class="card shadow-sm border-0">
    <div class="card-body table-responsive">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Code</th><th>Société</th><th>Adresse</th><th>Contact</th><th>Fonction</th><th>Téléphone</th><th class="text-center">Type</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php if (!$clients): ?><tr><td colspan="8" class="text-center text-muted py-4">Aucun tiers.</td></tr><?php endif; ?>
            <?php foreach ($clients as $c):
                $badge = ['Client' => 'bg-primary', 'Fournisseur' => 'bg-orange', 'Salarié' => 'bg-success', 'Autre' => 'bg-danger'][$c['Type']] ?? 'bg-secondary'; ?>
                <tr>
                    <td><?= h($c['CodeClient']) ?></td>
                    <td class="fw-semibold"><?= h($c['NomSociete']) ?></td>
                    <td><?= h($c['Adresse']) ?></td>
                    <td><?= h($c['NomContact']) ?></td>
                    <td><?= h($c['FonctionContact']) ?></td>
                    <td><?= h($c['Telephone']) ?></td>
                    <td class="text-center"><?php if ($c['Type']): ?><span class="badge <?= $badge ?>"><?= h($c['Type']) ?></span><?php endif; ?></td>
                    <td class="text-center table-actions">
                        <a href="<?= h(url('client/edit', ['id' => $c['Id']])) ?>" class="btn btn-warning btn-sm">Modifier</a>
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
