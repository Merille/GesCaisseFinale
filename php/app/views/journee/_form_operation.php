<?php
// Fenêtre de saisie d'une opération. Variables : $type ('Encaissement' / 'Décaissement'), $idModal.
$suffixe = $type === 'Encaissement' ? 'Enc' : 'Dec';
?>
<div class="modal fade" id="<?= $idModal ?>" tabindex="-1">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header bg-brand text-white">
                <h5 class="modal-title">Nouvelle opération : <?= h(strtolower($type)) ?></h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>
            </div>
            <form method="post" action="<?= h(url('journee/operation')) ?>">
                <?= csrf_field() ?>
                <input type="hidden" name="journeeId" value="<?= (int) $journee['Id'] ?>">
                <input type="hidden" name="typeOperation" value="<?= h($type) ?>">
                <div class="modal-body">
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Tiers</label>
                            <select name="clientId" class="form-select">
                                <option value="">Aucun</option>
                                <?php foreach ($clients as $c): ?><option value="<?= (int) $c['Id'] ?>"><?= h($c['NomSociete']) ?></option><?php endforeach; ?>
                            </select>
                        </div>
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Montant</label>
                            <input name="montant" inputmode="decimal" class="form-control" placeholder="0" required>
                        </div>
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Motif</label>
                            <select name="motifId" class="form-select">
                                <option value="">-- Choisir un motif --</option>
                                <?php foreach ($motifs as $m): ?><option value="<?= (int) $m['ID'] ?>"><?= h($m['LibelleMotif']) ?></option><?php endforeach; ?>
                            </select>
                        </div>
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Description</label>
                            <input name="libelle" class="form-control" placeholder="Description de l'opération">
                        </div>
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Mode de paiement</label>
                            <select name="modePaiementId" class="form-select">
                                <option value="">-- Choisir un mode de paiement --</option>
                                <?php foreach ($modes as $mp): ?><option value="<?= (int) $mp['Id'] ?>"><?= h($mp['Libelle']) ?></option><?php endforeach; ?>
                            </select>
                        </div>
                    </div>
                    <div class="card mt-2">
                        <div class="card-header bg-light">Validations</div>
                        <div class="card-body">
                            <div class="form-check mb-3">
                                <input class="form-check-input" type="checkbox" value="1" name="estJustifie" id="estJustifie<?= $suffixe ?>">
                                <label class="form-check-label" for="estJustifie<?= $suffixe ?>">Ce mouvement a été justifié</label>
                            </div>
                            <div class="d-flex gap-4 mb-3">
                                <?php foreach (['En attente', 'Validé', 'Rejeté'] as $i => $st): ?>
                                    <div class="form-check">
                                        <input class="form-check-input" type="radio" name="statutValidation" id="st<?= $suffixe . $i ?>" value="<?= h($st) ?>"
                                            <?= $i === 0 ? 'checked' : '' ?> <?= $i > 0 && !peut_valider() ? 'disabled' : '' ?>>
                                        <label class="form-check-label" for="st<?= $suffixe . $i ?>"><?= h($st) ?></label>
                                    </div>
                                <?php endforeach; ?>
                            </div>
                            <?php if (!peut_valider()): ?>
                                <div class="form-text mb-2">Seuls les utilisateurs ayant le droit « Peut valider / rejeter les opérations » peuvent changer le statut.</div>
                            <?php endif; ?>
                            <label class="form-label">Observation</label>
                            <textarea name="observation" class="form-control" rows="2"></textarea>
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Annuler</button>
                    <button class="btn btn-primary">Enregistrer</button>
                </div>
            </form>
        </div>
    </div>
</div>
