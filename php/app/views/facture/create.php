<?php $titre = 'Nouvelle facture'; ?>
<div class="card shadow-sm border-0" style="max-width: 640px;">
    <div class="card-header bg-brand text-white"><h5 class="mb-0">Nouvelle facture</h5></div>
    <div class="card-body">
        <?php if (!$clients): ?>
            <div class="alert alert-warning">Créez d'abord un tiers dans <a href="<?= h(url('client/create')) ?>">Tiers</a>.</div>
        <?php endif; ?>
        <form method="post">
            <?= csrf_field() ?>
            <div class="row g-3">
                <div class="col-md-6"><label class="form-label" for="Numero">Numéro</label><input class="form-control" id="Numero" name="Numero" value="<?= h($_POST['Numero'] ?? $numeroPropose) ?>" required></div>
                <div class="col-md-6"><label class="form-label" for="TauxTVA">Taux de TVA (%)</label><input class="form-control" id="TauxTVA" name="TauxTVA" inputmode="decimal" value="<?= h($_POST['TauxTVA'] ?? '18') ?>"></div>
                <div class="col-12">
                    <label class="form-label" for="ClientId">Client</label>
                    <select class="form-select" id="ClientId" name="ClientId" required>
                        <option value="">-- Choisir un client --</option>
                        <?php foreach ($clients as $c): ?><option value="<?= (int) $c['Id'] ?>"><?= h($c['NomSociete']) ?></option><?php endforeach; ?>
                    </select>
                </div>
            </div>
            <div class="mt-4 d-flex gap-2">
                <button class="btn btn-primary">Créer et ajouter les lignes</button>
                <a href="<?= h(url('facture/index')) ?>" class="btn btn-outline-secondary">Annuler</a>
            </div>
        </form>
    </div>
</div>
