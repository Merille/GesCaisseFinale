<?php $titre = 'Imprimantes de préparation'; ?>
<div class="d-flex justify-content-between align-items-center mb-3">
    <h4 class="mb-0">Imprimantes de préparation</h4>
    <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modalImprimante" data-imprimante=""><i class="fa fa-plus"></i> Nouvelle imprimante</button>
</div>
<p class="small text-muted">Imprimantes réseau de la cuisine et du bar (sans écran ni ordinateur) : à chaque envoi en préparation, la caisse leur envoie directement
    les articles des catégories cochées. <strong>Epson (ePOS)</strong> : rien à installer. <strong>Autre (ESC/POS réseau)</strong> : l'agent d'impression GesCaisse doit être installé sur le poste de caisse.
    Quand la caisse a des imprimantes, le bon n'est plus imprimé par la fenêtre d'impression du navigateur.</p>
<div class="card shadow-sm border-0">
    <div class="card-body">
        <table id="imprimantesTable" class="table table-hover align-middle mb-0">
            <thead class="table-dark"><tr><th>Nom</th><th>Type</th><th>Adresse</th><th>Caisse</th><th>Catégories imprimées</th><th class="text-center">Statut</th><th class="text-center">Actions</th></tr></thead>
            <tbody>
            <?php $noms = array_column($categories, 'Nom', 'Id'); ?>
            <?php foreach ($imprimantes as $i): ?>
                <?php $cats = array_values(array_filter(array_map(fn($c) => $noms[$c] ?? null, $i['js']['categories']))); ?>
                <tr class="<?= $i['Actif'] ? '' : 'text-muted' ?>">
                    <td class="fw-semibold"><i class="fa fa-print text-muted me-1"></i><?= h($i['Nom']) ?></td>
                    <td><?= h(IMPRIMANTE_TYPES[$i['Type']] ?? $i['Type']) ?></td>
                    <td><code><?= h($i['AdresseIp'] . ($i['Port'] ? ':' . $i['Port'] : '')) ?></code><div class="small text-muted"><?= (int) $i['Largeur'] ?> mm<?= $i['Encodage'] === 'SansAccents' ? ' · sans accents' : '' ?><?= $i['Bip'] ? ' · bip' : '' ?></div></td>
                    <td><?= $i['CaisseId'] ? h($i['ChkCode']) : '<span class="text-muted">Toutes</span>' ?></td>
                    <td><?= $cats ? h(implode(', ', $cats)) : '<span class="text-danger">Aucune</span>' ?></td>
                    <td class="text-center"><?= $i['Actif'] ? '<span class="badge bg-success">Active</span>' : '<span class="badge bg-secondary">Inactive</span>' ?></td>
                    <td class="text-center table-actions">
                        <button type="button" class="btn btn-outline-primary btn-sm" data-tester="<?= h(json_encode($i['js'], JSON_UNESCAPED_UNICODE)) ?>"><i class="fa fa-print"></i> Tester</button>
                        <button class="btn btn-warning btn-sm" data-bs-toggle="modal" data-bs-target="#modalImprimante"
                                data-imprimante="<?= h(json_encode($i['js'] + ['caisseId' => $i['CaisseId'] === null ? '' : (int) $i['CaisseId'], 'actif' => (bool) $i['Actif']], JSON_UNESCAPED_UNICODE)) ?>">Modifier</button>
                        <form method="post" action="<?= h(url('imprimante/toggle')) ?>">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $i['Id'] ?>">
                            <button class="btn btn-sm <?= $i['Actif'] ? 'btn-outline-secondary' : 'btn-success' ?>"><?= $i['Actif'] ? 'Désactiver' : 'Activer' ?></button>
                        </form>
                        <form method="post" action="<?= h(url('imprimante/delete')) ?>" onsubmit="return confirm('Supprimer cette imprimante ?');">
                            <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int) $i['Id'] ?>">
                            <button class="btn btn-danger btn-sm">Supprimer</button>
                        </form>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<div class="modal fade" id="modalImprimante" tabindex="-1" aria-labelledby="imprimanteTitre" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <form class="modal-content" method="post" action="<?= h(url('imprimante/save')) ?>">
            <div class="modal-header bg-brand text-white">
                <h5 class="modal-title" id="imprimanteTitre">Imprimante</h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>
            </div>
            <div class="modal-body">
                <?= csrf_field() ?>
                <input type="hidden" name="Id" id="impId">
                <div class="row g-3">
                    <div class="col-md-6"><label class="form-label" for="impNom">Nom de l'imprimante</label><input id="impNom" name="Nom" class="form-control" placeholder="Ex : Cuisine" maxlength="100" required></div>
                    <div class="col-md-6"><label class="form-label" for="impCaisse">Caisse</label>
                        <select id="impCaisse" name="CaisseId" class="form-select">
                            <option value="">Toutes les caisses restaurant / bar</option>
                            <?php foreach ($caisses as $c): ?><option value="<?= (int) $c['ID'] ?>"><?= h($c['ChkCode'] . ($c['ChkDescription'] ? ' - ' . $c['ChkDescription'] : '')) ?></option><?php endforeach; ?>
                        </select></div>
                    <div class="col-12">
                        <label class="form-label d-block">Type d'imprimante</label>
                        <div class="form-check"><input class="form-check-input" type="radio" name="Type" value="Epson" id="impTypeEpson"><label class="form-check-label" for="impTypeEpson">Imprimante Epson (ePOS) : impression directe depuis la caisse, rien à installer</label></div>
                        <div class="form-check"><input class="form-check-input" type="radio" name="Type" value="Reseau" id="impTypeReseau"><label class="form-check-label" for="impTypeReseau">Autre imprimante réseau ESC/POS (Xprinter, Rongta, HPRT…) : par l'agent d'impression installé sur le poste de caisse</label></div>
                    </div>
                    <div class="col-md-6"><label class="form-label" for="impIp">Adresse IP</label><input id="impIp" name="AdresseIp" class="form-control" placeholder="Ex : 192.168.1.50" maxlength="100" required pattern="[A-Za-z0-9.\-]+"></div>
                    <div class="col-md-3"><label class="form-label" for="impPort">Port</label><input id="impPort" name="Port" class="form-control" inputmode="numeric" placeholder="Par défaut"></div>
                    <div class="col-md-3"><label class="form-label" for="impLargeur">Papier</label>
                        <select id="impLargeur" name="Largeur" class="form-select"><option value="80">80 mm</option><option value="58">58 mm</option></select></div>
                    <div class="col-md-6"><label class="form-label" for="impEncodage">Caractères</label>
                        <select id="impEncodage" name="Encodage" class="form-select"><option value="PC850">Avec accents (page 850)</option><option value="SansAccents">Sans accents</option></select></div>
                    <div class="col-md-6 d-flex align-items-end gap-4">
                        <div class="form-check"><input class="form-check-input" type="checkbox" value="1" name="Bip" id="impBip"><label class="form-check-label" for="impBip">Signal sonore</label></div>
                        <div class="form-check"><input class="form-check-input" type="checkbox" value="1" name="Actif" id="impActif"><label class="form-check-label" for="impActif">Active</label></div>
                    </div>
                    <div class="col-12">
                        <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-1">
                            <label class="form-label mb-0">Catégories de produits imprimées</label>
                            <div class="btn-group btn-group-sm">
                                <button type="button" class="btn btn-outline-secondary" data-cocher="Cuisine">Poste Cuisine</button>
                                <button type="button" class="btn btn-outline-secondary" data-cocher="Bar">Poste Bar</button>
                                <button type="button" class="btn btn-outline-secondary" data-cocher="">Aucune</button>
                            </div>
                        </div>
                        <div class="border rounded p-2 row g-1 mx-0" id="impCategories" style="max-height:220px;overflow:auto">
                            <?php foreach ($categories as $c): ?>
                                <div class="col-md-4 col-6"><div class="form-check">
                                    <input class="form-check-input" type="checkbox" name="Categories[]" value="<?= (int) $c['Id'] ?>" id="impCat<?= (int) $c['Id'] ?>" data-poste="<?= h($c['Preparation']) ?>">
                                    <label class="form-check-label" for="impCat<?= (int) $c['Id'] ?>"><?= h($c['Nom']) ?> <span class="small text-muted">(<?= h($c['Preparation']) ?>)</span></label>
                                </div></div>
                            <?php endforeach; ?>
                            <?php if (!$categories): ?><div class="text-muted small">Aucune catégorie de produits.</div><?php endif; ?>
                        </div>
                        <div class="form-text">Les catégories dont le poste est « Aucun » ne partent pas en préparation et ne sont jamais imprimées.</div>
                    </div>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-outline-primary me-auto" id="impTester"><i class="fa fa-print"></i> Tester</button>
                <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Annuler</button><button class="btn btn-primary">Enregistrer</button>
            </div>
        </form>
    </div>
</div>
<?php ob_start(); ?>
<script src="<?= asset('assets/js/imprimantes.js') ?>"></script>
<script src="<?= asset('assets/js/imprimantes-page.js') ?>"></script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
<?php ob_start(); ?>
<script>
    listeDataTable('#imprimantesTable', { pageLength: 10, lengthMenu: [10, 25, 50, 100], order: [], columnDefs: [{ orderable: false, targets: -1 }] });
</script>
<?php $scripts = ($scripts ?? '') . ob_get_clean(); ?>
