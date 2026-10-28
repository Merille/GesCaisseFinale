<?php
$titre = 'Vente ' . $vente['Numero'];
$estRetour = (bool) $vente['CommandeOrigineId'];
$peutFacturer = !$estRetour && $vente['Statut'] === 'Payée' && !$vente['FactureId'];
$peutRetour = $peutRembourser && !$estRetour && in_array($vente['Statut'], ['Payée', 'Remboursée en partie'], true) && $restant > 0;
$peutAnnuler = $peutRembourser && !$estRetour && $vente['Statut'] === 'Payée' && !$vente['FactureId'] && $vente['StatutJournee'] === 'Ouverte';
?>
<div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-3">
    <h4 class="mb-0"><?= $estRetour ? 'Retour' : 'Vente' ?> <?= h($vente['Numero']) ?>
        <?php $statut = $vente['Statut']; require __DIR__ . '/_statut.php'; ?></h4>
    <div class="d-flex flex-wrap gap-2">
        <a href="<?= h(url('pos/ticket', ['id' => $vente['Id'], 'imprimer' => 1])) ?>" target="_blank" class="btn btn-outline-primary"><i class="fa fa-print"></i> Réimprimer le ticket</a>
        <?php if ($peutRetour): ?>
            <button class="btn btn-warning" data-bs-toggle="modal" data-bs-target="#modalRetour"><i class="fa fa-rotate-left"></i> Retour / remboursement</button>
        <?php endif; ?>
        <?php if ($peutAnnuler): ?>
            <button class="btn btn-outline-danger" data-bs-toggle="modal" data-bs-target="#modalAnnuler"><i class="fa fa-ban"></i> Annuler la vente</button>
        <?php endif; ?>
        <a href="<?= h(url('vente/index', ['journee' => $vente['JourneeCaisseId']])) ?>" class="btn btn-dark">Ventes de la journée</a>
    </div>
</div>

<div class="row g-3 mb-3">
    <div class="col-md-3"><div class="card h-100 border-0 shadow-sm"><div class="card-body">
        <div class="small text-muted">Date</div><div class="fw-bold"><?= date_fr($vente['DateCommande'], 'd/m/Y H:i') ?></div>
        <div class="small text-muted mt-2">Caisse · journée</div>
        <div><a href="<?= h(url('journee/details', ['id' => $vente['JourneeCaisseId']])) ?>"><?= h($vente['ChkCode'] . ' · ' . $vente['NumeroJournee']) ?></a></div>
    </div></div></div>
    <div class="col-md-3"><div class="card h-100 border-0 shadow-sm"><div class="card-body">
        <div class="small text-muted">Vendeur</div><div class="fw-bold"><?= h($vente['Vendeur']) ?></div>
        <div class="small text-muted mt-2">Client</div><div><?= $vente['Client'] ? h($vente['Client']) : '—' ?></div>
    </div></div></div>
    <div class="col-md-3"><div class="card h-100 border-0 shadow-sm"><div class="card-body">
        <div class="small text-muted">Total TTC</div>
        <div class="fs-4 fw-bold <?= (float) $vente['TotalTTC'] < 0 ? 'text-danger' : '' ?>"><?= fcfa($vente['TotalTTC']) ?> FCFA</div>
        <?php if ((float) $vente['RemiseGlobale'] != 0): ?><div class="small text-muted">après remise globale de <?= fcfa($vente['RemiseGlobale']) ?><?= $vente['RemiseGlobaleTaux'] !== null ? ' (' . quantite_fr($vente['RemiseGlobaleTaux']) . ' %)' : '' ?></div><?php endif; ?>
        <div class="small text-muted">dont taxes <?= fcfa($vente['TotalTVA']) ?><?php $taxesVente = vente_taxes((int) $vente['Id']); if (count($taxesVente) > 0): ?> :
            <?= h(implode(' · ', array_map(fn($l, $m) => $l . ' ' . fcfa($m), array_keys($taxesVente), $taxesVente))) ?><?php endif; ?></div>
    </div></div></div>
    <div class="col-md-3"><div class="card h-100 border-0 shadow-sm"><div class="card-body">
        <?php if ($estRetour): ?>
            <div class="small text-muted">Vente d'origine</div>
            <div class="fw-bold"><a href="<?= h(url('vente/details', ['id' => $vente['CommandeOrigineId']])) ?>"><?= h($vente['NumeroOrigine']) ?></a></div>
        <?php else: ?>
            <div class="small text-muted">Facture</div>
            <?php if ($vente['FactureId']): ?>
                <div class="fw-bold"><a href="<?= h(url('facture/edit', ['id' => $vente['FactureId']])) ?>"><?= h($vente['NumeroFacture']) ?></a></div>
            <?php elseif ($peutFacturer): ?>
                <form method="post" action="<?= h(url('vente/facture')) ?>" class="mt-1" onsubmit="return confirm('Créer et valider une facture pour cette vente ?');">
                    <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $vente['Id'] ?>">
                    <?php if (!$vente['ClientId']): ?>
                        <select name="clientId" class="form-select form-select-sm mb-2" required aria-label="Client à facturer">
                            <option value="">-- Client à facturer --</option>
                            <?php foreach ($clients as $c): ?><option value="<?= (int) $c['Id'] ?>"><?= h($c['NomSociete']) ?></option><?php endforeach; ?>
                        </select>
                    <?php endif; ?>
                    <button class="btn btn-sm btn-success"><i class="fa fa-file-invoice"></i> Établir la facture</button>
                </form>
            <?php else: ?>
                <div class="text-muted">—</div>
            <?php endif; ?>
        <?php endif; ?>
        <?php if ($vente['Motif']): ?><div class="small text-muted mt-2">Motif</div><div><?= h($vente['Motif']) ?></div><?php endif; ?>
    </div></div></div>
