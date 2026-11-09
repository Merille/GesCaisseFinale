<?php
$titre = 'Journée de caisse';
$ouverte = $journee['Statut'] === 'Ouverte';
?>
<div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-3">
    <h4 class="mb-0">Journée <?= h($journee['NumeroJournee']) ?> <small class="text-muted fs-6">— <?= h($journee['ChkCode'] . ' · ' . $journee['ChkDescription']) ?>, <?= date_fr($journee['DateJournee']) ?></small></h4>
    <div class="d-flex flex-wrap gap-2">
        <?php if ($ouverte): ?>
            <a href="<?= h(url('pos/index', ['journee' => $journee['Id']])) ?>" class="btn btn-primary"><i class="fa fa-store"></i> Ouvrir le POS</a>
            <button class="btn btn-success" data-bs-toggle="modal" data-bs-target="#modalEncaissement">+ Encaissement</button>
            <button class="btn btn-outline-danger" data-bs-toggle="modal" data-bs-target="#modalDecaissement">− Décaissement</button>
            <button class="btn btn-outline-primary" data-bs-toggle="modal" data-bs-target="#modalReglement"><i class="fa fa-address-book"></i> Règlement client</button>
            <button class="btn btn-warning" data-bs-toggle="modal" data-bs-target="#modalCloture">Clôturer</button>
            <form method="post" action="<?= h(url('journee/supprimer')) ?>" onsubmit="return confirm('Supprimer cette journée et toutes ses opérations ?');">
                <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $journee['Id'] ?>">
                <button class="btn btn-danger">Supprimer</button>
            </form>
        <?php endif; ?>
        <a href="<?= h(url('caisse/details', ['id' => $journee['CaisseId']])) ?>" class="btn btn-dark">Retour</a>
    </div>
</div>

<div class="row g-3 mb-4">
    <?php foreach ([['Initial', $journee['SoldeInitial'], 'border-primary'], ['Encaissements', $totalEncaisse, 'border-success'],
                    ['Décaissements', $totalDecaisse, 'border-danger'], ['Solde actuel', $soldeActuel, 'border-dark']] as [$lib, $val, $cls]): ?>
        <div class="col-md-3 col-6">
            <div class="card <?= $cls ?> h-100"><div class="card-body text-center"><h6><?= $lib ?></h6><h3 class="mb-0"><?= fcfa($val) ?></h3></div></div>
        </div>
    <?php endforeach; ?>
</div>

<?php if (!$ouverte): ?>
    <div class="card shadow-sm mb-4">
        <div class="card-header bg-secondary text-white">Résultat de la clôture</div>
        <div class="card-body">
            <div class="row mb-3">
                <div class="col-md-4"><strong>Solde final compté :</strong> <?= fcfa($journee['SoldeFinal']) ?></div>
                <div class="col-md-4"><strong>Écart (compté − théorique) :</strong>
                    <span class="<?= (float) $journee['EcartCloture'] == 0 ? 'text-success' : 'text-danger fw-bold' ?>"><?= fcfa($journee['EcartCloture'] ?? 0) ?></span></div>
                <div class="col-md-4"><strong>Clôturée le :</strong> <?= date_fr($journee['DateFermeture'], 'd/m/Y H:i') ?></div>
            </div>
            <?php if (!empty($journee['NoteCloture'])): ?><p><strong>Note :</strong> <?= h($journee['NoteCloture']) ?></p><?php endif; ?>
            <table class="table table-sm table-bordered mb-0">
                <thead class="table-light"><tr><th>Mode de paiement</th><th class="text-end">Théorique</th><th class="text-end">Compté</th><th class="text-end">Écart</th></tr></thead>
                <tbody>
                <?php foreach ($comptages as $c): $ecart = (float) $c['MontantCompte'] - (float) $c['MontantTheorique']; ?>
                    <tr>
                        <td><?= h($c['Libelle']) ?></td>
                        <td class="text-end"><?= fcfa($c['MontantTheorique']) ?></td>
                        <td class="text-end"><?= fcfa($c['MontantCompte']) ?></td>
                        <td class="text-end <?= $ecart == 0 ? 'text-success' : 'text-danger' ?>"><?= fcfa($ecart) ?></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
    <div class="alert alert-secondary">Cette journée est clôturée. Aucune opération possible.</div>
<?php endif; ?>

