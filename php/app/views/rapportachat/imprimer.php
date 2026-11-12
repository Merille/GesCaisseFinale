<?php $titreImpression = 'Rapport des achats et consommations'; require __DIR__ . '/../partials/print_debut.php'; ?>
<h1>Rapport des achats et consommations</h1>
<p class="muted"><?= h($periode) ?></p>
<h2>Par fournisseur</h2>
<table>
    <tr><th>Fournisseur</th><th class="r">Achats</th><th class="r">Montant</th><th class="r">Réglé</th><th class="r">Reste à payer</th></tr>
    <?php foreach ($parFournisseur as $nom => $s): ?>
        <tr><td><?= h($nom) ?></td><td class="r"><?= (int) $s['Nombre'] ?></td><td class="r"><?= fcfa($s['Montant']) ?></td><td class="r"><?= fcfa($s['Regle']) ?></td><td class="r"><?= fcfa($s['Reste']) ?></td></tr>
    <?php endforeach; ?>
    <tr class="total"><td>Total (hors annulés)</td><td class="r"><?= (int) $total['Nombre'] ?></td><td class="r"><?= fcfa($total['Montant']) ?></td><td class="r"><?= fcfa($total['Regle']) ?></td><td class="r"><?= fcfa($total['Reste']) ?></td></tr>
</table>
<h2>Par produit : achats et consommations</h2>
<table>
    <tr><th>Produit</th><th class="r">Qté achetée</th><th class="r">Montant acheté</th><th class="r">Prix moyen</th><th class="r">Qté consommée</th><th class="r">Valeur consommée</th><th class="r">Stock</th></tr>
    <?php if (!$produits): ?><tr><td colspan="7" class="muted">Aucun achat ni consommation.</td></tr><?php endif; ?>
    <?php foreach ($produits as $p): ?>
        <tr><td><?= h($p['Code'] . ' · ' . $p['Nom']) ?></td><td class="r"><?= $p['QteAchetee'] ? quantite_fr($p['QteAchetee']) . ' ' . h($p['Unite']) : '' ?></td>
            <td class="r"><?= $p['MontantAchete'] ? fcfa($p['MontantAchete']) : '' ?></td><td class="r"><?= $p['QteAchetee'] > 0 ? quantite_fr($p['MontantAchete'] / $p['QteAchetee']) : '' ?></td>
            <td class="r"><?= $p['QteConsommee'] ? quantite_fr($p['QteConsommee']) . ' ' . h($p['Unite']) : '' ?></td><td class="r"><?= $p['ValeurConsommee'] ? fcfa($p['ValeurConsommee']) : '' ?></td>
            <td class="r"><?= quantite_fr($p['Stock']) ?> <?= h($p['Unite']) ?></td></tr>
    <?php endforeach; ?>
    <tr class="total"><td>Total</td><td></td><td class="r"><?= fcfa($totalProduits['MontantAchete']) ?></td><td></td><td></td><td class="r"><?= fcfa($totalProduits['ValeurConsommee']) ?></td><td></td></tr>
</table>
<h2>Détail des achats</h2>
<table>
    <tr><th class="r">N°</th><th>Date</th><th>Fournisseur</th><th>Référence</th><th class="r">Montant</th><th class="r">Réglé</th><th class="r">Reste</th><th>Statut</th></tr>
    <?php if (!$achats): ?><tr><td colspan="8" class="muted">Aucun achat.</td></tr><?php endif; ?>
    <?php foreach ($achats as $a): ?>
        <tr><td class="r"><?= (int) $a['Numero'] ?></td><td><?= date_fr($a['DateAchat']) ?></td><td><?= h((string) ($a['Fournisseur'] ?? '')) ?></td><td><?= h((string) $a['Reference']) ?></td>
            <td class="r"><?= fcfa($a['Total']) ?></td><td class="r"><?= fcfa($a['Regle']) ?></td><td class="r"><?= $a['Reste'] > 0 ? fcfa($a['Reste']) : '' ?></td><td><?= rapportachat_statut($a) ?></td></tr>
    <?php endforeach; ?>
</table>
<p class="muted">Les totaux ne comptent pas les achats annulés. Consommations : sorties de la période, valorisées au coût actuel du produit (coût moyen pondéré). Stock : quantité actuelle dans le dépôt des achats.</p>
<?php require __DIR__ . '/../partials/print_fin.php'; ?>
