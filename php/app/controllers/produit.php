<?php
// Produits du point de vente : liste, fiche, suppression, export / import Excel.
// Le prix de vente est saisi TTC ; la TVA est calculée à partir du TTC.

require_once __DIR__ . '/../xlsx.php';

// Colonnes du fichier Excel (export et import), dans cet ordre.
const PRODUIT_COLONNES_EXCEL = [
    'Code', 'Nom', 'Catégorie', 'Code-barres', 'Prix TTC', 'TVA %', 'Suivi stock', 'Stock', 'Seuil alerte', 'Actif',
];

function produit_categories(): array
{
    return q('SELECT Id, Nom, Couleur FROM Categories WHERE ' . tf() . ' ORDER BY Ordre, Nom');
}

/** Condition de recherche (nom, code, code-barres) et de catégorie, sur l'alias p. */
function produit_filtre(string $search, int $categorie): array
{
    $sql = tf('p');
    $params = [];
    if ($search !== '') {
        $sql .= ' AND (p.Nom LIKE ? OR p.Code LIKE ? OR p.CodeBarres LIKE ?)';
        array_push($params, "%$search%", "%$search%", "%$search%");
    }
    if ($categorie > 0) {
        $sql .= ' AND p.CategorieId = ?';
        $params[] = $categorie;
    }
    return [$sql, $params];
}

const PRODUIT_SELECT = 'SELECT p.*, c.Nom AS Categorie, c.Couleur FROM Produits p LEFT JOIN Categories c ON c.Id = p.CategorieId';

function produit_index(): void
{
    $search = (string) get('search', '');
    $categorie = (int) get('categorie', 0);
    [$where, $params] = produit_filtre($search, $categorie);
    $pagination = paginer(
        (int) qv('SELECT COUNT(*) FROM Produits p WHERE ' . $where, $params),
        'produit/index', ['search' => $search, 'categorie' => $categorie ?: null], 'Produits'
    );
    render('produit/index', [
        'produits' => q(PRODUIT_SELECT . ' WHERE ' . $where . ' ORDER BY p.Nom, p.Id' . $pagination['limite'], $params),
        'categories' => produit_categories(),
        'search' => $search,
        'categorie' => $categorie,
        'pagination' => $pagination,
        'nbAlertes' => (int) qv('SELECT COUNT(*) FROM Produits WHERE SuiviStock = 1 AND Actif = 1 AND SeuilAlerte IS NOT NULL AND StockActuel <= SeuilAlerte AND ' . tf()),
    ]);
}

function produit_charger(int $id): array
{
    $p = q1('SELECT * FROM Produits WHERE Id = ? AND ' . tf(), [$id]);
    if (!$p) {
        not_found('Produit introuvable.');
    }
    return $p;
}

/** Valeurs du formulaire. */
function produit_valeurs(): array
{
    $categorie = int_or_null(post('CategorieId'));
    if ($categorie && !q1('SELECT Id FROM Categories WHERE Id = ? AND ' . tf(), [$categorie])) {
        $categorie = null;
    }
    $seuil = trim((string) post('SeuilAlerte', ''));
    return [
        'Code' => (string) post('Code', ''),
        'CodeBarres' => ((string) post('CodeBarres', '')) ?: null,
        'Nom' => (string) post('Nom', ''),
        'CategorieId' => $categorie,
        'PrixVente' => montant(post('PrixVente')),
        'TauxTVA' => montant(post('TauxTVA', '18')),
        'SuiviStock' => post('SuiviStock') ? 1 : 0,
        'StockActuel' => montant(post('StockActuel')),
        'SeuilAlerte' => $seuil === '' ? null : montant($seuil),
        'Actif' => post('Actif') ? 1 : 0,
    ];
}

