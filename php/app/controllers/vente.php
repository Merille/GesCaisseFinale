<?php
// Ventes du point de vente : liste, détail, réimpression du ticket, facture depuis
// une vente, retour / remboursement et annulation.
// Retours et annulations : administrateurs et utilisateurs autorisés à valider.

function vente_peut_rembourser(): bool
{
    return is_admin() || peut_valider();
}

function vente_charger(int $id): array
{
    $v = q1(
        'SELECT cmd.*, j.Statut AS StatutJournee, j.CaisseId, j.NumeroJournee, c.ChkCode, c.ChkDescription,
                u.NomComplet AS Vendeur, cl.NomSociete AS Client, f.Numero AS NumeroFacture,
                o.Numero AS NumeroOrigine
         FROM CommandesPos cmd
         JOIN JourneesCaisses j ON j.Id = cmd.JourneeCaisseId
         JOIN Caisses c ON c.ID = j.CaisseId
         LEFT JOIN Utilisateurs u ON u.Id = cmd.UtilisateurId
         LEFT JOIN Clients cl ON cl.Id = cmd.ClientId
         LEFT JOIN Factures f ON f.Id = cmd.FactureId
         LEFT JOIN CommandesPos o ON o.Id = cmd.CommandeOrigineId
         WHERE cmd.Id = ? AND ' . tf('cmd'),
        [$id]
    );
    if (!$v) {
        not_found('Vente introuvable.');
    }
    return $v;
}

/** Lignes d'une vente avec la quantité déjà retournée. */
function vente_lignes(int $id): array
{
    return q(
        'SELECT l.*, COALESCE((SELECT -SUM(r.Quantite) FROM LignesCommandePos r
                               JOIN CommandesPos rc ON rc.Id = r.CommandePosId AND rc.Statut <> \'Annulée\'
                               WHERE r.LigneOrigineId = l.Id), 0) AS QteRetournee
         FROM LignesCommandePos l WHERE l.CommandePosId = ? ORDER BY l.Id',
        [$id]
    );
}

function vente_index(): void
{
    $journee = (int) get('journee', 0);
    $search = (string) get('search', '');
    $where = tf('cmd');
    $params = [];
    if ($journee > 0) {
        $where .= ' AND cmd.JourneeCaisseId = ?';
        $params[] = $journee;
    }
    if ($search !== '') {
        $where .= ' AND (cmd.Numero LIKE ? OR cl.NomSociete LIKE ?)';
        array_push($params, "%$search%", "%$search%");
    }
    $from = ' FROM CommandesPos cmd
              JOIN JourneesCaisses j ON j.Id = cmd.JourneeCaisseId
              JOIN Caisses c ON c.ID = j.CaisseId
              LEFT JOIN Clients cl ON cl.Id = cmd.ClientId
              LEFT JOIN Utilisateurs u ON u.Id = cmd.UtilisateurId
              WHERE ' . $where;
    $pagination = paginer((int) qv('SELECT COUNT(*)' . $from, $params), 'vente/index',
        ['journee' => $journee ?: null, 'search' => $search], 'Ventes');
    $ventes = q(
        'SELECT cmd.*, c.ChkCode, cl.NomSociete AS Client, u.NomComplet AS Vendeur' . $from
        . ' ORDER BY cmd.DateCommande DESC, cmd.Id DESC' . $pagination['limite'],
        $params
    );
    $infoJournee = $journee ? q1(
        'SELECT j.*, c.ChkCode FROM JourneesCaisses j JOIN Caisses c ON c.ID = j.CaisseId WHERE j.Id = ? AND ' . tf('j'), [$journee]
    ) : null;
    render('vente/index', [
        'ventes' => $ventes, 'pagination' => $pagination, 'search' => $search,
        'journee' => $journee, 'infoJournee' => $infoJournee,
    ]);
}

