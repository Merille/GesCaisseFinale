<?php
$titre = 'Rapports du point de vente';
$params = array_filter($f, fn($v) => $v !== null && $v !== '');
$s = fn($n) => $n > 1 ? 's' : '';
$lienPeriode = fn(string $du, string $au) => url('posrapport/index', ['dateDebut' => $du, 'dateFin' => $au, 'caisseId' => $f['caisseId']]);
$periodes = [
    "Aujourd'hui" => [date('Y-m-d'), date('Y-m-d')],
    '7 jours' => [date('Y-m-d', strtotime('-6 days')), date('Y-m-d')],
    'Ce mois' => [date('Y-m-01'), date('Y-m-d')],
    'Mois dernier' => [date('Y-m-01', strtotime('first day of last month')), date('Y-m-t', strtotime('first day of last month'))],
];
$part = fn($v) => $kpi['ca'] != 0 ? round((float) $v * 100 / $kpi['ca']) : 0;
$maxCategorie = max(array_map(fn($c) => (float) $c['ca'], $categories) ?: [0]);
$maxMode = max(array_map(fn($m) => (float) $m['montant'], $modes) ?: [0]);
$top = array_slice($produits, 0, 10);
$maxTop = max(array_map(fn($p) => (float) $p['ca'], $top) ?: [0]);

// Heures : de la première à la dernière heure de vente, les heures creuses à zéro.
$heures = [];
if ($parHeure) {
    $index = array_column($parHeure, null, 'h');
    for ($h = (int) min(array_keys($index)); $h <= (int) max(array_keys($index)); $h++) {
        $heures[] = ['l' => sprintf('%02dh', $h), 'ca' => (float) ($index[$h]['ca'] ?? 0), 't' => (int) ($index[$h]['tickets'] ?? 0)];
    }
}
$jours = array_map(fn($j) => ['l' => date_fr($j['d'], 'd/m'), 'ca' => (float) $j['ca'], 't' => (int) $j['tickets']], $parJour);
?>
<link rel="stylesheet" href="<?= asset('assets/css/dashboard.css') ?>">

