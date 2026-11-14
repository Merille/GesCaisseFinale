<?php
// Connexion, déconnexion et page « société suspendue ».

function auth_login(): void
{
    $erreur = null;

    if (is_post()) {
        $nom = (string) post('username', '');
        $mdp = (string) post('password', '');

        $ip = adresse_client();
        $attente = connexion_bloquee($nom, $ip);
        if ($attente > 0) {
            render('auth/login', ['erreur' => 'Trop de tentatives de connexion. Réessayez dans ' . $attente . ' minute' . ($attente > 1 ? 's' : '') . '.'], false);
            return;
        }

        // Le nom d'utilisateur est unique pour toutes les sociétés.
        $u = q1(
            'SELECT u.*, t.Nom AS TenantNom
             FROM Utilisateurs u LEFT JOIN Tenants t ON t.Id = u.TenantId
             WHERE u.NomUtilisateur = ?',
            [$nom]
        );
        // Utilisateur inconnu : même calcul, pour ne pas révéler par le temps de réponse si le compte existe.
        $ok = verifier_mdp($mdp, $u['MotPasse'] ?? 'pbkdf2_sha512$' . MDP_ITERATIONS . '$AAAAAAAAAAAAAAAAAAAAAA==$AAAA');

        if ($u && $ok) {
            connexion_reussie($nom);
            // Ancien format de mot de passe : remplacé par le format actuel.
            if (mdp_a_mettre_a_niveau($u['MotPasse'])) {
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
            redirect('accueil');
        }
        connexion_echec($nom, $ip);
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

/** Profil sans aucun droit : page d'information (avec lien de déconnexion). */
function auth_aucunacces(): void
{
    require_login();
    render('auth/aucunacces', [], false);
}
