<?php
// Formulaire d'une caisse : page (modification sans JavaScript), modale de création, ou modale
// de modification ($modification = true) remplie en JavaScript depuis la liste des caisses.
$modification = !empty($modification);
$edition = !empty($caisse) || $modification;
$titre = $edition ? 'Modifier la caisse' : 'Nouvelle caisse';
$v = fn(string $k) => h($caisse[$k] ?? '');
// Identifiants des champs : distincts entre la modale de création et celle de modification.
$sfx = $modification ? 'E' : '';
$sfxPv = $modification ? 'E' : (!empty($modale) ? 'M' : '');
$entete = $titre;
$action = !empty($modale) ? ($modification ? url('caisse/index') : url('caisse/create')) : null;
$retour = url('caisse/index');
if ($modification) {
    $idModale = 'modalModification';
}
require __DIR__ . '/../partials/form_debut.php';
?>
            <div class="row g-3">
                <div class="col-md-4">
                    <label class="form-label" for="ChkCode<?= $sfx ?>">Code</label>
                    <input class="form-control" id="ChkCode<?= $sfx ?>" name="ChkCode" value="<?= $v('ChkCode') ?>" required>
                </div>
                <div class="col-md-8">
                    <label class="form-label" for="ChkDescription<?= $sfx ?>">Description</label>
                    <input class="form-control" id="ChkDescription<?= $sfx ?>" name="ChkDescription" value="<?= $v('ChkDescription') ?>" required>
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="StCode<?= $sfx ?>">StCode</label>
                    <input class="form-control" id="StCode<?= $sfx ?>" name="StCode" value="<?= $v('StCode') ?>">
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="CashierDefault<?= $sfx ?>">Caissier par défaut</label>
                    <select class="form-select" id="CashierDefault<?= $sfx ?>" name="CashierDefault">
                        <option value="">-- Choisir un caissier --</option>
                        <?php foreach ($utilisateurs as $u): ?>
                            <option value="<?= (int) $u['Id'] ?>" <?= (int) ($caisse['CashierDefault'] ?? 0) === (int) $u['Id'] ? 'selected' : '' ?>><?= h($u['NomComplet']) ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="CompteComptable<?= $sfx ?>">Compte comptable (Sage)</label>
                    <input class="form-control" id="CompteComptable<?= $sfx ?>" name="CompteComptable" value="<?= $v('CompteComptable') ?>" placeholder="ex. 571000">
                </div>
                <?php if (module_pos_actif()): ?>
                <div class="col-md-4">
                    <label class="form-label" for="TypePointVente<?= $sfxPv ?>">Type de point de vente</label>
                    <select class="form-select" id="TypePointVente<?= $sfxPv ?>" name="TypePointVente">
                        <?php foreach (CAISSE_TYPES as $t): ?>
                            <option value="<?= h($t) ?>" <?= ($caisse['TypePointVente'] ?? 'Boutique') === $t ? 'selected' : '' ?>><?= h(caisse_type_libelle($t)) ?></option>
                        <?php endforeach; ?>
                    </select>
                    <div class="form-text">Restaurant / Bar : plan de salle, commandes sur les tables, bons cuisine / bar.</div>
                </div>
                <div class="col-md-8 d-flex align-items-center">
                    <div class="form-check">
                        <input class="form-check-input" type="checkbox" value="1" id="ImprimerBons<?= $sfxPv ?>" name="ImprimerBons" <?= ($caisse['ImprimerBons'] ?? 1) ? 'checked' : '' ?>>
                        <label class="form-check-label" for="ImprimerBons<?= $sfxPv ?>">Imprimer un bon de préparation à chaque envoi en cuisine / au bar
                            <span class="d-block small text-muted">Les bons s'affichent aussi sur l'écran cuisine / bar.</span></label>
                    </div>
                </div>
                <?php else: ?>
                <input type="hidden" name="TypePointVente" value="<?= h($caisse['TypePointVente'] ?? 'Boutique') ?>">
                <?php if ($modification): ?><input type="hidden" name="ImprimerBons" value="1"><?php elseif ($caisse['ImprimerBons'] ?? 1): ?><input type="hidden" name="ImprimerBons" value="1"><?php endif; ?>
                <?php endif; ?>
            </div>
<?php require __DIR__ . '/../partials/form_fin.php'; ?>
