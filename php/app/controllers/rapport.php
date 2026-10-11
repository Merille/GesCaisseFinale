<?php
// Rapports : journal des opérations (écran / impression) et export comptable Sage.

require_once __DIR__ . '/../xlsx.php';

/** Filtres communs lus dans l'URL. */
function rapport_filtres(): array
{
    $d = fn($v) => ($v && DateTime::createFromFormat('!Y-m-d', $v)) ? $v : null;
    $type = (string) get('typeOperation', '');
    return [
        'dateDebut' => $d(get('dateDebut')),
        'dateFin' => $d(get('dateFin')),
        'caisseId' => int_or_null(get('caisseId')),
        'typeOperation' => in_array($type, ['Encaissement', 'Décaissement'], true) ? $type : '',
    ];
}

/** Clause WHERE et paramètres pour les opérations filtrées. */
function rapport_where(array $f, bool $horsRejetees = false): array
{
    $w = tf('o');
    $p = [];
    if ($f['dateDebut']) {
        $w .= ' AND o.DateOperation >= :dd';
        $p['dd'] = $f['dateDebut'];
    }
    if ($f['dateFin']) {
        // Date de fin incluse (jusqu'à 23:59:59).
        $w .= ' AND o.DateOperation < DATE_ADD(:df, INTERVAL 1 DAY)';
        $p['df'] = $f['dateFin'];
    }
    if ($f['caisseId']) {
        $w .= ' AND j.CaisseId = :cid';
        $p['cid'] = $f['caisseId'];
    }
    if ($f['typeOperation'] !== '') {
        $w .= ' AND o.TypeOperation = :typ';
        $p['typ'] = $f['typeOperation'];
    }
    if ($horsRejetees) {
        $w .= " AND o.StatutValidation <> '" . STATUT_REJETE . "'";
    }
    return [$w, $p];
}

function rapport_donnees(array $f): array
{
    [$w, $p] = rapport_where($f);
    $operations = q(
        "SELECT o.*, j.NumeroJournee, c.ChkCode, cl.NomSociete AS Tiers, u.NomComplet AS Caissier, mp.Libelle AS ModeLibelle
         FROM OperationsCaisses o
         JOIN JourneesCaisses j ON j.Id = o.JourneeCaisseId
         JOIN Caisses c ON c.ID = j.CaisseId
         LEFT JOIN Clients cl ON cl.Id = o.ClientId
         LEFT JOIN Utilisateurs u ON u.Id = o.UtilisateurId
         LEFT JOIN ModesPaiement mp ON mp.Id = o.ModePaiementId
         WHERE $w ORDER BY o.DateOperation DESC, o.Id DESC",
        $p
    );

    $entrees = $sorties = 0.0;
    foreach ($operations as $o) {
        if ($o['StatutValidation'] === STATUT_REJETE) {
            continue;
        }
        if ($o['TypeOperation'] === 'Encaissement') {
            $entrees += (float) $o['Montant'];
        } else {
            $sorties += (float) $o['Montant'];
        }
    }

    // Fond initial : solde initial de la première journée de chaque caisse sur la période.
    $wj = tf('j');
    $pj = [];
    if ($f['dateDebut']) {
        $wj .= ' AND j.DateJournee >= :dd';
        $pj['dd'] = $f['dateDebut'];
    }
    if ($f['dateFin']) {
        $wj .= ' AND j.DateJournee <= :df';
        $pj['df'] = $f['dateFin'];
    }
    if ($f['caisseId']) {
        $wj .= ' AND j.CaisseId = :cid';
        $pj['cid'] = $f['caisseId'];
    }
    $premieres = q("SELECT j.CaisseId, j.SoldeInitial FROM JourneesCaisses j WHERE $wj ORDER BY j.DateJournee, j.DateOuverture, j.Id", $pj);
    $fond = [];
    foreach ($premieres as $r) {
        $fond[$r['CaisseId']] ??= (float) $r['SoldeInitial'];
    }

    return [
        'operations' => $operations,
        'totalEntrees' => $entrees,
        'totalSorties' => $sorties,
        'montantInitial' => array_sum($fond),
    ];
}

function rapport_operations(): void
{
    $f = rapport_filtres();
    render('rapport/operations', rapport_donnees($f) + [
        'f' => $f,
        'caisses' => q('SELECT ID, ChkCode, ChkDescription FROM Caisses WHERE ' . tf() . ' ORDER BY ChkDescription'),
    ]);
}

function rapport_preview(): void
{
    $f = rapport_filtres();
    $caisse = $f['caisseId'] ? q1('SELECT ChkCode, ChkDescription FROM Caisses WHERE ID = ?', [$f['caisseId']]) : null;
    render('rapport/preview', rapport_donnees($f) + ['f' => $f, 'caisse' => $caisse], false);
}

/**
 * Écritures comptables pour Sage : 2 lignes par opération (caisse / contrepartie).
 * Contrepartie : compte du motif en priorité, sinon compte général du tiers.
 */
