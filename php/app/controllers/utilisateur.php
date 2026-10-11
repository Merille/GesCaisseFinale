<?php
// Utilisateurs. Seul le SuperAdmin choisit la société d'un utilisateur ;
// les autres profils créent des utilisateurs de leur propre société.

function utilisateur_profils(): array
{
    return is_super_admin() ? ['Admin', 'Caissier', 'SuperAdmin'] : ['Admin', 'Caissier'];
}

function utilisateur_charger(int $id): array
{
    $u = q1('SELECT * FROM Utilisateurs WHERE Id = ? AND ' . tf(), [$id]);
    if (!$u) {
        not_found('Utilisateur introuvable.');
    }
    return $u;
}

function utilisateur_index(): void
{
    $users = q(
        'SELECT u.*, t.Nom AS Societe FROM Utilisateurs u LEFT JOIN Tenants t ON t.Id = u.TenantId
         WHERE ' . tf('u') . ' ORDER BY u.NomUtilisateur'
    );
    render('utilisateur/index', ['users' => $users]);
}

/** Valeurs du formulaire, avec contrôle des droits. */
function utilisateur_valeurs(?array $existant): array
{
    $profil = (string) post('Profil', 'Caissier');
    if (!in_array($profil, utilisateur_profils(), true)) {
        $profil = 'Caissier';
    }
    if (is_super_admin()) {
        $tenant = $profil === 'SuperAdmin' ? null : int_or_null(post('TenantId'));
    } else {
        $tenant = $existant ? (int) $existant['TenantId'] : tenant_id();
    }
    return [
        'NomUtilisateur' => (string) post('NomUtilisateur', ''),
        'NomComplet' => (string) post('NomComplet', ''),
        'Profil' => $profil,
        'PeutValiderOperations' => post('PeutValiderOperations') ? 1 : 0,
        'TenantId' => $tenant,
        'MotPasse' => (string) post('MotPasse', ''),
    ];
}

function utilisateur_erreur(array $v, ?int $idExclu, bool $creation): ?string
{
    if ($v['NomUtilisateur'] === '' || $v['NomComplet'] === '') {
        return "Le nom d'utilisateur et le nom complet sont obligatoires.";
    }
    if ($creation && strlen($v['MotPasse']) < 3) {
        return 'Le mot de passe doit contenir au moins 3 caractères.';
    }
    if ($v['Profil'] !== 'SuperAdmin' && !$v['TenantId']) {
        return 'Choisissez la société de cet utilisateur.';
    }
    $doublon = qv('SELECT COUNT(*) FROM Utilisateurs WHERE NomUtilisateur = ? AND Id <> ?', [$v['NomUtilisateur'], $idExclu ?? 0]);
    return $doublon ? "Le nom d'utilisateur « {$v['NomUtilisateur']} » est déjà pris." : null;
}

function utilisateur_societes(): array
{
    return is_super_admin() ? q('SELECT Id, Nom FROM Tenants ORDER BY Nom') : [];
}

function utilisateur_create(): void
{
    $u = ['Profil' => 'Caissier', 'TenantId' => tenant_id() ?: null];
    if (is_post()) {
        $u = utilisateur_valeurs(null);
        if ($e = utilisateur_erreur($u, null, true)) {
            flash('danger', $e);
        } else {
            run(
                'INSERT INTO Utilisateurs (NomUtilisateur, MotPasse, NomComplet, Profil, PeutValiderOperations, TenantId) VALUES (?, ?, ?, ?, ?, ?)',
                [$u['NomUtilisateur'], hash_mdp($u['MotPasse']), $u['NomComplet'], $u['Profil'], $u['PeutValiderOperations'], $u['TenantId']]
            );
            flash('success', 'Utilisateur créé.');
            redirect('utilisateur/index');
        }
    }
    render('utilisateur/form', ['u' => $u, 'edition' => false, 'societes' => utilisateur_societes(), 'profils' => utilisateur_profils()]);
}

function utilisateur_edit(): void
{
    $existant = utilisateur_charger((int) get('id'));
    $u = $existant;
    if (is_post()) {
        $u = utilisateur_valeurs($existant) + ['Id' => $existant['Id']];
        if ($e = utilisateur_erreur($u, (int) $existant['Id'], false)) {
            flash('danger', $e);
        } else {
            run(
                'UPDATE Utilisateurs SET NomUtilisateur = ?, NomComplet = ?, Profil = ?, PeutValiderOperations = ?, TenantId = ? WHERE Id = ?',
                [$u['NomUtilisateur'], $u['NomComplet'], $u['Profil'], $u['PeutValiderOperations'], $u['TenantId'], $existant['Id']]
            );
            if ($u['MotPasse'] !== '') {
                run('UPDATE Utilisateurs SET MotPasse = ? WHERE Id = ?', [hash_mdp($u['MotPasse']), $existant['Id']]);
            }
            // L'utilisateur connecté modifie son propre compte : session à jour.
            if ((int) $existant['Id'] === user()['id']) {
                $_SESSION['user']['nom'] = $u['NomUtilisateur'];
                $_SESSION['user']['nomComplet'] = $u['NomComplet'];
                $_SESSION['user']['peutValider'] = (bool) $u['PeutValiderOperations'];
            }
            flash('success', 'Utilisateur modifié.');
            redirect('utilisateur/index');
        }
    }
    render('utilisateur/form', ['u' => $u, 'edition' => true, 'societes' => utilisateur_societes(), 'profils' => utilisateur_profils()]);
}

function utilisateur_delete(): void
{
    if (is_post()) {
        $u = utilisateur_charger((int) post('id'));
        if ((int) $u['Id'] === user()['id']) {
            flash('danger', 'Vous ne pouvez pas supprimer votre propre compte.');
        } elseif (qv('SELECT COUNT(*) FROM OperationsCaisses WHERE UtilisateurId = ?', [$u['Id']])) {
            flash('danger', 'Cet utilisateur a saisi des opérations : il ne peut pas être supprimé.');
        } else {
            run('DELETE FROM Utilisateurs WHERE Id = ?', [$u['Id']]);
            flash('success', 'Utilisateur supprimé.');
        }
    }
    redirect('utilisateur/index');
}
