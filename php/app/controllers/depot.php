<?php
// Dépôts de stockage (magasin, entrepôt, réserve…) : le stock de chaque produit est suivi par dépôt.
// Le dépôt par défaut reçoit le stock initial des produits et sert aux caisses sans dépôt choisi ;
// il ne peut être ni désactivé ni supprimé. Un dépôt qui a un historique se désactive au lieu
// d'être supprimé.

function depot_index(): void
{
    if (tenant_id() > 0) {
        depot_par_defaut(tenant_id());
    }
    render('depot/index', [
        'depots' => q(
            'SELECT d.*,
                (SELECT COUNT(*) FROM StocksDepots s WHERE s.DepotId = d.Id AND s.Quantite <> 0) AS NbProduits,
                (SELECT COUNT(*) FROM Caisses c WHERE c.DepotId = d.Id) AS NbCaisses
             FROM Depots d WHERE ' . tf('d') . ' ORDER BY d.ParDefaut DESC, d.Actif DESC, d.Code, d.Id'
        ),
    ]);
}

function depot_charger(int $id): array
{
    $d = q1('SELECT * FROM Depots WHERE Id = ? AND ' . tf(), [$id]);
    if (!$d) {
        not_found('Dépôt introuvable.');
    }
    return $d;
}

/** Message d'erreur si le dépôt ne peut pas être désactivé, sinon null. */
function depot_refus_desactivation(array $d): ?string
{
    if ($d['ParDefaut']) {
        return "Le dépôt par défaut ne peut pas être désactivé : choisissez d'abord un autre dépôt par défaut.";
    }
    $nb = (int) qv('SELECT COUNT(*) FROM Caisses WHERE DepotId = ?', [$d['Id']]);
    return $nb ? "Le dépôt « {$d['Nom']} » est utilisé par $nb caisse(s) : rattachez-les à un autre dépôt avant de le désactiver." : null;
}

/** Création (sans Id) ou modification (avec Id). */
function depot_save(): void
{
    if (is_post()) {
        $id = int_or_null(post('Id'));
        $code = mb_substr(trim((string) post('Code', '')), 0, 20);
        $nom = mb_substr(trim((string) post('Nom', '')), 0, 100);
        $adresse = mb_substr(trim((string) post('Adresse', '')), 0, 200) ?: null;
        $responsable = mb_substr(trim((string) post('Responsable', '')), 0, 100) ?: null;
        $actif = post('Actif') ? 1 : 0;
        if ($code === '' || $nom === '') {
            flash('danger', 'Le code et le nom du dépôt sont obligatoires.');
            redirect('depot/index');
        }
        $existant = $id ? depot_charger($id) : null;
        $tenant = $existant ? (int) $existant['TenantId'] : tenant_insert();
        if (qv('SELECT COUNT(*) FROM Depots WHERE Code = ? AND Id <> ? AND TenantId = ?', [$code, (int) $id, $tenant])) {
            flash('danger', "Le code « $code » est déjà utilisé par un autre dépôt.");
            redirect('depot/index');
        }
        if ($existant) {
            if ($existant['Actif'] && !$actif && ($refus = depot_refus_desactivation($existant))) {
                flash('danger', $refus);
                redirect('depot/index');
            }
            run('UPDATE Depots SET Code = ?, Nom = ?, Adresse = ?, Responsable = ?, Actif = ? WHERE Id = ?',
                [$code, $nom, $adresse, $responsable, $actif, $existant['Id']]);
            flash('success', 'Dépôt modifié.');
        } else {
            depot_par_defaut($tenant);
            run('INSERT INTO Depots (TenantId, Code, Nom, Adresse, Responsable, Actif, ParDefaut) VALUES (?, ?, ?, ?, ?, ?, 0)',
                [$tenant, $code, $nom, $adresse, $responsable, $actif]);
            flash('success', 'Dépôt créé.');
        }
    }
    redirect('depot/index');
}

/** Active ou désactive le dépôt (il n'est plus proposé pour les caisses ni les mouvements de stock). */
function depot_toggle(): void
{
    if (is_post()) {
        $d = depot_charger((int) post('id'));
        if ($d['Actif'] && ($refus = depot_refus_desactivation($d))) {
            flash('danger', $refus);
        } else {
            run('UPDATE Depots SET Actif = 1 - Actif WHERE Id = ?', [$d['Id']]);
            flash('success', $d['Actif']
                ? "Dépôt « {$d['Nom']} » désactivé : il n'est plus proposé pour les caisses ni les mouvements de stock."
                : "Dépôt « {$d['Nom']} » activé.");
        }
    }
    redirect('depot/index');
}

/** Choisit le dépôt par défaut de la société. */
function depot_defaut(): void
{
    if (is_post()) {
        $d = depot_charger((int) post('id'));
        if (!$d['Actif']) {
            flash('danger', "Activez d'abord le dépôt « {$d['Nom']} ».");
        } else {
            run('UPDATE Depots SET ParDefaut = (Id = ?) WHERE TenantId = ?', [$d['Id'], $d['TenantId']]);
            flash('success', "« {$d['Nom']} » est maintenant le dépôt par défaut.");
        }
    }
    redirect('depot/index');
}

function depot_delete(): void
{
    if (is_post()) {
        $d = depot_charger((int) post('id'));
        $utilise = (int) qv('SELECT COUNT(*) FROM MouvementsStock WHERE DepotId = ?', [$d['Id']])
            + (int) qv('SELECT COUNT(*) FROM Caisses WHERE DepotId = ?', [$d['Id']])
            + (int) qv('SELECT COUNT(*) FROM StocksDepots WHERE DepotId = ? AND Quantite <> 0', [$d['Id']]);
        if ($d['ParDefaut']) {
            flash('danger', 'Le dépôt par défaut ne peut pas être supprimé.');
        } elseif ($utilise) {
            flash('danger', "Le dépôt « {$d['Nom']} » a déjà des mouvements de stock ou des caisses rattachées : désactivez-le plutôt que de le supprimer.");
        } else {
            run('DELETE FROM StocksDepots WHERE DepotId = ?', [$d['Id']]);
            run('DELETE FROM Depots WHERE Id = ?', [$d['Id']]);
            flash('success', "Dépôt « {$d['Nom']} » supprimé.");
        }
    }
    redirect('depot/index');
}
