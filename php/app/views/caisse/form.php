<?php
$edition = !empty($caisse);
$titre = $edition ? 'Modifier la caisse' : 'Nouvelle caisse';
$v = fn(string $k) => h($caisse[$k] ?? '');
?>
<div class="card shadow-sm border-0" style="max-width: 760px;">
    <div class="card-header bg-brand text-white"><h5 class="mb-0"><?= h($titre) ?></h5></div>
    <div class="card-body">
        <form method="post">
            <?= csrf_field() ?>
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
            </div>
            <div class="mt-4 d-flex gap-2">
                <button class="btn btn-primary">Enregistrer</button>
                <a href="<?= h(url('caisse/index')) ?>" class="btn btn-outline-secondary">Annuler</a>
            </div>
        </form>
    </div>
</div>