<div class="card shadow-sm mb-4">
    <div class="card-header bg-dark text-white">Totaux par mode de paiement</div>
    <div class="card-body p-0">
        <table class="table table-bordered mb-0">
            <thead class="table-light"><tr><th>Mode de paiement</th><th class="text-end">Encaissements</th><th class="text-end">Décaissements</th><th class="text-end">Net</th></tr></thead>
            <tbody>
            <?php if (!$totauxParMode): ?><tr><td colspan="4" class="text-center text-muted">Aucune opération.</td></tr><?php endif; ?>
            <?php foreach ($totauxParMode as $t): ?>
                <tr>
                    <td><?= h($t['Libelle']) ?></td>
                    <td class="text-end text-success"><?= fcfa($t['Encaisse']) ?></td>
                    <td class="text-end text-danger"><?= fcfa($t['Decaisse']) ?></td>
                    <td class="text-end fw-bold"><?= fcfa($t['Net']) ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<div class="card shadow-sm">
    <div class="card-header bg-brand text-white d-flex justify-content-between align-items-center">
        <span>Historique des opérations</span>
        <a href="<?= h(url('journee/printoperations', ['journeeId' => $journee['Id']])) ?>" class="btn btn-light btn-sm"><i class="fa fa-print"></i> Imprimer les opérations</a>
    </div>
    <div class="card-body p-2">
        <div class="table-responsive">
            <table id="operationsTable" class="table table-hover align-middle mb-0">
                <thead><tr><th>Date</th><th>Motif</th><th>Description</th><th>Tiers</th><th>Mode de paiement</th><th class="text-end">Montant</th><th>Type</th><th>Statut</th><?php if (peut_valider()): ?><th></th><?php endif; ?></tr></thead>
                <tbody>
                <?php foreach ($operations as $op): ?>
                    <tr>
                        <td class="text-nowrap" data-order="<?= h($op['DateOperation']) ?>-<?= sprintf('%09d', $op['Id']) ?>"><?= date_fr($op['DateOperation'], 'd/m/Y H:i') ?></td>
                        <td><?= h($op['MotifLibelle']) ?></td>
                        <td><?= h($op['Libelle']) ?></td>
                        <td><?= h($op['Tiers'] ?? '-') ?></td>
                        <td><?= h($op['ModeLibelle']) ?></td>
                        <td class="text-end text-nowrap" data-order="<?= (float) $op['Montant'] ?>">
                            <?php if ($op['StatutValidation'] === STATUT_REJETE): ?>
                                <s class="text-muted" title="Opération rejetée : exclue des totaux"><?= fcfa($op['Montant']) ?></s> <small class="text-muted">(rejetée)</small>
                            <?php else: ?><?= fcfa($op['Montant']) ?><?php endif; ?>
                        </td>
                        <td><span class="badge <?= $op['TypeOperation'] === 'Encaissement' ? 'bg-success' : 'bg-danger' ?>"><?= h($op['TypeOperation']) ?></span></td>
                        <td>
                            <span class="badge <?= ['Validé' => 'bg-success', 'Rejeté' => 'bg-danger'][$op['StatutValidation']] ?? 'bg-secondary' ?>"><?= h($op['StatutValidation']) ?></span>
                            <?php if ($op['EstJustifie']): ?><span class="badge bg-info text-dark">Justifié</span><?php endif; ?>
                            <?php if ($op['Valideur']): ?><div class="small text-muted">par <?= h($op['Valideur']) ?></div><?php endif; ?>
                        </td>
                        <?php if (peut_valider()): ?>
                            <td>
                                <button type="button" class="btn btn-outline-primary btn-sm" data-bs-toggle="modal" data-bs-target="#modalValidation"
                                        data-id="<?= (int) $op['Id'] ?>" data-justifie="<?= $op['EstJustifie'] ? '1' : '0' ?>"
                                        data-statut="<?= h($op['StatutValidation']) ?>" data-observation="<?= h($op['Observation']) ?>">Modifier</button>
                            </td>
                        <?php endif; ?>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<?php if ($ouverte): ?>
    <?php $type = 'Encaissement'; $idModal = 'modalEncaissement'; require __DIR__ . '/_form_operation.php'; ?>
    <?php $type = 'Décaissement'; $idModal = 'modalDecaissement'; require __DIR__ . '/_form_operation.php'; ?>

    <div class="modal fade" id="modalReglement" tabindex="-1">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-brand text-white">
                    <h5 class="modal-title">Règlement d'un client en compte</h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>
                </div>
                <form method="post" action="<?= h(url('journee/reglement')) ?>">
                    <?= csrf_field() ?>
                    <input type="hidden" name="journeeId" value="<?= (int) $journee['Id'] ?>">
                    <div class="modal-body">
                        <?php if (!$clientsEnCompte): ?>
                            <div class="alert alert-info mb-0">Aucun client en compte : cochez « Client en compte » sur la fiche du tiers (menu Tiers).</div>
                        <?php else: ?>
                            <div class="mb-3">
                                <label class="form-label" for="reglementClient">Client</label>
                                <select class="form-select" id="reglementClient" name="clientId" required>
                                    <option value="">-- Choisir --</option>
                                    <?php foreach ($clientsEnCompte as $c): ?>
                                        <option value="<?= (int) $c['Id'] ?>" data-du="<?= h((string) round($c['Du'])) ?>"><?= h($c['NomSociete'] . ' (' . $c['CodeClient'] . ') — dû ' . fcfa($c['Du']) . ' FCFA') ?></option>
                                    <?php endforeach; ?>
                                </select>
                            </div>
                            <div class="row g-3 mb-3">
                                <div class="col-6">
                                    <label class="form-label" for="reglementMontant">Montant (FCFA)</label>
                                    <input class="form-control" id="reglementMontant" name="montant" inputmode="decimal" required>
                                </div>
                                <div class="col-6">
                                    <label class="form-label" for="reglementMode">Mode de paiement</label>
                                    <select class="form-select" id="reglementMode" name="modePaiementId" required>
                                        <?php foreach ($modes as $m): ?><option value="<?= (int) $m['Id'] ?>" <?= preg_match('/^esp/i', (string) $m['Libelle']) ? 'selected' : '' ?>><?= h($m['Libelle']) ?></option><?php endforeach; ?>
                                    </select>
                                </div>
                            </div>
                            <label class="form-label" for="reglementObservation">Observation</label>
                            <input class="form-control" id="reglementObservation" name="observation" placeholder="Ex : chèque n° 123, reçu remis">
                            <p class="small text-muted mt-3 mb-0">Le règlement est un encaissement de la journée (motif « Règlement client ») ; il diminue le solde dû du client, sans le dépasser.</p>
                        <?php endif; ?>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Annuler</button>
                        <?php if ($clientsEnCompte): ?><button class="btn btn-primary">Enregistrer le règlement</button><?php endif; ?>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <div class="modal fade" id="modalCloture" tabindex="-1">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header bg-warning">
                    <h5 class="modal-title">Clôture de la journée — comptage</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Fermer"></button>
                </div>
                <form method="post" action="<?= h(url('journee/cloturer')) ?>">
                    <?= csrf_field() ?>
                    <input type="hidden" name="id" value="<?= (int) $journee['Id'] ?>">
                    <div class="modal-body">
                        <p class="text-muted small">Saisissez, pour chaque mode de paiement, le montant réellement compté. L'écart avec le montant théorique (net des opérations de la journée) est enregistré.</p>
                        <table class="table table-bordered align-middle" id="tableCloture">
                            <thead class="table-light"><tr><th>Mode de paiement</th><th class="text-end">Théorique</th><th style="width:180px;">Compté</th><th class="text-end">Écart</th></tr></thead>
                            <tbody>
                            <?php foreach ($totauxParMode as $i => $t): ?>
                                <tr data-theorique="<?= h((string) $t['Net']) ?>">
                                    <td><?= h($t['Libelle']) ?>
                                        <input type="hidden" name="comptages[<?= $i ?>][modePaiementId]" value="<?= h((string) ($t['ModePaiementId'] ?? '')) ?>"></td>
                                    <td class="text-end"><?= fcfa($t['Net']) ?></td>
                                    <td><input class="form-control text-end" inputmode="decimal" name="comptages[<?= $i ?>][montantCompte]" value="<?= h((string) round($t['Net'])) ?>"></td>
                                    <td class="text-end ecart">0</td>
                                </tr>
                            <?php endforeach; ?>
                            <?php if (!$totauxParMode): ?><tr><td colspan="4" class="text-center text-muted">Aucune opération : rien à compter.</td></tr><?php endif; ?>
                            </tbody>
                            <tfoot class="fw-bold"><tr><td>Total</td><td class="text-end" id="totalTheorique">0</td><td class="text-end" id="totalCompte">0</td><td class="text-end" id="ecartGlobal">0</td></tr></tfoot>
                        </table>
                        <label class="form-label">Note de clôture</label>
                        <textarea name="noteCloture" class="form-control" rows="2"></textarea>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Annuler</button>
                        <button class="btn btn-warning" onclick="return confirm('Clôturer définitivement cette journée ?');">Clôturer la journée</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