</div>

<div class="row g-3">
    <div class="col-lg-8">
        <div class="card border-0 shadow-sm"><div class="card-header bg-brand text-white">Articles</div>
            <div class="card-body p-2 table-responsive">
                <table class="table align-middle mb-0">
                    <thead><tr><th>Article</th><th class="text-end">Qté</th><th class="text-end">Prix</th><th class="text-end">Remise</th><th class="text-end">Total TTC</th><?php if (!$estRetour): ?><th class="text-end">Retourné</th><?php endif; ?></tr></thead>
                    <tbody>
                    <?php foreach ($lignes as $l): ?>
                        <tr>
                            <td><?= h($l['Libelle']) ?></td>
                            <td class="text-end"><?= quantite_fr($l['Quantite']) ?></td>
                            <td class="text-end"><?= fcfa($l['PrixUnitaire']) ?></td>
                            <td class="text-end"><?= (float) $l['Remise'] > 0 ? quantite_fr($l['Remise']) . ' %' : '' ?></td>
                            <td class="text-end fw-semibold"><?= fcfa($l['TotalTTC']) ?></td>
                            <?php if (!$estRetour): ?><td class="text-end"><?= (float) $l['QteRetournee'] > 0 ? quantite_fr($l['QteRetournee']) : '' ?></td><?php endif; ?>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
    <div class="col-lg-4">
        <div class="card border-0 shadow-sm mb-3"><div class="card-header bg-brand text-white"><?= $estRetour ? 'Remboursement' : 'Règlements' ?></div>
            <ul class="list-group list-group-flush">
                <?php foreach ($paiements as $p): ?>
                    <li class="list-group-item d-flex justify-content-between"><span><?= h($p['Libelle']) ?></span><span class="fw-semibold"><?= fcfa($p['MontantRecu']) ?></span></li>
                <?php endforeach; ?>
                <?php if ((float) $vente['MonnaieRendue'] > 0): ?>
                    <li class="list-group-item d-flex justify-content-between text-muted"><span>Monnaie rendue</span><span><?= fcfa($vente['MonnaieRendue']) ?></span></li>
                <?php endif; ?>
            </ul>
        </div>
        <?php if ($retours): ?>
            <div class="card border-0 shadow-sm"><div class="card-header bg-warning">Retours</div>
                <ul class="list-group list-group-flush">
                    <?php foreach ($retours as $r): ?>
                        <li class="list-group-item d-flex justify-content-between">
                            <a href="<?= h(url('vente/details', ['id' => $r['Id']])) ?>"><?= h($r['Numero']) ?></a>
                            <span class="text-danger fw-semibold"><?= fcfa($r['TotalTTC']) ?></span>
                        </li>
                    <?php endforeach; ?>
                </ul>
            </div>
        <?php endif; ?>
    </div>
</div>