/** Message d'erreur, ou null si le produit peut être enregistré. */
function produit_erreur(array $v, int $idExclu = 0): ?string
{
    if ($v['Code'] === '' || $v['Nom'] === '') {
        return 'Le code et le nom du produit sont obligatoires.';
    }
    if ($v['PrixVente'] < 0 || $v['TauxTVA'] < 0 || $v['TauxTVA'] > 100) {
        return 'Le prix doit être positif et le taux de TVA compris entre 0 et 100 %.';
    }
    if (qv('SELECT COUNT(*) FROM Produits WHERE Code = ? AND Id <> ? AND ' . tf(), [$v['Code'], $idExclu])) {
        return "Le code « {$v['Code']} » est déjà utilisé par un autre produit.";
    }
    if ($v['CodeBarres'] !== null
        && qv('SELECT COUNT(*) FROM Produits WHERE CodeBarres = ? AND Id <> ? AND ' . tf(), [$v['CodeBarres'], $idExclu])) {
        return "Le code-barres « {$v['CodeBarres']} » est déjà utilisé par un autre produit.";
    }
    return null;
}

const PRODUIT_CHAMPS = ['Code', 'CodeBarres', 'Nom', 'CategorieId', 'PrixVente', 'TauxTVA', 'SuiviStock', 'StockActuel', 'SeuilAlerte', 'Actif'];

function produit_create(): void
{
    $produit = ['TauxTVA' => 18, 'SuiviStock' => 1, 'Actif' => 1];
    if (is_post()) {
        $produit = produit_valeurs();
        if ($e = produit_erreur($produit)) {
            flash('danger', $e);
        } else {
            $cols = implode(', ', PRODUIT_CHAMPS);
            $marques = implode(', ', array_fill(0, count(PRODUIT_CHAMPS), '?'));
            run("INSERT INTO Produits ($cols, TenantId) VALUES ($marques, ?)", [...array_values($produit), tenant_insert()]);
            flash('success', 'Produit créé.');
            redirect('produit/index');
        }
    }
    render('produit/form', ['produit' => $produit, 'edition' => false, 'categories' => produit_categories()]);
}

function produit_edit(): void
{
    $existant = produit_charger((int) get('id'));
    $produit = $existant;
    if (is_post()) {
        $produit = produit_valeurs() + ['Id' => $existant['Id']];
        if ($e = produit_erreur($produit, (int) $existant['Id'])) {
            flash('danger', $e);
        } else {
            $set = implode(', ', array_map(fn($c) => "$c = ?", PRODUIT_CHAMPS));
            $valeurs = array_map(fn($c) => $produit[$c], PRODUIT_CHAMPS);
            run("UPDATE Produits SET $set WHERE Id = ?", [...$valeurs, $existant['Id']]);
            flash('success', 'Produit modifié.');
            redirect('produit/index');
        }
    }
    render('produit/form', ['produit' => $produit, 'edition' => true, 'categories' => produit_categories()]);
}

function produit_delete(): void
{
    if (is_post()) {
        // Étapes suivantes : refuser la suppression d'un produit déjà vendu (le désactiver à la place).
        $produit = produit_charger((int) post('id'));
        run('DELETE FROM Produits WHERE Id = ?', [$produit['Id']]);
        flash('success', 'Produit supprimé.');
    }
    redirect('produit/index');
}

function produit_export(): void
{
    [$where, $params] = produit_filtre((string) get('search', ''), (int) get('categorie', 0));
    $lignes = [PRODUIT_COLONNES_EXCEL];
    foreach (q(PRODUIT_SELECT . ' WHERE ' . $where . ' ORDER BY p.Nom', $params) as $p) {
        $lignes[] = [
            $p['Code'], $p['Nom'], (string) $p['Categorie'], (string) $p['CodeBarres'],
            quantite_fr($p['PrixVente'], false), quantite_fr($p['TauxTVA'], false),
            $p['SuiviStock'] ? 'Oui' : 'Non', quantite_fr($p['StockActuel'], false),
            $p['SeuilAlerte'] === null ? '' : quantite_fr($p['SeuilAlerte'], false), $p['Actif'] ? 'Oui' : 'Non',
        ];
    }
    xlsx_envoyer('Produits_' . date('Ymd_Hi') . '.xlsx', ['Produits' => $lignes]);
}

