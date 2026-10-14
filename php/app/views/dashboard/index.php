<?php
$titre = 'Tableau de bord';
$s = fn(int $n) => $n > 1 ? 's' : '';
$tendance = fn(?float $v) => $v === null ? null : ($v >= 0 ? '▲ ' : '▼ ') . fcfa(abs($v)) . ' %';
$lienPeriode = fn(string $p) => url('dashboard/index', ['periode' => $p, 'caisseId' => $caisseId, 'statutJournee' => $statutJournee]);
$lienNouvelleOp = $journeeOuverteId ? url('journee/details', ['id' => $journeeOuverteId]) : url('caisse/index');
$solde = $montantInitial + $entrees - $sorties;
$net = $entrees - $sorties;
$rienATraiter = array_sum(array_column($aTraiter, 'n')) === 0;
?>
<link rel="stylesheet" href="<?= asset('assets/css/dashboard.css') ?>">

<div class="container-fluid d-flex flex-column gap-4">

    <form method="get" action="index.php" class="db-card p-3">
        <input type="hidden" name="r" value="dashboard/index">
        <input type="hidden" name="periode" value="perso">
        <div class="d-flex flex-wrap align-items-end gap-3">
            <div>
                <div class="form-label small fw-semibold text-muted mb-1">Période</div>
                <nav class="db-periodes" aria-label="Période">
                    <?php foreach (['jour' => "Aujourd'hui", 'semaine' => '7 jours', 'mois' => 'Ce mois'] as $code => $lib): ?>
                        <a href="<?= h($lienPeriode($code)) ?>" class="<?= $periode === $code ? 'active' : '' ?>"><?= h($lib) ?></a>
                    <?php endforeach; ?>
                    <a href="#" class="<?= $periode === 'perso' ? 'active' : '' ?>"
                       onclick="document.getElementById('dbPerso').classList.toggle('d-none'); return false;">Personnalisé</a>
                </nav>
            </div>
            <div id="dbPerso" class="d-flex gap-2 align-items-end <?= $periode === 'perso' ? '' : 'd-none' ?>">
                <div>
                    <label for="dateDebut" class="form-label small fw-semibold text-muted mb-1">Du</label>
                    <input id="dateDebut" name="dateDebut" type="date" class="form-control" value="<?= h($debut->format('Y-m-d')) ?>">
                </div>
                <div>
                    <label for="dateFin" class="form-label small fw-semibold text-muted mb-1">Au</label>
                    <input id="dateFin" name="dateFin" type="date" class="form-control" value="<?= h($fin->format('Y-m-d')) ?>">
                </div>
            </div>
            <div>
                <label for="caisseId" class="form-label small fw-semibold text-muted mb-1">Caisse</label>
                <select id="caisseId" name="caisseId" class="form-select">
                    <option value="">-- Toutes les caisses --</option>
                    <?php foreach ($caisses as $c): ?>
                        <option value="<?= (int) $c['ID'] ?>" <?= $caisseId === (int) $c['ID'] ? 'selected' : '' ?>><?= h($c['ChkCode'] . ' - ' . $c['ChkDescription']) ?></option>
                    <?php endforeach; ?>
                </select>
            </div>
            <div>
                <label for="statutJournee" class="form-label small fw-semibold text-muted mb-1">Statut journée</label>
                <select id="statutJournee" name="statutJournee" class="form-select">
                    <option value="">Toutes</option>
                    <option value="Ouverte" <?= $statutJournee === 'Ouverte' ? 'selected' : '' ?>>Ouvertes</option>
                    <option value="Cloturee" <?= $statutJournee === 'Cloturee' ? 'selected' : '' ?>>Clôturées</option>
                </select>
            </div>
            <button class="btn btn-outline-primary"><i class="fa fa-search"></i> Filtrer</button>
            <div class="ms-auto d-flex gap-2">
                <a href="<?= h($lienNouvelleOp) ?>" class="btn btn-success fw-semibold"><i class="fa fa-plus"></i> Nouvelle opération</a>
                <a href="<?= h(url('rapport/operations')) ?>" class="btn btn-outline-secondary fw-semibold"><i class="fa fa-chart-column"></i> Rapports</a>
            </div>
        </div>
        <div class="small text-muted mt-2">
            Du <strong class="db-num text-dark"><?= $debut->format('d/m/Y') ?></strong>
            au <strong class="db-num text-dark"><?= $fin->format('d/m/Y') ?></strong>
        </div>
    </form>

    <div class="row g-4">
        <div class="col-xl-5">
            <section class="db-solde p-4 h-100 d-flex flex-column gap-3">
                <div class="d-flex justify-content-between align-items-center">
                    <span class="db-label">Solde en caisse</span>
                    <span class="db-badge" style="background:#2a6f97;color:#fff;"><?= $nbOuvertes ?> caisse<?= $s($nbOuvertes) ?> ouverte<?= $s($nbOuvertes) ?></span>
                </div>
                <div class="db-num fw-bold" style="font-size:40px;line-height:1;"><?= fcfa($solde) ?> <span class="db-muted" style="font-size:18px;">FCFA</span></div>
                <div class="row g-0 db-solde-split pt-3" style="border-top:1px solid #2f6d92;">
                    <div class="col-4 pe-3"><div class="small db-muted">Fond initial</div><div class="db-num fw-bold"><?= fcfa($montantInitial) ?></div></div>
                    <div class="col-4 px-3"><div class="small db-muted">+ Entrées</div><div class="db-num fw-bold" style="color:#8fe3b4;"><?= fcfa($entrees) ?></div></div>
                    <div class="col-4 ps-3"><div class="small db-muted">− Sorties</div><div class="db-num fw-bold" style="color:#ffc29a;"><?= fcfa($sorties) ?></div></div>
                </div>
            </section>
        </div>
        <div class="col-xl-7">
            <div class="row g-4 h-100">
                <?php foreach ([
                    ['Entrées', '+', '#0f7a4a', 'db-in', $entrees, "$nbEnc encaissement" . $s($nbEnc), $varEntrees, true],
                    ['Sorties', '−', '#c2410c', 'db-out', $sorties, "$nbDec décaissement" . $s($nbDec), $varSorties, false],
                ] as [$lib, $signe, $coul, $cls, $val, $sous, $var, $hausseBonne]): ?>
                    <div class="col-md-4">
                        <section class="db-card p-4 h-100 d-flex flex-column gap-2">
                            <div class="d-flex align-items-center gap-2"><span class="db-sign" style="background:<?= $coul ?>;"><?= $signe ?></span><span class="db-label"><?= $lib ?></span></div>
                            <div class="db-num fw-bold <?= $cls ?>" style="font-size:26px;"><?= fcfa($val) ?></div>
                            <div class="small text-muted">FCFA</div>
                            <div class="d-flex flex-wrap justify-content-between column-gap-2 border-top pt-2 mt-auto small">
                                <span class="text-muted text-nowrap"><?= h($sous) ?></span>
                                <?php if ($var !== null): ?>
                                    <?php $favorable = $hausseBonne ? $var >= 0 : $var > 0; ?>
                                    <span class="fw-bold text-nowrap <?= $favorable ? $cls : 'text-muted' ?>" title="Par rapport à la période précédente"><?= h($tendance($var)) ?></span>
                                <?php endif; ?>
                            </div>
                        </section>
                    </div>
                <?php endforeach; ?>
                <div class="col-md-4">
                    <section class="db-card p-4 h-100 d-flex flex-column gap-2">
                        <div class="d-flex align-items-center gap-2"><span class="db-sign" style="background:var(--brand);">=</span><span class="db-label">Résultat net</span></div>
                        <div class="db-num fw-bold" style="font-size:26px;color:var(--brand);"><?= $net > 0 ? '+' : '' ?><?= fcfa($net) ?></div>
                        <div class="small text-muted">FCFA</div>
                        <div class="border-top pt-2 mt-auto small text-muted"><?= $nbEnc + $nbDec ?> opération<?= $s($nbEnc + $nbDec) ?></div>
                    </section>
                </div>
            </div>
        </div>
    </div>

    <?php if (!$rienATraiter): ?>
        <section class="db-todo p-3 d-flex flex-wrap align-items-center gap-3">
            <div class="d-flex align-items-center gap-2">
                <span class="db-sign" style="background:#c2410c;width:36px;height:36px;"><i class="fa fa-exclamation"></i></span>
                <h2 class="m-0 fw-bold" style="font-size:16px;color:#7c2d12;">À traiter</h2>
            </div>
            <div class="row g-2 flex-grow-1">
                <?php foreach ($aTraiter as $t): if ($t['n'] === 0) continue; ?>
                    <div class="col-md-4">
                        <a class="d-flex align-items-center gap-3 px-3 py-2 h-100" href="<?= h(url('journee/details', ['id' => $t['j']])) ?>">
                            <span class="db-count db-num"><?= $t['n'] ?></span>
                            <span class="small flex-grow-1"><?= h(str_replace('%s', $s($t['n']), $t['txt'])) ?></span>
                            <i class="fa fa-chevron-right" style="color:#c2410c;"></i>
                        </a>
                    </div>
                <?php endforeach; ?>
            </div>
        </section>
    <?php endif; ?>

    <div class="row g-4">
        <div class="col-xl-8">
            <section class="db-card p-4 h-100 d-flex flex-column gap-3">
                <div class="d-flex align-items-center gap-3">
                    <h2 class="flex-grow-1"><?= h($titreFlux) ?></h2>
                    <span class="small text-muted"><span class="d-inline-block rounded-1 me-1" style="width:12px;height:12px;background:#0f7a4a;"></span>Entrées</span>
                    <span class="small text-muted"><span class="d-inline-block rounded-1 me-1" style="width:12px;height:12px;background:#f59e5b;"></span>Sorties</span>
                </div>
                <div style="position:relative;height:260px;"><canvas id="chartFlux" role="img" aria-label="Entrées et sorties par période"></canvas></div>
            </section>
        </div>
        <div class="col-xl-4">
            <section class="db-card p-4 h-100 d-flex flex-column gap-3">
                <div class="d-flex align-items-center">
                    <h2 class="flex-grow-1">État des caisses</h2>
                    <a href="<?= h(url('caisse/index')) ?>" class="small fw-semibold">Gérer</a>
                </div>
                <?php if (!$etatCaisses): ?><p class="text-muted small m-0">Aucune caisse configurée.</p><?php endif; ?>
                <?php foreach ($etatCaisses as $c): $ouverte = $c['Statut'] === 'Ouverte'; ?>
                    <a href="<?= h($c['JourneeId'] ? url('journee/details', ['id' => $c['JourneeId']]) : url('caisse/details', ['id' => $c['CaisseId']])) ?>"
                       class="d-flex flex-column gap-1 p-3 border rounded-3 text-decoration-none text-dark">
                        <div class="d-flex align-items-center gap-2">
                            <span class="fw-bold small flex-grow-1"><?= h($c['Nom']) ?></span>
                            <?php if ($c['Statut'] === null): ?>
                                <span class="db-badge db-badge-off">Aucune journée</span>
                            <?php else: ?>
                                <span class="db-badge <?= $ouverte ? 'db-badge-ok' : 'db-badge-off' ?>"><?= $ouverte ? 'Ouverte' : 'Clôturée' ?></span>
                            <?php endif; ?>
                        </div>
                        <div class="d-flex justify-content-between small text-muted">
                            <span>
                                <?php if ($ouverte): ?>Ouverte le <?= date_fr($c['DateOuverture'], 'd/m à H:i') ?>
                                <?php elseif ($c['DateFermeture']): ?>Clôturée le <?= date_fr($c['DateFermeture'], 'd/m à H:i') ?><?php endif; ?>
                                <?= $c['Caissier'] ? ' · ' . h($c['Caissier']) : '' ?>
                            </span>
                            <?php if ($c['Statut'] !== null): ?><strong class="db-num text-dark"><?= fcfa($c['Solde']) ?> FCFA</strong><?php endif; ?>
                        </div>
                    </a>
                <?php endforeach; ?>
            </section>
        </div>
    </div>

    <div class="row g-4">
        <div class="col-xl-8">
            <section class="db-card p-4 h-100">
                <div class="d-flex align-items-center mb-2">
                    <h2 class="flex-grow-1">Dernières opérations</h2>
                    <a href="<?= h(url('rapport/operations', ['dateDebut' => $debut->format('Y-m-d'), 'dateFin' => $fin->format('Y-m-d'), 'caisseId' => $caisseId])) ?>" class="small fw-semibold">Voir tout le journal <i class="fa fa-chevron-right"></i></a>
                </div>
                <?php if (!$dernieres): ?>
                    <p class="text-muted small m-0 py-4 text-center">Aucune opération sur la période.</p>
                <?php else: ?>
                    <div class="table-responsive">
                        <table class="table table-hover align-middle small db-table mb-0">
                            <thead><tr><th>Date</th><th>Réf.</th><th>Libellé</th><th>Mode</th><th>Validation</th><th class="text-end">Montant</th></tr></thead>
                            <tbody>
                            <?php foreach ($dernieres as $o):
                                $entree = $o['TypeOperation'] === 'Encaissement';
                                $badge = ['Validé' => 'db-badge-ok', 'Rejeté' => 'db-badge-ko'][$o['StatutValidation']] ?? 'db-badge-wait'; ?>
                                <tr>
                                    <td class="db-num text-muted text-nowrap"><?= date_fr($o['DateOperation'], 'd/m H:i') ?></td>
                                    <td class="db-num text-muted"><a href="<?= h(url('journee/details', ['id' => $o['JourneeCaisseId']])) ?>">OP<?= str_pad((string) $o['Id'], 6, '0', STR_PAD_LEFT) ?></a></td>
                                    <td><div class="fw-semibold"><?= h($o['Libelle']) ?></div><div class="text-muted" style="font-size:12px;"><?= h($o['Caissier']) ?></div></td>
                                    <td><?= h($o['ModePaiement'] ?? '—') ?></td>
                                    <td><span class="db-badge <?= $badge ?>"><?= h($o['StatutValidation']) ?></span></td>
                                    <td class="db-num text-end fw-bold text-nowrap">
                                        <?php if ($o['StatutValidation'] === STATUT_REJETE): ?>
                                            <span class="text-muted text-decoration-line-through" title="Opération rejetée : exclue des totaux"><?= $entree ? '+' : '−' ?><?= fcfa($o['Montant']) ?></span>
                                        <?php else: ?>
                                            <span class="<?= $entree ? 'db-in' : 'db-out' ?>"><?= $entree ? '+' : '−' ?><?= fcfa($o['Montant']) ?></span>
                                        <?php endif; ?>
                                    </td>
                                </tr>
                            <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                <?php endif; ?>
            </section>
        </div>
        <div class="col-xl-4">
            <section class="db-card p-4 h-100 d-flex flex-column gap-3">
                <h2>Entrées par mode de paiement</h2>
                <?php if (!$parMode): ?><p class="text-muted small m-0">Aucun encaissement sur la période.</p><?php endif; ?>
                <?php foreach ($parMode as $m): $pct = $entrees > 0 ? round($m['m'] * 100 / $entrees) : 0; ?>
                    <div>
                        <div class="d-flex justify-content-between small mb-1">
                            <span class="fw-semibold"><?= h($m['l']) ?></span>
                            <span class="db-num text-muted"><?= fcfa($m['m']) ?> · <strong class="text-dark"><?= $pct ?> %</strong></span>
                        </div>
                        <div class="db-bar"><div style="width:<?= (int) $pct ?>%"></div></div>
                    </div>
                <?php endforeach; ?>
                <div class="border-top pt-3 d-flex flex-column gap-2">
                    <h3 class="fw-bold m-0" style="font-size:14px;">Principaux motifs de sortie</h3>
                    <?php if (!$topMotifs): ?><p class="text-muted small m-0">Aucun décaissement sur la période.</p><?php endif; ?>
                    <?php foreach ($topMotifs as $x): ?>
                        <div class="d-flex justify-content-between small"><span><?= h($x['l']) ?></span><strong class="db-num"><?= fcfa($x['m']) ?></strong></div>
                    <?php endforeach; ?>
                </div>
            </section>
        </div>
    </div>
</div>

<?php ob_start(); ?>
<script>
    (function () {
        const labels = <?= json_encode(array_column($flux, 'l')) ?>;
        const entrees = <?= json_encode(array_map('floatval', array_column($flux, 'e'))) ?>;
        const sorties = <?= json_encode(array_map('floatval', array_column($flux, 's'))) ?>;
        const fmt = new Intl.NumberFormat('fr-FR');
        new Chart(document.getElementById('chartFlux'), {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [
                    { label: 'Entrées', data: entrees, backgroundColor: '#0f7a4a', borderRadius: 5, maxBarThickness: 22 },
                    { label: 'Sorties', data: sorties, backgroundColor: '#f59e5b', borderRadius: 5, maxBarThickness: 22 }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { display: false }, tooltip: { callbacks: { label: (c) => c.dataset.label + ' : ' + fmt.format(c.parsed.y) + ' FCFA' } } },
                scales: { x: { grid: { display: false } }, y: { beginAtZero: true, ticks: { callback: (v) => fmt.format(v) } } }
            }
        });
    })();
</script>
<?php $scripts = ob_get_clean(); ?>
