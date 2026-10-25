<?php $titre = 'Catégories'; ?>
<div class="d-flex justify-content-between align-items-center mb-3">
    <h4 class="mb-0">Catégories de produits</h4>
    <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalCategorie" data-id=""><i class="fa fa-plus"></i> Nouvelle catégorie</button>
</div>
<div class="card shadow-sm border-0">
    <div class="card-body">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Catégorie</th><th class="text-center">Ordre</th><th class="text-center">Produits</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php if (!$categories): ?><tr><td colspan="4" class="text-center text-muted py-4">Aucune catégorie. Créez-en une pour regrouper les produits sur l'écran de vente.</td></tr><?php endif; ?>
            <?php foreach ($categories as $c): ?>
                <tr>
                    <td><span class="pastille-categorie" style="background: <?= h($c['Couleur']) ?>"></span> <span class="fw-semibold"><?= h($c['Nom']) ?></span></td>
                    <td class="text-center"><?= (int) $c['Ordre'] ?></td>
                    <td class="text-center"><a href="<?= h(url('produit/index', ['categorie' => $c['Id']])) ?>"><?= (int) $c['NbProduits'] ?></a></td>
                    <td class="text-center table-actions">
                        <button class="btn btn-warning btn-sm" data-bs-toggle="modal" data-bs-target="#modalCategorie"
                                data-id="<?= (int) $c['Id'] ?>" data-nom="<?= h($c['Nom']) ?>" data-couleur="<?= h($c['Couleur']) ?>" data-ordre="<?= (int) $c['Ordre'] ?>">Modifier</button>
                        <form method="post" action="<?= h(url('categorie/delete')) ?>" onsubmit="return confirm('Supprimer cette catégorie ?');">
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

<div class="modal fade" id="modalCategorie" tabindex="-1" aria-labelledby="categorieTitre" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <form class="modal-content" method="post" action="<?= h(url('categorie/save')) ?>">
            <div class="modal-header bg-brand text-white">
                <h5 class="modal-title" id="categorieTitre">Catégorie</h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>
            </div>
            <div class="modal-body">
                <?= csrf_field() ?>
                <input type="hidden" name="Id" id="categorieId">
                <div class="mb-3"><label class="form-label" for="categorieNom">Nom</label><input id="categorieNom" name="Nom" class="form-control" placeholder="Ex : Boissons" required></div>
                <div class="row g-3">
                    <div class="col-6"><label class="form-label" for="categorieCouleur">Couleur des tuiles</label><input type="color" id="categorieCouleur" name="Couleur" class="form-control form-control-color w-100" value="#195d84"></div>
                    <div class="col-6"><label class="form-label" for="categorieOrdre">Ordre d'affichage</label><input type="number" id="categorieOrdre" name="Ordre" class="form-control" value="0"></div>
                </div>
            </div>
            <div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Annuler</button><button class="btn btn-primary">Enregistrer</button></div>
        </form>
    </div>
</div>
<?php ob_start(); ?>
<script>
    document.getElementById('modalCategorie').addEventListener('show.bs.modal', function (e) {
        const d = e.relatedTarget ? e.relatedTarget.dataset : {};
        document.getElementById('categorieTitre').textContent = d.id ? 'Modifier la catégorie' : 'Nouvelle catégorie';
        document.getElementById('categorieId').value = d.id || '';
        document.getElementById('categorieNom').value = d.nom || '';
        document.getElementById('categorieCouleur').value = d.couleur || '#195d84';
        document.getElementById('categorieOrdre').value = d.ordre || '0';
    });
</script>
<?php $scripts = ob_get_clean(); ?>
