<?php
// Produits du point de vente : liste, fiche, suppression, export / import Excel.
// Le prix de vente est saisi TTC ; un produit peut porter plusieurs taxes (TVA, CSS…)
// qui s'additionnent sur le HT. Produits.TauxTVA garde le taux total.

require_once __DIR__ . '/../xlsx.php';

// Colonnes du fichier Excel (export et import), dans cet ordre.
const PRODUIT_COLONNES_EXCEL = [
    'Code', 'Nom', 'Catégorie', 'Code-barres', 'Prix TTC', 'Taxes', 'Suivi stock', 'Stock', 'Seuil alerte', 'Actif', 'Unité', 'Coût',
];

// Unités de vente proposées (la saisie reste libre).
const PRODUIT_UNITES = ['Unité', 'Pièce', 'Kg', 'g', 'Litre', 'cl', 'Mètre', 'Carton', 'Paquet', 'Boîte', 'Sac', 'Bouteille', 'Page', 'Heure'];

function produit_categories(): array
{
    return q('SELECT Id, Nom, Couleur FROM Categories WHERE ' . tf() . ' ORDER BY Ordre, Nom');
}

/** Condition de recherche (nom, code, code-barres) et de catégorie, sur l'alias p. */
function produit_filtre(string $search, int $categorie): array
{
    // Les variantes sont gérées depuis la fiche de leur modèle.
    $sql = tf('p') . ' AND p.ParentId IS NULL';
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
         FROM ProduitTaxes pt JOIN Taxes t ON t.Id = pt.TaxeId WHERE pt.ProduitId = p.Id) AS Taxes,
        (SELECT COUNT(*) FROM Produits v WHERE v.ParentId = p.Id AND v.Actif = 1) AS NbVariantes,
        (SELECT COALESCE(SUM(v.StockActuel), 0) FROM Produits v WHERE v.ParentId = p.Id AND v.Actif = 1) AS StockVariantes
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
        'nbAlertes' => (int) qv('SELECT COUNT(*) FROM Produits WHERE SuiviStock = 1 AND Actif = 1 AND EstModele = 0 AND SeuilAlerte IS NOT NULL AND StockActuel <= SeuilAlerte AND ' . tf()),
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
    $cout = trim((string) post('Cout', ''));
    return [
        'Code' => (string) post('Code', ''),
        'CodeBarres' => ((string) post('CodeBarres', '')) ?: null,
        'Nom' => (string) post('Nom', ''),
        'CategorieId' => $categorie,
        'PrixVente' => montant(post('PrixVente')),
        'Cout' => $cout === '' ? null : montant($cout),
        'Unite' => mb_substr(trim((string) post('Unite', '')), 0, 20) ?: 'Unité',
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
    if ($v['PrixVente'] < 0 || ($v['Cout'] ?? 0) < 0) {
        return 'Le prix et le coût doivent être positifs.';
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
const PRODUIT_CHAMPS = ['Code', 'CodeBarres', 'Nom', 'CategorieId', 'PrixVente', 'Cout', 'Unite', 'SuiviStock', 'SeuilAlerte', 'Actif'];

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
        produit_propager_variantes($id);
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
        $image = image_televersee('Image');
        if ($e = produit_erreur($produit) ?? (is_string($image) ? $image : null)) {
            flash('danger', $e);
        } else {
            enregistrer_image('produit', produit_inserer($produit, tenant_insert()), $image, false);
            flash('success', 'Produit créé.');
            redirect('produit/index');
        }
    }
    render('produit/form', ['produit' => $produit, 'edition' => false, 'categories' => produit_categories(), 'taxes' => taxes_liste()]);
}