<div class="container-fluid d-flex flex-column gap-4">

    <form method="get" action="index.php" class="db-card p-3">
        <input type="hidden" name="r" value="posrapport/index">
        <div class="d-flex flex-wrap align-items-end gap-3">
            <div>
                <div class="form-label small fw-semibold text-muted mb-1">Période</div>
                <nav class="db-periodes flex-wrap" aria-label="Période">
                    <?php foreach ($periodes as $lib => [$du, $au]): ?>
                        <a href="<?= h($lienPeriode($du, $au)) ?>" class="<?= $f['dateDebut'] === $du && $f['dateFin'] === $au ? 'active' : '' ?>"><?= h($lib) ?></a>
                    <?php endforeach; ?>
                </nav>
            </div>
            <div><label for="dateDebut" class="form-label small fw-semibold text-muted mb-1">Du</label><input id="dateDebut" name="dateDebut" type="date" class="form-control" value="<?= h($f['dateDebut']) ?>"></div>
            <div><label for="dateFin" class="form-label small fw-semibold text-muted mb-1">Au</label><input id="dateFin" name="dateFin" type="date" class="form-control" value="<?= h($f['dateFin']) ?>"></div>
            <div>
                <label for="caisseId" class="form-label small fw-semibold text-muted mb-1">Caisse</label>
                <select id="caisseId" name="caisseId" class="form-select">
                    <option value="">-- Toutes les caisses --</option>
                    <?php foreach ($caisses as $c): ?>
                        <option value="<?= (int) $c['ID'] ?>" <?= $f['caisseId'] === (int) $c['ID'] ? 'selected' : '' ?>><?= h($c['ChkCode'] . ' - ' . $c['ChkDescription']) ?></option>
                    <?php endforeach; ?>
                </select>
            </div>
            <button class="btn btn-outline-primary"><i class="fa fa-search"></i> Filtrer</button>
            <div class="ms-auto d-flex gap-2">
                <a class="btn btn-success fw-semibold" href="<?= h(url('posrapport/excel', $params)) ?>"><i class="fa fa-file-excel"></i> Excel</a>
                <a class="btn btn-outline-secondary fw-semibold" href="<?= h(url('posrapport/preview', $params)) ?>"><i class="fa fa-file-pdf"></i> Imprimer / PDF</a>
            </div>
        </div>
        <div class="small text-muted mt-2">
            Du <strong class="db-num text-dark"><?= date_fr($f['dateDebut']) ?></strong> au <strong class="db-num text-dark"><?= date_fr($f['dateFin']) ?></strong>
            · Chiffre d'affaires net = ventes − retours, ventes annulées exclues.
        </div>
    </form>

    <div class="row g-4">
        <div class="col-md-6 col-xl-3">
            <section class="db-solde p-4 h-100 d-flex flex-column gap-2">
                <span class="db-label">Chiffre d'affaires net</span>
                <div class="db-num fw-bold" style="font-size:28px;line-height:1.1;"><?= fcfa($kpi['ca']) ?> <span class="db-muted text-nowrap" style="font-size:15px;">FCFA TTC</span></div>
                <div class="small db-muted mt-auto pt-2" style="border-top:1px solid #2f6d92;">HT : <strong class="db-num text-white"><?= fcfa($kpi['ht']) ?></strong> FCFA</div>
            </section>
        </div>
        <?php foreach ([
            ['Tickets de vente', fcfa($kpi['tickets']), '', quantite_fr($kpi['articles']) . ' article' . $s($kpi['articles']) . ' vendu' . $s($kpi['articles'])],
            ['Panier moyen', fcfa($kpi['panier']), 'FCFA TTC', 'Ventes : ' . fcfa($kpi['ventes']) . ' FCFA'],
            ['Retours', fcfa($kpi['retours']), 'FCFA TTC', $kpi['nbRetours'] . ' retour' . $s($kpi['nbRetours']) . ' · ' . $kpi['annulees'] . ' vente' . $s($kpi['annulees']) . ' annulée' . $s($kpi['annulees'])],
        ] as [$lib, $val, $unite, $sous]): ?>
            <div class="col-md-6 col-xl-3">
                <section class="db-card p-4 h-100 d-flex flex-column gap-2">
                    <span class="db-label"><?= h($lib) ?></span>
                    <div class="db-num fw-bold" style="font-size:28px;line-height:1.1;"><?= $val ?> <span class="text-muted fw-normal" style="font-size:15px;"><?= $unite ?></span></div>
                    <div class="small text-muted border-top pt-2 mt-auto"><?= h($sous) ?></div>
                </section>
            </div>
        <?php endforeach; ?>
    </div>

    <div class="row g-4">
        <div class="col-xl-8">
            <section class="db-card p-4 h-100 d-flex flex-column gap-3">
                <h2>Chiffre d'affaires par jour</h2>
                <?php if (!$jours): ?><p class="text-muted small m-0 py-5 text-center">Aucune vente sur la période.</p>
                <?php else: ?><div style="position:relative;height:260px;"><canvas id="chartJours" role="img" aria-label="Chiffre d'affaires par jour"></canvas></div><?php endif; ?>
            </section>
        </div>
        <div class="col-xl-4">
            <section class="db-card p-4 h-100 d-flex flex-column gap-3">
                <h2>Encaissements nets par mode</h2>
                <?php if (!$modes): ?><p class="text-muted small m-0">Aucun encaissement sur la période.</p><?php endif; ?>
                <?php foreach ($modes as $m): ?>
                    <div>
                        <div class="d-flex justify-content-between small mb-1">
                            <span class="fw-semibold"><?= h($m['nom']) ?></span>
                            <span class="db-num text-muted"><?= (int) $m['tickets'] ?> ticket<?= $s((int) $m['tickets']) ?> · <strong class="text-dark"><?= fcfa($m['montant']) ?></strong></span>
                        </div>
                        <div class="db-bar"><div style="width:<?= $maxMode > 0 ? max(0, round((float) $m['montant'] * 100 / $maxMode)) : 0 ?>%"></div></div>
                    </div>
                <?php endforeach; ?>
                <div class="border-top pt-3 d-flex flex-column gap-2 mt-auto">
                    <h3 class="fw-bold m-0" style="font-size:14px;">Taxes collectées</h3>
                    <?php if (!$taxes): ?><p class="text-muted small m-0">Aucune taxe sur la période.</p><?php endif; ?>
                    <?php foreach ($taxes as $t): ?>
                        <div class="d-flex justify-content-between small"><span><?= h($t['nom']) ?></span><strong class="db-num"><?= fcfa($t['montant']) ?></strong></div>
                    <?php endforeach; ?>
                </div>
            </section>
        </div>
    </div>

    <div class="row g-4">
        <div class="col-xl-6">
            <section class="db-card p-4 h-100 d-flex flex-column gap-3">
                <h2>Ventes par heure</h2>
                <?php if (!$heures): ?><p class="text-muted small m-0 py-5 text-center">Aucune vente sur la période.</p>
                <?php else: ?><div style="position:relative;height:240px;"><canvas id="chartHeures" role="img" aria-label="Chiffre d'affaires par heure"></canvas></div><?php endif; ?>
            </section>
        </div>
        <div class="col-xl-6">
            <section class="db-card p-4 h-100 d-flex flex-column gap-3">
                <h2>Ventes par catégorie</h2>
                <?php if (!$categories): ?><p class="text-muted small m-0">Aucune vente sur la période.</p><?php endif; ?>
                <?php foreach ($categories as $c): ?>
                    <div>
                        <div class="d-flex justify-content-between small mb-1">
                            <span class="fw-semibold"><span class="d-inline-block rounded-circle me-2" style="width:10px;height:10px;background:<?= h($c['couleur'] ?: '#999997') ?>;"></span><?= h($c['nom']) ?></span>
                            <span class="db-num text-muted"><?= quantite_fr($c['qte']) ?> art. · <strong class="text-dark"><?= fcfa($c['ca']) ?></strong> · <?= $part($c['ca']) ?> %</span>
                        </div>
                        <div class="db-bar"><div style="width:<?= $maxCategorie > 0 ? max(0, round((float) $c['ca'] * 100 / $maxCategorie)) : 0 ?>%"></div></div>
                    </div>
                <?php endforeach; ?>
            </section>
        </div>
    </div>

    <div class="row g-4">
        <div class="col-xl-6">
            <section class="db-card p-4 h-100 d-flex flex-column gap-3">
                <h2>Meilleures ventes</h2>
                <?php if (!$top): ?><p class="text-muted small m-0">Aucune vente sur la période.</p><?php endif; ?>
                <?php foreach ($top as $i => $p): ?>
                    <div class="d-flex align-items-center gap-3">
                        <span class="db-num fw-bold text-muted" style="width:22px;"><?= $i + 1 ?></span>
                        <div class="flex-grow-1">
                            <div class="d-flex justify-content-between small mb-1">
                                <span class="fw-semibold"><?= h($p['nom']) ?></span>
                                <span class="db-num text-muted"><?= quantite_fr($p['qte']) ?> vendu<?= $s((float) $p['qte']) ?> · <strong class="text-dark"><?= fcfa($p['ca']) ?></strong></span>
                            </div>
                            <div class="db-bar"><div style="width:<?= $maxTop > 0 ? max(0, round((float) $p['ca'] * 100 / $maxTop)) : 0 ?>%"></div></div>
                        </div>
                    </div>
                <?php endforeach; ?>
            </section>
        </div>
        <div class="col-xl-6">
            <section class="db-card p-4 h-100">
                <h2 class="mb-3">Ventes par vendeur</h2>
                <div class="table-responsive">
                    <table class="table align-middle small db-table mb-0">
                        <thead><tr><th>Vendeur</th><th class="text-end">Tickets</th><th class="text-end">Retours</th><th class="text-end">CA net</th><th class="text-end">Panier moyen</th></tr></thead>
                        <tbody>
                        <?php if (!$vendeurs): ?><tr><td colspan="5" class="text-center text-muted py-4">Aucune vente sur la période.</td></tr><?php endif; ?>
                        <?php foreach ($vendeurs as $v): ?>
                            <tr>
                                <td class="fw-semibold"><?= h($v['nom']) ?></td>
                                <td class="db-num text-end"><?= (int) $v['tickets'] ?></td>
                                <td class="db-num text-end text-muted"><?= fcfa($v['retours']) ?></td>
                                <td class="db-num text-end fw-bold"><?= fcfa($v['ca']) ?></td>
                                <td class="db-num text-end"><?= (int) $v['tickets'] > 0 ? fcfa($v['ventes'] / $v['tickets']) : '—' ?></td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </section>
        </div>
    </div>

    <section class="db-card p-4">
        <div class="d-flex align-items-center mb-3">
            <h2 class="flex-grow-1">Ventes par produit</h2>
            <span class="small text-muted"><?= count($produits) ?> produit<?= $s(count($produits)) ?></span>
        </div>
        <div class="table-responsive" style="max-height:460px;">
            <table class="table table-hover align-middle small db-table mb-0">
                <thead class="sticky-top bg-white"><tr><th>#</th><th>Code</th><th>Produit</th><th>Catégorie</th><th class="text-end">Quantité</th><th class="text-end">CA TTC</th><th class="text-end">Part</th></tr></thead>
                <tbody>
                <?php if (!$produits): ?><tr><td colspan="7" class="text-center text-muted py-4">Aucune vente sur la période.</td></tr><?php endif; ?>
                <?php foreach ($produits as $i => $p): ?>
                    <tr>
                        <td class="db-num text-muted"><?= $i + 1 ?></td>
                        <td class="db-num text-muted"><?= h($p['code'] ?? '') ?></td>
                        <td class="fw-semibold"><?= h($p['nom']) ?></td>
                        <td><?= h($p['categorie']) ?></td>
                        <td class="db-num text-end"><?= quantite_fr($p['qte']) ?></td>
                        <td class="db-num text-end fw-bold"><?= fcfa($p['ca']) ?></td>
                        <td class="db-num text-end text-muted"><?= $part($p['ca']) ?> %</td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </section>
</div>

<?php ob_start(); ?>
<script>
    (function () {
        const fmt = new Intl.NumberFormat('fr-FR');
        const graphique = (id, points) => {
            const el = document.getElementById(id);
            if (!el) return;
            new Chart(el, {
                type: 'bar',
                data: {
                    labels: points.map((p) => p.l),
                    datasets: [{ label: "Chiffre d'affaires", data: points.map((p) => p.ca), backgroundColor: '#195d84', borderRadius: 4, maxBarThickness: 26 }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: false },
                        tooltip: { callbacks: { label: (c) => fmt.format(c.parsed.y) + ' FCFA · ' + points[c.dataIndex].t + ' ticket' + (points[c.dataIndex].t > 1 ? 's' : '') } }
                    },
                    scales: { x: { grid: { display: false } }, y: { beginAtZero: true, ticks: { callback: (v) => fmt.format(v) } } }
                }
            });
        };
        graphique('chartJours', <?= json_encode($jours) ?>);
        graphique('chartHeures', <?= json_encode($heures) ?>);
    })();
</script>
<?php $scripts = ob_get_clean(); ?>
