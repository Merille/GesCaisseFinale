<?php
$titre = 'Synchronisation';
$typeLibelle = ['vente' => 'Vente', 'depot' => 'Dépôt de linge', 'table' => 'Commande de table', 'attente' => 'Mise en attente'];
?>
<p class="text-muted small mb-3">Les postes travaillent sans connexion quand le réseau tombe : leurs ventes, dépôts, commandes de table et mises en attente
    sont gardés sur le poste puis envoyés au retour de la connexion. Chaque poste connecté indique ici ce qu'il lui reste à envoyer.</p>

<div class="row g-3 mb-3">
    <?php foreach ([['Postes suivis', $kpi['postes'], 'fa-desktop', false, false],
                    ['Postes avec envois en attente', $kpi['postesEnAttente'], 'fa-cloud-arrow-up', false, $kpi['postesEnAttente'] > 0],
                    ['Opérations à envoyer', $kpi['enAttente'], 'fa-hourglass-half', false, $kpi['enAttente'] > 0],
                    ['Montant à envoyer', $kpi['montantEnAttente'], 'fa-coins', true, false],
                    ['Ventes hors ligne (période)', $kpi['ventes'], 'fa-receipt', false, false],
                    ['Ventes à vérifier', $kpi['aVerifier'], 'fa-triangle-exclamation', false, $kpi['aVerifier'] > 0]] as [$lib, $val, $ico, $montant, $alerte]): ?>
        <div class="col-6 col-lg"><div class="card border-0 shadow-sm h-100"><div class="card-body">
            <div class="small text-muted"><i class="fa <?= $ico ?>"></i> <?= $lib ?></div>
            <div class="fs-5 fw-bold<?= $alerte ? ' text-danger' : '' ?>"><?= $montant ? fcfa($val) . ' <small class="fs-6 fw-normal text-muted">FCFA</small>' : (int) $val ?></div>
        </div></div></div>
    <?php endforeach; ?>
</div>

<div class="card shadow-sm border-0 mb-3" id="synchroPostes">
    <div class="card-header bg-white fw-semibold"><i class="fa fa-desktop"></i> Postes</div>
    <div class="card-body table-responsive">
        <?php if (!$postes): ?>
            <div class="text-muted">Aucun poste ne s'est encore signalé. Un poste apparaît ici dès qu'il ouvre GesCaisse avec la connexion.</div>
        <?php else: ?>
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Poste</th><th>Dernier utilisateur</th><th>Dernier contact</th><th class="text-end">À envoyer</th>
                <th class="text-end">Montant</th><th>Plus ancienne</th><th>Dernier envoi</th><th>État</th><th></th></tr></thead>
            <tbody>
            <?php foreach ($postes as $p): ?>
                <tr>
                    <td class="fw-semibold">H-<?= h($p['Code']) ?><div class="small text-muted text-truncate" style="max-width:220px" title="<?= h($p['Navigateur']) ?>"><?= h($p['Navigateur']) ?></div></td>
                    <td><?= h($p['Utilisateur'] ?? '') ?></td>
                    <td class="text-nowrap"><?= date_fr($p['DernierRapport'], 'd/m/Y H:i') ?><div class="small text-muted"><?= h(synchro_depuis($p['DernierRapport'])) ?></div></td>
                    <td class="text-end fw-semibold"><?= (int) $p['EnAttente'] ?><?= (int) $p['Refusees'] ? ' <span class="badge bg-danger">' . (int) $p['Refusees'] . ' refusée' . ((int) $p['Refusees'] > 1 ? 's' : '') . '</span>' : '' ?></td>
                    <td class="text-end text-nowrap"><?= (int) $p['EnAttente'] ? fcfa($p['MontantEnAttente']) : '' ?></td>
                    <td class="text-nowrap small"><?= $p['PlusAncien'] ? date_fr($p['PlusAncien'], 'd/m/Y H:i') : '' ?></td>
                    <td class="text-nowrap small"><?= $p['DernierEnvoi'] ? date_fr($p['DernierEnvoi'], 'd/m/Y H:i') : '' ?></td>
                    <td><span class="badge <?= $p['Badge'] ?>"><?= h($p['Etat']) ?></span></td>
                    <td class="text-end text-nowrap">
                        <?php if ($p['Elements']): ?>
                            <button class="btn btn-sm btn-outline-primary" type="button" data-bs-toggle="collapse" data-bs-target="#poste<?= (int) $p['Id'] ?>" aria-expanded="false">Détail</button>
                        <?php endif; ?>
                        <form method="post" action="<?= h(url('synchro/oublier')) ?>" class="d-inline" onsubmit="return confirm('Retirer le poste H-<?= h($p['Code']) ?> de la liste ?<?= (int) $p['EnAttente'] ? '\nIl a encore des opérations à envoyer : elles restent sur le poste.' : '' ?>')">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $p['Id'] ?>">
                            <button class="btn btn-sm btn-outline-secondary" title="Retirer de la liste (poste qui ne sert plus)" aria-label="Retirer le poste H-<?= h($p['Code']) ?>"><i class="fa fa-xmark"></i></button>
                        </form>
                    </td>
                </tr>
                <?php if ($p['Elements']): ?>
                    <tr class="collapse" id="poste<?= (int) $p['Id'] ?>"><td colspan="9" class="bg-light">
                        <table class="table table-sm mb-0 small">
                            <thead><tr><th>N° provisoire</th><th>Opération</th><th>Faite le</th><th class="text-end">Montant</th><th>Refus</th></tr></thead>
                            <tbody>
                            <?php foreach ($p['Elements'] as $e): ?>
                                <tr><td class="fw-semibold"><?= h($e['numero']) ?></td><td><?= h($e['libelle'] ?: ($typeLibelle[$e['type']] ?? $e['type'])) ?></td>
                                    <td class="text-nowrap"><?= $e['cree'] ? date_fr($e['cree'], 'd/m/Y H:i') : '' ?></td>
                                    <td class="text-end text-nowrap"><?= $e['montant'] !== null ? fcfa($e['montant']) : '' ?></td>
                                    <td class="text-danger"><?= h($e['erreur']) ?></td></tr>
                            <?php endforeach; ?>
                            </tbody>
                        </table>
                    </td></tr>
                <?php endif; ?>
            <?php endforeach; ?>
            </tbody>
        </table>
        <div class="small text-muted mt-2">Un poste « sans nouvelles » a des opérations à envoyer et ne s'est plus signalé depuis plus d'une heure : vérifiez sa connexion,
            puis ouvrez GesCaisse sur ce poste pour lancer l'envoi. Les opérations restent dans le navigateur du poste : ne videz pas ses données.</div>
        <?php endif; ?>
    </div>
