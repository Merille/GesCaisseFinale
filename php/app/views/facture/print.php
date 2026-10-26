<?php $titreImpression = 'Facture ' . $facture['Numero']; $infosSociete = q1('SELECT * FROM Tenants WHERE Id = ?', [$facture['TenantId']]); require __DIR__ . '/../partials/print_debut.php'; ?>
<div style="display:flex; justify-content:space-between; margin-top:24px;">
    <div>
        <h1 style="margin:0;">FACTURE</h1>
        <div>N° <strong><?= h($facture['Numero']) ?></strong></div>
        <div>Date : <?= date_fr($facture['DateFacture']) ?></div>
        <?php if ($facture['Statut'] !== 'Validée'): ?><div class="muted">Brouillon (non validée)</div><?php endif; ?>
    </div>
    <div style="border:1px solid #999; padding:10px 14px; min-width:260px;">
        <div class="muted">Client</div>
        <strong><?= h($facture['NomSociete']) ?></strong><br>
        <?= h($facture['Adresse']) ?><br>
        <?= h($facture['Telephone']) ?> <?= h($facture['Email']) ?>
    </div>
</div>
<table style="margin-top:24px;">
    <tr><th>Désignation</th><th class="r">Qté</th><th class="r">Prix unitaire</th><th class="r">Total</th></tr>
    <?php foreach ($lignes as $l): ?>
        <tr><td><?= h($l['Designation']) ?></td><td class="r"><?= h(rtrim(rtrim((string) $l['Quantite'], '0'), '.')) ?></td><td class="r"><?= fcfa($l['PrixUnitaire']) ?></td><td class="r"><?= fcfa($l['TotalLigne']) ?></td></tr>
    <?php endforeach; ?>
</table>
<table style="width:320px; margin:16px 0 0 auto;">
    <tr><td>Montant HT</td><td class="r"><?= fcfa($facture['MontantHT']) ?></td></tr>
    <tr><td>TVA (<?= h(rtrim(rtrim((string) $facture['TauxTVA'], '0'), '.')) ?> %)</td><td class="r"><?= fcfa($facture['MontantTVA']) ?></td></tr>
    <tr class="total"><td>Montant TTC (FCFA)</td><td class="r"><?= fcfa($facture['MontantTTC']) ?></td></tr>
</table>
<?php require __DIR__ . '/../partials/print_fin.php'; ?>
