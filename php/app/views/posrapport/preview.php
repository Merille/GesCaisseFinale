<?php $titreImpression = 'Rapport du point de vente'; require __DIR__ . '/../partials/print_debut.php'; ?>
<?php $part = fn($v) => str_replace('.', ',', (string) ($kpi['ca'] != 0 ? round((float) $v * 100 / $kpi['ca'], 1) : 0)); ?>
<h1>Rapport du point de vente</h1>
<p class="muted">
    Période : <?= date_fr($f['dateDebut']) ?> au <?= date_fr($f['dateFin']) ?>
    — Caisse : <?= $caisse ? h($caisse['ChkCode'] . ' - ' . $caisse['ChkDescription']) : 'toutes' ?>
</p>

<h2>Synthèse</h2>
<table>
    <tr><td>Chiffre d'affaires net TTC</td><td class="r"><strong><?= fcfa($kpi['ca']) ?></strong></td><td>Tickets de vente</td><td class="r"><?= fcfa($kpi['tickets']) ?></td></tr>
    <tr><td>Chiffre d'affaires net HT</td><td class="r"><?= fcfa($kpi['ht']) ?></td><td>Panier moyen TTC</td><td class="r"><?= fcfa($kpi['panier']) ?></td></tr>
    <tr><td>Ventes TTC</td><td class="r"><?= fcfa($kpi['ventes']) ?></td><td>Articles vendus (net)</td><td class="r"><?= quantite_fr($kpi['articles']) ?></td></tr>
    <tr><td>Retours TTC</td><td class="r"><?= fcfa($kpi['retours']) ?></td><td>Retours / ventes annulées</td><td class="r"><?= $kpi['nbRetours'] ?> / <?= $kpi['annulees'] ?></td></tr>
</table>

<h2>Ventes par produit</h2>
<table>
    <tr><th>#</th><th>Code</th><th>Produit</th><th>Catégorie</th><th class="r">Quantité</th><th class="r">CA TTC</th><th class="r">Part</th></tr>
    <?php foreach ($produits as $i => $p): ?>
        <tr><td><?= $i + 1 ?></td><td><?= h($p['code'] ?? '') ?></td><td><?= h($p['nom']) ?></td><td><?= h($p['categorie']) ?></td>
            <td class="r"><?= quantite_fr($p['qte']) ?></td><td class="r"><?= fcfa($p['ca']) ?></td><td class="r"><?= $part($p['ca']) ?> %</td></tr>
    <?php endforeach; ?>
    <?php if (!$produits): ?><tr><td colspan="7" class="muted">Aucune vente sur la période.</td></tr><?php endif; ?>
</table>

<h2>Ventes par catégorie</h2>
<table>
    <tr><th>Catégorie</th><th class="r">Quantité</th><th class="r">CA TTC</th><th class="r">Part</th></tr>
    <?php foreach ($categories as $c): ?>
        <tr><td><?= h($c['nom']) ?></td><td class="r"><?= quantite_fr($c['qte']) ?></td><td class="r"><?= fcfa($c['ca']) ?></td><td class="r"><?= $part($c['ca']) ?> %</td></tr>
    <?php endforeach; ?>
    <?php if (!$categories): ?><tr><td colspan="4" class="muted">Aucune vente sur la période.</td></tr><?php endif; ?>
</table>

<h2>Ventes par vendeur</h2>
<table>
    <tr><th>Vendeur</th><th class="r">Tickets</th><th class="r">Ventes TTC</th><th class="r">Retours TTC</th><th class="r">CA net TTC</th><th class="r">Panier moyen</th></tr>
    <?php foreach ($vendeurs as $v): ?>
        <tr><td><?= h($v['nom']) ?></td><td class="r"><?= (int) $v['tickets'] ?></td><td class="r"><?= fcfa($v['ventes']) ?></td><td class="r"><?= fcfa($v['retours']) ?></td>
            <td class="r"><?= fcfa($v['ca']) ?></td><td class="r"><?= (int) $v['tickets'] > 0 ? fcfa($v['ventes'] / $v['tickets']) : '—' ?></td></tr>
    <?php endforeach; ?>
    <?php if (!$vendeurs): ?><tr><td colspan="6" class="muted">Aucune vente sur la période.</td></tr><?php endif; ?>
</table>

<h2>Ventes par heure</h2>
<table>
    <tr><th>Heure</th><th class="r">Tickets</th><th class="r">CA net TTC</th></tr>
    <?php foreach ($parHeure as $h): ?>
        <tr><td><?= sprintf('%02dh - %02dh', $h['h'], ($h['h'] + 1) % 24) ?></td><td class="r"><?= (int) $h['tickets'] ?></td><td class="r"><?= fcfa($h['ca']) ?></td></tr>
    <?php endforeach; ?>
    <?php if (!$parHeure): ?><tr><td colspan="3" class="muted">Aucune vente sur la période.</td></tr><?php endif; ?>
</table>

<h2>Ventes par jour</h2>
<table>
    <tr><th>Date</th><th class="r">Tickets</th><th class="r">CA net TTC</th></tr>
    <?php foreach ($parJour as $j): ?>
        <tr><td><?= date_fr($j['d']) ?></td><td class="r"><?= (int) $j['tickets'] ?></td><td class="r"><?= fcfa($j['ca']) ?></td></tr>
    <?php endforeach; ?>
    <tr class="total"><td>Total</td><td class="r"><?= fcfa($kpi['tickets']) ?></td><td class="r"><?= fcfa($kpi['ca']) ?></td></tr>
</table>

<h2>Encaissements par mode de paiement</h2>
<table>
    <tr><th>Mode</th><th class="r">Tickets</th><th class="r">Encaissé net</th></tr>
    <?php foreach ($modes as $m): ?>
        <tr><td><?= h($m['nom']) ?></td><td class="r"><?= (int) $m['tickets'] ?></td><td class="r"><?= fcfa($m['montant']) ?></td></tr>
    <?php endforeach; ?>
    <?php if (!$modes): ?><tr><td colspan="3" class="muted">Aucun encaissement sur la période.</td></tr><?php endif; ?>
</table>
<h2>Taxes collectées</h2>
<table>
    <tr><th>Taxe</th><th class="r">Montant collecté</th></tr>
    <?php foreach ($taxes as $t): ?>
        <tr><td><?= h($t['nom']) ?></td><td class="r"><?= fcfa($t['montant']) ?></td></tr>
    <?php endforeach; ?>
    <?php if (!$taxes): ?><tr><td colspan="2" class="muted">Aucune taxe sur la période.</td></tr><?php endif; ?>
</table>
<p class="muted">Chiffre d'affaires net = ventes − retours ; les ventes annulées sont exclues. Encaissements nets : remboursements des retours déduits.</p>
<?php require __DIR__ . '/../partials/print_fin.php'; ?>
