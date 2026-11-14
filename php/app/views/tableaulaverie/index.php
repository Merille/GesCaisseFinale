<?php
$titre = 'Tableau de bord laverie';
$admin = peut('rapports_pdv');   // liens vers le rapport des dépôts
$s = fn(float $n) => $n > 1 ? 's' : '';
$lien = fn(string $route, array $p = []) => h(url($route, $p));
$aujourdhui = date('Y-m-d');
$joursRetard = $aRetirer['PlusAncien'] ? (int) floor((strtotime($aujourdhui) - strtotime($aRetirer['PlusAncien'])) / 86400) : 0;
$top = array_key_first($topArticles);
// Tuile : lien vers la page détaillée (administrateurs) ou l'écran de vente.
$tuile = function (string $couleur, string $icone, string $titreTuile, string $corps, ?string $href) {
    $balise = $href ? 'a href="' . $href . '"' : 'div';
    return '<' . $balise . ' class="lav-tuile ' . $couleur . '"><span class="lav-icone"><i class="fas ' . $icone . '"></i></span><div>'
        . '<h3>' . h($titreTuile) . '</h3>' . $corps . '</div></' . ($href ? 'a' : 'div') . '>';
};
?>
<link rel="stylesheet" href="<?= asset('assets/css/laverie.css') ?>">

<div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-3">
    <div class="text-muted small">Laverie · <?= h(date_fr($aujourdhui, 'd/m/Y')) ?> · semaine du <?= h(date_fr(date('Y-m-d', strtotime('monday this week')))) ?></div>
    <div class="d-flex gap-2">
        <?php if (peut('vendre')): ?><a class="btn btn-primary" href="<?= $lien('pos/index') ?>"><i class="fas fa-store"></i> Vendre / déposer</a><?php endif; ?>
        <?php if ($admin): ?><a class="btn btn-outline-primary" href="<?= $lien('rapportlinge/index') ?>"><i class="fas fa-chart-line"></i> Rapport des dépôts</a><?php endif; ?>
    </div>
</div>

<div class="lav-tuiles mb-4" id="lavTuiles">
    <?= $tuile('lav-bleu', 'fa-shirt', 'Dépôts',
        '<div class="lav-grand">' . (int) $depotsJour['Nombre'] . ' <small>aujourd\'hui</small></div>'
        . '<div class="lav-ligne"><b>' . quantite_fr((float) $depotsJour['Articles']) . '</b> article' . $s((float) $depotsJour['Articles']) . ' · <b>' . fcfa($depotsJour['Montant']) . '</b> FCFA</div>'
        . '<div class="lav-ligne">Cette semaine : <b>' . $depotsSemaine . '</b></div>',
        $admin ? $lien('rapportlinge/index', ['du' => $aujourdhui, 'au' => $aujourdhui]) : (peut('vendre') ? $lien('pos/index') : null)) ?>
    <?= $tuile('lav-ciel', 'fa-hand-holding', 'Retraits',
        '<div class="lav-grand">' . (int) $retraits['Jour'] . ' <small>aujourd\'hui</small></div>'
        . '<div class="lav-ligne">Encaissé : <b>' . fcfa($retraits['MontantJour']) . '</b> FCFA</div>'
        . '<div class="lav-ligne">Cette semaine : <b>' . (int) $retraits['Semaine'] . '</b></div>',
        $admin ? $lien('rapportlinge/index', ['du' => date('Y-m-d', strtotime('monday this week')), 'au' => $aujourdhui, 'statut' => 'Retiré']) : null) ?>
    <?= $tuile('lav-indigo', 'fa-box-open', 'À retirer',
        '<div class="lav-grand">' . (int) $aRetirer['Nombre'] . ' <small>dépôt' . $s((float) $aRetirer['Nombre']) . '</small></div>'
        . '<div class="lav-ligne">dont <b>' . (int) $aRetirer['Prets'] . '</b> prêt' . $s((float) $aRetirer['Prets']) . ' à remettre</div>'
        . '<div class="lav-ligne">Reste à encaisser : <b>' . fcfa($aRetirer['Reste']) . '</b> FCFA</div>',
        $admin ? $lien('rapportlinge/index', ['statut' => 'À retirer']) : (peut('vendre') ? $lien('pos/index') : null)) ?>
    <?= $tuile((int) $aRetirer['Retard'] ? 'lav-rouge' : 'lav-ardoise', 'fa-triangle-exclamation', 'En retard',
        '<div class="lav-grand">' . (int) $aRetirer['Retard'] . ' <small>dépôt' . $s((float) $aRetirer['Retard']) . '</small></div>'
        . ((int) $aRetirer['Retard'] ? '<div class="lav-ligne">Le plus ancien : <b>' . $joursRetard . ' jour' . $s($joursRetard) . '</b> de retard</div>'
            . '<div class="lav-ligne">Reste à encaisser : <b>' . fcfa($aRetirer['ResteRetard']) . '</b> FCFA</div>'
            : '<div class="lav-ligne">Aucun linge en retard.</div>'),
        $admin ? $lien('rapportlinge/index', ['statut' => 'En retard']) : null) ?>
    <?= $tuile('lav-violet', 'fa-users', 'Clients',
        '<div class="lav-grand">' . $clientsMois . ' <small>servi' . $s($clientsMois) . ' ce mois</small></div>'
        . '<div class="lav-ligne">Fiches clients : <b>' . $clientsTotal . '</b></div>'
        . '<div class="lav-ligne">Dû (clients en compte) : <b>' . fcfa($du) . '</b> FCFA</div>',
        peut('tiers') ? $lien('client/index') : null) ?>
    <?= $tuile('lav-vert', 'fa-tags', 'Articles',
        '<div class="lav-grand">' . $articles . ' <small>en vente</small></div>'
        . '<div class="lav-ligne"><b>' . $categories . '</b> catégorie' . $s($categories) . '</div>'
        . '<div class="lav-ligne">' . ($top !== null ? 'Le plus déposé ce mois : <b>' . h($top) . '</b> (' . quantite_fr($topArticles[$top]) . ')' : 'Aucun dépôt ce mois.') . '</div>',
        peut('catalogue') ? $lien('produit/index') : null) ?>
    <?= $tuile('lav-ambre', 'fa-bottle-droplet', 'Produits d\'entretien',
        '<div class="lav-grand">' . $aRacheter . ' <small>à racheter</small></div>'
        . '<div class="lav-ligne">Valeur du stock : <b>' . fcfa($entretien['Valeur']) . '</b> FCFA</div>'
        . '<div class="lav-ligne">Achats du mois : <b>' . fcfa($achatsMois) . '</b> FCFA</div>',
        peut('achats') ? $lien('achat/stock') : null) ?>
    <?= $tuile('lav-rose', 'fa-cash-register', 'Caisse',
        '<div class="lav-grand">' . fcfa($encaissements) . ' <small>FCFA encaissés</small></div>'
        . '<div class="lav-ligne">aujourd\'hui (ventes, retraits, acomptes)</div>'
        . '<div class="lav-ligne">' . ($journees ? 'Journée ouverte : <b>' . h(implode(', ', array_column($journees, 'ChkCode'))) . '</b>' : 'Aucune journée ouverte') . '</div>',
        !peut('caisses') ? null : ($journees ? $lien('journee/details', ['id' => $journees[0]['Id']]) : $lien('caisse/index'))) ?>
