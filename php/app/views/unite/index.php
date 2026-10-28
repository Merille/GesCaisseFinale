<?php $titre = 'Unités de vente'; ?>
<div class="d-flex justify-content-between align-items-center mb-3">
    <h4 class="mb-0">Unités de vente</h4>
    <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalUnite" data-id="" data-actif="1"><i class="fa fa-plus"></i> Nouvelle unité</button>
</div>
<p class="small text-muted">L'unité indique ce que représente le prix d'un produit (ex. 1 Kg, 1 Litre, 1 Carton) ; elle s'affiche sur le ticket.
    Une unité désactivée n'est plus proposée sur la fiche produit mais reste sur les produits qui l'utilisent. Renommer une unité met à jour ses produits.</p>
<div class="card shadow-sm border-0">
    <div class="card-body">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Unité</th><th>Libellé</th><th class="text-center">Produits</th><th class="text-center">Statut</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php if (!$unites): ?><tr><td colspan="5" class="text-center text-muted py-4">Aucune unité.</td></tr><?php endif; ?>
            <?php foreach ($unites as $u): ?>
                <tr class="<?= $u['Actif'] ? '' : 'text-muted' ?>">
                    <td class="fw-semibold"><?= h($u['Nom']) ?></td>
                    <td><?= h($u['Libelle'] ?? '') ?></td>
                    <td class="text-center"><?= (int) $u['NbProduits'] ?></td>
                    <td class="text-center"><?= $u['Actif'] ? '<span class="badge bg-success">Active</span>' : '<span class="badge bg-secondary">Inactive</span>' ?></td>
                    <td class="text-center table-actions">
                        <button class="btn btn-warning btn-sm" data-bs-toggle="modal" data-bs-target="#modalUnite"
                                data-id="<?= (int) $u['Id'] ?>" data-nom="<?= h($u['Nom']) ?>" data-libelle="<?= h($u['Libelle'] ?? '') ?>" data-actif="<?= $u['Actif'] ? '1' : '0' ?>">Modifier</button>
                        <form method="post" action="<?= h(url('unite/toggle')) ?>">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $u['Id'] ?>">
                            <button class="btn btn-sm <?= $u['Actif'] ? 'btn-outline-secondary' : 'btn-success' ?>"><?= $u['Actif'] ? 'Désactiver' : 'Activer' ?></button>
                        </form>
                        <form method="post" action="<?= h(url('unite/delete')) ?>" onsubmit="return confirm('Supprimer cette unité ?');">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $u['Id'] ?>">
                            <button class="btn btn-danger btn-sm">Supprimer</button>
                        </form>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
        <?= partial('partials/pagination', $pagination) ?>
    </div>
</div>

<div class="modal fade" id="modalUnite" tabindex="-1" aria-labelledby="uniteTitre" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <form class="modal-content" method="post" action="<?= h(url('unite/save')) ?>">
            <div class="modal-header bg-brand text-white">
                <h5 class="modal-title" id="uniteTitre">Unité</h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>
            </div>
            <div class="modal-body">
                <?= csrf_field() ?>
                <input type="hidden" name="Id" id="uniteId">
                <div class="row g-3">
                    <div class="col-5"><label class="form-label" for="uniteNom">Unité</label><input id="uniteNom" name="Nom" class="form-control" placeholder="Ex : Kg" maxlength="20" required></div>
                    <div class="col-7"><label class="form-label" for="uniteLibelle">Libellé</label><input id="uniteLibelle" name="Libelle" class="form-control" placeholder="Ex : Kilogramme" maxlength="100"></div>
                    <div class="col-12"><div class="form-check"><input class="form-check-input" type="checkbox" value="1" name="Actif" id="uniteActif"><label class="form-check-label" for="uniteActif">Active (proposée sur la fiche produit)</label></div></div>
                </div>
                <div class="form-text mt-3">Le nom court (20 caractères au plus) s'affiche sur le ticket, ex. « 2 Kg x 1 500 ».</div>
            </div>
            <div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Annuler</button><button class="btn btn-primary">Enregistrer</button></div>
        </form>
    </div>
</div>
<?php ob_start(); ?>
<script>
    document.getElementById('modalUnite').addEventListener('show.bs.modal', function (e) {
        const d = e.relatedTarget ? e.relatedTarget.dataset : {};
        document.getElementById('uniteTitre').textContent = d.id ? "Modifier l'unité" : 'Nouvelle unité';
        document.getElementById('uniteId').value = d.id || '';
        document.getElementById('uniteNom').value = d.nom || '';
        document.getElementById('uniteLibelle').value = d.libelle || '';
        document.getElementById('uniteActif').checked = d.actif === '1';
    });
</script>
<?php $scripts = ob_get_clean(); ?>
