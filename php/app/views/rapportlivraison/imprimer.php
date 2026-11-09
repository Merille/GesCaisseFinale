<?php $titreImpression = 'Rapport des livraisons'; require __DIR__ . '/../partials/print_debut.php';
$nomLivreur = '';
foreach ($livreurs as $l) {
    if ((int) $l['Id'] === $f['livreur']) {
        $nomLivreur = $l['Nom'];
    }
}
?>
<h1>Rapport des livraisons</h1>
<p class="muted">
    Période : du <?= date_fr($f['du']) ?> au <?= date_fr($f['au']) ?>
    — Livreur : <?= $nomLivreur !== '' ? h($nomLivreur) : 'tous' ?>
    — Statut : <?= $f['statut'] !== '' ? h($f['statut']) : 'tous' ?>
</p>
<h2>Par livreur</h2>
<table>
    <tr><th>Livreur</th><th>Moyen</th><th class="r">Livraisons</th><th class="r">Livrées</th><th class="r">À livrer</th><th class="r">À encaisser</th><th class="r">Montant des ventes</th><th class="r">Frais de livraison</th></tr>
    <?php foreach ($parLivreur as $l): ?>
        <tr><td><?= h((string) $l['Livreur']) ?></td><td><?= h((string) $l['Moyen']) ?></td><td class="r"><?= (int) $l['Livraisons'] ?></td><td class="r"><?= (int) $l['Livrees'] ?></td>
            <td class="r"><?= (int) $l['ALivrer'] ?></td><td class="r"><?= (int) $l['AEncaisser'] ?></td><td class="r"><?= fcfa($l['Montant']) ?></td><td class="r"><?= fcfa($l['Frais']) ?></td></tr>
    <?php endforeach; ?>
    <tr class="total"><td colspan="2">Total</td><td class="r"><?= (int) $total['Livraisons'] ?></td><td class="r"><?= (int) $total['Livrees'] ?></td><td class="r"><?= (int) $total['ALivrer'] ?></td>
        <td class="r"><?= (int) $total['AEncaisser'] ?></td><td class="r"><?= fcfa($total['Montant']) ?></td><td class="r"><?= fcfa($total['Frais']) ?></td></tr>
</table>
<h2>Détail des livraisons</h2>
<table>
    <tr><th>Date</th><th>N°</th><th>Livreur</th><th>Destinataire</th><th>Adresse</th><th class="r">Montant</th><th class="r">Frais</th><th>Statut</th></tr>
    <?php if (!$lignes): ?><tr><td colspan="8" class="muted">Aucune livraison sur la période.</td></tr><?php endif; ?>
    <?php foreach ($lignes as $l): ?>
        <tr><td><?= date_fr($l['Date'], 'd/m/Y H:i') ?></td><td><?= h((string) $l['Numero']) ?></td><td><?= h((string) $l['Livreur']) ?></td>
            <td><?= h((string) ($l['NomLivraison'] ?: $l['Client'])) ?><?= $l['TelephoneLivraison'] ? ' · ' . h($l['TelephoneLivraison']) : '' ?></td>
            <td><?= h((string) $l['AdresseLivraison']) ?></td><td class="r"><?= fcfa($l['Montant']) ?></td><td class="r"><?= fcfa($l['Frais']) ?></td>
            <td><?= h($l['Statut']) ?><?= $l['DateLivraison'] ? ' le ' . date_fr($l['DateLivraison'], 'd/m/Y H:i') : '' ?></td></tr>
    <?php endforeach; ?>
</table>
<p class="muted">Montant : articles de la vente (TTC), frais de livraison en plus. « À encaisser » : commande confiée au livreur, encaissée à son retour. Les ventes annulées ne sont pas comptées.</p>
<?php require __DIR__ . '/../partials/print_fin.php'; ?>
