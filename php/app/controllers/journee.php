<?php
// Journées de caisse : ouverture, opérations, validation, clôture avec comptage, impressions.

function journee_charger(int $id): array
{
    $j = q1(
        'SELECT j.*, c.ChkCode, c.ChkDescription
         FROM JourneesCaisses j JOIN Caisses c ON c.ID = j.CaisseId
         WHERE j.Id = ? AND ' . tf('j'),
        [$id]
    );
    if (!$j) {
        not_found('Journée introuvable.');
    }
    return $j;
}

/**
 * Solde initial proposé à l'ouverture : solde compté de la dernière journée
 * clôturée, ou solde théorique de la dernière journée encore ouverte.
 */
function journee_solde_suggere(int $caisseId): float
{
    $derniere = q1('SELECT * FROM JourneesCaisses WHERE CaisseId = ? ORDER BY DateJournee DESC, Id DESC LIMIT 1', [$caisseId]);
    if (!$derniere) {
        return 0.0;
    }
    if ($derniere['Statut'] === 'Cloturee') {
        return (float) $derniere['SoldeFinal'];
    }
    $t = totaux_journee((int) $derniere['Id']);
    return (float) $derniere['SoldeInitial'] + $t['encaisse'] - $t['decaisse'];
}

function journee_create(): void
{
    $caisse = q1('SELECT * FROM Caisses WHERE ID = ? AND ' . tf(), [(int) (get('id') ?? post('caisseId'))]);
    if (!$caisse) {
        not_found('Caisse introuvable.');
    }

    if (is_post()) {
        $date = DateTimeImmutable::createFromFormat('!Y-m-d', (string) post('dateJournee')) ?: new DateTimeImmutable('today');
        $existe = (int) qv('SELECT COUNT(*) FROM JourneesCaisses WHERE CaisseId = ? AND DateJournee = ?', [$caisse['ID'], $date->format('Y-m-d')]);
        if ($existe) {
            flash('danger', 'Cette journée existe déjà.');
        } else {
            $id = run(
                "INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, SoldeInitial, Statut)
                 VALUES (?, ?, ?, ?, NOW(), ?, 'Ouverte')",
                [(int) $caisse['TenantId'], $caisse['ID'], $caisse['ChkCode'] . '-' . $date->format('Ymd'), $date->format('Y-m-d'), montant(post('soldeInitial'))]
            );
            redirect('journee/details', ['id' => $id]);
        }
    }

    render('journee/create', ['caisse' => $caisse, 'soldeSuggere' => journee_solde_suggere((int) $caisse['ID'])]);
}

function journee_details(): void
{
    $journee = journee_charger((int) get('id'));
    $t = totaux_journee((int) $journee['Id']);

    $operations = q(
        "SELECT o.*, COALESCE(m.LibelleMotif, '-') AS MotifLibelle, COALESCE(mp.Libelle, '-') AS ModeLibelle,
                cl.NomSociete AS Tiers
         FROM OperationsCaisses o
         LEFT JOIN Motifs m ON m.ID = o.MotifId
         LEFT JOIN ModesPaiement mp ON mp.Id = o.ModePaiementId
         LEFT JOIN Clients cl ON cl.Id = o.ClientId
         WHERE o.JourneeCaisseId = ? ORDER BY o.DateOperation DESC, o.Id DESC",
        [$journee['Id']]
    );

    render('journee/details', [
        'journee' => $journee,
        'totalEncaisse' => $t['encaisse'],
        'totalDecaisse' => $t['decaisse'],
        'soldeActuel' => (float) $journee['SoldeInitial'] + $t['encaisse'] - $t['decaisse'],
        'totauxParMode' => totaux_par_mode((int) $journee['Id']),
        'comptages' => q(
            "SELECT c.*, COALESCE(mp.Libelle, 'Non renseigné') AS Libelle
             FROM ComptagesCloture c LEFT JOIN ModesPaiement mp ON mp.Id = c.ModePaiementId
             WHERE c.JourneeCaisseId = ?",
            [$journee['Id']]
        ),
        'operations' => $operations,
        'clients' => q('SELECT Id, NomSociete FROM Clients WHERE ' . tf() . ' ORDER BY NomSociete'),
        'motifs' => q('SELECT ID, LibelleMotif FROM Motifs WHERE ' . tf() . ' ORDER BY LibelleMotif'),
        'modes' => q('SELECT Id, Libelle FROM ModesPaiement WHERE Actif = 1 AND ' . tf() . ' ORDER BY Libelle'),
    ]);
}

/** Nouvelle opération (encaissement ou décaissement). */
function journee_operation(): void
{
    $journee = journee_charger((int) post('journeeId'));

    if ($journee['Statut'] === 'Cloturee') {
        flash('danger', 'Cette journée est clôturée. Aucune opération autorisée.');
        redirect('journee/details', ['id' => $journee['Id']]);
    }

    $type = post('typeOperation') === 'Décaissement' ? 'Décaissement' : 'Encaissement';
    $montant = montant(post('montant'));
    if ($montant <= 0) {
        flash('danger', 'Le montant doit être supérieur à zéro.');
        redirect('journee/details', ['id' => $journee['Id']]);
    }

    // Sans le droit de validation, le statut posté est ignoré : "En attente".
    $statut = (string) post('statutValidation', '');
    if (!peut_valider() || !in_array($statut, ['En attente', 'Validé', 'Rejeté'], true)) {
        $statut = 'En attente';
    }

    run(
        'INSERT INTO OperationsCaisses
            (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId,
             ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur, Observation)
         VALUES (?, ?, NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
            (int) $journee['TenantId'], $journee['Id'], $type, $montant, (string) post('libelle', ''),
            int_or_null(post('clientId')), int_or_null(post('motifId')), int_or_null(post('modePaiementId')),
            user()['id'], post('estJustifie') ? 1 : 0, $statut,
            $statut !== 'En attente' ? user()['nomComplet'] : null,
            post('observation') ?: null,
        ]
    );
    flash('success', $type . ' enregistré.');
    redirect('journee/details', ['id' => $journee['Id']]);
}

