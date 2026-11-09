<?php $titre = 'Livreurs'; ?>
<div class="d-flex justify-content-between align-items-center mb-3">
    <h4 class="mb-0">Livreurs</h4>
    <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalLivreur" data-id="" data-actif="1"><i class="fa fa-plus"></i> Nouveau livreur</button>
</div>
<p class="small text-muted">Les livreurs (à moto, en voiture, à vélo…) sont proposés au point de vente sur une commande à livrer (bouton « Livraison »). Ils n'ont pas de compte de connexion.
    Un livreur désactivé n'est plus proposé mais reste sur ses livraisons passées.</p>
<?php if ($fraisDefaut !== null): ?>
    <form method="post" action="<?= h(url('livreur/frais')) ?>" class="card shadow-sm border-0 mb-3">
        <?= csrf_field() ?>
        <div class="card-body d-flex flex-wrap align-items-end gap-3">
            <div>
                <label class="form-label" for="fraisLivraison"><i class="fa fa-truck-fast"></i> Frais de livraison par défaut (FCFA)</label>
                <input class="form-control" id="fraisLivraison" name="fraisLivraison" inputmode="decimal" style="max-width:200px" value="<?= h((string) round($fraisDefaut)) ?>">
            </div>
            <button class="btn btn-primary">Enregistrer</button>
            <div class="small text-muted flex-grow-1" style="min-width:260px">Proposés dans la fenêtre « Livraison » du point de vente, modifiables à chaque vente (0 = sans frais).
                Ils s'ajoutent au total à payer, hors taxes, et reviennent à la société.</div>
        </div>
    </form>
<?php endif; ?>
<div class="card shadow-sm border-0">
    <div class="card-body">
        <table id="livreursTable" class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Nom</th><th>Téléphone</th><th>Moyen de livraison</th><th class="text-center">Livraisons</th><th class="text-center">Statut</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php foreach ($livreurs as $l): ?>
                <tr class="<?= $l['Actif'] ? '' : 'text-muted' ?>">
                    <td class="fw-semibold"><?= h($l['Nom']) ?></td>
                    <td><?= h($l['Telephone'] ?? '') ?></td>
                    <td><i class="fa <?= livreur_icone($l['MoyenLivraison']) ?> text-muted me-1"></i><?= h($l['MoyenLivraison']) ?></td>
                    <td class="text-center"><?= (int) $l['NbLivraisons'] ?></td>
                    <td class="text-center"><?= $l['Actif'] ? '<span class="badge bg-success">Actif</span>' : '<span class="badge bg-secondary">Inactif</span>' ?></td>
                    <td class="text-center table-actions">
                        <button class="btn btn-warning btn-sm" data-bs-toggle="modal" data-bs-target="#modalLivreur"
                                data-id="<?= (int) $l['Id'] ?>" data-nom="<?= h($l['Nom']) ?>" data-telephone="<?= h($l['Telephone'] ?? '') ?>" data-moyen="<?= h($l['MoyenLivraison']) ?>" data-actif="<?= $l['Actif'] ? '1' : '0' ?>">Modifier</button>
                        <form method="post" action="<?= h(url('livreur/toggle')) ?>">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $l['Id'] ?>">
                            <button class="btn btn-sm <?= $l['Actif'] ? 'btn-outline-secondary' : 'btn-success' ?>"><?= $l['Actif'] ? 'Désactiver' : 'Activer' ?></button>
                        </form>
                        <form method="post" action="<?= h(url('livreur/delete')) ?>" onsubmit="return confirm('Supprimer ce livreur ?');">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $l['Id'] ?>">
                            <button class="btn btn-danger btn-sm">Supprimer</button>
                        </form>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<div class="modal fade" id="modalLivreur" tabindex="-1" aria-labelledby="livreurTitre" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <form class="modal-content" method="post" action="<?= h(url('livreur/save')) ?>">
            <div class="modal-header bg-brand text-white">
                <h5 class="modal-title" id="livreurTitre">Livreur</h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>
            </div>
            <div class="modal-body">
                <?= csrf_field() ?>
                <input type="hidden" name="Id" id="livreurId">
                <div class="row g-3">
                    <div class="col-md-7"><label class="form-label" for="livreurNom">Nom</label><input id="livreurNom" name="Nom" class="form-control" placeholder="Ex : Jean Moussavou" maxlength="100" required></div>
                    <div class="col-md-5"><label class="form-label" for="livreurTelephone">Téléphone</label><input id="livreurTelephone" name="Telephone" class="form-control" placeholder="Ex : 077 00 00 00" maxlength="30"></div>
                    <div class="col-md-7"><label class="form-label" for="livreurMoyen">Moyen de livraison</label>
                        <select id="livreurMoyen" name="MoyenLivraison" class="form-select">
                            <?php foreach (LIVREUR_MOYENS as $m): ?><option><?= h($m) ?></option><?php endforeach; ?>
                        </select></div>
                    <div class="col-12"><div class="form-check"><input class="form-check-input" type="checkbox" value="1" name="Actif" id="livreurActif"><label class="form-check-label" for="livreurActif">Actif (proposé au point de vente)</label></div></div>
                </div>
            </div>
            <div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Annuler</button><button class="btn btn-primary">Enregistrer</button></div>
        </form>
    </div>
</div>
<?php ob_start(); ?>
<script>
    const modaleLivreur = document.getElementById('modalLivreur');
    modaleLivreur.addEventListener('show.bs.modal', function (e) {
        const d = e.relatedTarget ? e.relatedTarget.dataset : {};
        document.getElementById('livreurTitre').textContent = d.id ? 'Modifier le livreur' : 'Nouveau livreur';
        document.getElementById('livreurId').value = d.id || '';
        document.getElementById('livreurNom').value = d.nom || '';
        document.getElementById('livreurTelephone').value = d.telephone || '';
        document.getElementById('livreurMoyen').value = d.moyen || 'Moto';
        document.getElementById('livreurActif').checked = d.actif === '1';
    });
    modaleLivreur.addEventListener('shown.bs.modal', function () { document.getElementById('livreurNom').focus(); });
    listeDataTable('#livreursTable', {
        pageLength: 10,
        lengthMenu: [10, 25, 50, 100],
        order: [],
        columnDefs: [{ orderable: false, targets: -1 }]
    });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
