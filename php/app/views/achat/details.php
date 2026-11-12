<?php
$titre = 'Achat n° ' . (int) $a['Numero'];
$onglet = 'index';
require __DIR__ . '/_onglets.php';
$reste = $a['Statut'] === 'Validé' ? max(0, round((float) $a['Total'] - (float) $a['Regle'], 2)) : 0.0;
?>
<div class="d-flex flex-wrap align-items-center gap-2 mb-3">
    <h2 class="h5 mb-0">Achat n° <?= (int) $a['Numero'] ?> du <?= date_fr($a['DateAchat']) ?></h2>
    <span class="badge <?= $a['Statut'] === 'Annulé' ? 'bg-secondary' : ($reste > 0 ? 'bg-warning text-dark' : 'bg-success') ?>"><?= $a['Statut'] === 'Annulé' ? 'Annulé' : ($reste > 0 ? 'Non soldé' : 'Soldé') ?></span>
    <a class="btn btn-sm btn-outline-secondary ms-auto" href="<?= h(url('achat/index')) ?>"><i class="fa fa-arrow-left"></i> Retour à la liste</a>
    <?php if ($a['Statut'] === 'Validé'): ?>
        <form method="post" action="<?= h(url('achat/annuler')) ?>" onsubmit="return confirm('Annuler cet achat ? Les quantités sortiront du stock et les paiements par la caisse seront remboursés.')">
            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $a['Id'] ?>">
            <button class="btn btn-sm btn-outline-danger"><i class="fa fa-ban"></i> Annuler l'achat</button>
        </form>
    <?php endif; ?>
</div>

<div class="row g-3 mb-3">
    <div class="col-lg-8">
        <div class="card shadow-sm border-0 h-100"><div class="card-body">
            <dl class="row mb-0 small">
                <dt class="col-sm-3">Fournisseur</dt><dd class="col-sm-9"><?= $a['Fournisseur'] ? h($a['CodeFournisseur'] . ' · ' . $a['Fournisseur']) : '—' ?></dd>
                <dt class="col-sm-3">Dépôt</dt><dd class="col-sm-9"><?= h((string) $a['Depot']) ?></dd>
                <dt class="col-sm-3">Référence</dt><dd class="col-sm-9"><?= h((string) $a['Reference']) ?: '—' ?></dd>
                <dt class="col-sm-3">Saisi par</dt><dd class="col-sm-9"><?= h((string) $a['Utilisateur']) ?>, le <?= date_fr($a['DateCreation'], 'd/m/Y H:i') ?></dd>
                <?php if ($a['DateAnnulation']): ?><dt class="col-sm-3">Annulé le</dt><dd class="col-sm-9"><?= date_fr($a['DateAnnulation'], 'd/m/Y H:i') ?></dd><?php endif; ?>
                <?php if ($a['Commentaire']): ?><dt class="col-sm-3">Commentaire</dt><dd class="col-sm-9"><?= h($a['Commentaire']) ?></dd><?php endif; ?>
            </dl>
        </div></div>
    </div>
    <div class="col-lg-4">
        <div class="card shadow-sm border-0 h-100"><div class="card-body">
            <div class="d-flex justify-content-between"><span>Total</span><strong><?= fcfa($a['Total']) ?> FCFA</strong></div>
            <div class="d-flex justify-content-between"><span>Réglé</span><strong><?= fcfa($a['Regle']) ?> FCFA</strong></div>
            <div class="d-flex justify-content-between fs-5 <?= $reste > 0 ? 'text-danger' : '' ?>"><span>Reste à payer</span><strong><?= fcfa($reste) ?> FCFA</strong></div>
        </div></div>
    </div>
</div>