<?php if ($peutRetour): ?>
<div class="modal fade" id="modalRetour" tabindex="-1" aria-labelledby="retourTitre" aria-hidden="true">
    <div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">
        <form class="modal-content" method="post" action="<?= h(url('vente/retour')) ?>">
            <div class="modal-header bg-brand text-white">
                <h5 class="modal-title" id="retourTitre">Retour / remboursement · <?= h($vente['Numero']) ?></h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>
            </div>
            <div class="modal-body">
                <?= csrf_field() ?>
                <input type="hidden" name="id" value="<?= (int) $vente['Id'] ?>">
                <input type="hidden" name="cle" value="<?= h(bin2hex(random_bytes(12))) ?>">
                <table class="table align-middle">
                    <thead><tr><th>Article</th><th class="text-end">Vendu</th><th class="text-end">Déjà retourné</th><th style="width:140px">Quantité retournée</th></tr></thead>
                    <tbody>
                    <?php foreach ($lignes as $l): $reste = (float) $l['Quantite'] - (float) $l['QteRetournee']; ?>
                        <tr>
                            <td><?= h($l['Libelle']) ?></td>
                            <td class="text-end"><?= quantite_fr($l['Quantite']) ?></td>
                            <td class="text-end"><?= (float) $l['QteRetournee'] > 0 ? quantite_fr($l['QteRetournee']) : '' ?></td>
                            <td><input class="form-control form-control-sm text-end" name="qte[<?= (int) $l['Id'] ?>]" inputmode="decimal"
                                       value="0" <?= $reste <= 0 ? 'disabled' : '' ?> aria-label="Quantité retournée : <?= h($l['Libelle']) ?>"
                                       data-max="<?= h((string) $reste) ?>"></td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
                <div class="d-flex justify-content-end mb-3"><button type="button" class="btn btn-sm btn-outline-secondary" id="retourTout">Tout retourner</button></div>
                <div class="row g-3">
                    <div class="col-md-6">
                        <label class="form-label" for="retourJournee">Journée où rembourser</label>
                        <select class="form-select" id="retourJournee" name="journeeId" required>
                            <?php if (!$journeesOuvertes): ?><option value="">Aucune journée ouverte</option><?php endif; ?>
                            <?php foreach ($journeesOuvertes as $j): ?>
                                <option value="<?= (int) $j['Id'] ?>"><?= h($j['ChkCode']) ?> · <?= date_fr($j['DateJournee']) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                    <div class="col-md-6">
                        <label class="form-label" for="retourMode">Mode de remboursement</label>
                        <select class="form-select" id="retourMode" name="modeId" required>
                            <?php foreach ($modes as $m): ?><option value="<?= (int) $m['Id'] ?>" <?= pos_est_especes($m) ? 'selected' : '' ?>><?= h($m['Libelle']) ?></option><?php endforeach; ?>
                        </select>
                    </div>
                    <div class="col-12"><label class="form-label" for="retourMotif">Motif</label><input class="form-control" id="retourMotif" name="motif" placeholder="Ex : produit défectueux"></div>
                </div>
                <div class="form-text mt-2">Le montant remboursé est calculé au prorata de chaque ligne (remise comprise). Il sort de la caisse en décaissement validé, et le stock est remis.</div>
            </div>
            <div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Annuler</button><button class="btn btn-warning" <?= $journeesOuvertes ? '' : 'disabled' ?>>Enregistrer le retour</button></div>
        </form>
    </div>
</div>
<?php endif; ?>

<?php if ($peutAnnuler): ?>
<div class="modal fade" id="modalAnnuler" tabindex="-1" aria-labelledby="annulerTitre" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <form class="modal-content" method="post" action="<?= h(url('vente/annuler')) ?>">
            <div class="modal-header bg-danger text-white">
                <h5 class="modal-title" id="annulerTitre">Annuler la vente <?= h($vente['Numero']) ?></h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>
            </div>
            <div class="modal-body">
                <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $vente['Id'] ?>">
                <p>Les encaissements de cette vente passeront « Rejeté » (ils sortent des totaux de la journée) et le stock sera remis. Rendez l'argent au client.</p>
                <label class="form-label" for="annulerMotif">Motif</label>
                <input class="form-control" id="annulerMotif" name="motif" placeholder="Ex : erreur de saisie" required>
            </div>
            <div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Retour</button><button class="btn btn-danger">Annuler la vente</button></div>
        </form>
    </div>
</div>
<?php endif; ?>

<?php ob_start(); ?>
<script>
    (function () {
        const tout = document.getElementById('retourTout');
        if (tout) tout.addEventListener('click', function () {
            document.querySelectorAll('#modalRetour input[data-max]').forEach(function (i) {
                if (!i.disabled) i.value = String(i.dataset.max).replace('.', ',');
            });
        });
    })();
</script>
<?php $scripts = ob_get_clean(); ?>
