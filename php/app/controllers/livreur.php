<?php
// Livreurs (sans compte de connexion) : choisis au point de vente sur une commande à livrer.
// Un livreur qui a déjà des livraisons se désactive au lieu d'être supprimé.

const LIVREUR_MOYENS = ['Moto', 'Voiture', 'Vélo', 'Autre'];

/** Pictogramme Font Awesome du moyen de livraison. */
function livreur_icone(?string $moyen): string
{
    return ['Voiture' => 'fa-car', 'Vélo' => 'fa-bicycle', 'Autre' => 'fa-truck-fast'][$moyen] ?? 'fa-motorcycle';
}

function livreur_index(): void
{
    render('livreur/index', [
        'livreurs' => q(
            'SELECT l.*, (SELECT COUNT(*) FROM CommandesPos c WHERE c.LivreurId = l.Id) AS NbLivraisons
             FROM Livreurs l WHERE ' . tf('l') . ' ORDER BY l.Actif DESC, l.Nom, l.Id'
        ),
    ]);
}

function livreur_charger(int $id): array
{
    $l = q1('SELECT * FROM Livreurs WHERE Id = ? AND ' . tf(), [$id]);
    if (!$l) {
        not_found('Livreur introuvable.');
    }
    return $l;
}

/** Création (sans Id) ou modification (avec Id). */
function livreur_save(): void
{
    if (is_post()) {
        $id = int_or_null(post('Id'));
        $nom = mb_substr(trim((string) post('Nom', '')), 0, 100);
        $telephone = mb_substr(trim((string) post('Telephone', '')), 0, 30) ?: null;
        $moyen = in_array(post('MoyenLivraison'), LIVREUR_MOYENS, true) ? post('MoyenLivraison') : 'Moto';
        $actif = post('Actif') ? 1 : 0;
        if ($nom === '') {
            flash('danger', 'Le nom du livreur est obligatoire.');
            redirect('livreur/index');
        }
        if ($id) {
            $l = livreur_charger($id);
            run('UPDATE Livreurs SET Nom = ?, Telephone = ?, MoyenLivraison = ?, Actif = ? WHERE Id = ?', [$nom, $telephone, $moyen, $actif, $l['Id']]);
            flash('success', 'Livreur modifié.');
        } else {
            run('INSERT INTO Livreurs (TenantId, Nom, Telephone, MoyenLivraison, Actif) VALUES (?, ?, ?, ?, ?)', [tenant_insert(), $nom, $telephone, $moyen, $actif]);
            flash('success', 'Livreur créé.');
        }
    }
    redirect('livreur/index');
}

/** Active ou désactive le livreur (il n'est plus proposé au point de vente). */
function livreur_toggle(): void
{
    if (is_post()) {
        $l = livreur_charger((int) post('id'));
        run('UPDATE Livreurs SET Actif = 1 - Actif WHERE Id = ?', [$l['Id']]);
        flash('success', $l['Actif']
            ? "Livreur « {$l['Nom']} » désactivé : il n'est plus proposé au point de vente."
            : "Livreur « {$l['Nom']} » activé.");
    }
    redirect('livreur/index');
}

function livreur_delete(): void
{
    if (is_post()) {
        $l = livreur_charger((int) post('id'));
        $utilise = (int) qv('SELECT COUNT(*) FROM CommandesPos WHERE LivreurId = ?', [$l['Id']])
            + (int) qv('SELECT COUNT(*) FROM CommandesAttente WHERE LivreurId = ?', [$l['Id']]);
        if ($utilise) {
            flash('danger', "Le livreur « {$l['Nom']} » a déjà des livraisons : désactivez-le plutôt que de le supprimer.");
        } else {
            run('DELETE FROM Livreurs WHERE Id = ?', [$l['Id']]);
            flash('success', "Livreur « {$l['Nom']} » supprimé.");
        }
    }
    redirect('livreur/index');
}
