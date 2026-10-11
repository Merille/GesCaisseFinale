<?php $titreImpression = 'Opérations ' . $journee['NumeroJournee']; require __DIR__ . '/../partials/print_debut.php'; ?>
<h1>Opérations de caisse — Journée <?= h($journee['NumeroJournee']) ?></h1>
<p class="muted"><?= h($journee['ChkCode'] . ' · ' . $journee['ChkDescription']) ?> — <?= date_fr($journee['DateJournee']) ?> — <?= $journee['Statut'] === 'Ouverte' ? 'Ouverte' : 'Clôturée' ?></p>
<table>
    <tr><th class="r">Solde initial</th><th class="r">Encaissements</th><th class="r">Décaissements</th><th class="r">Solde actuel</th></tr>
    <tr><td class="r"><?= fcfa($journee['SoldeInitial']) ?></td><td class="r"><?= fcfa($totalEncaisse) ?></td><td class="r"><?= fcfa($totalDecaisse) ?></td><td class="r"><?= fcfa($soldeActuel) ?></td></tr>
</table>

<h2>Totaux par mode de paiement</h2>
<table>
    <tr><th>Mode de paiement</th><th class="r">Encaissements</th><th class="r">Décaissements</th><th class="r">Net</th></tr>
    <?php foreach ($totauxParMode as $t): ?>
        <tr><td><?= h($t['Libelle']) ?></td><td class="r"><?= fcfa($t['Encaisse']) ?></td><td class="r"><?= fcfa($t['Decaisse']) ?></td><td class="r"><?= fcfa($t['Net']) ?></td></tr>
    <?php endforeach; ?>
</table>

<h2>Détail des opérations</h2>
<table>
    <tr><th>Date</th><th>Type</th><th>Libellé</th><th>Mode de paiement</th><th>Statut</th><th class="r">Montant</th></tr>
    <?php foreach ($operations as $o): ?>
        <tr>
            <td><?= date_fr($o['DateOperation'], 'd/m/Y H:i') ?></td>
            <td><?= h($o['TypeOperation']) ?></td>
            <td><?= h($o['Libelle']) ?></td>
            <td><?= h($o['ModeLibelle']) ?></td>
            <td><?= h($o['StatutValidation']) ?></td>
            <td class="r"><?php if ($o['StatutValidation'] === STATUT_REJETE): ?><s><?= fcfa($o['Montant']) ?></s> <small>(rejetée, exclue des totaux)</small><?php else: ?><?= fcfa($o['Montant']) ?><?php endif; ?></td>
        </tr>
    <?php endforeach; ?>
</table>
<?php require __DIR__ . '/../partials/print_fin.php'; ?>
