<?php $titre = 'Taxes'; ?>
<div class="d-flex justify-content-between align-items-center mb-3">
    <h4 class="mb-0">Taxes des produits</h4>
    <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalTaxe" data-id=""><i class="fa fa-plus"></i> Nouvelle taxe</button>
</div>
<p class="small text-muted">Un produit peut porter plusieurs taxes (ex. TVA 18 % + CSS 1 %) : elles s'additionnent sur le prix HT
    et sont comprises dans le prix de vente TTC. Les taxes « par défaut » sont cochées sur un nouveau produit.</p>
<div class="card shadow-sm border-0">
    <div class="card-body">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Code</th><th>Libellé</th><th class="text-end">Taux</th><th class="text-center">Par défaut</th><th class="text-center">Produits</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php if (!$taxes): ?><tr><td colspan="6" class="text-center text-muted py-4">Aucune taxe.</td></tr><?php endif; ?>
            <?php foreach ($taxes as $t): ?>
                <tr>
                    <td class="fw-semibold"><?= h($t['Code']) ?></td>
                    <td><?= h($t['Libelle']) ?></td>
                    <td class="text-end"><?= quantite_fr($t['Taux']) ?> %</td>
                    <td class="text-center"><?= $t['ParDefaut'] ? '<span class="badge bg-success">Oui</span>' : '<span class="text-muted">—</span>' ?></td>
                    <td class="text-center"><?= (int) $t['NbProduits'] ?></td>
                    <td class="text-center table-actions">
                        <button class="btn btn-warning btn-sm" data-bs-toggle="modal" data-bs-target="#modalTaxe"
                                data-id="<?= (int) $t['Id'] ?>" data-code="<?= h($t['Code']) ?>" data-libelle="<?= h($t['Libelle']) ?>"
                                data-taux="<?= h(quantite_fr($t['Taux'], false)) ?>" data-defaut="<?= $t['ParDefaut'] ? '1' : '0' ?>">Modifier</button>
                        <form method="post" action="<?= h(url('taxe/delete')) ?>" onsubmit="return confirm('Supprimer cette taxe ?');">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $t['Id'] ?>">
                            <button class="btn btn-danger btn-sm">Supprimer</button>
                        </form>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<div class="modal fade" id="modalTaxe" tabindex="-1" aria-labelledby="taxeTitre" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <form class="modal-content" method="post" action="<?= h(url('taxe/save')) ?>">
            <div class="modal-header bg-brand text-white">
                <h5 class="modal-title" id="taxeTitre">Taxe</h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>
            </div>
            <div class="modal-body">
                <?= csrf_field() ?>
                <input type="hidden" name="Id" id="taxeId">
                <div class="row g-3">
                    <div class="col-5"><label class="form-label" for="taxeCode">Code</label><input id="taxeCode" name="Code" class="form-control" placeholder="Ex : CSS" maxlength="20" required></div>
                    <div class="col-7"><label class="form-label" for="taxeTaux">Taux (%)</label><input id="taxeTaux" name="Taux" class="form-control" inputmode="decimal" placeholder="Ex : 1" required></div>
                    <div class="col-12"><label class="form-label" for="taxeLibelle">Libellé</label><input id="taxeLibelle" name="Libelle" class="form-control" placeholder="Ex : Contribution spéciale de solidarité" required></div>
                    <div class="col-12"><div class="form-check"><input class="form-check-input" type="checkbox" value="1" name="ParDefaut" id="taxeDefaut"><label class="form-check-label" for="taxeDefaut">Cochée par défaut sur un nouveau produit</label></div></div>
                </div>
                <div class="form-text mt-3">Modifier un taux met à jour les produits qui portent cette taxe ; les ventes déjà enregistrées gardent leur taux.</div>
            </div>
            <div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Annuler</button><button class="btn btn-primary">Enregistrer</button></div>
        </form>
    </div>
</div>
<?php ob_start(); ?>
<script>
    document.getElementById('modalTaxe').addEventListener('show.bs.modal', function (e) {
        const d = e.relatedTarget ? e.relatedTarget.dataset : {};
        document.getElementById('taxeTitre').textContent = d.id ? 'Modifier la taxe' : 'Nouvelle taxe';
        document.getElementById('taxeId').value = d.id || '';
        document.getElementById('taxeCode').value = d.code || '';
        document.getElementById('taxeLibelle').value = d.libelle || '';
        document.getElementById('taxeTaux').value = d.taux || '';
        document.getElementById('taxeDefaut').checked = d.defaut === '1';
    });
</script>
<?php $scripts = ob_get_clean(); ?>
