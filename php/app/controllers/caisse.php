<?php
// Caisses : liste, création, modification, suppression, détail (journées) et impression.

// Boutique (affiché « Vente en détail ») : vente au comptoir. Restaurant / Bar : plan de salle,
// commandes sur les tables, bons de préparation envoyés en cuisine ou au bar.
// Laverie : vente au comptoir comme la vente en détail (prestations sans suivi de stock).
const CAISSE_TYPES = ['Boutique', 'Restaurant', 'Bar', 'Laverie'];

/** Badge et icône du type dans la liste des caisses. */
const CAISSE_TYPE_BADGES = ['Bar' => 'bg-info text-dark', 'Restaurant' => 'bg-warning text-dark', 'Laverie' => 'bg-primary'];
const CAISSE_TYPE_ICONES = ['Bar' => 'fa-martini-glass', 'Restaurant' => 'fa-utensils', 'Laverie' => 'fa-shirt'];

/** Libellé affiché du type de point de vente. */
function caisse_type_libelle(?string $type): string
{
    return ($type ?? 'Boutique') === 'Boutique' ? 'Vente en détail' : (string) $type;
}

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

/** Dépôts proposés sur la fiche caisse (dépôts actifs de la société). */
function caisse_depots(): array
{
    return q('SELECT Id, Code, Nom, ParDefaut FROM Depots WHERE Actif = 1 AND ' . tf() . ' ORDER BY ParDefaut DESC, Code');
}

/** Dépôt saisi sur la fiche caisse, s'il est actif et de la société ; sinon null (dépôt par défaut). */
function caisse_depot_saisi(): ?int
{
    $id = int_or_null(post('DepotId'));
    return $id && qv('SELECT Id FROM Depots WHERE Id = ? AND Actif = 1 AND ' . tf(), [$id]) ? $id : null;
}

function caisse_index(): void
{
    $caisses = q(
        'SELECT c.*, u.NomComplet AS Caissier
         FROM Caisses c LEFT JOIN Utilisateurs u ON u.Id = c.CashierDefault
         WHERE ' . tf('c') . ' ORDER BY c.ChkCode'
    );
    render('caisse/index', ['caisses' => $caisses, 'utilisateurs' => caisse_utilisateurs(), 'depots' => caisse_depots()]);
}

function caisse_valeurs(): array
{
    return [
        post('ChkCode', ''),
        post('ChkDescription', ''),
        post('StCode', ''),
        int_or_null(post('CashierDefault')),
        post('CompteComptable') ?: null,
        in_array(post('TypePointVente'), CAISSE_TYPES, true) ? post('TypePointVente') : 'Boutique',
        post('ImprimerBons') ? 1 : 0,
        caisse_depot_saisi(),
    ];
}

function caisse_create(): void
{
    if (is_post()) {
        [$code, $desc, $st, $caissier, $compte, $type, $bons, $depot] = caisse_valeurs();
        $tenant = tenant_insert();
        run(
            'INSERT INTO Caisses (ChkCode, ChkDescription, StCode, CashierDefault, CompteComptable, TypePointVente, ImprimerBons, DepotId, TenantId) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [$code, $desc, $st, $caissier, $compte, $type, $bons, $depot ?? depot_par_defaut($tenant), $tenant]
        );
        flash('success', 'Caisse créée.');
        redirect('caisse/index');
    }
    render('caisse/form', ['caisse' => [], 'utilisateurs' => caisse_utilisateurs(), 'depots' => caisse_depots()]);
}

function caisse_edit(): void
{
    $caisse = caisse_charger((int) get('id'));
    if (is_post()) {
        [$code, $desc, $st, $caissier, $compte, $type, $bons, $depot] = caisse_valeurs();
        run(
            'UPDATE Caisses SET ChkCode = ?, ChkDescription = ?, StCode = ?, CashierDefault = ?, CompteComptable = ?, TypePointVente = ?, ImprimerBons = ?, DepotId = ? WHERE ID = ?',
            [$code, $desc, $st, $caissier, $compte, $type, $bons, $depot ?? $caisse['DepotId'] ?? depot_par_defaut((int) $caisse['TenantId']), $caisse['ID']]
        );
        flash('success', 'Caisse modifiée.');
        redirect('caisse/index');
    }
    render('caisse/form', ['caisse' => $caisse, 'utilisateurs' => caisse_utilisateurs(), 'depots' => caisse_depots()]);
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
    render('caisse/details', ['caisse' => $caisse, 'journees' => $journees, 'soldeSuggere' => journee_solde_suggere((int) $caisse['ID'])]);
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
