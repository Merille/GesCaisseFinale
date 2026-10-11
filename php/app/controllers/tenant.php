<?php
// Sociétés (multi-société) : réservé au SuperAdmin.

function tenant_charger(int $id): array
{
    $t = q1('SELECT * FROM Tenants WHERE Id = ?', [$id]);
    if (!$t) {
        not_found('Société introuvable.');
    }
    return $t;
}

function tenant_index(): void
{
    require_super_admin();
    render('tenant/index', ['tenants' => q('SELECT * FROM Tenants ORDER BY Nom')]);
}

function tenant_valeurs(): array
{
    $mode = post('ModeAcces') === 'Abonnement' ? 'Abonnement' : 'Licence';
    $exp = post('DateExpiration');
    return [
        (string) post('Nom', ''),
        (string) post('Code', ''),
        post('Actif') ? 1 : 0,
        $mode,
        $exp && DateTime::createFromFormat('!Y-m-d', $exp) ? $exp : null,
    ];
}

function tenant_create(): void
{
    require_super_admin();
    if (is_post()) {
        $v = tenant_valeurs();
        if ($v[0] === '' || $v[1] === '') {
            flash('danger', 'Le nom et le code sont obligatoires.');
        } else {
            run('INSERT INTO Tenants (Nom, Code, Actif, ModeAcces, DateExpiration, DateCreation) VALUES (?, ?, ?, ?, ?, NOW())', $v);
            flash('success', 'Société créée.');
            redirect('tenant/index');
        }
    }
    render('tenant/form', ['t' => ['Actif' => 1, 'ModeAcces' => 'Licence'], 'edition' => false]);
}

function tenant_edit(): void
{
    require_super_admin();
    $t = tenant_charger((int) get('id'));
    if (is_post()) {
        $v = tenant_valeurs();
        if ($v[0] === '' || $v[1] === '') {
            flash('danger', 'Le nom et le code sont obligatoires.');
        } else {
            run('UPDATE Tenants SET Nom = ?, Code = ?, Actif = ?, ModeAcces = ?, DateExpiration = ? WHERE Id = ?', [...$v, $t['Id']]);
            flash('success', 'Société modifiée.');
            redirect('tenant/index');
        }
    }
    render('tenant/form', ['t' => $t, 'edition' => true]);
}

/**
 * Renouvellement (+1 mois / +1 an) : à partir d'aujourd'hui si la licence
 * est déjà expirée, sinon à partir de la date d'expiration actuelle.
 */
function tenant_prolonger(): void
{
    require_super_admin();
    $t = tenant_charger((int) post('id'));
    $mois = max(1, min(120, (int) post('mois')));
    $aujourdhui = new DateTimeImmutable('today');
    $exp = $t['DateExpiration'] ? new DateTimeImmutable($t['DateExpiration']) : null;
    $depart = ($exp && $exp >= $aujourdhui) ? $exp : $aujourdhui;
    run('UPDATE Tenants SET DateExpiration = ? WHERE Id = ?', [$depart->modify("+$mois month")->format('Y-m-d'), $t['Id']]);
    flash('success', "Licence de « {$t['Nom']} » prolongée.");
    redirect('tenant/index');
}

/** Change la société consultée par le SuperAdmin (0 / vide = toutes). */
function tenant_consulter(): void
{
    require_super_admin();
    $id = (int) post('tenantId');
    if ($id > 0 && q1('SELECT Id FROM Tenants WHERE Id = ?', [$id])) {
        $_SESSION['consultation'] = $id;
    } else {
        unset($_SESSION['consultation']);
    }
    $retour = (string) post('retour', '');
    // Retour uniquement vers une page de l'application.
    if ($retour !== '' && preg_match('#^/[^/\\\\]#', $retour) && !str_contains($retour, '://')) {
        header('Location: ' . $retour);
        exit;
    }
    redirect('dashboard/index');
}