</div>

<form method="get" action="index.php" class="card shadow-sm border-0 mb-3">
    <input type="hidden" name="r" value="synchro/index">
    <div class="card-body d-flex flex-wrap align-items-end gap-3">
        <div>
            <label class="form-label small fw-semibold text-muted mb-1" for="etat">Ventes hors ligne</label>
            <select class="form-select" id="etat" name="etat" onchange="['du', 'au'].forEach(i => document.getElementById(i).disabled = this.value === 'à vérifier')">
                <?php foreach (SYNCHRO_ETATS as $v => $lib): ?><option value="<?= h($v) ?>" <?= $f['etat'] === $v ? 'selected' : '' ?>><?= h($lib) ?></option><?php endforeach; ?>
            </select>
        </div>
        <div><label class="form-label small fw-semibold text-muted mb-1" for="du">Du</label><input type="date" class="form-control" id="du" name="du" value="<?= h($f['du']) ?>"<?= $f['etat'] === 'à vérifier' ? ' disabled' : '' ?>></div>
        <div><label class="form-label small fw-semibold text-muted mb-1" for="au">Au</label><input type="date" class="form-control" id="au" name="au" value="<?= h($f['au']) ?>"<?= $f['etat'] === 'à vérifier' ? ' disabled' : '' ?>></div>
        <button class="btn btn-primary"><i class="fa fa-search"></i> Filtrer</button>
    </div>
</form>