</div>

<div class="row g-3">
    <div class="col-lg-6">
        <div class="lav-carte">
            <h4>Dépôts et retraits des 14 derniers jours</h4>
            <div style="height:260px"><canvas id="lavGraphique" aria-label="Dépôts et retraits par jour" role="img"></canvas></div>
        </div>
    </div>
    <div class="col-lg-3 col-md-6">
        <div class="lav-carte" id="lavPrets">
            <h4><i class="fas fa-check text-success"></i> Prêts à remettre</h4>
            <?php if (!$prets): ?><div class="lav-vide">Aucun linge prêt en attente.</div><?php else: ?>
            <ul class="lav-liste">
                <?php foreach ($prets as $d): ?>
                    <li><span><b>N° <?= (int) $d['Numero'] ?></b> · <?= h($d['NomClient']) ?><small><?= h($d['TelephoneClient'] ?? '') ?><?= $d['DatePret'] ? ' · prêt le ' . h(date_fr($d['DatePret'], 'd/m')) : '' ?></small></span>
                        <span class="lav-montant"><?= fcfa(max(0, (float) $d['Total'] - (float) $d['Acompte'])) ?></span></li>
                <?php endforeach; ?>
            </ul>
            <?php endif; ?>
        </div>
    </div>
    <div class="col-lg-3 col-md-6">
        <div class="lav-carte" id="lavRetards">
            <h4><i class="fas fa-triangle-exclamation text-danger"></i> En retard</h4>
            <?php if (!$retards): ?><div class="lav-vide">Aucun linge en retard.</div><?php else: ?>
            <ul class="lav-liste">
                <?php foreach ($retards as $d): $j = (int) floor((strtotime($aujourdhui) - strtotime($d['DateRetraitPrevue'])) / 86400); ?>
                    <li><span><b>N° <?= (int) $d['Numero'] ?></b> · <?= h($d['NomClient']) ?><small><?= h($d['TelephoneClient'] ?? '') ?> · prévu le <?= h(date_fr($d['DateRetraitPrevue'], 'd/m')) ?> (<?= $j ?> j)</small></span>
                        <span class="lav-montant"><?= fcfa(max(0, (float) $d['Total'] - (float) $d['Acompte'])) ?></span></li>
                <?php endforeach; ?>
            </ul>
            <?php endif; ?>
        </div>
    </div>
</div>
<?php ob_start(); ?>
<script>
    (function () {
        const jours = <?= json_encode(array_map(fn($j) => date('d/m', strtotime($j)), array_keys($jours))) ?>;
        const valeurs = <?= json_encode(array_values($jours)) ?>;
        if (!window.Chart) return;
        new Chart(document.getElementById('lavGraphique'), {
            type: 'bar',
            data: { labels: jours, datasets: [
                { label: 'Dépôts', data: valeurs.map(v => v.depots), backgroundColor: '#1d74c9', borderRadius: 4, borderSkipped: 'bottom', maxBarThickness: 18 },
                { label: 'Retraits', data: valeurs.map(v => v.retraits), backgroundColor: '#e8890c', borderRadius: 4, borderSkipped: 'bottom', maxBarThickness: 18 }
            ] },
            options: { maintainAspectRatio: false, plugins: { legend: { position: 'top', align: 'end' } },
                scales: { y: { beginAtZero: true, ticks: { precision: 0 }, grid: { color: '#eef2f6' } }, x: { grid: { display: false } } } }
        });
    })();
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
