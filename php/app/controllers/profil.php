<?php
// Profils et droits d'accès (administrateurs) : l'administrateur crée des profils (Caissier, Serveur,
// Gérant…) et coche les droits de chacun ; il attribue ensuite un profil à chaque utilisateur
// (Paramètres › Utilisateurs). Le profil Administrateur a toujours tous les droits.

const PROFILS_RESERVES = ['admin', 'administrateur', 'superadmin'];

function profil_index(): void
{
    $profils = q('SELECT p.*, t.Nom AS Societe, (SELECT COUNT(*) FROM Utilisateurs u WHERE u.ProfilId = p.Id) AS Utilisateurs
                  FROM Profils p JOIN Tenants t ON t.Id = p.TenantId WHERE ' . tf('p') . ' ORDER BY t.Nom, p.Nom');
    $admins = (int) qv("SELECT COUNT(*) FROM Utilisateurs WHERE Profil = 'Admin' AND " . tf());
    render('profil/index', ['profils' => $profils, 'admins' => $admins, 'catalogue' => droits_catalogue()]);
}

function profil_save(): void
{
    if (!is_post()) {
        redirect('profil/index');
    }
    $id = (int) post('Id', 0);
    $nom = mb_substr((string) post('Nom', ''), 0, 50);
    $description = mb_substr((string) post('Description', ''), 0, 200);
    $codes = array_keys(droits_catalogue_plat());
    $droits = array_values(array_intersect($codes, (array) ($_POST['Droits'] ?? [])));
    $existant = $id ? q1('SELECT * FROM Profils WHERE Id = ? AND ' . tf(), [$id]) : null;
    if ($id && !$existant) {
        not_found('Profil introuvable.');
    }
    $tenant = $existant ? (int) $existant['TenantId'] : tenant_id();
    if ($nom === '') {
        flash('danger', 'Le nom du profil est obligatoire.');
    } elseif (in_array(mb_strtolower($nom), PROFILS_RESERVES, true)) {
        flash('danger', 'Ce nom est réservé : choisissez un autre nom de profil.');
    } elseif (!$tenant) {
        flash('danger', 'Consultez d\'abord une société pour lui créer des profils.');
    } elseif (qv('SELECT COUNT(*) FROM Profils WHERE TenantId = ? AND Nom = ? AND Id <> ?', [$tenant, $nom, $id])) {
        flash('danger', "Le profil « $nom » existe déjà.");
    } elseif ($existant) {
        run('UPDATE Profils SET Nom = ?, Description = ?, Droits = ? WHERE Id = ?', [$nom, $description ?: null, implode(',', $droits), $id]);
        // Le nom du profil est affiché sur les comptes des utilisateurs.
        run('UPDATE Utilisateurs SET Profil = ? WHERE ProfilId = ?', [$nom, $id]);
        flash('success', 'Profil modifié.');
    } else {
        run('INSERT INTO Profils (TenantId, Nom, Description, Droits) VALUES (?, ?, ?, ?)', [$tenant, $nom, $description ?: null, implode(',', $droits)]);
        flash('success', 'Profil créé.');
    }
    redirect('profil/index');
}

function profil_delete(): void
{
    if (is_post()) {
        $p = q1('SELECT * FROM Profils WHERE Id = ? AND ' . tf(), [(int) post('id')]);
        if (!$p) {
            not_found('Profil introuvable.');
        }
        $n = (int) qv('SELECT COUNT(*) FROM Utilisateurs WHERE ProfilId = ?', [$p['Id']]);
        if ($n) {
            flash('danger', "Ce profil est attribué à $n utilisateur" . ($n > 1 ? 's' : '') . ' : changez d\'abord leur profil.');
        } else {
            run('DELETE FROM Profils WHERE Id = ?', [$p['Id']]);
            flash('success', 'Profil supprimé.');
        }
    }
    redirect('profil/index');
}
