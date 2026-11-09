<?php
// Rapport des tiers : synthèse par tiers sur une période (ventes du point de vente, encaissements,
// décaissements, solde), export Excel et impression ; relevé détaillé d'un tiers (opérations de
// caisse et ventes de la période), imprimable. Les opérations rejetées et les ventes annulées
// sont exclues des montants.

require_once __DIR__ . '/../xlsx.php';

const RAPPORT_TIERS_TYPES = ['Client', 'Fournisseur', 'Salarié', 'Autre'];

/** Filtres lus dans l'URL (par défaut : du 1er du mois à aujourd'hui). */
function rapporttiers_filtres(): array
{
    $d = fn($v) => ($v && DateTime::createFromFormat('!Y-m-d', (string) $v)) ? (string) $v : null;
    $type = (string) get('type', '');
    $genre = (string) get('genre', '');
    $f = [
        'du' => $d(get('du')) ?? date('Y-m-01'),
        'au' => $d(get('au')) ?? date('Y-m-d'),
        'type' => in_array($type, RAPPORT_TIERS_TYPES, true) ? $type : '',
        'genre' => in_array($genre, ['Entreprise', 'Particulier'], true) ? $genre : '',
        'tous' => get('tous') === '1',
    ];
    if ($f['au'] < $f['du']) {
        [$f['du'], $f['au']] = [$f['au'], $f['du']];
    }
    return $f;
}

/** Paramètres d'URL des filtres (liens Imprimer, Excel, relevé). */
function rapporttiers_params(array $f): array
{
    return array_filter(['du' => $f['du'], 'au' => $f['au'], 'type' => $f['type'], 'genre' => $f['genre'], 'tous' => $f['tous'] ? '1' : ''],
        fn($v) => $v !== '');
}

/** Une ligne par tiers : ventes (nombre, montant net), encaissements, décaissements, solde, dernier mouvement. */
function rapporttiers_lignes(array $f): array
{
    $p = ['du1' => $f['du'], 'au1' => $f['au'], 'du2' => $f['du'], 'au2' => $f['au']];
    $w = tf('c');
    if ($f['type'] !== '') {
        $w .= ' AND c.Type = :type';
        $p['type'] = $f['type'];
    }
    if ($f['genre'] !== '') {
        $w .= ' AND c.Genre = :genre';
        $p['genre'] = $f['genre'];
    }
    if (!$f['tous']) {
        $w .= ' AND (v.ClientId IS NOT NULL OR o.ClientId IS NOT NULL)';
    }
    $lignes = q(
        "SELECT c.Id, c.TenantId, c.CodeClient, c.NomSociete, c.Genre, c.Type, c.Telephone, c.EnCompte,
                COALESCE(v.NbVentes, 0) AS NbVentes, COALESCE(v.Ventes, 0) AS Ventes, v.Derniere AS DerniereVente,
                COALESCE(o.Encaisse, 0) AS Encaissements, COALESCE(o.Decaisse, 0) AS Decaissements, o.Derniere AS DerniereOperation
         FROM Clients c
         LEFT JOIN (SELECT ClientId, SUM(CASE WHEN CommandeOrigineId IS NULL THEN 1 ELSE 0 END) AS NbVentes,
                           SUM(TotalTTC) AS Ventes, MAX(DateCommande) AS Derniere
                    FROM CommandesPos
                    WHERE ClientId IS NOT NULL AND Statut <> 'Annulée'
                      AND DateCommande >= :du1 AND DateCommande < DATE_ADD(:au1, INTERVAL 1 DAY)
                    GROUP BY ClientId) v ON v.ClientId = c.Id
         LEFT JOIN (SELECT ClientId,
                           SUM(CASE WHEN TypeOperation = 'Encaissement' THEN Montant ELSE 0 END) AS Encaisse,
                           SUM(CASE WHEN TypeOperation = 'Décaissement' THEN Montant ELSE 0 END) AS Decaisse,
                           MAX(DateOperation) AS Derniere
                    FROM OperationsCaisses
                    WHERE ClientId IS NOT NULL AND StatutValidation <> 'Rejeté'
                      AND DateOperation >= :du2 AND DateOperation < DATE_ADD(:au2, INTERVAL 1 DAY)
                    GROUP BY ClientId) o ON o.ClientId = c.Id
         WHERE $w
         ORDER BY c.NomSociete, c.Id",
        $p
    );
    // Clients en compte : solde dû à la fin de la période.
    $soldes = [];
    foreach (array_unique(array_column(array_filter($lignes, fn($l) => $l['EnCompte']), 'TenantId')) as $t) {
        $soldes += compte_soldes((int) $t, null, $f['au']);
    }
    foreach ($lignes as &$l) {
        $l['Solde'] = (float) $l['Encaissements'] - (float) $l['Decaissements'];
        $l['Dernier'] = max((string) $l['DerniereVente'], (string) $l['DerniereOperation']) ?: null;
        $l['Du'] = $l['EnCompte'] ? ($soldes[(int) $l['Id']] ?? 0.0) : null;
    }
    unset($l);
    return $lignes;
}

function rapporttiers_totaux(array $lignes): array
{
    $t = ['NbVentes' => 0, 'Ventes' => 0.0, 'Encaissements' => 0.0, 'Decaissements' => 0.0, 'Solde' => 0.0, 'Du' => 0.0];
    foreach ($lignes as $l) {
        foreach ($t as $k => $v) {
            $t[$k] += (float) $l[$k];
        }
    }
    return $t;
}

