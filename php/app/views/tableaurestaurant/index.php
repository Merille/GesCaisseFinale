<?php
$titre = 'Tableau de bord restaurant-bar';
$admin = peut('rapports_pdv');   // liens vers les rapports du point de vente
$s = fn(float $n) => $n > 1 ? 's' : '';
$lien = fn(string $route, array $p = []) => h(url($route, $p));
$aujourdhui = date('Y-m-d');
$lundi = date('Y-m-d', strtotime('monday this week'));
$rapportJour = $admin ? $lien('posrapport/index', ['dateDebut' => $aujourdhui, 'dateFin' => $aujourdhui]) : null;
$parCouvert = (int) $jour['Couverts'] > 0 ? (float) $jour['VentesCouverts'] / (int) $jour['Couverts'] : 0;
$panier = (int) $jour['Tickets'] > 0 ? (float) $jour['Ventes'] / (int) $jour['Tickets'] : 0;
$depuis = fn(string $date) => max(0, (int) floor((time() - strtotime($date)) / 60));
$duree = fn(int $min) => $min >= 60 ? intdiv($min, 60) . ' h ' . str_pad((string) ($min % 60), 2, '0', STR_PAD_LEFT) : $min . ' min';
// Tuile : lien vers la page détaillée (administrateurs) ou l'écran de vente.
$tuile = function (string $couleur, string $icone, string $titreTuile, string $corps, ?string $href) {
    $balise = $href ? 'a href="' . $href . '"' : 'div';
    return '<' . $balise . ' class="lav-tuile ' . $couleur . '"><span class="lav-icone"><i class="fas ' . $icone . '"></i></span><div>'
        . '<h3>' . h($titreTuile) . '</h3>' . $corps . '</div></' . ($href ? 'a' : 'div') . '>';
};
?>
<link rel="stylesheet" href="<?= asset('assets/css/laverie.css') ?>">

<div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-3">
    <div class="text-muted small">Restaurant · Bar · <?= h(date_fr($aujourdhui, 'd/m/Y')) ?> · semaine du <?= h(date_fr($lundi)) ?></div>
    <div class="d-flex gap-2">
        <?php if (peut('vendre')): ?><a class="btn btn-primary" href="<?= $lien('pos/index') ?>"><i class="fas fa-store"></i> Vendre</a><?php endif; ?>
        <?php if (peut('cuisine')): ?><a class="btn btn-outline-primary" href="<?= $lien('cuisine/index') ?>"><i class="fas fa-fire-burner"></i> Écran cuisine / bar</a><?php endif; ?>
        <?php if ($admin): ?><a class="btn btn-outline-primary" href="<?= $lien('posrapport/index') ?>"><i class="fas fa-chart-line"></i> Rapports des ventes</a><?php endif; ?>
    </div>
</div>

<div class="lav-tuiles mb-4" id="restoTuiles">
    <?= $tuile('lav-bleu', 'fa-sack-dollar', 'Ventes',
        '<div class="lav-grand">' . fcfa($jour['CA']) . ' <small>FCFA</small></div>'
        . '<div class="lav-ligne">Aujourd\'hui : <b>' . (int) $jour['Tickets'] . '</b> ticket' . $s((float) $jour['Tickets']) . '</div>'
        . '<div class="lav-ligne">Panier moyen : <b>' . fcfa($panier) . '</b> FCFA</div>'
        . '<div class="lav-ligne">Cette semaine : <b>' . fcfa($semaine['CA']) . '</b> FCFA</div>',
        $rapportJour ?? (peut('vendre') ? $lien('pos/index') : null)) ?>
    <?= $tuile('lav-indigo', 'fa-chair', 'Tables',
        '<div class="lav-grand">' . $occupees . ' <small>/ ' . $tables . ' occupée' . $s($occupees) . '</small></div>'
        . '<div class="lav-ligne">Couverts en salle : <b>' . $couvertsSalle . '</b></div>'
        . '<div class="lav-ligne">En cours : <b>' . fcfa($enCours) . '</b> FCFA (' . $nbOuvertes . ' commande' . $s($nbOuvertes) . ')</div>',
        peut('vendre') ? $lien('pos/index') : null) ?>
    <?= $tuile('lav-ciel', 'fa-users', 'Couverts',
        '<div class="lav-grand">' . (int) $jour['Couverts'] . ' <small>servi' . $s((float) $jour['Couverts']) . ' aujourd\'hui</small></div>'
        . '<div class="lav-ligne">Par couvert : <b>' . fcfa($parCouvert) . '</b> FCFA</div>'
        . '<div class="lav-ligne">Cette semaine : <b>' . (int) $semaine['Couverts'] . '</b></div>',
        $rapportJour) ?>
    <?= $tuile($attente >= 20 ? 'lav-rouge' : 'lav-ambre', 'fa-fire-burner', 'Cuisine et bar',
        '<div class="lav-grand">' . $nbBons . ' <small>bon' . $s($nbBons) . ' à préparer</small></div>'
        . '<div class="lav-ligne">Cuisine : <b>' . $parPoste['Cuisine'] . '</b> · Bar : <b>' . $parPoste['Bar'] . '</b></div>'
        . '<div class="lav-ligne">' . ($nbBons ? 'Le plus ancien : <b>' . $duree($attente) . '</b> d\'attente' : 'Rien en attente.') . '</div>',
        peut('cuisine') ? $lien('cuisine/index') : null) ?>
    <?= $tuile('lav-violet', 'fa-motorcycle', 'Livraisons',
        '<div class="lav-grand">' . (int) $aLivrer['Nombre'] . ' <small>à livrer</small></div>'
        . '<div class="lav-ligne">À encaisser : <b>' . $aEncaisser['Nombre'] . '</b> · <b>' . fcfa($aEncaisser['Montant']) . '</b> FCFA</div>'
        . '<div class="lav-ligne">Livrée' . $s($livrees) . ' aujourd\'hui : <b>' . $livrees . '</b></div>',
        $admin ? $lien('rapportlivraison/index') : (peut('vendre') ? $lien('pos/index') : null)) ?>
    <?= $tuile('lav-vert', 'fa-utensils', 'Meilleures ventes',
        '<div class="lav-grand">' . quantite_fr($articlesVendus) . ' <small>article' . $s($articlesVendus) . ' vendu' . $s($articlesVendus) . '</small></div>'
        . '<div class="lav-ligne">' . ($top ? 'Le plus vendu : <b>' . h($top['Nom']) . '</b> (' . quantite_fr($top['Qte']) . ')' : 'Aucune vente aujourd\'hui.') . '</div>'
        . ($topCategorie ? '<div class="lav-ligne">Catégorie : <b>' . h($topCategorie['Nom']) . '</b> (' . fcfa($topCategorie['CA']) . ' FCFA)</div>' : ''),
        $rapportJour) ?>
    <?= $tuile($stockBas ? 'lav-rouge' : 'lav-ardoise', 'fa-boxes-stacked', 'Stock',
        '<div class="lav-grand">' . $stockBas . ' <small>sous le seuil</small></div>'
        . '<div class="lav-ligne">En rupture : <b>' . $ruptures . '</b></div>'
        . '<div class="lav-ligne">Produits suivis : <b>' . $suivis . '</b></div>',
        peut('stock') ? $lien('stock/index') : null) ?>
    <?= $tuile('lav-rose', 'fa-cash-register', 'Caisse',
        '<div class="lav-grand">' . fcfa($encaissements) . ' <small>FCFA encaissés</small></div>'
        . '<div class="lav-ligne">Pourboires : <b>' . fcfa($jour['Pourboires']) . '</b> FCFA</div>'
        . '<div class="lav-ligne">' . ($journees ? 'Journée ouverte : <b>' . h(implode(', ', array_column($journees, 'ChkCode'))) . '</b>' : 'Aucune journée ouverte') . '</div>',
        !peut('caisses') ? null : ($journees ? $lien('journee/details', ['id' => $journees[0]['Id']]) : $lien('caisse/index'))) ?>