<?php endif; ?>

<?php if (peut_valider()): ?>
    <div class="modal fade" id="modalValidation" tabindex="-1">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header bg-brand text-white">
                    <h5 class="modal-title">Validation de l'opération</h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>
                </div>
                <form method="post" action="<?= h(url('journee/validation')) ?>">
                    <?= csrf_field() ?>
                    <input type="hidden" name="journeeId" value="<?= (int) $journee['Id'] ?>">
                    <input type="hidden" name="id" id="valId">
                    <div class="modal-body">
                        <div class="form-check mb-3">
                            <input class="form-check-input" type="checkbox" value="1" name="estJustifie" id="valJustifie">
                            <label class="form-check-label" for="valJustifie">Ce mouvement a été justifié</label>
                        </div>
                        <div class="d-flex gap-4 mb-3">
                            <?php foreach (['En attente', 'Validé', 'Rejeté'] as $i => $st): ?>
                                <div class="form-check">
                                    <input class="form-check-input" type="radio" name="statutValidation" id="valSt<?= $i ?>" value="<?= h($st) ?>">
                                    <label class="form-check-label" for="valSt<?= $i ?>"><?= h($st) ?></label>
                                </div>
                            <?php endforeach; ?>
                        </div>
                        <label class="form-label">Valideur</label>
                        <input class="form-control mb-3" value="<?= h(user()['nomComplet']) ?>" readonly>
                        <label class="form-label" for="valObservation">Observation</label>
                        <textarea name="observation" id="valObservation" class="form-control" rows="3"></textarea>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Annuler</button>
                        <button class="btn btn-primary">Enregistrer</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
