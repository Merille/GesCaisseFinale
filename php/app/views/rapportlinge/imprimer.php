<?php $titreImpression = 'Rapport des dépôts de linge'; require __DIR__ . '/../partials/print_debut.php'; ?>
<h1>Rapport des dépôts de linge</h1>
<p class="muted"><?= h(rapportlinge_periode($f)) ?></p>
<h2>Par statut</h2>
<table>
    <tr><th>Statut</th><th class="r">Dépôts</th><th class="r">Articles</th><th class="r">Montant</th><th class="r">Acomptes</th><th class="r">Reste à encaisser</th><th class="r">En retard</th></tr>
    <?php foreach ($parStatut as $statut => $s): ?>
        <tr><td><?= h($statut) ?></td><td class="r"><?= (int) $s['Nombre'] ?></td><td class="r"><?= quantite_fr($s['Articles']) ?></td><td class="r"><?= fcfa($s['Montant']) ?></td>
            <td class="r"><?= fcfa($s['Acomptes']) ?></td><td class="r"><?= fcfa($s['Reste']) ?></td><td class="r"><?= (int) $s['EnRetard'] ?></td></tr>
    <?php endforeach; ?>
    <tr class="total"><td>Total (hors annulés)</td><td class="r"><?= (int) $total['Nombre'] ?></td><td class="r"><?= quantite_fr($total['Articles']) ?></td><td class="r"><?= fcfa($total['Montant']) ?></td>
        <td class="r"><?= fcfa($total['Acomptes']) ?></td><td class="r"><?= fcfa($total['Reste']) ?></td><td class="r"><?= (int) $total['EnRetard'] ?></td></tr>
</table>
<h2>Détail des dépôts</h2>
<table>
    <tr><th class="r">N°</th><th>Déposé le</th><th>Client</th><th class="r">Articles</th><th class="r">Montant</th><th class="r">Acompte</th><th class="r">Reste</th><th>Retrait prévu</th><th>Statut</th></tr>
    <?php if (!$lignes): ?><tr><td colspan="9" class="muted">Aucun dépôt.</td></tr><?php endif; ?>
    <?php foreach ($lignes as $l): $fin = $l['DateRetrait'] ?: $l['DateAnnulation']; ?>
        <tr><td class="r"><?= (int) $l['Numero'] ?></td><td><?= date_fr($l['DateDepot'], 'd/m/Y H:i') ?></td>
            <td><?= h($l['NomClient']) ?><?= $l['TelephoneClient'] ? ' · ' . h($l['TelephoneClient']) : '' ?></td><td class="r"><?= quantite_fr($l['NbArticles']) ?></td>
            <td class="r"><?= fcfa($l['Total']) ?></td><td class="r"><?= (float) $l['Acompte'] > 0 ? fcfa($l['Acompte']) : '' ?></td><td class="r"><?= $l['Reste'] > 0 ? fcfa($l['Reste']) : '' ?></td>
            <td><?= $l['DateRetraitPrevue'] ? date_fr($l['DateRetraitPrevue']) . ($l['EnRetard'] ? ' (en retard)' : '') : '' ?></td>
            <td><?= h($l['Statut']) ?><?= $fin ? ' le ' . date_fr($fin, 'd/m/Y H:i') : '' ?></td></tr>
    <?php endforeach; ?>
</table>
<p class="muted">Montant : articles du dépôt (TTC). Acompte : versé au dépôt, encaissé dans la journée du dépôt (remboursé si le dépôt est annulé). Reste à encaisser : montant moins acompte, pour les dépôts en cours ou prêts. Les totaux ne comptent pas les dépôts annulés.</p>
<?php require __DIR__ . '/../partials/print_fin.php'; ?>
