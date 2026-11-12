<?php $titre = 'Dépôts'; ?>
<div class="d-flex justify-content-between align-items-center mb-3">
    <h4 class="mb-0">Dépôts de stockage</h4>
    <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalDepot" data-id="" data-actif="1"><i class="fa fa-plus"></i> Nouveau dépôt</button>
</div>
<p class="small text-muted">Le stock de chaque produit est suivi par dépôt (magasin, entrepôt, réserve…). Chaque caisse vend depuis son dépôt principal, complété au besoin par ses dépôts secondaires ;
    les entrées, les inventaires et les transferts se font dans le dépôt choisi. Le dépôt par défaut reçoit le stock initial des nouveaux produits
    et sert aux caisses sans dépôt choisi. Le dépôt des achats (laverie) reçoit les achats de produits d'entretien et fournit les consommations ;
    il ne sert à aucune caisse.</p>
<div class="card shadow-sm border-0">
    <div class="card-body">
        <table id="depotsTable" class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Code</th><th>Nom</th><th>Adresse</th><th>Responsable</th><th class="text-center">Produits en stock</th><th class="text-center">Caisses</th><th class="text-center">Statut</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php foreach ($depots as $d): ?>
                <tr class="<?= $d['Actif'] ? '' : 'text-muted' ?>">
                    <td class="fw-semibold"><?= h($d['Code']) ?></td>
                    <td><?= h($d['Nom']) ?></td>
                    <td><?= h($d['Adresse'] ?? '') ?></td>
                    <td><?= h($d['Responsable'] ?? '') ?></td>
                    <td class="text-center"><?= (int) $d['NbProduits'] ?></td>
                    <td class="text-center"><?= (int) $d['NbCaisses'] ?></td>
                    <td class="text-center">
                        <?= $d['Actif'] ? '<span class="badge bg-success">Actif</span>' : '<span class="badge bg-secondary">Inactif</span>' ?>
                        <?php if ($d['ParDefaut']): ?><span class="badge bg-primary">Par défaut</span><?php endif; ?>
                        <?php if ($d['DepotAchats']): ?><span class="badge bg-info text-dark">Dépôt des achats</span><?php endif; ?>
                    </td>
                    <td class="text-center table-actions">
                        <button class="btn btn-warning btn-sm" data-bs-toggle="modal" data-bs-target="#modalDepot"
                                data-id="<?= (int) $d['Id'] ?>" data-code="<?= h($d['Code']) ?>" data-nom="<?= h($d['Nom']) ?>"
                                data-adresse="<?= h($d['Adresse'] ?? '') ?>" data-responsable="<?= h($d['Responsable'] ?? '') ?>" data-actif="<?= $d['Actif'] ? '1' : '0' ?>">Modifier</button>
                        <?php if (!$d['ParDefaut'] && !$d['DepotAchats']): ?>
                            <?php if ($d['Actif']): ?>
                                <form method="post" action="<?= h(url('depot/defaut')) ?>">
                                    <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $d['Id'] ?>">
                                    <button class="btn btn-outline-primary btn-sm">Par défaut</button>
                                </form>
                                <?php if (laverie_actif() && !(int) $d['NbCaisses']): ?>
                                    <form method="post" action="<?= h(url('depot/achats')) ?>">
                                        <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $d['Id'] ?>">
                                        <button class="btn btn-outline-info btn-sm">Dépôt des achats</button>
                                    </form>
                                <?php endif; ?>
                            <?php endif; ?>
                            <form method="post" action="<?= h(url('depot/toggle')) ?>">
                                <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $d['Id'] ?>">
                                <button class="btn btn-sm <?= $d['Actif'] ? 'btn-outline-secondary' : 'btn-success' ?>"><?= $d['Actif'] ? 'Désactiver' : 'Activer' ?></button>
                            </form>
                            <form method="post" action="<?= h(url('depot/delete')) ?>" onsubmit="return confirm('Supprimer ce dépôt ?');">
                                <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $d['Id'] ?>">
                                <button class="btn btn-danger btn-sm">Supprimer</button>
                            </form>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<div class="modal fade" id="modalDepot" tabindex="-1" aria-labelledby="depotTitre" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <form class="modal-content" method="post" action="<?= h(url('depot/save')) ?>">
            <div class="modal-header bg-brand text-white">
                <h5 class="modal-title" id="depotTitre">Dépôt</h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>
            </div>
            <div class="modal-body">
                <?= csrf_field() ?>
                <input type="hidden" name="Id" id="depotId">
                <div class="row g-3">
                    <div class="col-md-4"><label class="form-label" for="depotCode">Code</label><input id="depotCode" name="Code" class="form-control" placeholder="Ex : DEP02" maxlength="20" required></div>
                    <div class="col-md-8"><label class="form-label" for="depotNom">Nom</label><input id="depotNom" name="Nom" class="form-control" placeholder="Ex : Entrepôt Owendo" maxlength="100" required></div>
                    <div class="col-md-8"><label class="form-label" for="depotAdresse">Adresse</label><input id="depotAdresse" name="Adresse" class="form-control" maxlength="200"></div>
                    <div class="col-md-4"><label class="form-label" for="depotResponsable">Responsable</label><input id="depotResponsable" name="Responsable" class="form-control" maxlength="100"></div>
                    <div class="col-12"><div class="form-check"><input class="form-check-input" type="checkbox" value="1" name="Actif" id="depotActif"><label class="form-check-label" for="depotActif">Actif (proposé pour les caisses et les mouvements de stock)</label></div></div>
                </div>
            </div>
            <div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Annuler</button><button class="btn btn-primary">Enregistrer</button></div>
        </form>
    </div>
</div>
<?php ob_start(); ?>
<script>
    const modaleDepot = document.getElementById('modalDepot');
    modaleDepot.addEventListener('show.bs.modal', function (e) {
        const d = e.relatedTarget ? e.relatedTarget.dataset : {};
        document.getElementById('depotTitre').textContent = d.id ? 'Modifier le dépôt' : 'Nouveau dépôt';
        document.getElementById('depotId').value = d.id || '';
        document.getElementById('depotCode').value = d.code || '';
        document.getElementById('depotNom').value = d.nom || '';
        document.getElementById('depotAdresse').value = d.adresse || '';
        document.getElementById('depotResponsable').value = d.responsable || '';
        document.getElementById('depotActif').checked = d.actif === '1';
    });
    modaleDepot.addEventListener('shown.bs.modal', function () { document.getElementById('depotCode').focus(); });
    listeDataTable('#depotsTable', {
        pageLength: 10,
        lengthMenu: [10, 25, 50, 100],
        order: [],
        columnDefs: [{ orderable: false, targets: -1 }]
    });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
