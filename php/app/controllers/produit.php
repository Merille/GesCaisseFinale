<?php
// Produits du point de vente : liste, fiche, suppression, export / import Excel.
// Le prix de vente est saisi TTC ; un produit peut porter plusieurs taxes (TVA, CSS…)
// qui s'additionnent sur le HT. Produits.TauxTVA garde le taux total.

require_once __DIR__ . '/../xlsx.php';

// Colonnes du fichier Excel (export et import), dans cet ordre.
const PRODUIT_COLONNES_EXCEL = [
    'Code', 'Nom', 'Catégorie', 'Code-barres', 'Prix TTC', 'Taxes', 'Suivi stock', 'Stock', 'Seuil alerte', 'Actif',
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

const PRODUIT_SELECT = "SELECT p.*, c.Nom AS Categorie, c.Couleur,
        (SELECT GROUP_CONCAT(t.Code ORDER BY t.ParDefaut DESC, t.Taux DESC, t.Code SEPARATOR ' + ')
         FROM ProduitTaxes pt JOIN Taxes t ON t.Id = pt.TaxeId WHERE pt.ProduitId = p.Id) AS Taxes
    FROM Produits p LEFT JOIN Categories c ON c.Id = p.CategorieId";

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
        'taxes' => taxes_liste(),
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
        'SuiviStock' => post('SuiviStock') ? 1 : 0,
        'StockActuel' => montant(post('StockActuel')),
        'SeuilAlerte' => $seuil === '' ? null : montant($seuil),
        'Actif' => post('Actif') ? 1 : 0,
        'TaxeIds' => array_map('intval', (array) post('Taxes', [])),
    ];
}