</div>

<div class="row g-3">
    <div class="col-lg-6">
        <div class="lav-carte">
            <h4>Chiffre d'affaires des 14 derniers jours</h4>
            <div style="height:260px"><canvas id="restoGraphique" aria-label="Chiffre d'affaires par jour" role="img"></canvas></div>
        </div>
    </div>
    <div class="col-lg-3 col-md-6">
        <div class="lav-carte" id="restoTables">
            <h4><i class="fas fa-chair text-primary"></i> Tables occupées</h4>
            <?php if (!$tablesOccupees): ?><div class="lav-vide">Aucune table occupée.</div><?php else: ?>
            <ul class="lav-liste">
                <?php foreach ($tablesOccupees as $o): ?>
                    <li><span><b><?= h($o['TableNom'] ?? '?') ?></b> · <?= (int) $o['Couverts'] ?> couvert<?= $s((float) $o['Couverts']) ?><small><?= h($o['Serveur'] ?? '') ?><?= $o['Serveur'] ? ' · ' : '' ?>depuis <?= h($duree($depuis($o['DateOuverture']))) ?></small></span>
                        <span class="lav-montant"><?= fcfa($o['Total']) ?></span></li>
                <?php endforeach; ?>
            </ul>
            <?php endif; ?>
        </div>
    </div>
    <div class="col-lg-3 col-md-6">
        <div class="lav-carte" id="restoBons">
            <h4><i class="fas fa-fire-burner text-warning"></i> Bons en attente</h4>
            <?php if (!$bons): ?><div class="lav-vide">Aucun bon en attente.</div><?php else: ?>
            <ul class="lav-liste">
                <?php foreach ($bons as $b): ?>
                    <li><span><b>Bon <?= (int) $b['Numero'] ?></b> · <?= h($b['Poste']) ?><small><?= $b['TableNom'] ? h($b['TableNom']) . ' · ' : '' ?><?= (int) $b['Lignes'] ?> ligne<?= $s((float) $b['Lignes']) ?></small></span>
                        <span class="lav-montant"><?= h($duree($depuis($b['DateEnvoi']))) ?></span></li>
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
        const fcfa = n => Math.round(n).toLocaleString('fr-FR') + ' FCFA';
        new Chart(document.getElementById('restoGraphique'), {
            type: 'bar',
            data: { labels: jours, datasets: [
                { label: "Chiffre d'affaires", data: valeurs, backgroundColor: '#1d74c9', borderRadius: 4, borderSkipped: 'bottom', maxBarThickness: 22 }
            ] },
            options: { maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: c => fcfa(c.parsed.y) } } },
                scales: { y: { beginAtZero: true, ticks: { callback: v => Math.round(v).toLocaleString('fr-FR') }, grid: { color: '#eef2f6' } }, x: { grid: { display: false } } } }
        });
    })();
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
