<?php
// Tableau de bord : même calcul que la version .NET (DashboardController).

function dashboard_index(): void
{
    $aujourdhui = new DateTimeImmutable('today');
    $periode = (string) get('periode', '');
    $dateDebut = get('dateDebut');
    $dateFin = get('dateFin');
    $statutJournee = (string) get('statutJournee', '');
    $caisseId = int_or_null(get('caisseId'));

    if ($periode === '') {
        $periode = ($dateDebut || $dateFin) ? 'perso' : 'jour';
    }

    switch ($periode) {
        case 'semaine':
            $debut = $aujourdhui->modify('-6 days');
            $fin = $aujourdhui;
            break;
        case 'mois':
            $debut = $aujourdhui->modify('first day of this month');
            $fin = $aujourdhui;
            break;
        case 'perso':
            $debut = date_ou($dateDebut, $aujourdhui);
            $fin = date_ou($dateFin, $aujourdhui);
            break;
        default:
            $periode = 'jour';
            $debut = $aujourdhui;
            $fin = $aujourdhui;
    }
    if ($fin < $debut) {
        [$debut, $fin] = [$fin, $debut];
    }
    $finExclue = $fin->modify('+1 day');

    // Filtres caisse + statut (sans les dates), hors opérations rejetées.
    $filtreOps = tf('o') . " AND o.StatutValidation <> '" . STATUT_REJETE . "'";
    $filtreJournees = tf('j');
    $p = [];
    if ($caisseId) {
        $filtreOps .= ' AND j.CaisseId = :caisse';
        $filtreJournees .= ' AND j.CaisseId = :caisse';
        $p['caisse'] = $caisseId;
    }
    if ($statutJournee !== '') {
        $filtreOps .= ' AND j.Statut = :statut';
        $filtreJournees .= ' AND j.Statut = :statut';
        $p['statut'] = $statutJournee;
    }
    $opsBase = "FROM OperationsCaisses o JOIN JourneesCaisses j ON j.Id = o.JourneeCaisseId WHERE $filtreOps";
    $periodeSql = ' AND o.DateOperation >= :debut AND o.DateOperation < :finx';
    $pp = $p + ['debut' => $debut->format('Y-m-d'), 'finx' => $finExclue->format('Y-m-d')];

    // Montants et compteurs.
    $totaux = q("SELECT o.TypeOperation AS t, COUNT(*) AS n, SUM(o.Montant) AS m $opsBase $periodeSql GROUP BY o.TypeOperation", $pp);
    $m = ['Encaissement' => ['n' => 0, 'm' => 0.0], 'Décaissement' => ['n' => 0, 'm' => 0.0]];
    foreach ($totaux as $t) {
        $m[$t['t']] = ['n' => (int) $t['n'], 'm' => (float) $t['m']];
    }
    $entrees = $m['Encaissement']['m'];
    $sorties = $m['Décaissement']['m'];

    // Fond initial : solde initial de la première journée de chaque caisse sur la période.
    $montantInitial = (float) qv(
        "SELECT COALESCE(SUM(j.SoldeInitial), 0)
         FROM JourneesCaisses j
         WHERE $filtreJournees AND j.DateJournee >= :debut AND j.DateJournee < :finx
           AND j.Id = (
               SELECT j2.Id FROM JourneesCaisses j2
               WHERE j2.CaisseId = j.CaisseId AND j2.DateJournee >= :debut2 AND j2.DateJournee < :finx2
               ORDER BY j2.DateJournee, j2.DateOuverture, j2.Id LIMIT 1)",
        $pp + ['debut2' => $pp['debut'], 'finx2' => $pp['finx']]
    );

    // Période précédente de même durée, pour les tendances.
    $duree = (int) $debut->diff($fin)->days + 1;
    $debutPrecedent = $debut->modify("-$duree days");
    $prec = q(
        "SELECT o.TypeOperation AS t, SUM(o.Montant) AS m $opsBase
         AND o.DateOperation >= :pd AND o.DateOperation < :pf GROUP BY o.TypeOperation",
        $p + ['pd' => $debutPrecedent->format('Y-m-d'), 'pf' => $debut->format('Y-m-d')]
    );
    $precM = ['Encaissement' => 0.0, 'Décaissement' => 0.0];
    foreach ($prec as $t) {
        $precM[$t['t']] = (float) $t['m'];
    }

    // État des caisses : dernière journée de chaque caisse.
    $sqlCaisses = 'SELECT c.ID, c.ChkCode, c.ChkDescription, u.NomComplet AS Caissier
                   FROM Caisses c LEFT JOIN Utilisateurs u ON u.Id = c.CashierDefault
                   WHERE ' . tf('c') . ($caisseId ? ' AND c.ID = ' . $caisseId : '') . ' ORDER BY c.ChkCode';
    $etatCaisses = [];
    foreach (q($sqlCaisses) as $c) {
        $j = q1('SELECT * FROM JourneesCaisses WHERE CaisseId = ? ORDER BY DateOuverture DESC, Id DESC LIMIT 1', [$c['ID']]);
        $etat = [
            'CaisseId' => (int) $c['ID'],
            'Nom' => $c['ChkCode'] . ' · ' . $c['ChkDescription'],
            'Caissier' => $c['Caissier'],
            'JourneeId' => null, 'Statut' => null, 'DateOuverture' => null, 'DateFermeture' => null, 'Solde' => 0.0,
        ];
        if ($j) {
            $tj = totaux_journee((int) $j['Id']);
            $etat['JourneeId'] = (int) $j['Id'];
            $etat['Statut'] = $j['Statut'];
            $etat['DateOuverture'] = $j['DateOuverture'];
            $etat['DateFermeture'] = $j['DateFermeture'];
            $etat['Solde'] = (float) $j['SoldeInitial'] + $tj['encaisse'] - $tj['decaisse'];
        }
        $etatCaisses[] = $etat;
    }
    $ouvertes = array_values(array_filter($etatCaisses, fn($e) => $e['Statut'] === 'Ouverte'));

    // À traiter (toutes dates : un retard reste à traiter), filtré par caisse.
    $filtreTraiter = tf('o') . ($caisseId ? ' AND j.CaisseId = ' . $caisseId : '');
    $baseTraiter = "FROM OperationsCaisses o JOIN JourneesCaisses j ON j.Id = o.JourneeCaisseId WHERE $filtreTraiter";
    $enAttenteN = (int) qv("SELECT COUNT(*) $baseTraiter AND o.StatutValidation = 'En attente'");
    $enAttenteJ = qv("SELECT o.JourneeCaisseId $baseTraiter AND o.StatutValidation = 'En attente' ORDER BY o.DateOperation LIMIT 1");
    $nonJustifN = (int) qv("SELECT COUNT(*) $baseTraiter AND o.TypeOperation = 'Décaissement' AND o.EstJustifie = 0 AND o.StatutValidation <> '" . STATUT_REJETE . "'");
    $nonJustifJ = qv("SELECT o.JourneeCaisseId $baseTraiter AND o.TypeOperation = 'Décaissement' AND o.EstJustifie = 0 AND o.StatutValidation <> '" . STATUT_REJETE . "' ORDER BY o.DateOperation LIMIT 1");
    $filtreJ = tf('j') . ($caisseId ? ' AND j.CaisseId = ' . $caisseId : '');
    $limite = date('Y-m-d H:i:s', time() - 86400);
    $anciennesN = (int) qv("SELECT COUNT(*) FROM JourneesCaisses j WHERE $filtreJ AND j.Statut = 'Ouverte' AND j.DateOuverture < ?", [$limite]);
    $anciennesJ = qv("SELECT j.Id FROM JourneesCaisses j WHERE $filtreJ AND j.Statut = 'Ouverte' AND j.DateOuverture < ? ORDER BY j.DateOuverture LIMIT 1", [$limite]);

    // Flux (graphique) : par jour (au moins 7 jours) ou par mois au-delà de 31 jours.
    $flux = [];
    if ($duree <= 31) {
        $debutFlux = $duree < 7 ? $fin->modify('-6 days') : $debut;
        $rows = q(
            "SELECT DATE(o.DateOperation) AS d, o.TypeOperation AS t, SUM(o.Montant) AS m $opsBase
             AND o.DateOperation >= :fd AND o.DateOperation < :finx GROUP BY DATE(o.DateOperation), o.TypeOperation",
            $p + ['fd' => $debutFlux->format('Y-m-d'), 'finx' => $pp['finx']]
        );
        $idx = [];
        foreach ($rows as $r) {
            $idx[$r['d']][$r['t']] = (float) $r['m'];
        }
        $titreFlux = $duree < 7 ? 'Flux des 7 derniers jours' : 'Flux par jour';
        for ($d = $debutFlux; $d <= $fin; $d = $d->modify('+1 day')) {
            $k = $d->format('Y-m-d');
            $flux[] = ['l' => jour_court($d), 'e' => $idx[$k]['Encaissement'] ?? 0, 's' => $idx[$k]['Décaissement'] ?? 0];
        }
    } else {
        $rows = q(
            "SELECT DATE_FORMAT(o.DateOperation, '%Y-%m') AS d, o.TypeOperation AS t, SUM(o.Montant) AS m $opsBase $periodeSql
             GROUP BY DATE_FORMAT(o.DateOperation, '%Y-%m'), o.TypeOperation",
            $pp
        );
        $idx = [];
        foreach ($rows as $r) {
            $idx[$r['d']][$r['t']] = (float) $r['m'];
        }
        $titreFlux = 'Flux par mois';
        for ($d = $debut->modify('first day of this month'); $d <= $fin; $d = $d->modify('+1 month')) {
            $k = $d->format('Y-m');
            $flux[] = ['l' => mois_court($d), 'e' => $idx[$k]['Encaissement'] ?? 0, 's' => $idx[$k]['Décaissement'] ?? 0];
        }
    }

    // Répartitions.
    $parMode = q(
        "SELECT COALESCE(mp.Libelle, 'Non renseigné') AS l, SUM(o.Montant) AS m
         FROM OperationsCaisses o JOIN JourneesCaisses j ON j.Id = o.JourneeCaisseId
         LEFT JOIN ModesPaiement mp ON mp.Id = o.ModePaiementId
         WHERE $filtreOps $periodeSql AND o.TypeOperation = 'Encaissement'
         GROUP BY mp.Libelle ORDER BY m DESC",
        $pp
    );
    $topMotifs = q(
        "SELECT COALESCE(mo.LibelleMotif, 'Sans motif') AS l, SUM(o.Montant) AS m
         FROM OperationsCaisses o JOIN JourneesCaisses j ON j.Id = o.JourneeCaisseId
         LEFT JOIN Motifs mo ON mo.ID = o.MotifId
         WHERE $filtreOps $periodeSql AND o.TypeOperation = 'Décaissement'
         GROUP BY mo.LibelleMotif ORDER BY m DESC LIMIT 3",
        $pp
    );

    // Dernières opérations (rejetées comprises, montant barré).
    $filtreListe = tf('o') . ($caisseId ? ' AND j.CaisseId = :caisse' : '') . ($statutJournee !== '' ? ' AND j.Statut = :statut' : '');
    $dernieres = q(
        "SELECT o.*, u.NomComplet AS Caissier, mp.Libelle AS ModePaiement
         FROM OperationsCaisses o JOIN JourneesCaisses j ON j.Id = o.JourneeCaisseId
         LEFT JOIN Utilisateurs u ON u.Id = o.UtilisateurId
         LEFT JOIN ModesPaiement mp ON mp.Id = o.ModePaiementId
         WHERE $filtreListe $periodeSql ORDER BY o.DateOperation DESC, o.Id DESC LIMIT 10",
        $pp
    );

    $caisses = q('SELECT ID, ChkCode, ChkDescription FROM Caisses WHERE ' . tf() . ' ORDER BY ChkDescription');

    render('dashboard/index', [
        'periode' => $periode,
        'debut' => $debut,
        'fin' => $fin,
        'caisseId' => $caisseId,
        'statutJournee' => $statutJournee,
        'caisses' => $caisses,
        'montantInitial' => $montantInitial,
        'entrees' => $entrees,
        'sorties' => $sorties,
        'nbEnc' => $m['Encaissement']['n'],
        'nbDec' => $m['Décaissement']['n'],
        'varEntrees' => variation($entrees, $precM['Encaissement']),
        'varSorties' => variation($sorties, $precM['Décaissement']),
        'etatCaisses' => $etatCaisses,
        'nbOuvertes' => count($ouvertes),
        'journeeOuverteId' => count($ouvertes) === 1 ? $ouvertes[0]['JourneeId'] : null,
        'aTraiter' => [
            ['n' => $enAttenteN, 'j' => $enAttenteJ, 'txt' => 'opération%s en attente de validation'],
            ['n' => $nonJustifN, 'j' => $nonJustifJ, 'txt' => 'décaissement%s sans justificatif'],
            ['n' => $anciennesN, 'j' => $anciennesJ, 'txt' => 'journée%s ouverte%s depuis plus de 24 h'],
        ],
        'titreFlux' => $titreFlux,
        'flux' => $flux,
        'parMode' => $parMode,
        'topMotifs' => $topMotifs,
        'dernieres' => $dernieres,
    ]);
}

function date_ou(?string $valeur, DateTimeImmutable $defaut): DateTimeImmutable
{
    if ($valeur) {
        $d = DateTimeImmutable::createFromFormat('!Y-m-d', $valeur);
        if ($d) {
            return $d;
        }
    }
    return $defaut;
}

function variation(float $actuel, float $precedent): ?float
{
    return $precedent == 0.0 ? null : round(($actuel - $precedent) * 100 / $precedent);
}

function jour_court(DateTimeImmutable $d): string
{
    $jours = ['dim.', 'lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.'];
    return $jours[(int) $d->format('w')] . ' ' . $d->format('d');
}

function mois_court(DateTimeImmutable $d): string
{
    $mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
    return $mois[(int) $d->format('n') - 1] . ' ' . $d->format('y');
}
