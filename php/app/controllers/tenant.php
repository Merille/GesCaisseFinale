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

// Champs enregistrés : identification, accès et coordonnées (en-tête des tickets et factures).
const TENANT_CHAMPS = ['Nom', 'Code', 'Actif', 'ModeAcces', 'DateExpiration', 'Adresse', 'Ville', 'Pays', 'Email', 'Telephone', 'NIF'];

function tenant_valeurs(): array
{
    $exp = post('DateExpiration');
    $texte = fn(string $k) => ((string) post($k, '')) ?: null;
    return [
        'Nom' => (string) post('Nom', ''),
        'Code' => (string) post('Code', ''),
        'Actif' => post('Actif') ? 1 : 0,
        'ModeAcces' => post('ModeAcces') === 'Abonnement' ? 'Abonnement' : 'Licence',
        'DateExpiration' => $exp && DateTime::createFromFormat('!Y-m-d', $exp) ? $exp : null,
        'Adresse' => $texte('Adresse'),
        'Ville' => $texte('Ville'),
        'Pays' => $texte('Pays'),
        'Email' => $texte('Email'),
        'Telephone' => $texte('Telephone'),
        'NIF' => $texte('NIF'),
    ];
}

/** Message d'erreur, ou null si la société peut être enregistrée. */
function tenant_erreur(array $v, array|string|null $logo): ?string
{
    if ($v['Nom'] === '' || $v['Code'] === '') {
        return 'Le nom et le code sont obligatoires.';
    }
    if ($v['Email'] !== null && !filter_var($v['Email'], FILTER_VALIDATE_EMAIL)) {
        return "L'adresse e-mail n'est pas valide.";
    }
    return is_string($logo) ? $logo : null;
}

function tenant_create(): void
{
    require_super_admin();
    $t = ['Actif' => 1, 'ModeAcces' => 'Licence'];
    if (is_post()) {
        $t = tenant_valeurs();
        $logo = image_televersee('Logo');
        if ($e = tenant_erreur($t, $logo)) {
            flash('danger', $e);
        } else {
            db()->beginTransaction();
            try {
                $marques = implode(', ', array_fill(0, count(TENANT_CHAMPS), '?'));
                $id = run('INSERT INTO Tenants (' . implode(', ', TENANT_CHAMPS) . ", DateCreation) VALUES ($marques, NOW())", array_values($t));
                taxes_initiales($id);
                unites_initiales($id);
                enregistrer_image('logo', $id, $logo, false);
                db()->commit();
            } catch (Throwable $e) {
                db()->rollBack();
                throw $e;
            }
            flash('success', 'Société créée.');
            redirect('tenant/index');
        }
    }
    render('tenant/form', ['t' => $t, 'edition' => false]);
}

function tenant_edit(): void
{
    require_super_admin();
    $existant = tenant_charger((int) get('id'));
    $t = $existant;
    if (is_post()) {
        $t = tenant_valeurs() + ['Id' => $existant['Id'], 'LogoMaj' => $existant['LogoMaj']];
        $logo = image_televersee('Logo');
        if ($e = tenant_erreur($t, $logo)) {
            flash('danger', $e);
        } else {
            $set = implode(', ', array_map(fn($c) => "$c = ?", TENANT_CHAMPS));
            run("UPDATE Tenants SET $set WHERE Id = ?", [...array_map(fn($c) => $t[$c], TENANT_CHAMPS), $existant['Id']]);
            enregistrer_image('logo', (int) $existant['Id'], $logo, (bool) post('SupprimerLogo'));
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
