<?php $titre = 'Facture ' . $facture['Numero']; $brouillon = $facture['Statut'] === 'Brouillon'; ?>
<div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-3">
    <h4 class="mb-0">Facture <?= h($facture['Numero']) ?>
        <span class="badge <?= $brouillon ? 'bg-secondary' : 'bg-success' ?> fs-6 align-middle"><?= h($facture['Statut']) ?></span></h4>
    <div class="d-flex gap-2">
        <?php if ($brouillon): ?>
            <form method="post" action="<?= h(url('facture/valider')) ?>" onsubmit="return confirm('Valider la facture ? Elle ne pourra plus être modifiée.');">
                <?= csrf_field() ?><input type="hidden" name="factureId" value="<?= (int) $facture['Id'] ?>">
                <button class="btn btn-success">Valider la facture</button>
            </form>
        <?php endif; ?>
        <a href="<?= h(url('facture/print', ['id' => $facture['Id']])) ?>" class="btn btn-outline-primary"><i class="fa fa-print"></i> Imprimer / PDF</a>
        <a href="<?= h(url('facture/index')) ?>" class="btn btn-dark">Retour</a>
    </div>
</div>

<div class="row g-3 mb-3">
    <div class="col-md-6"><div class="card h-100"><div class="card-body">
        <div class="small text-muted">Client</div>
        <div class="fw-bold"><?= h($facture['NomSociete']) ?></div>
        <div class="small"><?= h($facture['Adresse']) ?></div>
    </div></div></div>
    <div class="col-md-6"><div class="card h-100"><div class="card-body">
        <div class="d-flex justify-content-between"><span class="text-muted">Date</span><span><?= date_fr($facture['DateFacture']) ?></span></div>
        <div class="d-flex justify-content-between"><span class="text-muted">Taux de TVA</span><span><?= h(rtrim(rtrim((string) $facture['TauxTVA'], '0'), '.')) ?> %</span></div>
    </div></div></div>
</div>

<div class="card shadow-sm border-0">
    <div class="card-header bg-brand text-white">Lignes</div>
    <div class="card-body">
        <table class="table align-middle">
            <thead><tr><th>Désignation</th><th class="text-end">Quantité</th><th class="text-end">Prix unitaire</th><th class="text-end">Total</th><?php if ($brouillon): ?><th></th><?php endif; ?></tr></thead>
            <tbody>
            <?php if (!$lignes): ?><tr><td colspan="5" class="text-muted text-center">Aucune ligne.</td></tr><?php endif; ?>
            <?php foreach ($lignes as $l): ?>
                <tr>
                    <td><?= h($l['Designation']) ?></td>
                    <td class="text-end"><?= h(rtrim(rtrim((string) $l['Quantite'], '0'), '.')) ?></td>
                    <td class="text-end"><?= fcfa($l['PrixUnitaire']) ?></td>
                    <td class="text-end"><?= fcfa($l['TotalLigne']) ?></td>
                    <?php if ($brouillon): ?>
                        <td class="text-end">
                            <form method="post" action="<?= h(url('facture/supprimerligne')) ?>" onsubmit="return confirm('Supprimer cette ligne ?');">
                                <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $l['Id'] ?>">
                                <button class="btn btn-outline-danger btn-sm" aria-label="Supprimer la ligne"><i class="fa fa-trash"></i></button>
                            </form>
                        </td>
                    <?php endif; ?>
                </tr>
            <?php endforeach; ?>
            </tbody>
            <tfoot>
                <tr><th colspan="3" class="text-end">Montant HT</th><th class="text-end"><?= fcfa($facture['MontantHT']) ?></th><?php if ($brouillon): ?><th></th><?php endif; ?></tr>
                <tr><th colspan="3" class="text-end">TVA</th><th class="text-end"><?= fcfa($facture['MontantTVA']) ?></th><?php if ($brouillon): ?><th></th><?php endif; ?></tr>
                <tr class="table-primary"><th colspan="3" class="text-end">Montant TTC</th><th class="text-end"><?= fcfa($facture['MontantTTC']) ?></th><?php if ($brouillon): ?><th></th><?php endif; ?></tr>
            </tfoot>
        </table>

        <?php if ($brouillon): ?>
            <form method="post" action="<?= h(url('facture/ligne')) ?>" class="row g-2 align-items-end border-top pt-3">
                <?= csrf_field() ?><input type="hidden" name="factureId" value="<?= (int) $facture['Id'] ?>">
                <div class="col-md-6"><label class="form-label" for="designation">Désignation</label><input class="form-control" id="designation" name="designation" required></div>
                <div class="col-md-2"><label class="form-label" for="quantite">Quantité</label><input class="form-control" id="quantite" name="quantite" inputmode="decimal" value="1" required></div>
                <div class="col-md-2"><label class="form-label" for="prixUnitaire">Prix unitaire</label><input class="form-control" id="prixUnitaire" name="prixUnitaire" inputmode="decimal" required></div>
                <div class="col-md-2"><button class="btn btn-primary w-100">Ajouter</button></div>
            </form>
        <?php endif; ?>
    </div>
</div>
