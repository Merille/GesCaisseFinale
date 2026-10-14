<?php
$titre = 'Ouvrir une journée';
$entete = 'Nouvelle journée — ' . $caisse['ChkCode'] . ' · ' . $caisse['ChkDescription'];
$largeur = '560px';
$tailleModale = '';
$action = url('journee/create', ['id' => $caisse['ID']]);
$retour = url('caisse/details', ['id' => $caisse['ID']]);
$libelleBouton = 'Ouvrir la journée';
$classeBouton = 'btn-success';
require __DIR__ . '/../partials/form_debut.php';
?>
            <input type="hidden" name="caisseId" value="<?= (int) $caisse['ID'] ?>">
            <div class="mb-3">
                <label class="form-label" for="dateJournee">Date de la journée</label>
                <input type="date" class="form-control" id="dateJournee" name="dateJournee" value="<?= date('Y-m-d') ?>" required>
            </div>
            <div class="mb-3">
                <label class="form-label" for="soldeInitial">Solde initial (FCFA)</label>
                <input class="form-control" id="soldeInitial" name="soldeInitial" inputmode="decimal" value="<?= h((string) round($soldeSuggere)) ?>" required>
                <div class="form-text">Proposé à partir de la dernière journée de cette caisse (solde compté si elle est clôturée).</div>
            </div>
<?php require __DIR__ . '/../partials/form_fin.php'; ?>