function vente_details(): void
{
    $vente = vente_charger((int) get('id'));
    $lignes = vente_lignes((int) $vente['Id']);
    $restant = array_sum(array_map(fn($l) => (float) $l['Quantite'] - (float) $l['QteRetournee'], $lignes));
    render('vente/details', [
        'vente' => $vente,
        'lignes' => $lignes,
        'paiements' => q('SELECT * FROM PaiementsPos WHERE CommandePosId = ? ORDER BY Id', [$vente['Id']]),
        'retours' => q("SELECT * FROM CommandesPos WHERE CommandeOrigineId = ? AND Statut <> 'Annulée' ORDER BY Id", [$vente['Id']]),
        'restant' => $restant,
        'clients' => $vente['ClientId'] ? [] : q('SELECT Id, NomSociete FROM Clients WHERE TenantId = ? ORDER BY NomSociete', [$vente['TenantId']]),
        'journeesOuvertes' => q(
            "SELECT j.Id, j.CaisseId, c.ChkCode, j.DateJournee FROM JourneesCaisses j JOIN Caisses c ON c.ID = j.CaisseId
             WHERE j.Statut = 'Ouverte' AND j.TenantId = ? ORDER BY (j.CaisseId = ?) DESC, j.DateJournee DESC",
            [$vente['TenantId'], $vente['CaisseId']]
        ),
        'modes' => q('SELECT Id, Code, Libelle FROM ModesPaiement WHERE Actif = 1 AND TenantId = ? ORDER BY Libelle', [$vente['TenantId']]),
        'peutRembourser' => vente_peut_rembourser(),
    ]);
}

/** Facture validée créée depuis une vente (un seul taux de TVA par facture). */
function vente_facture(): void
{
    $vente = vente_charger((int) post('id'));
    $retour = fn(string $type, string $msg) => [flash($type, $msg), redirect('vente/details', ['id' => $vente['Id']])];
    if ($vente['CommandeOrigineId'] || $vente['Statut'] !== 'Payée') {
        $retour('danger', 'Seule une vente payée, sans retour, peut être facturée.');
    }
    if ($vente['FactureId']) {
        $retour('warning', 'Cette vente est déjà facturée (' . $vente['NumeroFacture'] . ').');
    }
    $client = (int) ($vente['ClientId'] ?: post('clientId'));
    if (!q1('SELECT Id FROM Clients WHERE Id = ? AND TenantId = ?', [$client, $vente['TenantId']])) {
        $retour('danger', 'Choisissez le client à facturer.');
    }
    $lignes = vente_lignes((int) $vente['Id']);
    $taux = array_unique(array_map(fn($l) => (string) (float) $l['TauxTVA'], $lignes));
    if (count($taux) > 1) {
        $retour('danger', 'Les articles ont des taux de TVA différents : une facture GesCaisse ne porte qu\'un seul taux.');
    }
    $t = (float) reset($taux);

    db()->beginTransaction();
    try {
        $n = (int) qv('SELECT COUNT(*) FROM Factures WHERE YEAR(DateFacture) = YEAR(CURDATE()) AND TenantId = ?', [$vente['TenantId']]) + 1;
        $numero = 'FAC-' . date('Y') . '-' . str_pad((string) $n, 4, '0', STR_PAD_LEFT);
        $factureId = run(
            "INSERT INTO Factures (TenantId, Numero, DateFacture, ClientId, TauxTVA, Statut) VALUES (?, ?, NOW(), ?, ?, 'Brouillon')",
            [$vente['TenantId'], $numero, $client, $t]
        );
        // Prix HT déduits du TTC payé (remise comprise).
        foreach ($lignes as $l) {
            $ht = round((float) $l['TotalTTC'] / (1 + $t / 100), 2);
            $designation = $l['Libelle'] . ((float) $l['Remise'] > 0 ? ' (remise ' . quantite_fr($l['Remise']) . ' %)' : '');
            run(
                'INSERT INTO LignesFactures (TenantId, FactureId, Designation, Quantite, PrixUnitaire, TotalLigne) VALUES (?, ?, ?, ?, ?, ?)',
                [$vente['TenantId'], $factureId, $designation, $l['Quantite'], round($ht / (float) $l['Quantite'], 2), $ht]
            );
        }
        $ht = (float) qv('SELECT COALESCE(SUM(TotalLigne), 0) FROM LignesFactures WHERE FactureId = ?', [$factureId]);
        $tva = round($ht * $t / 100, 2);
        run(
            "UPDATE Factures SET MontantHT = ?, MontantTVA = ?, MontantTTC = ?, MontantPaye = ?, Statut = 'Validée' WHERE Id = ?",
            [$ht, $tva, $ht + $tva, $ht + $tva, $factureId]
        );
        run('UPDATE CommandesPos SET FactureId = ?, ClientId = ? WHERE Id = ?', [$factureId, $client, $vente['Id']]);
        db()->commit();
    } catch (Throwable $e) {
        db()->rollBack();
        throw $e;
    }
    flash('success', "Facture $numero créée et validée.");
    redirect('facture/edit', ['id' => $factureId]);
}

