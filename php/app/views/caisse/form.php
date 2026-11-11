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
                    <div class="form-text">Restaurant / Bar : plan de salle, commandes sur les tables, bons cuisine / bar. Laverie : vente au comptoir de prestations.</div>
                </div>
                <div class="col-md-8">
                    <label class="form-label" for="DepotId<?= $sfxPv ?>">Dépôt de la caisse</label>
                    <select class="form-select" id="DepotId<?= $sfxPv ?>" name="DepotId">
                        <?php $depotChoisi = (int) ($caisse['DepotId'] ?? 0); $defaut = current(array_filter($depots ?? [], fn($d) => $d['ParDefaut'])); ?>
                        <option value="" data-depot="<?= $defaut ? (int) $defaut['Id'] : '' ?>">Dépôt par défaut de la société<?= $defaut ? h(' (' . $defaut['Code'] . ' · ' . $defaut['Nom'] . ')') : '' ?></option>
                        <?php foreach ($depots ?? [] as $d): ?>
                            <option value="<?= (int) $d['Id'] ?>" <?= $depotChoisi === (int) $d['Id'] ? 'selected' : '' ?>><?= h($d['Code'] . ' · ' . $d['Nom']) ?></option>
                        <?php endforeach; ?>
                    </select>
                    <div class="form-text">Dépôt principal de la caisse : les ventes en sortent d'abord et les retours y reviennent. Sans choix, la caisse utilise le dépôt par défaut de la société (Paramètres › Dépôts).</div>
                </div>
                <div class="col-12">
                    <input type="hidden" name="SecondairesSaisis" value="1">
                    <?php $secondaires = $caisse['Secondaires'] ?? []; ?>
                    <label class="form-label mb-1">Dépôts secondaires (complément)</label>
                    <div class="border rounded px-2 py-1 depots-secondaires" data-sfx="<?= $sfxPv ?>">
                        <?php if (count($depots ?? []) < 2): ?>
                            <div class="small text-muted py-1">Créez d'autres dépôts (Paramètres › Dépôts) pour compléter le stock de cette caisse.</div>
                        <?php endif; ?>
                        <?php foreach ($depots ?? [] as $i => $d): $id = (int) $d['Id']; $coche = isset($secondaires[$id]); ?>
                            <div class="d-flex align-items-center gap-2 py-1" data-depot="<?= $id ?>">
                                <div class="form-check mb-0 flex-grow-1">
                                    <input class="form-check-input" type="checkbox" name="Secondaires[]" value="<?= $id ?>" id="Secondaire<?= $sfxPv . $id ?>" <?= $coche ? 'checked' : '' ?>>
                                    <label class="form-check-label" for="Secondaire<?= $sfxPv . $id ?>"><?= h($d['Code'] . ' · ' . $d['Nom']) ?></label>
                                </div>
                                <label class="small text-muted mb-0" for="Ordre<?= $sfxPv . $id ?>">Ordre</label>
                                <input type="number" class="form-control form-control-sm" style="width:4.5rem;" min="1" max="99" name="Ordre[<?= $id ?>]" id="Ordre<?= $sfxPv . $id ?>" value="<?= $coche ? $secondaires[$id] : $i + 1 ?>">
                            </div>
                        <?php endforeach; ?>
                    </div>
                    <div class="form-text">Quand le stock du dépôt principal ne suffit pas, la vente complète dans ces dépôts, dans l'ordre indiqué.
                        Le stock affiché à la caisse est le total du principal et des secondaires.</div>
                </div>
                <div class="col-12 d-flex align-items-center caisse-restaurant<?= in_array($caisse['TypePointVente'] ?? 'Boutique', ['Restaurant', 'Bar'], true) ? '' : ' d-none' ?>">
                    <div class="form-check">
                        <input class="form-check-input" type="checkbox" value="1" id="ImprimerBons<?= $sfxPv ?>" name="ImprimerBons" <?= ($caisse['ImprimerBons'] ?? 1) ? 'checked' : '' ?>>
                        <label class="form-check-label" for="ImprimerBons<?= $sfxPv ?>">Imprimer un bon de préparation à chaque envoi en cuisine / au bar
                            <span class="d-block small text-muted">Les bons s'affichent aussi sur l'écran cuisine / bar.</span></label>
                    </div>
                </div>
                <?php else: ?>
                <input type="hidden" name="TypePointVente" value="<?= h($caisse['TypePointVente'] ?? 'Boutique') ?>">
                <input type="hidden" name="DepotId" value="<?= h((string) ($caisse['DepotId'] ?? '')) ?>">
                <?php if ($modification): ?><input type="hidden" name="ImprimerBons" value="1"><?php elseif ($caisse['ImprimerBons'] ?? 1): ?><input type="hidden" name="ImprimerBons" value="1"><?php endif; ?>
                <?php endif; ?>
            </div>
<?php require __DIR__ . '/../partials/form_fin.php'; ?>