/** Modification du justificatif / statut de validation d'une opération. */
function journee_validation(): void
{
    $journee = journee_charger((int) post('journeeId'));

    if (!peut_valider()) {
        flash('danger', "Vous n'avez pas le droit de valider/rejeter les opérations de caisse.");
        redirect('journee/details', ['id' => $journee['Id']]);
    }

    $statut = (string) post('statutValidation', '');
    if (!in_array($statut, ['En attente', 'Validé', 'Rejeté'], true)) {
        $statut = 'En attente';
    }

    run(
        'UPDATE OperationsCaisses SET EstJustifie = ?, StatutValidation = ?, Observation = ?, Valideur = ?
         WHERE Id = ? AND JourneeCaisseId = ?',
        [post('estJustifie') ? 1 : 0, $statut, post('observation') ?: null, user()['nomComplet'], (int) post('id'), $journee['Id']]
    );
    redirect('journee/details', ['id' => $journee['Id']]);
}

/**
 * Clôture : comparaison du compté et du théorique par mode de paiement
 * (comme la fermeture de caisse d'un point de vente).
 */
function journee_cloturer(): void
{
    $journee = journee_charger((int) post('id'));
    if ($journee['Statut'] === 'Cloturee') {
        redirect('journee/details', ['id' => $journee['Id']]);
    }

    $theoriques = [];
    foreach (totaux_par_mode((int) $journee['Id']) as $t) {
        $theoriques[(string) ($t['ModePaiementId'] ?? '')] = $t['Net'];
    }

    $pdo = db();
    $pdo->beginTransaction();
    try {
        $totalCompte = 0.0;
        $totalTheorique = 0.0;
        foreach ((array) ($_POST['comptages'] ?? []) as $c) {
            $modeId = int_or_null($c['modePaiementId'] ?? null);
            $compte = montant($c['montantCompte'] ?? '0');
            $theorique = $theoriques[(string) ($modeId ?? '')] ?? 0.0;
            run(
                'INSERT INTO ComptagesCloture (JourneeCaisseId, ModePaiementId, MontantTheorique, MontantCompte, TenantId) VALUES (?, ?, ?, ?, ?)',
                [$journee['Id'], $modeId, $theorique, $compte, (int) $journee['TenantId']]
            );
            $totalCompte += $compte;
            $totalTheorique += $theorique;
        }
        run(
            "UPDATE JourneesCaisses SET Statut = 'Cloturee', DateFermeture = NOW(), SoldeFinal = ?, EcartCloture = ?, NoteCloture = ? WHERE Id = ?",
            [(float) $journee['SoldeInitial'] + $totalCompte, $totalCompte - $totalTheorique, post('noteCloture') ?: null, $journee['Id']]
        );
        $pdo->commit();
    } catch (Throwable $e) {
        $pdo->rollBack();
        throw $e;
    }
    flash('success', 'Journée clôturée.');
    redirect('journee/details', ['id' => $journee['Id']]);
}

function journee_supprimer(): void
{
    $journee = journee_charger((int) post('id'));
    if ($journee['Statut'] === 'Cloturee') {
        flash('danger', 'Impossible de supprimer une journée clôturée.');
        redirect('journee/details', ['id' => $journee['Id']]);
    }
    run('DELETE FROM JourneesCaisses WHERE Id = ?', [$journee['Id']]);
    flash('success', 'Journée supprimée.');
    redirect('caisse/details', ['id' => $journee['CaisseId']]);
}

function journee_printoperations(): void
{
    $journee = journee_charger((int) get('journeeId'));
    $t = totaux_journee((int) $journee['Id']);
    render('journee/print_operations', [
        'journee' => $journee,
        'totalEncaisse' => $t['encaisse'],
        'totalDecaisse' => $t['decaisse'],
        'soldeActuel' => (float) $journee['SoldeInitial'] + $t['encaisse'] - $t['decaisse'],
        'totauxParMode' => totaux_par_mode((int) $journee['Id']),
        'operations' => q(
            "SELECT o.*, COALESCE(mp.Libelle, '-') AS ModeLibelle
             FROM OperationsCaisses o LEFT JOIN ModesPaiement mp ON mp.Id = o.ModePaiementId
             WHERE o.JourneeCaisseId = ? ORDER BY o.DateOperation, o.Id",
            [$journee['Id']]
        ),
    ], false);
}

function journee_printjournees(): void
{
    $caisse = q1('SELECT * FROM Caisses WHERE ID = ? AND ' . tf(), [(int) get('caisseId')]);
    if (!$caisse) {
        not_found('Caisse introuvable.');
    }
    $journees = q('SELECT * FROM JourneesCaisses WHERE CaisseId = ? ORDER BY DateJournee, Id', [$caisse['ID']]);
    foreach ($journees as &$j) {
        $t = totaux_journee((int) $j['Id']);
        $j['Encaisse'] = $t['encaisse'];
        $j['Decaisse'] = $t['decaisse'];
        $j['Solde'] = (float) $j['SoldeInitial'] + $t['encaisse'] - $t['decaisse'];
    }
    render('journee/print_journees', ['caisse' => $caisse, 'journees' => $journees], false);
}
