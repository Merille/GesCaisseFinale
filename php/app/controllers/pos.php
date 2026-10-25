<?php
// Point de vente : choix de la journée ouverte, puis écran de vente plein écran.
// Les tickets en cours sont gardés dans le navigateur jusqu'au paiement.

function pos_index(): void
{
    $id = (int) get('journee', 0);
    if ($id === 0) {
        pos_choix();
        return;
    }

    $journee = q1(
        'SELECT j.*, c.ChkCode, c.ChkDescription
         FROM JourneesCaisses j JOIN Caisses c ON c.ID = j.CaisseId
         WHERE j.Id = ? AND ' . tf('j'),
        [$id]
    );
    if (!$journee) {
        not_found('Journée introuvable.');
    }
    if ($journee['Statut'] !== 'Ouverte') {
        flash('warning', 'Cette journée est clôturée : ouvrez une nouvelle journée pour vendre.');
        redirect('pos/index');
    }

    // Catalogue de la société de la journée (aussi pour le SuperAdmin en mode « toutes »).
    $tenant = (int) $journee['TenantId'];
    $produits = array_map(fn($p) => [
        'id' => (int) $p['Id'],
        'code' => $p['Code'],
        'codeBarres' => $p['CodeBarres'],
        'nom' => $p['Nom'],
        'categorieId' => $p['CategorieId'] === null ? null : (int) $p['CategorieId'],
        'prix' => (float) $p['PrixVente'],
        'tva' => (float) $p['TauxTVA'],
        'suivi' => (bool) $p['SuiviStock'],
        'stock' => (float) $p['StockActuel'],
        'seuil' => $p['SeuilAlerte'] === null ? null : (float) $p['SeuilAlerte'],
    ], q('SELECT * FROM Produits WHERE Actif = 1 AND TenantId = ? ORDER BY Nom', [$tenant]));

    $categories = array_map(fn($c) => [
        'id' => (int) $c['Id'], 'nom' => $c['Nom'], 'couleur' => $c['Couleur'],
    ], q('SELECT Id, Nom, Couleur FROM Categories WHERE TenantId = ? ORDER BY Ordre, Nom', [$tenant]));

    $clients = array_map(fn($c) => [
        'id' => (int) $c['Id'], 'nom' => $c['NomSociete'], 'code' => $c['CodeClient'],
    ], q('SELECT Id, NomSociete, CodeClient FROM Clients WHERE TenantId = ? ORDER BY NomSociete', [$tenant]));

    $u = user();
    $donnees = [
        'cle' => 'gescaisse-pos:' . $tenant . ':' . $journee['Id'],
        'journee' => [
            'id' => (int) $journee['Id'],
            'caisse' => $journee['ChkCode'],
            'libelle' => $journee['ChkDescription'] . ' · Journée du ' . date_fr($journee['DateJournee']) . ' (ouverte)',
        ],
        'produits' => $produits,
        'categories' => $categories,
        'clients' => $clients,
        'utilisateur' => ['nom' => $u['nomComplet'] ?: $u['nom'], 'profil' => $u['profil']],
        'peutModifierPrix' => is_admin(),
        'urlFermer' => url('journee/details', ['id' => $journee['Id']]),
    ];
    render('pos/ecran', ['donnees' => $donnees], false);
}

/** Liste des journées ouvertes, pour choisir où vendre. */
function pos_choix(): void
{
    $journees = q(
        "SELECT j.Id, j.NumeroJournee, j.DateJournee, j.DateOuverture, c.ChkCode, c.ChkDescription
         FROM JourneesCaisses j JOIN Caisses c ON c.ID = j.CaisseId
         WHERE j.Statut = 'Ouverte' AND " . tf('j') . '
         ORDER BY j.DateJournee DESC, c.ChkCode'
    );
    render('pos/choix', ['journees' => $journees]);
}
