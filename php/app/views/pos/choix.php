<?php $titre = 'Vendre'; ?>
<p class="text-muted">Choisissez la journée de caisse dans laquelle enregistrer les ventes.</p>
<?php if (!$journees): ?>
    <div class="alert alert-info">
        Aucune journée de caisse n'est ouverte. Ouvrez-en une depuis
        <a href="<?= h(url('caisse/index')) ?>">Caisses</a> (bouton « Journées », puis « Ouvrir une journée »).
    </div>
<?php else: ?>
    <div class="row g-3">
        <?php foreach ($journees as $j): ?>
            <div class="col-md-6 col-xl-4">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body d-flex flex-column">
                        <div class="d-flex align-items-center gap-2 mb-1">
                            <i class="fa fa-cash-register text-brand"></i>
                            <strong><?= h($j['ChkCode']) ?></strong>
                            <span class="badge bg-success ms-auto">Ouverte</span>
                        </div>
                        <div><?= h($j['ChkDescription']) ?></div>
                        <div class="small text-muted mb-3">Journée du <?= date_fr($j['DateJournee']) ?> · <?= h($j['NumeroJournee']) ?></div>
                        <a href="<?= h(url('pos/index', ['journee' => $j['Id']])) ?>" class="btn btn-success mt-auto"><i class="fa fa-store"></i> Ouvrir le point de vente</a>
                    </div>
                </div>
            </div>
        <?php endforeach; ?>
    </div>
<?php endif; ?>
