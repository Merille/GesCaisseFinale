<?php $titreImpression = 'Rapport des opérations'; require __DIR__ . '/../partials/print_debut.php'; ?>
<h1>Rapport des opérations</h1>
<p class="muted">
    Période : <?= $f['dateDebut'] ? date_fr($f['dateDebut']) : 'début' ?> au <?= $f['dateFin'] ? date_fr($f['dateFin']) : "aujourd'hui" ?>
    — Caisse : <?= $caisse ? h($caisse['ChkCode'] . ' - ' . $caisse['ChkDescription']) : 'toutes' ?>
    — Type : <?= $f['typeOperation'] !== '' ? h($f['typeOperation']) : 'tous' ?>
</p>
<table>
    <tr><th>Date</th><th>Journée</th><th>Type</th><th>Libellé</th><th>Tiers</th><th>Caissier</th><th class="r">Montant</th></tr>
    <?php foreach ($operations as $o): ?>
        <tr>
            <td><?= date_fr($o['DateOperation'], 'd/m/Y H:i') ?></td>
            <td><?= h($o['NumeroJournee']) ?></td>
            <td><?= h($o['TypeOperation']) ?></td>
            <td><?= h($o['Libelle']) ?></td>
            <td><?= h($o['Tiers']) ?></td>
            <td><?= h($o['Caissier']) ?></td>
            <td class="r"><?php if ($o['StatutValidation'] === STATUT_REJETE): ?><s><?= fcfa($o['Montant']) ?></s> (rejetée)<?php else: ?><?= fcfa($o['Montant']) ?><?php endif; ?></td>
        </tr>
    <?php endforeach; ?>
    <tr class="total"><td colspan="6">Total encaissements</td><td class="r"><?= fcfa($totalEntrees) ?></td></tr>
    <tr class="total"><td colspan="6">Total décaissements</td><td class="r"><?= fcfa($totalSorties) ?></td></tr>
    <tr class="total"><td colspan="6">Solde de la période</td><td class="r"><?= fcfa($totalEntrees - $totalSorties) ?></td></tr>
    <tr class="total"><td colspan="6">Montant initial des journées</td><td class="r"><?= fcfa($montantInitial) ?></td></tr>
    <tr class="total"><td colspan="6">Solde en caisse</td><td class="r"><?= fcfa($montantInitial + $totalEntrees - $totalSorties) ?></td></tr>
</table>
<p class="muted">Les opérations rejetées sont listées mais exclues des totaux.</p>
<?php require __DIR__ . '/../partials/print_fin.php'; ?>