/**
 * Retour / remboursement : quantités retournées par ligne, montant remboursé au
 * prorata de la ligne (remise comprise), décaissement validé dans une journée
 * ouverte, remise en stock.
 */
function vente_retour(): void
{
    $vente = vente_charger((int) post('id'));
    $echec = function (string $msg) use ($vente): never {
        flash('danger', $msg);
        redirect('vente/details', ['id' => $vente['Id']]);
    };
    if (!vente_peut_rembourser()) {
        $echec("Vous n'avez pas le droit d'enregistrer un retour.");
    }
    if ($vente['CommandeOrigineId'] || !in_array($vente['Statut'], ['Payée', 'Remboursée en partie'], true)) {
        $echec('Cette vente ne peut pas faire l\'objet d\'un retour.');
    }
    $cle = 'R-' . substr(preg_replace('/[^A-Za-z0-9-]/', '', (string) post('cle')), 0, 60);
    if (q1('SELECT Id FROM CommandesPos WHERE TenantId = ? AND CleClient = ?', [$vente['TenantId'], $cle])) {
        redirect('vente/details', ['id' => $vente['Id']]);   // formulaire envoyé deux fois
    }

    $journee = q1(
        "SELECT j.*, c.ChkCode FROM JourneesCaisses j JOIN Caisses c ON c.ID = j.CaisseId
         WHERE j.Id = ? AND j.TenantId = ? AND j.Statut = 'Ouverte'",
        [(int) post('journeeId'), $vente['TenantId']]
    );
    if (!$journee) {
        $echec('Choisissez une journée de caisse ouverte pour enregistrer le remboursement.');
    }
    $mode = q1('SELECT * FROM ModesPaiement WHERE Id = ? AND TenantId = ? AND Actif = 1', [(int) post('modeId'), $vente['TenantId']]);
    if (!$mode) {
        $echec('Choisissez le mode de remboursement.');
    }

    $quantites = (array) ($_POST['qte'] ?? []);
    $retours = [];
    $ttc = $tva = 0.0;
    foreach (vente_lignes((int) $vente['Id']) as $l) {
        $q = round(montant($quantites[$l['Id']] ?? 0), 2);
        if ($q <= 0) {
            continue;
        }
        $reste = (float) $l['Quantite'] - (float) $l['QteRetournee'];
        if ($q > $reste + 0.001) {
            $echec('Quantité retournée trop élevée pour « ' . $l['Libelle'] . ' » (' . quantite_fr($reste) . ' au plus).');
        }
        $total = round((float) $l['TotalTTC'] * $q / (float) $l['Quantite']);
        $ttc += $total;
        $tva += $total - $total / (1 + (float) $l['TauxTVA'] / 100);
        $retours[] = ['ligne' => $l, 'qte' => $q, 'total' => $total];
    }
    if (!$retours) {
        $echec('Indiquez au moins une quantité à retourner.');
    }
    $tva = round($tva);
    $motif = trim((string) post('motif', '')) ?: null;

    db()->beginTransaction();
    try {
        q('SELECT Id FROM JourneesCaisses WHERE Id = ? FOR UPDATE', [$journee['Id']]);
        $rang = (int) qv('SELECT COUNT(*) FROM CommandesPos WHERE JourneeCaisseId = ?', [$journee['Id']]) + 1;
        $numero = sprintf('RET-%s-%s-%04d', $journee['ChkCode'], date('Ymd', strtotime($journee['DateJournee'])), $rang);
        $retourId = run(
            "INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande,
                TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut, CommandeOrigineId, Motif)
             VALUES (?, ?, ?, ?, ?, ?, NOW(), ?, ?, ?, ?, 0, 'Retour', ?, ?)",
            [$vente['TenantId'], $numero, $cle, $journee['Id'], $vente['ClientId'], user()['id'],
             -($ttc - $tva), -$tva, -$ttc, -$ttc, $vente['Id'], $motif]
        );
        foreach ($retours as $r) {
            $l = $r['ligne'];
            run(
                'INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC, LigneOrigineId)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [$vente['TenantId'], $retourId, $l['ProduitId'], $l['Libelle'], -$r['qte'], $l['PrixUnitaire'], $l['Remise'], $l['TauxTVA'], -$r['total'], $l['Id']]
            );
            if ($l['ProduitId']) {
                run('UPDATE Produits SET StockActuel = StockActuel + ? WHERE Id = ? AND SuiviStock = 1', [$r['qte'], $l['ProduitId']]);
            }
        }
        $motifId = qv("SELECT ID FROM Motifs WHERE LibelleMotif = 'Retour POS' AND TenantId = ?", [$vente['TenantId']])
            ?: run("INSERT INTO Motifs (LibelleMotif, TypeModif, TenantId) VALUES ('Retour POS', 'Client', ?)", [$vente['TenantId']]);
        $operation = run(
            "INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle,
                ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur, Observation)
             VALUES (?, ?, NOW(), 'Décaissement', ?, ?, ?, ?, ?, ?, 1, 'Validé', 'Point de vente', ?)",
            [$vente['TenantId'], $journee['Id'], $ttc, "Retour POS $numero (vente {$vente['Numero']})", $vente['ClientId'],
             $motifId, $mode['Id'], user()['id'], $motif]
        );
        run(
            'INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
             VALUES (?, ?, ?, ?, ?, ?, ?)',
            [$vente['TenantId'], $retourId, $mode['Id'], (string) $mode['Libelle'], -$ttc, -$ttc, $operation]
        );
        // Statut de la vente d'origine : remboursée en totalité ou en partie.
        $restant = array_sum(array_map(fn($l) => (float) $l['Quantite'] - (float) $l['QteRetournee'], vente_lignes((int) $vente['Id'])));
        run('UPDATE CommandesPos SET Statut = ? WHERE Id = ?', [$restant > 0.001 ? 'Remboursée en partie' : 'Remboursée', $vente['Id']]);
        db()->commit();
    } catch (Throwable $e) {
        db()->rollBack();
        throw $e;
    }
    flash('success', "Retour $numero enregistré : " . fcfa($ttc) . ' FCFA à rembourser (' . $mode['Libelle'] . ').');
    redirect('vente/details', ['id' => $retourId]);
}

