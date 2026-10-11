<?php $titre = $edition ? 'Modifier la société' : 'Nouvelle société'; ?>
<div class="card shadow-sm border-0" style="max-width: 720px;">
    <div class="card-header bg-brand text-white"><h5 class="mb-0"><?= h($titre) ?></h5></div>
    <div class="card-body">
        <form method="post">
            <?= csrf_field() ?>
            <div class="row g-3">
                <div class="col-md-8"><label class="form-label" for="Nom">Nom</label><input class="form-control" id="Nom" name="Nom" value="<?= h($t['Nom'] ?? '') ?>" required></div>
                <div class="col-md-4"><label class="form-label" for="Code">Code</label><input class="form-control" id="Code" name="Code" value="<?= h($t['Code'] ?? '') ?>" required></div>
                <div class="col-md-4">
                    <label class="form-label" for="ModeAcces">Mode d'accès</label>
                    <select class="form-select" id="ModeAcces" name="ModeAcces">
                        <?php foreach (['Licence', 'Abonnement'] as $m): ?><option <?= ($t['ModeAcces'] ?? '') === $m ? 'selected' : '' ?>><?= $m ?></option><?php endforeach; ?>
                    </select>
                </div>
                <div class="col-md-4">
                    <label class="form-label" for="DateExpiration">Date d'expiration</label>
                    <input class="form-control" type="date" id="DateExpiration" name="DateExpiration" value="<?= h($t['DateExpiration'] ?? '') ?>">
                    <div class="form-text">Vide = sans limite.</div>
                </div>
                <div class="col-md-4 d-flex align-items-center">
                    <div class="form-check mt-3">
                        <input class="form-check-input" type="checkbox" value="1" id="Actif" name="Actif" <?= !empty($t['Actif']) ? 'checked' : '' ?>>
                        <label class="form-check-label" for="Actif">Société active</label>
                    </div>
                </div>
            </div>
            <div class="mt-4 d-flex gap-2">
                <button class="btn btn-primary">Enregistrer</button>
                <a href="<?= h(url('tenant/index')) ?>" class="btn btn-outline-secondary">Annuler</a>
            </div>
        </form>
    </div>
</div>
