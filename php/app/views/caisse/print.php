<?php $titreImpression = 'Liste des caisses'; require __DIR__ . '/../partials/print_debut.php'; ?>
<h1>Liste des caisses</h1>
<table>
    <tr><th>Code</th><th>Description</th><th>StCode</th><th>Caissier par défaut</th><th>Compte comptable</th></tr>
    <?php foreach ($caisses as $c): ?>
        <tr>
            <td><?= h($c['ChkCode']) ?></td>
            <td><?= h($c['ChkDescription']) ?></td>
            <td><?= h($c['StCode']) ?></td>
            <td><?= h($c['Caissier']) ?></td>
            <td><?= h($c['CompteComptable']) ?></td>
        </tr>
    <?php endforeach; ?>
</table>
<?php require __DIR__ . '/../partials/print_fin.php'; ?>
