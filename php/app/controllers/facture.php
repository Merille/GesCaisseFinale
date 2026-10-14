<?php
// Factures : brouillon, lignes, recalcul HT / TVA / TTC, validation, impression.

function facture_charger(int $id): array
{
    $f = q1(
        'SELECT f.*, c.NomSociete, c.CodeClient, c.Adresse, c.Telephone, c.Email
         FROM Factures f LEFT JOIN Clients c ON c.Id = f.ClientId
         WHERE f.Id = ? AND ' . tf('f'),
        [$id]
    );
    if (!$f) {
        not_found('Facture introuvable.');
    }
    return $f;
}

function facture_recalculer(int $id): void
{
    $ht = (float) qv('SELECT COALESCE(SUM(TotalLigne), 0) FROM LignesFactures WHERE FactureId = ?', [$id]);
    $taux = (float) qv('SELECT TauxTVA FROM Factures WHERE Id = ?', [$id]);
    $tva = round($ht * $taux / 100, 2);
    run('UPDATE Factures SET MontantHT = ?, MontantTVA = ?, MontantTTC = ? WHERE Id = ?', [$ht, $tva, $ht + $tva, $id]);
}

function facture_index(): void
{
    $pagination = paginer((int) qv('SELECT COUNT(*) FROM Factures WHERE ' . tf()), 'facture/index', [], 'Factures');
    $factures = q(
        'SELECT f.*, c.NomSociete FROM Factures f LEFT JOIN Clients c ON c.Id = f.ClientId
         WHERE ' . tf('f') . ' ORDER BY f.DateFacture DESC, f.Id DESC' . $pagination['limite']
    );
    render('facture/index', ['factures' => $factures, 'pagination' => $pagination, 'creation' => facture_donnees_creation()]);
}

function facture_create(): void
{
    if (is_post()) {
        $clientId = (int) post('ClientId');
        $numero = (string) post('Numero', '');
        if (!q1('SELECT Id FROM Clients WHERE Id = ? AND ' . tf(), [$clientId])) {
            flash('danger', 'Choisissez un client.');
        } elseif ($numero === '') {
            flash('danger', 'Le numéro de facture est obligatoire.');
        } elseif (qv('SELECT COUNT(*) FROM Factures WHERE Numero = ? AND ' . tf(), [$numero])) {
            flash('danger', "Le numéro « $numero » existe déjà.");
        } else {
            $id = run(
                "INSERT INTO Factures (TenantId, Numero, DateFacture, ClientId, TauxTVA, Statut) VALUES (?, ?, NOW(), ?, ?, 'Brouillon')",
                [tenant_insert(), $numero, $clientId, montant(post('TauxTVA'))]
            );
            redirect('facture/edit', ['id' => $id]);
        }
    }
    render('facture/create', facture_donnees_creation());
}

/** Clients et numéro proposé (FAC-AAAA-0001, suivant le nombre de factures de l'année). */
function facture_donnees_creation(): array
{
    $n = (int) qv('SELECT COUNT(*) FROM Factures WHERE YEAR(DateFacture) = YEAR(CURDATE()) AND ' . tf()) + 1;
    return [
        'clients' => q('SELECT Id, NomSociete FROM Clients WHERE ' . tf() . ' ORDER BY NomSociete'),
        'numeroPropose' => 'FAC-' . date('Y') . '-' . str_pad((string) $n, 4, '0', STR_PAD_LEFT),
    ];
}

function facture_edit(): void
{
    $facture = facture_charger((int) get('id'));
    render('facture/edit', [
        'facture' => $facture,
        'lignes' => q('SELECT * FROM LignesFactures WHERE FactureId = ? ORDER BY Id', [$facture['Id']]),
    ]);
}

function facture_ligne(): void
{
    $facture = facture_charger((int) post('factureId'));
    if ($facture['Statut'] !== 'Brouillon') {
        flash('danger', 'Une facture validée ne peut plus être modifiée.');
        redirect('facture/edit', ['id' => $facture['Id']]);
    }
    $designation = (string) post('designation', '');
    $quantite = montant(post('quantite'));
    $pu = montant(post('prixUnitaire'));
    if ($designation === '' || $quantite <= 0) {
        flash('danger', 'Indiquez une désignation et une quantité supérieure à zéro.');
        redirect('facture/edit', ['id' => $facture['Id']]);
    }
    $pdo = db();
    $pdo->beginTransaction();
    try {
        run(
            'INSERT INTO LignesFactures (TenantId, FactureId, Designation, Quantite, PrixUnitaire, TotalLigne) VALUES (?, ?, ?, ?, ?, ?)',
            [(int) $facture['TenantId'], $facture['Id'], $designation, $quantite, $pu, round($quantite * $pu, 2)]
        );
        facture_recalculer((int) $facture['Id']);
        $pdo->commit();
    } catch (Throwable $e) {
        $pdo->rollBack();
        throw $e;
    }
    redirect('facture/edit', ['id' => $facture['Id']]);
}

function facture_supprimerligne(): void
{
    $ligne = q1('SELECT * FROM LignesFactures WHERE Id = ? AND ' . tf(), [(int) post('id')]);
    if (!$ligne) {
        not_found('Ligne introuvable.');
    }
    $facture = facture_charger((int) $ligne['FactureId']);
    if ($facture['Statut'] !== 'Brouillon') {
        flash('danger', 'Une facture validée ne peut plus être modifiée.');
    } else {
        run('DELETE FROM LignesFactures WHERE Id = ?', [$ligne['Id']]);
        facture_recalculer((int) $facture['Id']);
    }
    redirect('facture/edit', ['id' => $facture['Id']]);
}

function facture_valider(): void
{
    $facture = facture_charger((int) post('factureId'));
    if (!qv('SELECT COUNT(*) FROM LignesFactures WHERE FactureId = ?', [$facture['Id']])) {
        flash('danger', 'Ajoutez au moins une ligne avant de valider la facture.');
    } else {
        run("UPDATE Factures SET Statut = 'Validée' WHERE Id = ?", [$facture['Id']]);
        flash('success', 'Facture validée.');
    }
    redirect('facture/edit', ['id' => $facture['Id']]);
}

function facture_print(): void
{
    $facture = facture_charger((int) get('id'));
    render('facture/print', [
        'facture' => $facture,
        'lignes' => q('SELECT * FROM LignesFactures WHERE FactureId = ? ORDER BY Id', [$facture['Id']]),
    ], false);
}
