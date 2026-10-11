<?php
// Caisses : liste, création, modification, suppression, détail (journées) et impression.

function caisse_charger(int $id): array
{
    $c = q1('SELECT * FROM Caisses WHERE ID = ? AND ' . tf(), [$id]);
    if (!$c) {
        not_found('Caisse introuvable.');
    }
    return $c;
}

function caisse_utilisateurs(): array
{
    return q('SELECT Id, NomComplet FROM Utilisateurs WHERE ' . tf() . ' ORDER BY NomComplet');
}

function caisse_index(): void
{
    $caisses = q(
        'SELECT c.*, u.NomComplet AS Caissier
         FROM Caisses c LEFT JOIN Utilisateurs u ON u.Id = c.CashierDefault
         WHERE ' . tf('c') . ' ORDER BY c.ChkCode'
    );
    render('caisse/index', ['caisses' => $caisses]);
}

function caisse_valeurs(): array
{
    return [
        post('ChkCode', ''),
        post('ChkDescription', ''),
        post('StCode', ''),
        int_or_null(post('CashierDefault')),
        post('CompteComptable') ?: null,
    ];
}

function caisse_create(): void
{
    if (is_post()) {
        [$code, $desc, $st, $caissier, $compte] = caisse_valeurs();
        run(
            'INSERT INTO Caisses (ChkCode, ChkDescription, StCode, CashierDefault, CompteComptable, TenantId) VALUES (?, ?, ?, ?, ?, ?)',
            [$code, $desc, $st, $caissier, $compte, tenant_insert()]
        );
        flash('success', 'Caisse créée.');
        redirect('caisse/index');
    }
    render('caisse/form', ['caisse' => [], 'utilisateurs' => caisse_utilisateurs()]);
}

function caisse_edit(): void
{
    $caisse = caisse_charger((int) get('id'));
    if (is_post()) {
        [$code, $desc, $st, $caissier, $compte] = caisse_valeurs();
        run(
            'UPDATE Caisses SET ChkCode = ?, ChkDescription = ?, StCode = ?, CashierDefault = ?, CompteComptable = ? WHERE ID = ?',
            [$code, $desc, $st, $caissier, $compte, $caisse['ID']]
        );
        flash('success', 'Caisse modifiée.');
        redirect('caisse/index');
    }
    render('caisse/form', ['caisse' => $caisse, 'utilisateurs' => caisse_utilisateurs()]);
}

function caisse_delete(): void
{
    if (is_post()) {
        $caisse = caisse_charger((int) post('id'));
        $nb = (int) qv('SELECT COUNT(*) FROM JourneesCaisses WHERE CaisseId = ?', [$caisse['ID']]);
        if ($nb > 0) {
            flash('danger', "Impossible de supprimer cette caisse : elle a $nb journée(s) enregistrée(s).");
        } else {
            run('DELETE FROM Caisses WHERE ID = ?', [$caisse['ID']]);
            flash('success', 'Caisse supprimée.');
        }
    }
    redirect('caisse/index');
}

function caisse_details(): void
{
    $caisse = caisse_charger((int) get('id'));
    $journees = q('SELECT * FROM JourneesCaisses WHERE CaisseId = ? ORDER BY DateOuverture DESC, Id DESC', [$caisse['ID']]);
    foreach ($journees as &$j) {
        $t = totaux_journee((int) $j['Id']);
        $j['Encaisse'] = $t['encaisse'];
        $j['Decaisse'] = $t['decaisse'];
        $j['Solde'] = (float) $j['SoldeInitial'] + $t['encaisse'] - $t['decaisse'];
    }
    render('caisse/details', ['caisse' => $caisse, 'journees' => $journees]);
}

function caisse_print(): void
{
    $caisses = q(
        'SELECT c.*, u.NomComplet AS Caissier
         FROM Caisses c LEFT JOIN Utilisateurs u ON u.Id = c.CashierDefault
         WHERE ' . tf('c') . ' ORDER BY c.ChkCode'
    );
    render('caisse/print', ['caisses' => $caisses], false);
}