function rapport_ecritures(array $f): array
{
    [$w, $p] = rapport_where($f, true);
    $ops = q(
        "SELECT o.*, c.ChkCode, c.ChkDescription, c.CompteComptable, m.LibelleMotif, m.CG_Num,
                cl.CompteGeneral, cl.CodeClient
         FROM OperationsCaisses o
         JOIN JourneesCaisses j ON j.Id = o.JourneeCaisseId
         JOIN Caisses c ON c.ID = j.CaisseId
         LEFT JOIN Motifs m ON m.ID = o.MotifId
         LEFT JOIN Clients cl ON cl.Id = o.ClientId
         WHERE $w ORDER BY o.DateOperation, o.Id",
        $p
    );

    $lignes = [];
    $anomalies = [];
    foreach ($ops as $o) {
        $piece = 'OP' . str_pad((string) $o['Id'], 6, '0', STR_PAD_LEFT);
        $libelle = trim((string) $o['Libelle']) !== '' ? $o['Libelle'] : ($o['LibelleMotif'] ?? $o['TypeOperation']);
        $contrepartie = trim((string) $o['CG_Num']) !== '' ? $o['CG_Num'] : $o['CompteGeneral'];
        if (trim((string) $o['CompteComptable']) === '') {
            $anomalies[] = "$piece : compte comptable manquant sur la caisse \"{$o['ChkDescription']}\".";
        }
        if (trim((string) $contrepartie) === '') {
            $anomalies[] = "$piece : aucun motif ni tiers avec compte général renseigné, compte de contrepartie vide.";
        }
        $enc = $o['TypeOperation'] === 'Encaissement';
        $m = (float) $o['Montant'];
        $date = new DateTimeImmutable($o['DateOperation']);
        $lignes[] = ['caisse' => $o['ChkCode'], 'date' => $date, 'compte' => $o['CompteComptable'], 'tiers' => null,
                     'libelle' => $libelle, 'debit' => $enc ? $m : 0.0, 'credit' => $enc ? 0.0 : $m, 'piece' => $piece];
        $lignes[] = ['caisse' => $o['ChkCode'], 'date' => $date, 'compte' => $contrepartie, 'tiers' => $o['CodeClient'],
                     'libelle' => $libelle, 'debit' => $enc ? 0.0 : $m, 'credit' => $enc ? $m : 0.0, 'piece' => $piece];
    }
    return [$lignes, $anomalies];
}

/** Export Sage : ?format=xlsx (défaut), csv (avec en-têtes) ou txt (sans en-têtes). */
function rapport_sage(): void
{
    [$lignes, $anomalies] = rapport_ecritures(rapport_filtres());
    $format = (string) get('format', 'xlsx');
    $nom = 'Export_Sage_' . date('Ymd_Hi');
    $entetes = ['CodeCaisse', 'DateEcriture', 'CompteGeneral', 'CompteTiers', 'Libelle', 'Debit', 'Credit', 'NumeroPiece'];
    $n2 = fn(float $v) => number_format($v, 2, '.', '');

    if ($format === 'csv' || $format === 'txt') {
        $csv = $format === 'csv';
        $champ = $csv
            ? fn($v) => preg_match('/[;"\n]/', (string) $v) ? '"' . str_replace('"', '""', (string) $v) . '"' : (string) $v
            : fn($v) => str_replace(';', ',', (string) $v);
        $sortie = "\u{FEFF}" . ($csv ? implode(';', $entetes) . "\r\n" : '');
        foreach ($lignes as $l) {
            $sortie .= implode(';', [
                $champ($l['caisse']), $l['date']->format($csv ? 'dmy' : 'd/m/Y'), $champ($l['compte']), $champ($l['tiers']),
                $champ($l['libelle']), $n2($l['debit']), $n2($l['credit']), $champ($l['piece']),
            ]) . "\r\n";
        }
        header('Content-Type: ' . ($csv ? 'text/csv' : 'text/plain') . '; charset=utf-8');
        header('Content-Disposition: attachment; filename="' . $nom . '.' . $format . '"');
        echo $sortie;
        exit;
    }

    $feuille = [$entetes];
    foreach ($lignes as $l) {
        // Date en texte "jjmmaa" (garde le zéro de tête).
        $feuille[] = [(string) $l['caisse'], $l['date']->format('dmy'), (string) $l['compte'], (string) $l['tiers'],
                      (string) $l['libelle'], round($l['debit'], 2), round($l['credit'], 2), $l['piece']];
    }
    $feuilles = ['Ecritures' => $feuille];
    if ($anomalies) {
        $feuilles['Anomalies'] = array_merge([['Écritures à compléter avant import (compte manquant)']], array_map(fn($a) => [$a], $anomalies));
    }
    xlsx_envoyer($nom . '.xlsx', $feuilles);
}
