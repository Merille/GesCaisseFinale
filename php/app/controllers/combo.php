<?php
// Combos (Configuration › Combos), comme dans le point de vente Odoo : un combo regroupe les
// produits proposés au choix (ex. « Plats » : Poulet, Poisson + 500) et le nombre d'articles à
// choisir. Un produit combo (fiche produit) se compose d'une liste de combos.
// Réservé aux profils Admin et SuperAdmin.

function combo_index(): void
{
    $combos = q('SELECT c.*, (SELECT COUNT(*) FROM ProduitCombos pc WHERE pc.ComboId = c.Id) AS NbProduits FROM Combos c WHERE ' . tf('c') . ' ORDER BY c.Ordre, c.Nom, c.Id');
    foreach ($combos as &$c) {
        $c['choix'] = q('SELECT p.Nom, ch.Supplement FROM ComboChoix ch JOIN Produits p ON p.Id = ch.ProduitId WHERE ch.ComboId = ? ORDER BY ch.Ordre, ch.Id', [$c['Id']]);
        $c['produits'] = array_column(q('SELECT p.Nom FROM ProduitCombos pc JOIN Produits p ON p.Id = pc.ProduitId WHERE pc.ComboId = ? ORDER BY p.Nom', [$c['Id']]), 'Nom');
    }
    unset($c);
    render('combo/index', ['combos' => $combos, 'produits' => combo_produits(tenant_id())]);
}

function combo_charger(int $id): array
{
    $c = q1('SELECT * FROM Combos WHERE Id = ? AND ' . tf(), [$id]);
    if (!$c) {
        not_found('Combo introuvable.');
    }
    return $c;
}

/** Produits proposables dans un combo : actifs, ni modèle à variantes, ni produit combo. */
function combo_produits(int $tenant): array
{
    return array_map(fn($p) => ['id' => (int) $p['Id'], 'nom' => $p['Nom'], 'prix' => (float) $p['PrixVente']],
        q('SELECT Id, Nom, PrixVente FROM Produits WHERE TenantId = ? AND Actif = 1 AND EstModele = 0 AND EstCombo = 0 ORDER BY Nom', [$tenant]));
}

function combo_create(): void
{
    combo_formulaire(null);
}

function combo_edit(): void
{
    combo_formulaire(combo_charger((int) get('id')));
}

/** Formulaire du combo ; en POST : contrôle et enregistrement (nom, nombre à choisir, produits proposés). */
function combo_formulaire(?array $combo): void
{
    $tenant = $combo ? (int) $combo['TenantId'] : tenant_id();
    $choix = $combo ? array_map(fn($c) => ['produitId' => (int) $c['ProduitId'], 'supplement' => (float) $c['Supplement']],
        q('SELECT * FROM ComboChoix WHERE ComboId = ? ORDER BY Ordre, Id', [$combo['Id']])) : [];
    $valeurs = ['Nom' => $combo['Nom'] ?? '', 'Quantite' => (int) ($combo['Quantite'] ?? 1)];
    if (is_post()) {
        if (!$combo) {
            $tenant = tenant_insert();
        }
        $valeurs = ['Nom' => mb_substr(trim((string) post('Nom', '')), 0, 50), 'Quantite' => max(1, min(10, (int) post('Quantite', 1)))];
        $permis = array_column(combo_produits($tenant), null, 'id');
        $choix = [];
        foreach (array_slice((array) json_decode((string) post('choix', '[]'), true), 0, 50) as $c) {
            $pid = (int) ($c['produitId'] ?? 0);
            if (isset($permis[$pid]) && !isset($choix[$pid])) {
                $choix[$pid] = ['produitId' => $pid, 'supplement' => max(0, round((float) ($c['supplement'] ?? 0), 2))];
            }
        }
        $choix = array_values($choix);
        $erreur = $valeurs['Nom'] === '' ? 'Le nom du combo est obligatoire.' : (!$choix ? 'Ajoutez au moins un produit proposé.' : null);
        if ($erreur) {
            flash('danger', $erreur);
        } else {
            db()->beginTransaction();
            try {
                if ($combo) {
                    run('UPDATE Combos SET Nom = ?, Quantite = ? WHERE Id = ?', [$valeurs['Nom'], $valeurs['Quantite'], $combo['Id']]);
                    $id = (int) $combo['Id'];
                    run('DELETE FROM ComboChoix WHERE ComboId = ?', [$id]);
                } else {
                    $id = run('INSERT INTO Combos (TenantId, Nom, Quantite, Ordre) VALUES (?, ?, ?, 0)', [$tenant, $valeurs['Nom'], $valeurs['Quantite']]);
                }
                foreach ($choix as $k => $c) {
                    run('INSERT INTO ComboChoix (ComboId, ProduitId, Supplement, Ordre) VALUES (?, ?, ?, ?)', [$id, $c['produitId'], $c['supplement'], $k]);
                }
                db()->commit();
            } catch (Throwable $e) {
                db()->rollBack();
                throw $e;
            }
            flash('success', $combo ? 'Combo modifié.' : 'Combo créé.');
            redirect('combo/index');
        }
    }
    render('combo/form', ['combo' => $combo, 'valeurs' => $valeurs, 'donnees' => ['produits' => combo_produits($tenant), 'choix' => $choix]]);
}

function combo_delete(): void
{
    if (is_post()) {
        $combo = combo_charger((int) post('id'));
        $nb = (int) qv('SELECT COUNT(*) FROM ProduitCombos WHERE ComboId = ?', [$combo['Id']]);
        if ($nb > 0) {
            flash('danger', "Le combo « {$combo['Nom']} » compose $nb produit(s) : retirez-le de leur fiche avant de le supprimer.");
        } else {
            run('DELETE FROM Combos WHERE Id = ?', [$combo['Id']]);
            flash('success', "Combo « {$combo['Nom']} » supprimé.");
        }
    }
    redirect('combo/index');
}
