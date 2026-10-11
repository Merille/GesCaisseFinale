<?php $titre = 'Ouvrir une journée'; ?>
<div class="card shadow-sm border-0" style="max-width: 560px;">
    <div class="card-header bg-brand text-white"><h5 class="mb-0">Nouvelle journée — <?= h($caisse['ChkCode'] . ' · ' . $caisse['ChkDescription']) ?></h5></div>
    <div class="card-body">
        <form method="post" action="<?= h(url('journee/create', ['id' => $caisse['ID']])) ?>">
            <?= csrf_field() ?>
            <input type="hidden" name="caisseId" value="<?= (int) $caisse['ID'] ?>">
            <div class="mb-3">
                <label class="form-label" for="dateJournee">Date de la journée</label>
                <input type="date" class="form-control" id="dateJournee" name="dateJournee" value="<?= date('Y-m-d') ?>" required>
            </div>
            <div class="mb-3">
                <label class="form-label" for="soldeInitial">Solde initial (FCFA)</label>
                <input class="form-control" id="soldeInitial" name="soldeInitial" inputmode="decimal" value="<?= h((string) round($soldeSuggere)) ?>" required>
                <div class="form-text">Proposé à partir de la dernière journée de cette caisse (solde compté si elle est clôturée).</div>
            </div>
            <div class="d-flex gap-2">
                <button class="btn btn-success">Ouvrir la journée</button>
                <a href="<?= h(url('caisse/details', ['id' => $caisse['ID']])) ?>" class="btn btn-outline-secondary">Annuler</a>
            </div>
        </form>
    </div>
</div>
