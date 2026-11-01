<?php
$edition = !empty($caisse);
$titre = $edition ? 'Modifier la caisse' : 'Nouvelle caisse';
$v = fn(string $k) => h($caisse[$k] ?? '');
$entete = $titre;
$action = !empty($modale) ? url('caisse/create') : null;
$retour = url('caisse/index');
require __DIR__ . '/../partials/form_debut.php';
?>
            <div class="row g-3">
                <div class="col-md-4">
                    <label class="form-label" for="ChkCode">Code</label>
                    <input class="form-control" id="ChkCode" name="ChkCode" value="<?= $v('ChkCode') ?>" required>
                </div>
                <div class="col-md-8">
                    <label class="form-label" for="ChkDescription">Description</label>
                    <input class="form-control" id="ChkDescription" name="ChkDescription" value="<?= $v('ChkDescription') ?>" required>
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="StCode">StCode</label>
                    <input class="form-control" id="StCode" name="StCode" value="<?= $v('StCode') ?>">
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="CashierDefault">Caissier par défaut</label>
                    <select class="form-select" id="CashierDefault" name="CashierDefault">
                        <option value="">-- Choisir un caissier --</option>
                        <?php foreach ($utilisateurs as $u): ?>
                            <option value="<?= (int) $u['Id'] ?>" <?= (int) ($caisse['CashierDefault'] ?? 0) === (int) $u['Id'] ? 'selected' : '' ?>><?= h($u['NomComplet']) ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="CompteComptable">Compte comptable (Sage)</label>
                    <input class="form-control" id="CompteComptable" name="CompteComptable" value="<?= $v('CompteComptable') ?>" placeholder="ex. 571000">
                </div>
                <?php if (module_pos_actif()): ?>
                <div class="col-md-4">
                    <label class="form-label" for="TypePointVente<?= !empty($modale) ? 'M' : '' ?>">Type de point de vente</label>
                    <select class="form-select" id="TypePointVente<?= !empty($modale) ? 'M' : '' ?>" name="TypePointVente">
                        <?php foreach (CAISSE_TYPES as $t): ?>
                            <option value="<?= h($t) ?>" <?= ($caisse['TypePointVente'] ?? 'Boutique') === $t ? 'selected' : '' ?>><?= h(caisse_type_libelle($t)) ?></option>
                        <?php endforeach; ?>
                    </select>
                    <div class="form-text">Restaurant / Bar : plan de salle, commandes sur les tables, bons cuisine / bar.</div>
                </div>
                <div class="col-md-8 d-flex align-items-center">
                    <div class="form-check">
                        <input class="form-check-input" type="checkbox" value="1" id="ImprimerBons<?= !empty($modale) ? 'M' : '' ?>" name="ImprimerBons" <?= ($caisse['ImprimerBons'] ?? 1) ? 'checked' : '' ?>>
                        <label class="form-check-label" for="ImprimerBons<?= !empty($modale) ? 'M' : '' ?>">Imprimer un bon de préparation à chaque envoi en cuisine / au bar
                            <span class="d-block small text-muted">Les bons s'affichent aussi sur l'écran cuisine / bar.</span></label>
                    </div>
                </div>
                <?php else: ?>
                <input type="hidden" name="TypePointVente" value="<?= h($caisse['TypePointVente'] ?? 'Boutique') ?>">
                <?php if ($caisse['ImprimerBons'] ?? 1): ?><input type="hidden" name="ImprimerBons" value="1"><?php endif; ?>
                <?php endif; ?>
            </div>
<?php require __DIR__ . '/../partials/form_fin.php'; ?>
