<?php
// Imprimantes de préparation (cuisine, bar) en réseau : la caisse leur envoie directement les bons des
// catégories choisies. Epson : impression directe (ePOS) ; Réseau : imprimante ESC/POS par l'agent d'impression.

require_once __DIR__ . '/../restaurant.php';

const IMPRIMANTE_TYPES = ['Epson' => 'Epson (ePOS)', 'Reseau' => 'Autre (ESC/POS réseau, agent)'];

function imprimante_index(): void
{
    $imprimantes = q(
        'SELECT i.*, c.ChkCode FROM ImprimantesPreparation i LEFT JOIN Caisses c ON c.ID = i.CaisseId
         WHERE ' . tf('i') . ' ORDER BY i.Actif DESC, i.Nom, i.Id'
    );
    foreach ($imprimantes as &$i) {
        $i['js'] = imprimante_js($i);
    }
    unset($i);
    render('imprimante/index', [
        'imprimantes' => $imprimantes,
        'categories' => q('SELECT Id, Nom, Preparation FROM Categories WHERE ' . tf() . ' ORDER BY Ordre, Nom'),
        'caisses' => q("SELECT ID, ChkCode, ChkDescription FROM Caisses WHERE TypePointVente IN ('Restaurant', 'Bar') AND " . tf() . ' ORDER BY ChkCode'),
    ]);
}

function imprimante_charger(int $id): array
{
    $i = q1('SELECT * FROM ImprimantesPreparation WHERE Id = ? AND ' . tf(), [$id]);
    if (!$i) {
        not_found('Imprimante introuvable.');
    }
    return $i;
}

/** Adresse IP (ou nom d'hôte du réseau local) acceptée pour une imprimante. */
function imprimante_adresse_valide(string $adresse): bool
{
    return (bool) preg_match('/^[A-Za-z0-9]([A-Za-z0-9.\-]{0,98}[A-Za-z0-9])?$/', $adresse);
}

/** Création (sans Id) ou modification (avec Id). */
function imprimante_save(): void
{
    if (is_post()) {
        $id = int_or_null(post('Id'));
        $nom = mb_substr(trim((string) post('Nom', '')), 0, 100);
        $type = array_key_exists((string) post('Type'), IMPRIMANTE_TYPES) ? post('Type') : 'Epson';
        $adresse = trim((string) post('AdresseIp', ''));
        $port = int_or_null(post('Port'));
        $largeur = (int) post('Largeur') === 58 ? 58 : 80;
        $encodage = post('Encodage') === 'SansAccents' ? 'SansAccents' : 'PC850';
        $bip = post('Bip') ? 1 : 0;
        $actif = post('Actif') ? 1 : 0;
        $caisse = int_or_null(post('CaisseId'));
        if ($caisse && !qv("SELECT COUNT(*) FROM Caisses WHERE ID = ? AND " . tf(), [$caisse])) {
            $caisse = null;
        }
        if ($nom === '' || !imprimante_adresse_valide($adresse) || ($port !== null && ($port < 1 || $port > 65535))) {
            flash('danger', $nom === '' ? 'Le nom de l\'imprimante est obligatoire.' : 'Adresse IP ou port de l\'imprimante invalide.');
            redirect('imprimante/index');
        }
        $categories = array_values(array_unique(array_filter(array_map('intval', (array) ($_POST['Categories'] ?? [])))));
        if ($categories) {
            $marques = implode(',', array_fill(0, count($categories), '?'));
            $categories = array_map('intval', array_column(q("SELECT Id FROM Categories WHERE Id IN ($marques) AND " . tf(), $categories), 'Id'));
        }
        $valeurs = [$nom, $type, $adresse, $port, $largeur, $encodage, $bip, $caisse, $actif];
        if ($id) {
            $i = imprimante_charger($id);
            run('UPDATE ImprimantesPreparation SET Nom = ?, Type = ?, AdresseIp = ?, Port = ?, Largeur = ?, Encodage = ?, Bip = ?, CaisseId = ?, Actif = ? WHERE Id = ?', [...$valeurs, $i['Id']]);
            run('DELETE FROM ImprimantesPreparationCategories WHERE ImprimantePreparationId = ?', [$i['Id']]);
            flash('success', 'Imprimante modifiée.');
        } else {
            $id = run('INSERT INTO ImprimantesPreparation (Nom, Type, AdresseIp, Port, Largeur, Encodage, Bip, CaisseId, Actif, TenantId) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [...$valeurs, tenant_insert()]);
            flash('success', 'Imprimante créée.');
        }
        foreach ($categories as $c) {
            run('INSERT INTO ImprimantesPreparationCategories (ImprimantePreparationId, CategorieId) VALUES (?, ?)', [$id, $c]);
        }
    }
    redirect('imprimante/index');
}

/** Active ou désactive l'imprimante (la caisse ne lui envoie plus de bons). */
function imprimante_toggle(): void
{
    if (is_post()) {
        $i = imprimante_charger((int) post('id'));
        run('UPDATE ImprimantesPreparation SET Actif = 1 - Actif WHERE Id = ?', [$i['Id']]);
        flash('success', $i['Actif'] ? "Imprimante « {$i['Nom']} » désactivée." : "Imprimante « {$i['Nom']} » activée.");
    }
    redirect('imprimante/index');
}

function imprimante_delete(): void
{
    if (is_post()) {
        $i = imprimante_charger((int) post('id'));
        run('DELETE FROM ImprimantesPreparation WHERE Id = ?', [$i['Id']]);
        flash('success', "Imprimante « {$i['Nom']} » supprimée.");
    }
    redirect('imprimante/index');
}
