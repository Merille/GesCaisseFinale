<?php $titreImpression = 'Relevé ' . $tiers['CodeClient']; require __DIR__ . '/../partials/print_debut.php'; ?>
<h1>Relevé du tiers — <?= h($tiers['NomSociete']) ?></h1>
<p class="muted">
    <?= h($tiers['CodeClient']) ?> · <?= h($tiers['Genre']) ?><?= $tiers['Type'] ? ' · ' . h($tiers['Type']) : '' ?>
    <?= $tiers['Adresse'] ? ' · ' . h($tiers['Adresse']) : '' ?><?= $tiers['Telephone'] ? ' · ' . h($tiers['Telephone']) : '' ?>
    <br>Période : du <?= date_fr($f['du']) ?> au <?= date_fr($f['au']) ?>
</p>
<table>
    <tr><th class="r">Ventes nettes</th><th class="r">Encaissements</th><th class="r">Décaissements</th><th class="r">Solde</th></tr>
    <tr><td class="r"><?= fcfa($ventesNettes) ?></td><td class="r"><?= fcfa($encaissements) ?></td><td class="r"><?= fcfa($decaissements) ?></td><td class="r"><?= fcfa($encaissements - $decaissements) ?></td></tr>
</table>
<?php if ($compte): ?>
    <h2>Compte client</h2>
    <table>
        <tr><th class="r">Solde dû au <?= date_fr(date('Y-m-d', strtotime($f['du'] . ' -1 day'))) ?></th><th class="r">Ventes par compte</th><th class="r">Règlements</th>
            <th class="r">Solde dû au <?= date_fr($f['au']) ?></th></tr>
        <tr><td class="r"><?= fcfa($compte['debut']) ?></td><td class="r"><?= fcfa($compte['ventes']) ?></td><td class="r"><?= fcfa($compte['reglements']) ?></td>
            <td class="r"><b><?= fcfa($compte['fin']) ?></b></td></tr>
    </table>
    <p class="muted">Ventes par compte : retours crédités au compte déduits.<?= $compte['plafond'] !== null ? ' Plafond de crédit : ' . fcfa($compte['plafond']) . ' FCFA.' : ' Sans plafond de crédit.' ?></p>
<?php endif; ?>

<h2>Opérations de caisse</h2>
<table>
    <tr><th>Date</th><th>Journée</th><th>Type</th><th>Libellé</th><th>Mode de paiement</th><th>Statut</th><th class="r">Encaissement</th><th class="r">Décaissement</th></tr>
    <?php if (!$operations): ?><tr><td colspan="8" class="muted">Aucune opération sur la période.</td></tr><?php endif; ?>
    <?php foreach ($operations as $o): $rejete = $o['StatutValidation'] === STATUT_REJETE; $m = $rejete ? '<s>' . fcfa($o['Montant']) . '</s>' : fcfa($o['Montant']); ?>
        <tr>
            <td><?= date_fr($o['DateOperation'], 'd/m/Y H:i') ?></td>
            <td><?= h($o['NumeroJournee']) ?></td>
            <td><?= h($o['TypeOperation']) ?></td>
            <td><?= h($o['Libelle']) ?></td>
            <td><?= h($o['ModeLibelle']) ?></td>
            <td><?= h($o['StatutValidation']) ?></td>
            <td class="r"><?= $o['TypeOperation'] === 'Encaissement' ? $m : '' ?></td>
            <td class="r"><?= $o['TypeOperation'] === 'Décaissement' ? $m : '' ?></td>
        </tr>
    <?php endforeach; ?>
    <tr class="total"><td colspan="6">Total (hors opérations rejetées)</td><td class="r"><?= fcfa($encaissements) ?></td><td class="r"><?= fcfa($decaissements) ?></td></tr>
</table>

<h2>Ventes au point de vente</h2>
<table>
    <tr><th>Date</th><th>Ticket</th><th>Paiement</th><th>Statut</th><th class="r">Total</th></tr>
    <?php if (!$ventes): ?><tr><td colspan="5" class="muted">Aucune vente sur la période.</td></tr><?php endif; ?>
    <?php foreach ($ventes as $v): ?>
        <tr>
            <td><?= date_fr($v['DateCommande'], 'd/m/Y H:i') ?></td>
            <td><?= h($v['Numero']) ?></td>
            <td><?= h((string) $v['Paiement']) ?></td>
            <td><?= h($v['Statut']) ?></td>
            <td class="r"><?= $v['Statut'] === 'Annulée' ? '<s>' . fcfa($v['TotalTTC']) . '</s>' : fcfa($v['TotalTTC']) ?></td>
        </tr>
    <?php endforeach; ?>
    <tr class="total"><td colspan="4">Ventes nettes (retours déduits, ventes annulées exclues)</td><td class="r"><?= fcfa($ventesNettes) ?></td></tr>
</table>
<p class="muted">Les ventes payées apparaissent aussi dans les opérations de caisse (encaissements « Vente POS ») ; les ventes par compte, une fois réglées (« Règlement client »).</p>
<?php require __DIR__ . '/../partials/print_fin.php'; ?>