/** Message d'erreur, ou null si le produit peut être enregistré. */
function produit_erreur(array $v, int $idExclu = 0): ?string
{
    if ($v['Code'] === '' || $v['Nom'] === '') {
        return 'Le code et le nom du produit sont obligatoires.';
    }
    if ($v['PrixVente'] < 0) {
        return 'Le prix doit être positif.';
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

// Champs enregistrés tels quels. Le stock n'en fait pas partie : il ne change que par des
// mouvements (stock initial à la création, entrées, inventaires, ventes, retours).
// Le taux total (TauxTVA) suit les taxes du produit (produit_enregistrer_taxes).
const PRODUIT_CHAMPS = ['Code', 'CodeBarres', 'Nom', 'CategorieId', 'PrixVente', 'SuiviStock', 'SeuilAlerte', 'Actif'];

/** Crée le produit, ses taxes, puis enregistre son stock initial comme premier mouvement. */
function produit_inserer(array $v, int $tenant): int
{
    db()->beginTransaction();
    try {
        $cols = implode(', ', PRODUIT_CHAMPS);
        $marques = implode(', ', array_fill(0, count(PRODUIT_CHAMPS), '?'));
        $id = run("INSERT INTO Produits ($cols, TenantId) VALUES ($marques, ?)", [...array_map(fn($c) => $v[$c], PRODUIT_CHAMPS), $tenant]);
        produit_enregistrer_taxes($id, $v['TaxeIds'] ?? taxes_par_defaut($tenant), $tenant);
        mouvement_stock($id, (float) ($v['StockActuel'] ?? 0), 'Stock initial');
        db()->commit();
    } catch (Throwable $e) {
        db()->rollBack();
        throw $e;
    }
    return $id;
}

/** Met le produit à jour ; ses taxes sont remplacées si elles sont fournies. */
function produit_mettre_a_jour(array $v, int $id): void
{
    $set = implode(', ', array_map(fn($c) => "$c = ?", PRODUIT_CHAMPS));
    db()->beginTransaction();
    try {
        run("UPDATE Produits SET $set WHERE Id = ?", [...array_map(fn($c) => $v[$c], PRODUIT_CHAMPS), $id]);
        if (isset($v['TaxeIds'])) {
            produit_enregistrer_taxes($id, $v['TaxeIds'], (int) qv('SELECT TenantId FROM Produits WHERE Id = ?', [$id]));
        }
        db()->commit();
    } catch (Throwable $e) {
        db()->rollBack();
        throw $e;
    }
}

/** Taxes cochées par défaut sur un nouveau produit. */
function taxes_par_defaut(?int $tenant = null): array
{
    return array_map(fn($t) => (int) $t['Id'], array_filter(taxes_liste($tenant), fn($t) => $t['ParDefaut']));
}

function produit_create(): void
{
    $produit = ['SuiviStock' => 1, 'Actif' => 1, 'TaxeIds' => taxes_par_defaut()];
    if (is_post()) {
        $produit = produit_valeurs();
        if ($e = produit_erreur($produit)) {
            flash('danger', $e);
        } else {
            produit_inserer($produit, tenant_insert());
            flash('success', 'Produit créé.');
            redirect('produit/index');
        }
    }
    render('produit/form', ['produit' => $produit, 'edition' => false, 'categories' => produit_categories(), 'taxes' => taxes_liste()]);
}

function produit_edit(): void
{
    $existant = produit_charger((int) get('id'));
    $produit = $existant + ['TaxeIds' => array_keys(produit_taxes((int) $existant['Id']))];
    if (is_post()) {
        $produit = produit_valeurs() + ['Id' => $existant['Id']];
        $produit['StockActuel'] = $existant['StockActuel'];
        if ($e = produit_erreur($produit, (int) $existant['Id'])) {
            flash('danger', $e);
        } else {
            produit_mettre_a_jour($produit, (int) $existant['Id']);
            flash('success', 'Produit modifié.');
            redirect('produit/index');
        }
    }
    render('produit/form', ['produit' => $produit, 'edition' => true, 'categories' => produit_categories(), 'taxes' => taxes_liste()]);
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
            quantite_fr($p['PrixVente'], false), (string) $p['Taxes'],
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
    $taxes = taxes_liste();
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
        $taxeIds = produit_taxes_depuis_texte($col(5), $taxes);
        if (is_string($taxeIds)) {
            $erreurs[] = "Ligne $n : $taxeIds";
            continue;
        }
        $v = [
            'Code' => $col(0), 'CodeBarres' => $col(3) ?: null, 'Nom' => $col(1), 'CategorieId' => $categorieId,
            'PrixVente' => montant($col(4)),
            'SuiviStock' => produit_booleen($col(6), 1), 'StockActuel' => montant($col(7)),
            'SeuilAlerte' => $col(8) === '' ? null : montant($col(8)), 'Actif' => produit_booleen($col(9), 1),
        ];
        // Colonne Taxes vide : taxes par défaut pour un nouveau produit, inchangées pour un produit existant.
        if ($taxeIds !== null) {
            $v['TaxeIds'] = $taxeIds;
        }
        $existant = $v['Code'] !== '' ? q1('SELECT Id FROM Produits WHERE Code = ? AND ' . tf(), [$v['Code']]) : null;
        if ($e = produit_erreur($v, (int) ($existant['Id'] ?? 0))) {
            $erreurs[] = "Ligne $n : $e";
            continue;
        }
        // Produit existant : le stock du fichier est ignoré (il change par entrées et inventaires).
        if ($existant) {
            produit_mettre_a_jour($v, (int) $existant['Id']);
            $maj++;
        } else {
            produit_inserer($v, $tenant);
            $crees++;
        }
    }

    flash('success', "Import terminé : $crees produit(s) créé(s), $maj mis à jour.");
    if ($erreurs) {
        flash('warning', implode("\n", $erreurs));
    }
    redirect('produit/index');
}

/**
 * Taxes d'une ligne importée : codes séparés par « + », « , » ou « ; » (ex. « TVA + CSS »),
 * ou un taux seul (ancien format « TVA % », ex. 18). Null si la cellule est vide ;
 * message d'erreur si un code ou un taux est inconnu.
 */
function produit_taxes_depuis_texte(string $texte, array $taxes): array|string|null
{
    $texte = trim($texte);
    if ($texte === '') {
        return null;
    }
    if (preg_match('/^\d+([.,]\d+)?\s*%?$/', $texte)) {
        $taux = montant(rtrim($texte, " %"));
        if ($taux == 0) {
            return [];
        }
        foreach ($taxes as $t) {
            if ((float) $t['Taux'] == $taux) {
                return [(int) $t['Id']];
            }
        }
        return "aucune taxe de " . quantite_fr($taux) . " % (créez-la dans Paramètres > Taxes).";
    }
    $ids = [];
    foreach (preg_split('/\s*[+,;]\s*/', $texte, -1, PREG_SPLIT_NO_EMPTY) as $code) {
        $trouve = null;
        foreach ($taxes as $t) {
            if (mb_strtoupper($t['Code']) === mb_strtoupper($code)) {
                $trouve = (int) $t['Id'];
            }
        }
        if ($trouve === null) {
            return "taxe « $code » inconnue (voir Paramètres > Taxes).";
        }
        $ids[] = $trouve;
    }
    return $ids;
}