<form method="post" action="<?= h(url('synchro/verifier')) ?>" class="card shadow-sm border-0 mb-3" id="synchroVentes">
    <?= csrf_field() ?>
    <input type="hidden" name="etat" value="<?= h($f['etat']) ?>"><input type="hidden" name="du" value="<?= h($f['du']) ?>"><input type="hidden" name="au" value="<?= h($f['au']) ?>">
    <div class="card-header bg-white d-flex flex-wrap align-items-center gap-2">
        <span class="fw-semibold"><i class="fa fa-receipt"></i> Ventes enregistrées hors ligne
            <span class="text-muted fw-normal small">· <?= $f['etat'] === 'à vérifier' ? 'à vérifier, toutes dates' : h(SYNCHRO_ETATS[$f['etat']]) . ' du ' . date_fr($f['du']) . ' au ' . date_fr($f['au']) ?> (<?= count($ventes) ?>)</span></span>
        <?php if (array_filter($ventes, fn($v) => $v['AlerteHorsLigne'] && !$v['AlerteHorsLigneVue'])): ?>
            <button class="btn btn-sm btn-warning ms-auto"><i class="fa fa-check"></i> Marquer les ventes cochées vérifiées</button>
        <?php endif; ?>
    </div>
    <div class="card-body table-responsive">
        <?php if (!$ventes): ?>
            <div class="text-muted"><?= $f['etat'] === 'à vérifier' ? 'Aucune vente hors ligne à vérifier.' : 'Aucune vente hors ligne sur cette période.' ?></div>
        <?php else: ?>
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th style="width:32px"><input type="checkbox" class="form-check-input" aria-label="Tout cocher"
                onclick="document.querySelectorAll('#synchroVentes [name=&quot;ids[]&quot;]').forEach(c => c.checked = this.checked)"></th>
                <th>Ticket</th><th>Provisoire</th><th>Date</th><th>Caisse</th><th>Vendeur</th><th class="text-end">Total TTC</th><th>Vérification</th></tr></thead>
            <tbody>
            <?php foreach ($ventes as $v): $aVerifier = $v['AlerteHorsLigne'] && !$v['AlerteHorsLigneVue']; ?>
                <tr class="<?= $v['Statut'] === 'Annulée' ? 'text-muted' : '' ?>">
                    <td><?php if ($aVerifier): ?><input type="checkbox" class="form-check-input" name="ids[]" value="<?= (int) $v['Id'] ?>" aria-label="Cocher la vente <?= h($v['Numero']) ?>"><?php endif; ?></td>
                    <td class="fw-semibold"><a href="<?= h(url('vente/details', ['id' => $v['Id']])) ?>"><?= h($v['Numero']) ?></a><?= $v['Statut'] === 'Annulée' ? ' <span class="badge bg-secondary">Annulée</span>' : '' ?></td>
                    <td><?= h($v['NumeroHorsLigne']) ?></td>
                    <td class="text-nowrap"><?= date_fr($v['DateCommande'], 'd/m/Y H:i') ?></td>
                    <td><?= h($v['ChkCode']) ?></td>
                    <td><?= h($v['Vendeur'] ?? '') ?></td>
                    <td class="text-end text-nowrap"><?= fcfa($v['TotalTTC']) ?></td>
                    <td class="small"><?php if ($aVerifier): ?><span class="badge text-bg-warning">À vérifier</span> <?= h($v['AlerteHorsLigne']) ?>
                        <?php elseif ($v['AlerteHorsLigne']): ?><span class="badge bg-success">Vérifiée</span> le <?= date_fr($v['AlerteHorsLigneVue'], 'd/m/Y H:i') ?><div class="text-muted"><?= h($v['AlerteHorsLigne']) ?></div>
                        <?php else: ?><span class="badge text-bg-light border">Sans écart</span><?php endif; ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
        <?php endif; ?>
    </div>
</form>

<?php if ($depots !== null): ?>
<div class="card shadow-sm border-0">
    <div class="card-header bg-white fw-semibold"><i class="fa fa-shirt"></i> Dépôts de linge enregistrés hors ligne <span class="text-muted fw-normal small">· du <?= date_fr($f['du']) ?> au <?= date_fr($f['au']) ?> (<?= count($depots) ?>)</span></div>
    <div class="card-body table-responsive">
        <?php if (!$depots): ?>
            <div class="text-muted">Aucun dépôt de linge enregistré hors ligne sur cette période.</div>
        <?php else: ?>
        <table class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Dépôt</th><th>Provisoire</th><th>Déposé le</th><th>Caisse</th><th>Client</th><th class="text-end">Total</th><th>Statut</th></tr></thead>
            <tbody>
            <?php foreach ($depots as $d): ?>
                <tr><td class="fw-semibold">N° <?= (int) $d['Numero'] ?></td><td><?= h($d['NumeroHorsLigne']) ?></td><td class="text-nowrap"><?= date_fr($d['DateDepot'], 'd/m/Y H:i') ?></td>
                    <td><?= h($d['ChkCode'] ?? '') ?></td><td><?= h($d['NomClient']) ?><div class="small text-muted"><?= h($d['TelephoneClient'] ?? '') ?></div></td>
                    <td class="text-end text-nowrap"><?= fcfa($d['Total']) ?></td><td><?= h($d['Statut']) ?></td></tr>
            <?php endforeach; ?>
            </tbody>
        </table>
        <?php endif; ?>
    </div>
</div>
<?php endif; ?>
