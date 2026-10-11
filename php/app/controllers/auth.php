<?php
// Connexion, déconnexion et page « société suspendue ».

function auth_login(): void
{
    $erreur = null;

    if (is_post()) {
        $nom = (string) post('username', '');
        $mdp = (string) post('password', '');

        // Le nom d'utilisateur est unique pour toutes les sociétés.
        $u = q1(
            'SELECT u.*, t.Nom AS TenantNom
             FROM Utilisateurs u LEFT JOIN Tenants t ON t.Id = u.TenantId
             WHERE u.NomUtilisateur = ?',
            [$nom]
        );

        if ($u && verifier_mdp($mdp, $u['MotPasse'])) {
            // Ancien format de mot de passe (.NET) : converti en bcrypt.
            if (!str_starts_with($u['MotPasse'], '$')) {
                run('UPDATE Utilisateurs SET MotPasse = ? WHERE Id = ?', [hash_mdp($mdp), $u['Id']]);
            }
            session_regenerate_id(true);
            $_SESSION['user'] = [
                'id' => (int) $u['Id'],
                'nom' => $u['NomUtilisateur'],
                'nomComplet' => $u['NomComplet'],
                'profil' => $u['Profil'],
                'tenantId' => (int) ($u['TenantId'] ?? 0),
                'tenantNom' => $u['TenantNom'] ?? '',
                'peutValider' => (bool) $u['PeutValiderOperations'],
            ];
            unset($_SESSION['consultation']);
            redirect('dashboard/index');
        }
        $erreur = 'Utilisateur ou mot de passe incorrect';
    }

    render('auth/login', ['erreur' => $erreur], false);
}

function auth_logout(): void
{
    $_SESSION = [];
    session_destroy();
    redirect('auth/login');
}

function auth_suspendue(): void
{
    render('auth/suspendue', [], false);
}
