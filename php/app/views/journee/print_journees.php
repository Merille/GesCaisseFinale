<?php $titreImpression = 'Journées ' . $caisse['ChkCode']; require __DIR__ . '/../partials/print_debut.php'; ?>
<h1>Journées de caisse — <?= h($caisse['ChkDescription'] . ' - ' . $caisse['ChkCode']) ?></h1>
<table>
    <tr><th>Date</th><th>N° journée</th><th class="r">Solde initial</th><th class="r">Encaissé</th><th class="r">Décaissé</th><th class="r">Solde</th><th>Statut</th></tr>
    <?php $ti = $te = $td = 0.0; foreach ($journees as $j): $ti += $j['SoldeInitial']; $te += $j['Encaisse']; $td += $j['Decaisse']; ?>
        <tr>
            <td><?= date_fr($j['DateJournee']) ?></td>
            <td><?= h($j['NumeroJournee']) ?></td>
            <td class="r"><?= fcfa($j['SoldeInitial']) ?></td>
            <td class="r"><?= fcfa($j['Encaisse']) ?></td>
            <td class="r"><?= fcfa($j['Decaisse']) ?></td>
            <td class="r"><?= fcfa($j['Solde']) ?></td>
            <td><?= $j['Statut'] === 'Ouverte' ? 'Ouverte' : 'Clôturée' ?></td>
        </tr>
    <?php endforeach; ?>
    <tr class="total"><td colspan="2">Total</td><td class="r"><?= fcfa($ti) ?></td><td class="r"><?= fcfa($te) ?></td><td class="r"><?= fcfa($td) ?></td><td class="r"><?= fcfa($ti + $te - $td) ?></td><td></td></tr>
</table>
<p class="muted">Les opérations rejetées sont exclues des montants.</p>
<?php require __DIR__ . '/../partials/print_fin.php'; ?>