function rapporttiers_index(): void
{
    $f = rapporttiers_filtres();
    $lignes = rapporttiers_lignes($f);
    render('rapporttiers/index', ['f' => $f, 'lignes' => $lignes, 'totaux' => rapporttiers_totaux($lignes)]);
}

function rapporttiers_imprimer(): void
{
    $f = rapporttiers_filtres();
    $lignes = rapporttiers_lignes($f);
    render('rapporttiers/imprimer', ['f' => $f, 'lignes' => $lignes, 'totaux' => rapporttiers_totaux($lignes)], false);
}

function rapporttiers_excel(): void
{
    $f = rapporttiers_filtres();
    $lignes = rapporttiers_lignes($f);
    $t = rapporttiers_totaux($lignes);
    $feuille = [['Code', 'Tiers', 'Genre', 'Type', 'Nombre de ventes', 'Ventes nettes', 'Encaissements', 'Décaissements', 'Solde', 'Dû (compte)', 'Dernier mouvement']];
    foreach ($lignes as $l) {
        $feuille[] = [$l['CodeClient'], $l['NomSociete'], $l['Genre'], (string) $l['Type'], (int) $l['NbVentes'], (float) $l['Ventes'],
            (float) $l['Encaissements'], (float) $l['Decaissements'], (float) $l['Solde'], $l['Du'] === null ? '' : (float) $l['Du'],
            $l['Dernier'] ? date_fr($l['Dernier'], 'd/m/Y H:i') : ''];
    }
    $feuille[] = ['Total', count($lignes) . ' tiers', '', '', (int) $t['NbVentes'], $t['Ventes'], $t['Encaissements'], $t['Decaissements'], $t['Solde'], $t['Du'], ''];
    xlsx_envoyer('Rapport_tiers_' . str_replace('-', '', $f['du']) . '_' . str_replace('-', '', $f['au']) . '.xlsx', ['Tiers' => $feuille]);
}

/** Relevé d'un tiers sur la période : opérations de caisse et ventes du point de vente. */
function rapporttiers_releve(): void
{
    $f = rapporttiers_filtres();
    $tiers = q1('SELECT * FROM Clients WHERE Id = ? AND ' . tf(), [(int) get('id')]);
    if (!$tiers) {
        not_found('Tiers introuvable.');
    }
    $operations = q(
        'SELECT o.*, j.NumeroJournee, COALESCE(mp.Libelle, \'-\') AS ModeLibelle
         FROM OperationsCaisses o JOIN JourneesCaisses j ON j.Id = o.JourneeCaisseId
         LEFT JOIN ModesPaiement mp ON mp.Id = o.ModePaiementId
         WHERE o.ClientId = ? AND o.DateOperation >= ? AND o.DateOperation < DATE_ADD(?, INTERVAL 1 DAY)
         ORDER BY o.DateOperation, o.Id',
        [$tiers['Id'], $f['du'], $f['au']]
    );
    $ventes = q(
        "SELECT c.Id, c.Numero, c.DateCommande, c.Statut, c.TotalTTC, c.CommandeOrigineId,
                (SELECT GROUP_CONCAT(p.Libelle ORDER BY p.Id SEPARATOR ', ') FROM PaiementsPos p WHERE p.CommandePosId = c.Id) AS Paiement
         FROM CommandesPos c
         WHERE c.ClientId = ? AND c.DateCommande >= ? AND c.DateCommande < DATE_ADD(?, INTERVAL 1 DAY)
         ORDER BY c.DateCommande, c.Id",
        [$tiers['Id'], $f['du'], $f['au']]
    );
    // Client en compte : solde dû au début et à la fin de la période, ventes par compte et règlements.
    $compte = null;
    if ($tiers['EnCompte']) {
        $tenant = (int) $tiers['TenantId'];
        $veille = date('Y-m-d', strtotime($f['du'] . ' -1 day'));
        $compte = [
            'debut' => compte_solde($tenant, (int) $tiers['Id'], $veille),
            'fin' => compte_solde($tenant, (int) $tiers['Id'], $f['au']),
            'reglements' => (float) qv("SELECT COALESCE(SUM(Montant), 0) FROM OperationsCaisses WHERE ClientId = ? AND ReglementCompte = 1
                                        AND StatutValidation <> 'Rejeté' AND DateOperation >= ? AND DateOperation < DATE_ADD(?, INTERVAL 1 DAY)",
                                       [$tiers['Id'], $f['du'], $f['au']]),
            'plafond' => $tiers['PlafondCredit'],
        ];
        $compte['ventes'] = $compte['fin'] - $compte['debut'] + $compte['reglements'];
    }
    $enc = $dec = $nets = 0.0;
    foreach ($operations as $o) {
        if ($o['StatutValidation'] !== STATUT_REJETE) {
            $o['TypeOperation'] === 'Encaissement' ? $enc += (float) $o['Montant'] : $dec += (float) $o['Montant'];
        }
    }
    foreach ($ventes as $v) {
        if ($v['Statut'] !== 'Annulée') {
            $nets += (float) $v['TotalTTC'];
        }
    }
    render('rapporttiers/releve', [
        'f' => $f, 'tiers' => $tiers, 'operations' => $operations, 'ventes' => $ventes,
        'encaissements' => $enc, 'decaissements' => $dec, 'ventesNettes' => $nets, 'compte' => $compte,
    ], false);
}