/**
 * Annulation d'une vente du jour : ses encaissements passent « Rejeté » (donc hors
 * des totaux) et le stock est remis. Journée ouverte, sans retour ni facture.
 */
function vente_annuler(): void
{
    $vente = vente_charger((int) post('id'));
    $echec = function (string $msg) use ($vente): never {
        flash('danger', $msg);
        redirect('vente/details', ['id' => $vente['Id']]);
    };
    if (!vente_peut_rembourser()) {
        $echec("Vous n'avez pas le droit d'annuler une vente.");
    }
    if ($vente['CommandeOrigineId'] || $vente['Statut'] !== 'Payée' || $vente['FactureId']) {
        $echec('Seule une vente payée, sans retour ni facture, peut être annulée.');
    }
    if ($vente['StatutJournee'] !== 'Ouverte') {
        $echec('La journée de cette vente est clôturée : faites plutôt un retour.');
    }
    $motif = trim((string) post('motif', '')) ?: null;
    db()->beginTransaction();
    try {
        run("UPDATE CommandesPos SET Statut = 'Annulée', Motif = ? WHERE Id = ?", [$motif, $vente['Id']]);
        run(
            "UPDATE OperationsCaisses SET StatutValidation = 'Rejeté', Valideur = ?, Observation = ?
             WHERE Id IN (SELECT OperationCaisseId FROM PaiementsPos WHERE CommandePosId = ? AND OperationCaisseId IS NOT NULL)",
            [user()['nomComplet'] ?: user()['nom'], 'Vente annulée' . ($motif ? ' : ' . $motif : ''), $vente['Id']]
        );
        foreach (vente_lignes((int) $vente['Id']) as $l) {
            if ($l['ProduitId']) {
                run('UPDATE Produits SET StockActuel = StockActuel + ? WHERE Id = ? AND SuiviStock = 1', [$l['Quantite'], $l['ProduitId']]);
            }
        }
        db()->commit();
    } catch (Throwable $e) {
        db()->rollBack();
        throw $e;
    }
    flash('success', 'Vente ' . $vente['Numero'] . ' annulée : ses encaissements sont rejetés et le stock est remis.');
    redirect('vente/details', ['id' => $vente['Id']]);
}
