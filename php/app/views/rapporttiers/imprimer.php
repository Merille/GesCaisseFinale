<?php $titreImpression = 'Rapport des tiers'; require __DIR__ . '/../partials/print_debut.php'; ?>
<h1>Rapport des tiers</h1>
<p class="muted">
    Période : du <?= date_fr($f['du']) ?> au <?= date_fr($f['au']) ?>
    — Type : <?= $f['type'] !== '' ? h($f['type']) : 'tous' ?>
    — Genre : <?= $f['genre'] !== '' ? h($f['genre']) : 'tous' ?>
</p>
<table>
    <tr><th>Code</th><th>Tiers</th><th>Genre</th><th>Type</th><th class="r">Ventes</th><th class="r">Ventes nettes</th><th class="r">Encaissements</th><th class="r">Décaissements</th><th class="r">Solde</th></tr>
    <?php foreach ($lignes as $l): ?>
        <tr>
            <td><?= h($l['CodeClient']) ?></td>
            <td><?= h($l['NomSociete']) ?></td>
            <td><?= h($l['Genre']) ?></td>
            <td><?= h((string) $l['Type']) ?></td>
            <td class="r"><?= (int) $l['NbVentes'] ?></td>
            <td class="r"><?= fcfa($l['Ventes']) ?></td>
            <td class="r"><?= fcfa($l['Encaissements']) ?></td>
            <td class="r"><?= fcfa($l['Decaissements']) ?></td>
            <td class="r"><?= fcfa($l['Solde']) ?></td>
        </tr>
    <?php endforeach; ?>
    <tr class="total"><td colspan="4">Total (<?= count($lignes) ?> tiers)</td><td class="r"><?= (int) $totaux['NbVentes'] ?></td><td class="r"><?= fcfa($totaux['Ventes']) ?></td>
        <td class="r"><?= fcfa($totaux['Encaissements']) ?></td><td class="r"><?= fcfa($totaux['Decaissements']) ?></td><td class="r"><?= fcfa($totaux['Solde']) ?></td></tr>
</table>
<p class="muted">Ventes : tickets du point de vente (retours déduits). Les ventes payées apparaissent aussi dans les encaissements. Les opérations rejetées et les ventes annulées ne sont pas comptées.</p>
<?php require __DIR__ . '/../partials/print_fin.php'; ?>
