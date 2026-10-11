<?php
$titre = 'Rapport des opérations';
$params = array_filter($f, fn($v) => $v !== null && $v !== '');
?>
<form method="get" action="index.php" class="card shadow-sm border-0 mb-3">
    <input type="hidden" name="r" value="rapport/operations">
    <div class="card-body d-flex flex-wrap align-items-end gap-3">
        <div><label class="form-label small fw-semibold text-muted mb-1" for="dateDebut">Du</label><input type="date" class="form-control" id="dateDebut" name="dateDebut" value="<?= h($f['dateDebut']) ?>"></div>
        <div><label class="form-label small fw-semibold text-muted mb-1" for="dateFin">Au</label><input type="date" class="form-control" id="dateFin" name="dateFin" value="<?= h($f['dateFin']) ?>"></div>
        <div>
            <label class="form-label small fw-semibold text-muted mb-1" for="caisseId">Caisse</label>
            <select class="form-select" id="caisseId" name="caisseId">
                <option value="">Toutes</option>
                <?php foreach ($caisses as $c): ?><option value="<?= (int) $c['ID'] ?>" <?= $f['caisseId'] === (int) $c['ID'] ? 'selected' : '' ?>><?= h($c['ChkCode'] . ' - ' . $c['ChkDescription']) ?></option><?php endforeach; ?>
            </select>
        </div>
        <div>
            <label class="form-label small fw-semibold text-muted mb-1" for="typeOperation">Type</label>
            <select class="form-select" id="typeOperation" name="typeOperation">
                <option value="">Toutes</option>
                <?php foreach (['Encaissement', 'Décaissement'] as $t): ?><option <?= $f['typeOperation'] === $t ? 'selected' : '' ?>><?= $t ?></option><?php endforeach; ?>
            </select>
        </div>
        <button class="btn btn-primary"><i class="fa fa-search"></i> Filtrer</button>
        <div class="ms-auto d-flex flex-wrap gap-2">
            <a class="btn btn-outline-primary" href="<?= h(url('rapport/preview', $params)) ?>"><i class="fa fa-print"></i> Imprimer / PDF</a>
            <div class="btn-group">
                <a class="btn btn-success" href="<?= h(url('rapport/sage', $params + ['format' => 'xlsx'])) ?>"><i class="fa fa-file-excel"></i> Export Sage</a>
                <button type="button" class="btn btn-success dropdown-toggle dropdown-toggle-split" data-bs-toggle="dropdown" aria-label="Autres formats"></button>
                <ul class="dropdown-menu dropdown-menu-end">
                    <li><a class="dropdown-item" href="<?= h(url('rapport/sage', $params + ['format' => 'xlsx'])) ?>">Excel (.xlsx)</a></li>
                    <li><a class="dropdown-item" href="<?= h(url('rapport/sage', $params + ['format' => 'csv'])) ?>">CSV (.csv)</a></li>
                    <li><a class="dropdown-item" href="<?= h(url('rapport/sage', $params + ['format' => 'txt'])) ?>">Texte (.txt)</a></li>
                </ul>
            </div>
        </div>
    </div>
</form>

<div class="card shadow-sm border-0">
    <div class="card-body table-responsive">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Date</th><th>Journée</th><th>Type</th><th>Libellé</th><th>Tiers</th><th>Caissier</th><th class="text-end">Montant</th></tr></thead>
            <tbody>
            <?php if (!$operations): ?><tr><td colspan="7" class="text-center text-muted py-4">Aucune opération pour ces critères.</td></tr><?php endif; ?>
            <?php foreach ($operations as $o): ?>
                <tr>
                    <td class="text-nowrap"><?= date_fr($o['DateOperation'], 'd/m/Y H:i') ?></td>
                    <td><a href="<?= h(url('journee/details', ['id' => $o['JourneeCaisseId']])) ?>"><?= h($o['NumeroJournee']) ?></a></td>
                    <td><span class="badge <?= $o['TypeOperation'] === 'Encaissement' ? 'bg-success' : 'bg-danger' ?>"><?= h($o['TypeOperation']) ?></span></td>
                    <td><?= h($o['Libelle']) ?></td>
                    <td><?= h($o['Tiers']) ?></td>
                    <td><?= h($o['Caissier']) ?></td>
                    <td class="text-end text-nowrap">
                        <?php if ($o['StatutValidation'] === STATUT_REJETE): ?>
                            <s class="text-muted" title="Opération rejetée : exclue des totaux"><?= fcfa($o['Montant']) ?></s> <small class="text-muted">(rejetée)</small>
                        <?php else: ?><?= fcfa($o['Montant']) ?><?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
            <tfoot>
                <tr class="table-success"><th colspan="6">Total encaissements</th><th class="text-end"><?= fcfa($totalEntrees) ?></th></tr>
                <tr class="table-danger"><th colspan="6">Total décaissements</th><th class="text-end"><?= fcfa($totalSorties) ?></th></tr>
                <tr class="table-primary"><th colspan="6">Solde de la période (encaissements − décaissements)</th><th class="text-end"><?= fcfa($totalEntrees - $totalSorties) ?></th></tr>
                <tr><th colspan="6">Montant initial des journées</th><th class="text-end"><?= fcfa($montantInitial) ?></th></tr>
                <tr class="table-dark"><th colspan="6">Solde en caisse</th><th class="text-end"><?= fcfa($montantInitial + $totalEntrees - $totalSorties) ?></th></tr>
            </tfoot>
        </table>
    </div>
</div>
