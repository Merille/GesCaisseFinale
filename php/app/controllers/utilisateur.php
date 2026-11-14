<?php
// Utilisateurs. Seul le SuperAdmin choisit la société d'un utilisateur ;
// les autres profils créent des utilisateurs de leur propre société.

/**
 * Profils proposés : Administrateur (tous les droits), les profils de la société (Paramètres › Profils)
 * et, pour le SuperAdmin, SuperAdmin et les profils de toutes les sociétés. [valeur, libellé, société]
 */
function utilisateur_profils(): array
{
    $liste = [['Admin', 'Administrateur (tous les droits)', null]];
    $sql = 'SELECT p.Id, p.Nom, p.TenantId, t.Nom AS Societe FROM Profils p JOIN Tenants t ON t.Id = p.TenantId WHERE ' . tf('p') . ' ORDER BY t.Nom, p.Nom';
    foreach (q($sql) as $p) {
        $liste[] = ['p' . $p['Id'], $p['Nom'] . (is_super_admin() ? ' (' . $p['Societe'] . ')' : ''), (int) $p['TenantId']];
    }
    if (is_super_admin()) {
        $liste[] = ['SuperAdmin', 'SuperAdmin', null];
    }
    return $liste;
}

/** Valeur du champ Profil pour un utilisateur : « Admin », « SuperAdmin » ou « p<Id du profil> ». */
function utilisateur_valeur_profil(array $u): string
{
    if (!empty($u['ProfilId'])) {
        return 'p' . $u['ProfilId'];
    }
    $profil = (string) ($u['Profil'] ?? '');
    if ($profil !== '' && !in_array($profil, ['Admin', 'SuperAdmin'], true) && !empty($u['TenantId'])) {
        // Ancien compte sans profil rattaché : profil de même nom de la société.
        $id = qv('SELECT Id FROM Profils WHERE TenantId = ? AND Nom = ?', [(int) $u['TenantId'], $profil]);
        return $id ? 'p' . $id : '';
    }
    return $profil;
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
    render('utilisateur/index', ['users' => $users, 'societes' => utilisateur_societes(), 'profils' => utilisateur_profils()]);
}

/** Valeurs du formulaire, avec contrôle des droits. */
function utilisateur_valeurs(?array $existant): array
{
    $choix = (string) post('Profil', '');
    $profilId = null;
    $profil = '';
    if (in_array($choix, ['Admin', 'SuperAdmin'], true) && ($choix === 'Admin' || is_super_admin())) {
        $profil = $choix;
    } elseif (preg_match('/^p(\d+)$/', $choix, $m)) {
        $ligne = q1('SELECT Id, Nom, TenantId FROM Profils WHERE Id = ? AND ' . tf(), [(int) $m[1]]);
        if ($ligne) {
            $profilId = (int) $ligne['Id'];
            $profil = $ligne['Nom'];
        }
    }
    if (is_super_admin()) {
        $tenant = $profil === 'SuperAdmin' ? null : int_or_null(post('TenantId'));
    } else {
        $tenant = $existant ? (int) $existant['TenantId'] : tenant_id();
    }
    // SuperAdmin : la société de l'utilisateur est celle du profil choisi, si elle n'est pas indiquée.
    if ($profilId && is_super_admin() && !$tenant) {
        $tenant = (int) qv('SELECT TenantId FROM Profils WHERE Id = ?', [$profilId]);
    }
    // Profil d'une autre société que celle de l'utilisateur : refusé.
    if ($profilId && (int) qv('SELECT TenantId FROM Profils WHERE Id = ?', [$profilId]) !== (int) $tenant) {
        $profilId = null;
        $profil = '';
    }
    return [
        'NomUtilisateur' => (string) post('NomUtilisateur', ''),
        'NomComplet' => (string) post('NomComplet', ''),
        'Profil' => $profil,
        'ProfilId' => $profilId,
        'PeutValiderOperations' => post('PeutValiderOperations') ? 1 : 0,
        // Remises (article et globale) : droit et pourcentage maximal facultatif (vide = sans limite).
        'PeutRemise' => post('PeutRemise') ? 1 : 0,
        'RemiseMax' => post('PeutRemise') && trim((string) post('RemiseMax', '')) !== '' ? (float) str_replace(',', '.', (string) post('RemiseMax')) : null,
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
    if ($v['RemiseMax'] !== null && ($v['RemiseMax'] <= 0 || $v['RemiseMax'] > 100)) {
        return 'La remise maximale doit être comprise entre 0 et 100 % (laissez vide pour ne pas limiter).';
    }
    if ($v['Profil'] === '') {
        return 'Choisissez un profil (de la société de cet utilisateur).';
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
    $u = ['Profil' => '', 'TenantId' => tenant_id() ?: null];
    if (is_post()) {
        $u = utilisateur_valeurs(null);
        if ($e = utilisateur_erreur($u, null, true)) {
            flash('danger', $e);
        } else {
            run(
                'INSERT INTO Utilisateurs (NomUtilisateur, MotPasse, NomComplet, Profil, ProfilId, PeutValiderOperations, PeutRemise, RemiseMax, TenantId) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [$u['NomUtilisateur'], hash_mdp($u['MotPasse']), $u['NomComplet'], $u['Profil'], $u['ProfilId'], $u['PeutValiderOperations'], $u['PeutRemise'], $u['RemiseMax'], $u['TenantId']]
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
        $e = utilisateur_erreur($u, (int) $existant['Id'], false);
        // L'administrateur ne peut pas retirer son propre profil d'administrateur (il perdrait l'accès à cette page).
        if (!$e && (int) $existant['Id'] === user()['id'] && !in_array($u['Profil'], ['Admin', 'SuperAdmin'], true)) {
            $e = 'Vous ne pouvez pas retirer votre propre profil d\'administrateur.';
        }
        if ($e) {
            flash('danger', $e);
        } else {
            run(
                'UPDATE Utilisateurs SET NomUtilisateur = ?, NomComplet = ?, Profil = ?, ProfilId = ?, PeutValiderOperations = ?, PeutRemise = ?, RemiseMax = ?, TenantId = ? WHERE Id = ?',
                [$u['NomUtilisateur'], $u['NomComplet'], $u['Profil'], $u['ProfilId'], $u['PeutValiderOperations'], $u['PeutRemise'], $u['RemiseMax'], $u['TenantId'], $existant['Id']]
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