function produit_edit(): void
{
    $existant = produit_charger((int) get('id'));
    // Une variante se gère depuis la fiche de son modèle.
    if ($existant['ParentId']) {
        redirect('produit/edit', ['id' => $existant['ParentId']]);
    }
    $produit = $existant + ['TaxeIds' => array_keys(produit_taxes((int) $existant['Id']))];
    if (is_post()) {
        $produit = produit_valeurs() + ['Id' => $existant['Id'], 'ImageMaj' => $existant['ImageMaj']];
        $produit['StockActuel'] = $existant['StockActuel'];
        $image = image_televersee('Image');
        if ($e = produit_erreur($produit, (int) $existant['Id']) ?? (is_string($image) ? $image : null)) {
            flash('danger', $e);
        } else {
            produit_mettre_a_jour($produit, (int) $existant['Id']);
            enregistrer_image('produit', (int) $existant['Id'], $image, (bool) post('SupprimerImage'));
            flash('success', 'Produit modifié.');
            redirect('produit/index');
        }
    }
    render('produit/form', ['produit' => $produit, 'edition' => true, 'categories' => produit_categories(), 'taxes' => taxes_liste(),
        'attributs' => produit_attributs((int) $existant['Id']), 'variantes' => produit_variantes((int) $existant['Id']),
        'nomsAttributs' => array_column(q('SELECT DISTINCT a.Nom FROM ProduitAttributs a JOIN Produits p ON p.Id = a.ProduitId WHERE ' . tf('p') . ' ORDER BY a.Nom'), 'Nom')]);
}