<?php endif; ?>

<?php ob_start(); ?>
<script>
    (function () {
        const fmt = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 });
        const nombre = (v) => parseFloat(String(v).replace(/[\s  ]/g, '').replace(',', '.')) || 0;

        const validation = document.getElementById('modalValidation');
        if (validation) {
            validation.addEventListener('show.bs.modal', function (e) {
                const b = e.relatedTarget;
                document.getElementById('valId').value = b.dataset.id;
                document.getElementById('valJustifie').checked = b.dataset.justifie === '1';
                document.getElementById('valObservation').value = b.dataset.observation || '';
                validation.querySelectorAll('input[name=statutValidation]').forEach(r => r.checked = (r.value === b.dataset.statut));
            });
        }

        // Règlement client : montant proposé = solde dû du client choisi.
        const reglementClient = document.getElementById('reglementClient');
        if (reglementClient) {
            reglementClient.addEventListener('change', function () {
                const o = this.selectedOptions[0];
                document.getElementById('reglementMontant').value = o && o.dataset.du && Number(o.dataset.du) > 0 ? o.dataset.du : '';
            });
        }
        const cloture = document.getElementById('modalCloture');
        function recalculer() {
            let th = 0, co = 0;
            cloture.querySelectorAll('#tableCloture tbody tr[data-theorique]').forEach(function (tr) {
                const t = nombre(tr.dataset.theorique);
                const c = nombre(tr.querySelector('input[name$="[montantCompte]"]').value);
                const ecart = c - t;
                const cell = tr.querySelector('.ecart');
                cell.textContent = fmt.format(ecart);
                cell.className = 'text-end ecart ' + (ecart === 0 ? 'text-success' : 'text-danger fw-bold');
                th += t; co += c;
            });
            document.getElementById('totalTheorique').textContent = fmt.format(th);
            document.getElementById('totalCompte').textContent = fmt.format(co);
            document.getElementById('ecartGlobal').textContent = fmt.format(co - th);
        }
        if (cloture) {
            cloture.addEventListener('shown.bs.modal', recalculer);
            cloture.addEventListener('input', recalculer);
        }
    })();
</script>
<?php $scripts = ob_get_clean(); ?>
<?php ob_start(); ?>
<script>
    listeDataTable('#operationsTable', {
        pageLength: 20,
        lengthMenu: [20, 50, 100],
        order: [[0, 'desc']],
        columnDefs: [{ orderable: false, targets: <?= peut_valider() ? '[6, -1]' : '[6]' ?> }]
    });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