<div class="card shadow-sm border-0 mb-3">
    <div class="card-header bg-white fw-semibold">Produits achetés</div>
    <div class="card-body table-responsive">
        <table class="table align-middle mb-0">
            <thead class="table-dark"><tr><th>Code</th><th>Produit</th><th class="text-end">Quantité</th><th class="text-end">Prix unitaire</th><th class="text-end">Montant</th></tr></thead>
            <tbody>
            <?php foreach ($lignes as $l): ?>
                <tr><td><?= h($l['Code']) ?></td><td><?= h($l['Nom']) ?></td><td class="text-end"><?= quantite_fr($l['Quantite']) ?> <?= h($l['Unite']) ?></td>
                    <td class="text-end text-nowrap"><?= quantite_fr($l['PrixUnitaire']) ?></td><td class="text-end text-nowrap"><?= fcfa($l['Montant']) ?></td></tr>
            <?php endforeach; ?>
            </tbody>
            <tfoot><tr class="fw-bold"><td colspan="4" class="text-end">Total</td><td class="text-end text-nowrap"><?= fcfa($a['Total']) ?> FCFA</td></tr></tfoot>
        </table>
    </div>
</div>

<div class="card shadow-sm border-0">
    <div class="card-header bg-white fw-semibold">Règlements</div>
    <div class="card-body">
        <?php if ($reglements): ?>
        <div class="table-responsive"><table class="table align-middle small">
            <thead><tr><th>Date</th><th>Mode</th><th>Payé par</th><th>Saisi par</th><th class="text-end">Montant</th></tr></thead>
            <tbody>
            <?php foreach ($reglements as $r): ?>
                <tr><td class="text-nowrap"><?= date_fr($r['DateReglement'], 'd/m/Y H:i') ?></td><td><?= h((string) $r['Mode']) ?></td>
                    <td><?= $r['OperationCaisseId'] ? 'Caisse ' . h($r['ChkCode'] . ' · journée ' . $r['NumeroJournee']) : 'Hors caisse' ?></td>
                    <td><?= h((string) $r['Utilisateur']) ?></td><td class="text-end text-nowrap"><?= fcfa($r['Montant']) ?></td></tr>
            <?php endforeach; ?>
            </tbody>
        </table></div>
        <?php else: ?>
            <p class="text-muted">Aucun règlement : achat à crédit.</p>
        <?php endif; ?>
        <?php if ($reste > 0): ?>
        <form method="post" action="<?= h(url('achat/reglement')) ?>" class="row g-2 align-items-end border-top pt-3">
            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $a['Id'] ?>">
            <div class="col-md-3"><label class="form-label small" for="paiement">Payé</label>
                <select class="form-select" id="paiement" name="paiement" onchange="document.getElementById('blocJournee').classList.toggle('d-none', this.value !== 'caisse')">
                    <option value="caisse">Par la caisse (décaissement)</option><option value="hors">Hors caisse (virement, chèque…)</option>
                </select></div>
            <div class="col-md-2"><label class="form-label small" for="montant">Montant</label><input class="form-control text-end" id="montant" name="montant" inputmode="decimal" value="<?= quantite_fr($reste, false) ?>" required></div>
            <div class="col-md-2"><label class="form-label small" for="mode">Mode de paiement</label>
                <select class="form-select" id="mode" name="mode"><?php foreach ($modes as $m): ?><option value="<?= (int) $m['Id'] ?>"><?= h($m['Libelle']) ?></option><?php endforeach; ?></select></div>
            <div class="col-md-3" id="blocJournee"><label class="form-label small" for="journee">Journée de caisse</label>
                <select class="form-select" id="journee" name="journee">
                    <?php if (!$journees): ?><option value="">Aucune journée ouverte</option><?php endif; ?>
                    <?php foreach ($journees as $j): ?><option value="<?= (int) $j['Id'] ?>"><?= h($j['ChkCode'] . ' · ' . $j['NumeroJournee']) ?></option><?php endforeach; ?>
                </select></div>
            <div class="col-md-2"><button class="btn btn-success w-100"><i class="fa fa-check"></i> Régler</button></div>
        </form>
        <?php endif; ?>
    </div>
</div>