function produit_delete(): void
{
    if (is_post()) {
        // Étapes suivantes : refuser la suppression d'un produit déjà vendu (le désactiver à la place).
        $produit = produit_charger((int) post('id'));
        // Un modèle emporte ses variantes.
        run('DELETE FROM Produits WHERE ParentId = ?', [$produit['Id']]);
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
            $p['Unite'], $p['Cout'] === null ? '' : quantite_fr($p['Cout'], false),
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
        if (implode('', array_map($col, range(0, 11))) === '') {
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
            'Unite' => mb_substr($col(10), 0, 20) ?: 'Unité', 'Cout' => $col(11) === '' ? null : montant($col(11)),
        ];
        // Colonne Taxes vide : taxes par défaut pour un nouveau produit, inchangées pour un produit existant.
        if ($taxeIds !== null) {
            $v['TaxeIds'] = $taxeIds;
        }
        $existant = $v['Code'] !== '' ? q1('SELECT Id, Unite, Cout FROM Produits WHERE Code = ? AND ' . tf(), [$v['Code']]) : null;
        // Cellules Unité / Coût vides (ex. fichier d'une version précédente) : valeurs actuelles conservées.
        if ($existant && $col(10) === '') {
            $v['Unite'] = $existant['Unite'];
        }
        if ($existant && $col(11) === '') {
            $v['Cout'] = $existant['Cout'];
        }
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

// ----------------------------------------------------------------------------------
// Variantes : attributs du produit modèle (Taille : S, M, L…) et combinaisons générées.
// Chaque variante est un produit (ParentId = modèle) : stock, ventes, retours, taxes et
// rapports la traitent comme n'importe quel produit.
// ----------------------------------------------------------------------------------

/** Attributs du produit et leurs valeurs : [['Id', 'Nom', 'valeurs' => [Id => Valeur]]]. */
function produit_attributs(int $produitId): array
{
    $attributs = [];
    foreach (q('SELECT * FROM ProduitAttributs WHERE ProduitId = ? ORDER BY Ordre, Id', [$produitId]) as $a) {
        $a['valeurs'] = [];
        $attributs[(int) $a['Id']] = $a;
    }
    if ($attributs) {
        $ids = implode(',', array_keys($attributs));
        foreach (q("SELECT * FROM ProduitAttributValeurs WHERE ProduitAttributId IN ($ids) ORDER BY Ordre, Id") as $v) {
            $attributs[(int) $v['ProduitAttributId']]['valeurs'][(int) $v['Id']] = $v['Valeur'];
        }
    }
    return array_values($attributs);
}

/** Variantes du modèle (actives et désactivées). */
function produit_variantes(int $produitId): array
{
    return q('SELECT * FROM Produits WHERE ParentId = ? ORDER BY Actif DESC, Id', [$produitId]);
}

/** Code libre pour une nouvelle variante : CODE-01, CODE-02… */
function produit_code_variante(array $modele): string
{
    for ($n = 1; ; $n++) {
        $code = mb_substr($modele['Code'], 0, 44) . '-' . str_pad((string) $n, 2, '0', STR_PAD_LEFT);
        if (!qv('SELECT COUNT(*) FROM Produits WHERE Code = ? AND TenantId = ?', [$code, $modele['TenantId']])) {
            return $code;
        }
    }
}

/**
 * Recopie sur les variantes ce qui vient du modèle : nom (+ valeurs), catégorie, prix
 * (+ supplément), coût, unité, suivi du stock, seuil et taxes.
 */
function produit_propager_variantes(int $modeleId): void
{
    $m = q1('SELECT * FROM Produits WHERE Id = ?', [$modeleId]);
    if (!$m || !$m['EstModele']) {
        return;
    }
    run("UPDATE Produits SET Nom = LEFT(TRIM(CONCAT(?, ' ', COALESCE(LibelleVariante, ''))), 200), CategorieId = ?, PrixVente = ? + Supplement,
            Cout = ?, Unite = ?, SuiviStock = ?, SeuilAlerte = ?, TauxTVA = ?
         WHERE ParentId = ?",
        [$m['Nom'], $m['CategorieId'], $m['PrixVente'], $m['Cout'], $m['Unite'], $m['SuiviStock'], $m['SeuilAlerte'], $m['TauxTVA'], $modeleId]);
    run('DELETE pt FROM ProduitTaxes pt JOIN Produits v ON v.Id = pt.ProduitId WHERE v.ParentId = ?', [$modeleId]);
    run('INSERT INTO ProduitTaxes (ProduitId, TaxeId) SELECT v.Id, pt.TaxeId FROM Produits v JOIN ProduitTaxes pt ON pt.ProduitId = ? WHERE v.ParentId = ?',
        [$modeleId, $modeleId]);
}

/** Lit les attributs saisis : [['nom' => 'Taille', 'valeurs' => ['S', 'M', 'L']], …]. */
function produit_attributs_saisis(): array
{
    $saisis = [];
    foreach ((array) post('attribut', []) as $a) {
        $nom = mb_substr(trim((string) ($a['nom'] ?? '')), 0, 50);
        $valeurs = [];
        foreach (preg_split('/\s*[,;]\s*/', (string) ($a['valeurs'] ?? ''), -1, PREG_SPLIT_NO_EMPTY) as $v) {
            $v = mb_substr(trim($v), 0, 50);
            if ($v !== '' && !in_array(mb_strtolower($v), array_map('mb_strtolower', $valeurs), true)) {
                $valeurs[] = $v;
            }
        }
        if ($nom !== '' && $valeurs) {
            $saisis[mb_strtolower($nom)] = ['nom' => $nom, 'valeurs' => $valeurs];
        }
    }
    return array_values($saisis);
}

/**
 * Enregistre les attributs du modèle puis génère les combinaisons manquantes.
 * Une valeur ou un attribut retiré désactive les variantes qui l'utilisaient (l'historique
 * des ventes est gardé) ; une combinaison déjà existante n'est jamais dupliquée.
 */
function produit_genvariantes(): void
{
    $m = produit_charger((int) post('id'));
    $retour = fn(string $type, string $msg) => [flash($type, $msg), redirect('produit/edit', ['id' => $m['Id']])];
    if ($m['ParentId']) {
        $retour('danger', 'Une variante ne peut pas avoir ses propres variantes.');
    }
    $saisis = produit_attributs_saisis();
    if (!$m['EstModele'] && $saisis && $m['SuiviStock'] && abs((float) $m['StockActuel']) > 0.0001) {
        $retour('danger', 'Ce produit a encore ' . quantite_fr($m['StockActuel']) . ' en stock : ramenez son stock à 0 (inventaire) avant de créer des variantes, puis faites l\'entrée de stock sur chaque variante.');
    }
    $combinaisons = array_product(array_map(fn($a) => count($a['valeurs']), $saisis ?: [['valeurs' => []]]));
    if ($saisis && $combinaisons > 200) {
        $retour('danger', "Trop de combinaisons ($combinaisons) : 200 variantes au plus par produit.");
    }

    db()->beginTransaction();
    try {
        // 1. Attributs et valeurs (identifiés par leur nom, sans tenir compte des majuscules).
        $existants = produit_attributs((int) $m['Id']);
        $gardes = [];
        $valeursRetenues = [];
        foreach ($saisis as $ordre => $a) {
            $attr = null;
            foreach ($existants as $e) {
                if (mb_strtolower($e['Nom']) === mb_strtolower($a['nom'])) {
                    $attr = $e;
                }
            }
            if ($attr) {
                run('UPDATE ProduitAttributs SET Nom = ?, Ordre = ? WHERE Id = ?', [$a['nom'], $ordre, $attr['Id']]);
                $attrId = (int) $attr['Id'];
            } else {
                $attrId = run('INSERT INTO ProduitAttributs (ProduitId, Nom, Ordre) VALUES (?, ?, ?)', [$m['Id'], $a['nom'], $ordre]);
                $attr = ['valeurs' => []];
            }
            $gardes[] = $attrId;
            $ids = [];
            foreach ($a['valeurs'] as $o => $valeur) {
                $id = array_search(mb_strtolower($valeur), array_map('mb_strtolower', $attr['valeurs']), true);
                if ($id === false) {
                    $id = run('INSERT INTO ProduitAttributValeurs (ProduitAttributId, Valeur, Ordre) VALUES (?, ?, ?)', [$attrId, $valeur, $o]);
                } else {
                    run('UPDATE ProduitAttributValeurs SET Valeur = ?, Ordre = ? WHERE Id = ?', [$valeur, $o, $id]);
                }
                $ids[(int) $id] = $valeur;
            }
            // Valeurs retirées : variantes désactivées, puis valeur supprimée.
            foreach (array_diff_key($attr['valeurs'], $ids) as $idRetire => $_) {
                run('UPDATE Produits SET Actif = 0 WHERE Id IN (SELECT VarianteId FROM VarianteValeurs WHERE ValeurId = ?)', [$idRetire]);
                run('DELETE FROM ProduitAttributValeurs WHERE Id = ?', [$idRetire]);
            }
            $valeursRetenues[] = $ids;
        }
        // Attributs retirés : leurs variantes sont désactivées.
        foreach ($existants as $e) {
            if (!in_array((int) $e['Id'], $gardes, true)) {
                if ($e['valeurs']) {
                    $liste = implode(',', array_keys($e['valeurs']));
                    run("UPDATE Produits SET Actif = 0 WHERE Id IN (SELECT VarianteId FROM VarianteValeurs WHERE ValeurId IN ($liste))");
                }
                run('DELETE FROM ProduitAttributs WHERE Id = ?', [$e['Id']]);
            }
        }

        // 2. Combinaisons manquantes : une variante par combinaison de valeurs.
        $creees = 0;
        if ($valeursRetenues) {
            $connues = [];
            foreach (q('SELECT vv.VarianteId, GROUP_CONCAT(vv.ValeurId ORDER BY vv.ValeurId) AS Cle FROM VarianteValeurs vv
                        JOIN Produits v ON v.Id = vv.VarianteId WHERE v.ParentId = ? GROUP BY vv.VarianteId', [$m['Id']]) as $c) {
                $connues[$c['Cle']] = (int) $c['VarianteId'];
            }
            $combis = [[]];
            foreach ($valeursRetenues as $valeurs) {
                $suivantes = [];
                foreach ($combis as $c) {
                    foreach ($valeurs as $id => $valeur) {
                        $suivantes[] = $c + [$id => $valeur];
                    }
                }
                $combis = $suivantes;
            }
            foreach ($combis as $c) {
                $ids = array_keys($c);
                sort($ids);
                $cle = implode(',', $ids);
                $libelle = mb_substr(implode(' ', $c), 0, 150);
                if (isset($connues[$cle])) {
                    run('UPDATE Produits SET LibelleVariante = ? WHERE Id = ?', [$libelle, $connues[$cle]]);
                    continue;
                }
                $vid = run(
                    'INSERT INTO Produits (TenantId, Code, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif,
                        Cout, Unite, ParentId, Supplement, LibelleVariante)
                     VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, 1, ?, ?, ?, 0, ?)',
                    [$m['TenantId'], produit_code_variante($m), mb_substr($m['Nom'] . ' ' . $libelle, 0, 200), $m['CategorieId'], $m['PrixVente'],
                     $m['TauxTVA'], $m['SuiviStock'], $m['SeuilAlerte'], $m['Cout'], $m['Unite'], $m['Id'], $libelle]
                );
                foreach ($ids as $id) {
                    run('INSERT INTO VarianteValeurs (VarianteId, ValeurId) VALUES (?, ?)', [$vid, $id]);
                }
                $creees++;
            }
        }

        // 3. Le produit est un modèle tant qu'il a des variantes.
        $nb = (int) qv('SELECT COUNT(*) FROM Produits WHERE ParentId = ?', [$m['Id']]);
        run('UPDATE Produits SET EstModele = ? WHERE Id = ?', [$nb > 0 ? 1 : 0, $m['Id']]);
        produit_propager_variantes((int) $m['Id']);
        db()->commit();
    } catch (Throwable $e) {
        db()->rollBack();
        throw $e;
    }
    $retour('success', $creees ? "$creees variante(s) créée(s)." : 'Attributs enregistrés.');
}

/** Grille des variantes : code, code-barres, supplément de prix et activation. */
function produit_majvariantes(): void
{
    $m = produit_charger((int) post('id'));
    $retour = fn(string $type, string $msg) => [flash($type, $msg), redirect('produit/edit', ['id' => $m['Id']])];
    $saisies = (array) post('variante', []);
    $variantes = [];
    foreach (produit_variantes((int) $m['Id']) as $v) {
        $s = $saisies[$v['Id']] ?? null;
        if (!is_array($s)) {
            continue;
        }
        $v['Code'] = trim((string) ($s['Code'] ?? $v['Code']));
        $v['CodeBarres'] = trim((string) ($s['CodeBarres'] ?? '')) ?: null;
        // Prix TTC saisi : on garde l'écart avec le modèle (supplément) pour suivre ses changements de prix.
        $prix = isset($s['Prix']) ? montant($s['Prix']) : (float) $m['PrixVente'] + montant($s['Supplement'] ?? 0);
        $v['Supplement'] = round($prix - (float) $m['PrixVente'], 2);
        $v['Quantite'] = isset($s['Quantite']) && trim((string) $s['Quantite']) !== '' ? montant($s['Quantite']) : null;
        $v['Actif'] = empty($s['Actif']) ? 0 : 1;
        if ($v['Code'] === '') {
            $retour('danger', 'Le code de la variante « ' . $v['LibelleVariante'] . ' » est obligatoire.');
        }
        if (qv('SELECT COUNT(*) FROM Produits WHERE Code = ? AND Id <> ? AND TenantId = ?', [$v['Code'], $v['Id'], $m['TenantId']])) {
            $retour('danger', "Le code « {$v['Code']} » est déjà utilisé.");
        }
        if ($v['CodeBarres'] !== null && qv('SELECT COUNT(*) FROM Produits WHERE CodeBarres = ? AND Id <> ? AND TenantId = ?', [$v['CodeBarres'], $v['Id'], $m['TenantId']])) {
            $retour('danger', "Le code-barres « {$v['CodeBarres']} » est déjà utilisé.");
        }
        if ($prix < 0) {
            $retour('danger', 'Le prix de « ' . $v['LibelleVariante'] . ' » ne peut pas être négatif.');
        }
        $variantes[] = $v;
    }
    $codes = array_map(fn($v) => mb_strtolower($v['Code']), $variantes);
    if (count($codes) !== count(array_unique($codes))) {
        $retour('danger', 'Deux variantes ont le même code.');
    }
    // Quantité modifiée : l'écart avec le stock devient un mouvement « Inventaire ».
    $reference = 'INV-' . date('Ymd-Hi');
    $ajustees = 0;
    db()->beginTransaction();
    try {
        foreach ($variantes as $v) {
            run('UPDATE Produits SET Code = ?, CodeBarres = ?, Supplement = ?, PrixVente = ?, Actif = ? WHERE Id = ?',
                [$v['Code'], $v['CodeBarres'], $v['Supplement'], (float) $m['PrixVente'] + $v['Supplement'], $v['Actif'], $v['Id']]);
            if ($v['Quantite'] !== null && $v['SuiviStock']) {
                $stock = (float) qv('SELECT StockActuel FROM Produits WHERE Id = ? FOR UPDATE', [$v['Id']]);
                $ecart = round($v['Quantite'] - $stock, 2);
                if (abs($ecart) >= 0.01) {
                    mouvement_stock((int) $v['Id'], $ecart, 'Inventaire', $reference, null, 'Fiche produit (variantes)');
                    $ajustees++;
                }
            }
        }
        db()->commit();
    } catch (Throwable $e) {
        db()->rollBack();
        throw $e;
    }
    $retour('success', $ajustees ? "Variantes enregistrées : stock ajusté sur $ajustees variante(s) (inventaire $reference)." : 'Variantes enregistrées.');
}
