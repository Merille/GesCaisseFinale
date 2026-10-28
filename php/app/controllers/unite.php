<?php
// Unités de vente des produits (Kg, Litre, Carton…). Produits.Unite garde le nom de l'unité :
// renommer une unité met à jour ses produits ; une unité désactivée n'est plus proposée
// sur la fiche produit mais reste sur les produits qui l'utilisent.

function unite_index(): void
{
    render('unite/index', ['unites' => q(
        "SELECT u.*, (SELECT COUNT(*) FROM Produits p WHERE p.TenantId = u.TenantId AND p.Unite = u.Nom) AS NbProduits
         FROM Unites u WHERE " . tf('u') . " ORDER BY u.Actif DESC, u.Nom = 'Unité' DESC, u.Nom"
    )]);
}

function unite_charger(int $id): array
{
    $u = q1('SELECT * FROM Unites WHERE Id = ? AND ' . tf(), [$id]);
    if (!$u) {
        not_found('Unité introuvable.');
    }
    return $u;
}

/** Création (sans Id) ou modification (avec Id) ; un nouveau nom est reporté sur les produits. */
function unite_save(): void
{
    if (is_post()) {
        $nom = mb_substr(trim((string) post('Nom', '')), 0, 20);
        $libelle = mb_substr(trim((string) post('Libelle', '')), 0, 100) ?: null;
        $id = int_or_null(post('Id'));
        if ($nom === '') {
            flash('danger', "Le nom de l'unité est obligatoire.");
            redirect('unite/index');
        }
        $tenant = $id ? (int) unite_charger($id)['TenantId'] : tenant_insert();
        if (qv('SELECT COUNT(*) FROM Unites WHERE Nom = ? AND Id <> ? AND TenantId = ?', [$nom, (int) $id, $tenant])) {
            flash('danger', "L'unité « $nom » existe déjà.");
            redirect('unite/index');
        }
        db()->beginTransaction();
        try {
            if ($id) {
                $ancien = unite_charger($id)['Nom'];
                run('UPDATE Unites SET Nom = ?, Libelle = ?, Actif = ? WHERE Id = ?', [$nom, $libelle, post('Actif') ? 1 : 0, $id]);
                $nb = 0;
                if ($ancien !== $nom) {
                    $nb = (int) qv('SELECT COUNT(*) FROM Produits WHERE Unite = ? AND TenantId = ?', [$ancien, $tenant]);
                    run('UPDATE Produits SET Unite = ? WHERE Unite = ? AND TenantId = ?', [$nom, $ancien, $tenant]);
                }
                flash('success', $nb ? "Unité modifiée ; $nb produit(s) utilisent maintenant « $nom »." : 'Unité modifiée.');
            } else {
                run('INSERT INTO Unites (TenantId, Nom, Libelle, Actif) VALUES (?, ?, ?, ?)', [$tenant, $nom, $libelle, post('Actif') ? 1 : 0]);
                flash('success', 'Unité créée.');
            }
            db()->commit();
        } catch (Throwable $e) {
            db()->rollBack();
            throw $e;
        }
    }
    redirect('unite/index');
}

/** Active ou désactive l'unité (elle n'est plus proposée sur la fiche produit). */
function unite_toggle(): void
{
    if (is_post()) {
        $u = unite_charger((int) post('id'));
        run('UPDATE Unites SET Actif = 1 - Actif WHERE Id = ?', [$u['Id']]);
        flash('success', $u['Actif'] ? "Unité « {$u['Nom']} » désactivée : elle n'est plus proposée sur les produits." : "Unité « {$u['Nom']} » activée.");
    }
    redirect('unite/index');
}

function unite_delete(): void
{
    if (is_post()) {
        $u = unite_charger((int) post('id'));
        $nb = (int) qv('SELECT COUNT(*) FROM Produits WHERE Unite = ? AND TenantId = ?', [$u['Nom'], $u['TenantId']]);
        if ($nb > 0) {
            flash('danger', "L'unité « {$u['Nom']} » est utilisée par $nb produit(s) : changez leur unité ou désactivez-la plutôt que de la supprimer.");
        } else {
            run('DELETE FROM Unites WHERE Id = ?', [$u['Id']]);
            flash('success', "Unité « {$u['Nom']} » supprimée.");
        }
    }
    redirect('unite/index');
}
