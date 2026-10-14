<?php
$titre = 'Nouvelle facture';
$entete = $titre;
$largeur = '640px';
$tailleModale = '';
$action = !empty($modale) ? url('facture/create') : null;
$retour = url('facture/index');
$libelleBouton = 'Créer et ajouter les lignes';
require __DIR__ . '/../partials/form_debut.php';
?>
            <?php if (!$clients): ?>
                <div class="alert alert-warning">Créez d'abord un tiers dans <a href="<?= h(url('client/index')) ?>">Tiers</a>.</div>
            <?php endif; ?>
            <div class="row g-3">
                <div class="col-md-6"><label class="form-label" for="Numero">Numéro</label><input class="form-control" id="Numero" name="Numero" value="<?= h($_POST['Numero'] ?? $numeroPropose) ?>" required></div>
                <div class="col-md-6"><label class="form-label" for="TauxTVA">Taux de TVA (%)</label><input class="form-control" id="TauxTVA" name="TauxTVA" inputmode="decimal" value="<?= h($_POST['TauxTVA'] ?? '18') ?>"></div>
                <div class="col-12">
                    <label class="form-label" for="ClientId">Client</label>
                    <select class="form-select" id="ClientId" name="ClientId" required>
                        <option value="">-- Choisir un client --</option>
                        <?php foreach ($clients as $c): ?><option value="<?= (int) $c['Id'] ?>" <?= (int) ($_POST['ClientId'] ?? 0) === (int) $c['Id'] ? 'selected' : '' ?>><?= h($c['NomSociete']) ?></option><?php endforeach; ?>
                    </select>
                </div>
            </div>
<?php require __DIR__ . '/../partials/form_fin.php'; ?>