/** « Oui », « 1 », « vrai », « x »… → 1 ; vide → $defaut. */
function produit_booleen(string $v, int $defaut): int
{
    $v = mb_strtolower(trim($v));
    if ($v === '') {
        return $defaut;
    }
    return in_array($v, ['oui', 'o', '1', 'vrai', 'x', 'yes', 'true'], true) ? 1 : 0;
}

/** Import : un produit dont le code existe déjà est mis à jour, sinon il est créé. */
function produit_import(): void
{
    $fichier = $_FILES['file'] ?? null;
    if (!is_post() || !$fichier || $fichier['error'] !== UPLOAD_ERR_OK || $fichier['size'] === 0) {
        flash('danger', 'Veuillez sélectionner un fichier Excel.');
        redirect('produit/index');
    }
    if (strtolower(pathinfo($fichier['name'], PATHINFO_EXTENSION)) !== 'xlsx') {
        flash('danger', 'Le fichier doit être au format .xlsx');
        redirect('produit/index');
    }
    try {
        $lignes = xlsx_lire($fichier['tmp_name']);
    } catch (Throwable $e) {
        flash('danger', 'Fichier Excel illisible : ' . $e->getMessage());
        redirect('produit/index');
    }

    $tenant = tenant_insert();
    $categories = [];
    foreach (produit_categories() as $c) {
        $categories[mb_strtolower($c['Nom'])] = (int) $c['Id'];
    }
    $crees = $maj = 0;
    $erreurs = [];
    foreach (array_slice($lignes, 1) as $ligne) {
        $n = $ligne['_ligne'];
        $col = fn(int $i) => trim((string) ($ligne[$i] ?? ''));
        if (implode('', array_map($col, range(0, 9))) === '') {
            continue;
        }
        $nomCategorie = $col(2);
        $categorieId = null;
        if ($nomCategorie !== '') {
            $cle = mb_strtolower($nomCategorie);
            if (!isset($categories[$cle])) {
                $categories[$cle] = run('INSERT INTO Categories (Nom, TenantId) VALUES (?, ?)', [$nomCategorie, $tenant]);
            }
            $categorieId = $categories[$cle];
        }
        $v = [
            'Code' => $col(0), 'CodeBarres' => $col(3) ?: null, 'Nom' => $col(1), 'CategorieId' => $categorieId,
            'PrixVente' => montant($col(4)), 'TauxTVA' => $col(5) === '' ? 18.0 : montant($col(5)),
            'SuiviStock' => produit_booleen($col(6), 1), 'StockActuel' => montant($col(7)),
            'SeuilAlerte' => $col(8) === '' ? null : montant($col(8)), 'Actif' => produit_booleen($col(9), 1),
        ];
        $existant = $v['Code'] !== '' ? q1('SELECT Id FROM Produits WHERE Code = ? AND ' . tf(), [$v['Code']]) : null;
        if ($e = produit_erreur($v, (int) ($existant['Id'] ?? 0))) {
            $erreurs[] = "Ligne $n : $e";
            continue;
        }
        if ($existant) {
            $set = implode(', ', array_map(fn($c) => "$c = ?", PRODUIT_CHAMPS));
            run("UPDATE Produits SET $set WHERE Id = ?", [...array_values($v), $existant['Id']]);
            $maj++;
        } else {
            $cols = implode(', ', PRODUIT_CHAMPS);
            $marques = implode(', ', array_fill(0, count(PRODUIT_CHAMPS), '?'));
            run("INSERT INTO Produits ($cols, TenantId) VALUES ($marques, ?)", [...array_values($v), $tenant]);
            $crees++;
        }
    }

    flash('success', "Import terminé : $crees produit(s) créé(s), $maj mis à jour.");
    if ($erreurs) {
        flash('warning', implode("\n", $erreurs));
    }
    redirect('produit/index');
}
