<?php
// Socle commun : configuration, base de données, session, sécurité, aides d'affichage.

declare(strict_types=1);

$CONFIG = require __DIR__ . '/../config.php';

date_default_timezone_set($CONFIG['timezone'] ?? 'UTC');

if (!empty($CONFIG['debug'])) {
    ini_set('display_errors', '1');
    error_reporting(E_ALL);
} else {
    ini_set('display_errors', '0');
}

session_name('GESCAISSE');
session_set_cookie_params(['httponly' => true, 'samesite' => 'Lax']);
session_start();

const STATUT_REJETE = 'Rejeté';

// ---------------------------------------------------------------------------
// Base de données
// ---------------------------------------------------------------------------

function db(): PDO
{
    static $pdo = null;
    global $CONFIG;
    if ($pdo === null) {
        $dsn = sprintf(
            'mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
            $CONFIG['db_host'], (int) $CONFIG['db_port'], $CONFIG['db_name']
        );
        $pdo = new PDO($dsn, $CONFIG['db_user'], $CONFIG['db_pass'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
    }
    return $pdo;
}

/** Toutes les lignes d'une requête. */
function q(string $sql, array $params = []): array
{
    $st = db()->prepare($sql);
    $st->execute($params);
    return $st->fetchAll();
}

/** Première ligne d'une requête (ou null). */
function q1(string $sql, array $params = []): ?array
{
    $st = db()->prepare($sql);
    $st->execute($params);
    $row = $st->fetch();
    return $row === false ? null : $row;
}

/** Première colonne de la première ligne (ou null). */
function qv(string $sql, array $params = []): mixed
{
    $st = db()->prepare($sql);
    $st->execute($params);
    $v = $st->fetchColumn();
    return $v === false ? null : $v;
}

/** Exécute une requête d'écriture ; renvoie le dernier identifiant inséré. */
function run(string $sql, array $params = []): int
{
    $st = db()->prepare($sql);
    $st->execute($params);
    return (int) db()->lastInsertId();
}

/**
 * Met la base à jour : applique, une seule fois et dans l'ordre, les fichiers
 * sql/migrations/*.sql pas encore enregistrés dans la table MigrationsAppliquees.
 * Ainsi les nouvelles tables sont créées sans passer par phpMyAdmin.
 */
function schema_a_jour(): void
{
    $fichiers = glob(__DIR__ . '/../sql/migrations/*.sql') ?: [];
    if (!$fichiers) {
        return;
    }
    sort($fichiers);
    try {
        $faites = array_column(q('SELECT Nom FROM MigrationsAppliquees'), 'Nom');
    } catch (PDOException $e) {
        if ((string) $e->getCode() !== '42S02') {
            throw $e;
        }
        db()->exec('CREATE TABLE IF NOT EXISTS MigrationsAppliquees (
            Nom VARCHAR(100) NOT NULL PRIMARY KEY,
            DateApplication DATETIME NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci');
        $faites = [];
    }
    foreach ($fichiers as $fichier) {
        $nom = basename($fichier);
        if (in_array($nom, $faites, true)) {
            continue;
        }
        // Une instruction par bloc terminé par « ; » en fin de ligne ; commentaires « -- » ignorés.
        $sql = preg_replace('/^\s*--.*$/m', '', (string) file_get_contents($fichier));
        foreach (preg_split('/;\s*$/m', $sql) as $instruction) {
            if (trim($instruction) !== '') {
                db()->exec($instruction);
            }
        }
        run('INSERT INTO MigrationsAppliquees (Nom, DateApplication) VALUES (?, NOW())', [$nom]);
    }
}

// ---------------------------------------------------------------------------
// Utilisateur connecté et cloisonnement par société
// ---------------------------------------------------------------------------

function user(): ?array
{
    return $_SESSION['user'] ?? null;
}

function is_super_admin(): bool
{
    return (user()['profil'] ?? '') === 'SuperAdmin';
}

function peut_valider(): bool
{
    return !empty(user()['peutValider']);
}

/**
 * Société dont les données sont affichées : celle de l'utilisateur, ou pour le
 * SuperAdmin celle qu'il "consulte" (0 = toutes les sociétés).
 */
function tenant_id(): int
{
    if (is_super_admin()) {
        return (int) ($_SESSION['consultation'] ?? 0);
    }
    return (int) (user()['tenantId'] ?? 0);
}

// Modules du point de vente (vente, catalogue, stock, restaurant, taxes, unités) : accessibles
// seulement si la société a le module Point de vente.
const MODULES_POINT_VENTE = ['pos', 'vente', 'synchro', 'tableaulaverie', 'stock', 'posrapport', 'rapportlivraison', 'rapportlinge', 'rapportachat', 'achat', 'produit', 'categorie', 'combo', 'salle', 'cuisine', 'taxe', 'unite', 'depot', 'livreur'];

/** La société courante a-t-elle le module Point de vente ? (toujours oui pour « toutes les sociétés »). */
function module_pos_actif(): bool
{
    static $cache = [];
    $t = tenant_id();
    if ($t === 0) {
        return true;
    }
    return $cache[$t] ??= (bool) (qv('SELECT ModulePointVente FROM Tenants WHERE Id = ?', [$t]) ?? 1);
}

/**
 * Condition SQL qui limite une table à la société courante.
 * Ex. : "SELECT ... FROM Caisses c WHERE " . tf('c')
 */
function tf(string $alias = ''): string
{
    $t = tenant_id();
    if ($t === 0) {
        return '1=1';
    }
    $col = $alias === '' ? 'TenantId' : $alias . '.TenantId';
    return $col . ' = ' . $t;
}

/**
 * Société à enregistrer sur une nouvelle ligne. Le SuperAdmin en mode
 * « Toutes les sociétés » doit d'abord choisir la société concernée.
 */
function tenant_insert(): int
{
    $t = tenant_id();
    if ($t === 0) {
        flash('warning', "Choisissez d'abord la société concernée dans le menu « Société consultée », puis recommencez.");
        // Retour à la page précédente (chemin local uniquement).
        $ref = parse_url((string) ($_SERVER['HTTP_REFERER'] ?? ''));
        $retour = isset($ref['path']) ? $ref['path'] . (isset($ref['query']) ? '?' . $ref['query'] : '') : url('dashboard/index');
        header('Location: ' . $retour);
        exit;
    }
    return $t;
}

function require_login(): void
{
    if (!user()) {
        redirect('auth/login');
    }
    // Société inactive ou licence expirée : accès bloqué (sauf SuperAdmin).
    if (!is_super_admin()) {
        $t = q1('SELECT Actif, DateExpiration FROM Tenants WHERE Id = ?', [(int) user()['tenantId']]);
        if (!$t || societe_bloquee($t)) {
            redirect('auth/suspendue');
        }
    }
}

/** Profils Admin et SuperAdmin (gestion des utilisateurs et des paramètres). */
function is_admin(): bool
{
    return in_array(user()['profil'] ?? '', ['Admin', 'SuperAdmin'], true);
}

function require_admin(): void
{
    if (!is_admin()) {
        http_response_code(403);
        render('acces_refuse', [], user() !== null);
        exit;
    }
}

function require_super_admin(): void
{
    if (!is_super_admin()) {
        http_response_code(403);
        render('acces_refuse', ['reserveA' => 'au SuperAdmin'], user() !== null);
        exit;
    }
}

function societe_bloquee(array $tenant): bool
{
    if (empty($tenant['Actif'])) {
        return true;
    }
    return !empty($tenant['DateExpiration']) && $tenant['DateExpiration'] < date('Y-m-d');
}

// ---------------------------------------------------------------------------
// Mots de passe (bcrypt ; compatibilité avec le format SHA-256 de la version .NET)
// ---------------------------------------------------------------------------

function hash_mdp(string $mdp): string
{
    return password_hash($mdp, PASSWORD_DEFAULT);
}

function verifier_mdp(string $mdp, string $hash): bool
{
    if (str_starts_with($hash, '$2y$') || str_starts_with($hash, '$argon')) {
        return password_verify($mdp, $hash);
    }
    // Ancien format .NET : Base64(SHA-256(mot de passe)).
    return hash_equals($hash, base64_encode(hash('sha256', $mdp, true)));
}

// ---------------------------------------------------------------------------
// Requête HTTP, sécurité et navigation
// ---------------------------------------------------------------------------

function url(string $route, array $params = []): string
{
    $query = array_merge(['r' => $route], array_filter($params, fn($v) => $v !== null && $v !== ''));
    return 'index.php?' . str_replace('%2F', '/', http_build_query($query));
}

function redirect(string $route, array $params = []): never
{
    header('Location: ' . url($route, $params));
    exit;
}

function is_post(): bool
{
    return ($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST';
}

function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf'];
}

function csrf_field(): string
{
    return '<input type="hidden" name="_csrf" value="' . h(csrf_token()) . '">';
}

/** Refuse tout POST sans jeton CSRF valide. */
function csrf_check(): void
{
    if (!is_post()) {
        return;
    }
    $jeton = $_POST['_csrf'] ?? '';
    if (!is_string($jeton) || !hash_equals(csrf_token(), $jeton)) {
        http_response_code(400);
        exit('Formulaire expiré ou invalide. Revenez en arrière et rechargez la page.');
    }
}

function post(string $cle, mixed $defaut = null): mixed
{
    $v = $_POST[$cle] ?? $defaut;
    return is_string($v) ? trim($v) : $v;
}

function get(string $cle, mixed $defaut = null): mixed
{
    $v = $_GET[$cle] ?? $defaut;
    return is_string($v) ? trim($v) : $v;
}

/** Entier ou null (champs de formulaire facultatifs). */
function int_or_null(mixed $v): ?int
{
    return ($v === null || $v === '') ? null : (int) $v;
}

/** Montant saisi : accepte "1 500", "1500,50" ou "1500.50". */
function montant(mixed $v): float
{
    $s = str_replace([' ', "\u{00A0}", "\u{202F}", ','], ['', '', '', '.'], (string) ($v ?? '0'));
    return is_numeric($s) ? (float) $s : 0.0;
}

function flash(string $type, string $message): void
{
    $_SESSION['flash'][] = [$type, $message];
}

function flashes(): array
{
    $f = $_SESSION['flash'] ?? [];
    unset($_SESSION['flash']);
    return $f;
}

function not_found(string $message = 'Élément introuvable.'): never
{
    http_response_code(404);
    render('erreur', ['titre' => 'Introuvable', 'message' => $message]);
    exit;
}

// ---------------------------------------------------------------------------
// Affichage
// ---------------------------------------------------------------------------

/**
 * Adresse d'un fichier statique avec sa date de modification en paramètre,
 * pour que le navigateur recharge le fichier dès qu'il change (pas de cache périmé).
 */
function asset(string $chemin): string
{
    $fichier = __DIR__ . '/../' . $chemin;
    return h($chemin . (is_file($fichier) ? '?v=' . filemtime($fichier) : ''));
}

function h(mixed $v): string
{
    return htmlspecialchars((string) ($v ?? ''), ENT_QUOTES, 'UTF-8');
}

/** Montant au format français, sans décimales : 1 234 567 */
function fcfa(mixed $n): string
{
    return number_format((float) $n, 0, ',', ' ');
}

/** Quantité ou prix : sans décimales si entier, sinon 2 ; $milliers = séparateur d'espaces. */
function quantite_fr(mixed $n, bool $milliers = true): string
{
    $f = (float) $n;
    $dec = abs($f - round($f)) < 0.005 ? 0 : 2;
    return number_format($f, $dec, ',', $milliers ? ' ' : '');
}

function date_fr(?string $d, string $format = 'd/m/Y'): string
{
    if (!$d) {
        return '';
    }
    $ts = strtotime($d);
    return $ts ? date($format, $ts) : '';
}

/**
 * Pagination d'une liste de $total lignes : page demandée (?page=), bornée.
 * Renvoie les variables de partials/pagination.php, plus 'limite' (clause SQL).
 */
function paginer(int $total, string $route, array $params, string $libelle, int $parPage = 20): array
{
    $pages = max(1, (int) ceil($total / $parPage));
    $page = min(max(1, (int) get('page', 1)), $pages);
    return [
        'page' => $page, 'pages' => $pages, 'total' => $total, 'parPage' => $parPage,
        'route' => $route, 'params' => $params, 'libelle' => $libelle,
        'limite' => ' LIMIT ' . $parPage . ' OFFSET ' . (($page - 1) * $parPage),
    ];
}

/** Rend une vue de app/views et renvoie son HTML (ex. formulaire de création en modale). */
function partial(string $vue, array $data = []): string
{
    extract($data, EXTR_SKIP);
    ob_start();
    require __DIR__ . '/views/' . $vue . '.php';
    return (string) ob_get_clean();
}

/**
 * Affiche une vue de app/views. Les clés de $data deviennent des variables.
 * $layout = false pour une page autonome (connexion, impression).
 */
function render(string $vue, array $data = [], bool $layout = true): void
{
    extract($data, EXTR_SKIP);
    ob_start();
    require __DIR__ . '/views/' . $vue . '.php';
    $contenu = ob_get_clean();
    if ($layout) {
        require __DIR__ . '/views/layout.php';
    } else {
        echo $contenu;
    }
}

// ---------------------------------------------------------------------------
// Règles métier partagées
// ---------------------------------------------------------------------------

/** Totaux encaissé / décaissé d'une journée, hors opérations rejetées. */
function totaux_journee(int $journeeId): array
{
    $row = q1(
        "SELECT
            COALESCE(SUM(CASE WHEN TypeOperation = 'Encaissement' THEN Montant END), 0) AS encaisse,
            COALESCE(SUM(CASE WHEN TypeOperation = 'Décaissement' THEN Montant END), 0) AS decaisse
         FROM OperationsCaisses
         WHERE JourneeCaisseId = ? AND StatutValidation <> ?",
        [$journeeId, STATUT_REJETE]
    );
    return ['encaisse' => (float) $row['encaisse'], 'decaisse' => (float) $row['decaisse']];
}

/** Totaux par mode de paiement d'une journée (hors rejetées), triés par libellé. */
function totaux_par_mode(int $journeeId): array
{
    $rows = q(
        "SELECT o.ModePaiementId,
                COALESCE(m.Libelle, 'Non renseigné') AS Libelle,
                COALESCE(SUM(CASE WHEN o.TypeOperation = 'Encaissement' THEN o.Montant END), 0) AS Encaisse,
                COALESCE(SUM(CASE WHEN o.TypeOperation = 'Décaissement' THEN o.Montant END), 0) AS Decaisse
         FROM OperationsCaisses o
         LEFT JOIN ModesPaiement m ON m.Id = o.ModePaiementId
         WHERE o.JourneeCaisseId = ? AND o.StatutValidation <> ?
         GROUP BY o.ModePaiementId, m.Libelle
         ORDER BY Libelle",
        [$journeeId, STATUT_REJETE]
    );
    foreach ($rows as &$r) {
        $r['Encaisse'] = (float) $r['Encaisse'];
        $r['Decaisse'] = (float) $r['Decaisse'];
        $r['Net'] = $r['Encaisse'] - $r['Decaisse'];
    }
    return $rows;
}

/**
 * Solde initial proposé à l'ouverture : solde compté de la dernière journée
 * clôturée, ou solde théorique de la dernière journée encore ouverte.
 */
function journee_solde_suggere(int $caisseId): float
{
    $derniere = q1('SELECT * FROM JourneesCaisses WHERE CaisseId = ? ORDER BY DateJournee DESC, Id DESC LIMIT 1', [$caisseId]);
    if (!$derniere) {
        return 0.0;
    }
    if ($derniere['Statut'] === 'Cloturee') {
        return (float) $derniere['SoldeFinal'];
    }
    $t = totaux_journee((int) $derniere['Id']);
    return (float) $derniere['SoldeInitial'] + $t['encaisse'] - $t['decaisse'];
}

/** Remise globale sur un ticket : administrateurs et utilisateurs autorisés à valider. */
/** Annulation d'un dépôt de linge : administrateurs et utilisateurs autorisés à valider. */
function pos_peut_annuler(): bool
{
    return is_admin() || peut_valider();
}

/**
 * Droit d'accorder des remises (sur un article et globale) : [autorisé, pourcentage maximal ou null].
 * Administrateurs : toujours, sans limite ; autres : fiche de l'utilisateur (relue à chaque appel :
 * un changement fait par l'administrateur s'applique sans reconnexion).
 */
function pos_droit_remise(): array
{
    if (is_admin()) {
        return [true, null];
    }
    $u = q1('SELECT PeutRemise, RemiseMax FROM Utilisateurs WHERE Id = ?', [user()['id'] ?? 0]);
    return [(bool) ($u['PeutRemise'] ?? false), isset($u['RemiseMax']) && $u['RemiseMax'] !== null ? (float) $u['RemiseMax'] : null];
}

/**
 * Contrôle des remises d'un ticket : remises des lignes [[nom, %]…], remise globale en % (ou null).
 * Renvoie le message d'erreur, ou null si l'utilisateur a le droit.
 */
function pos_controle_remises(array $lignes, ?float $globalePct): ?string
{
    $avecRemise = array_filter($lignes, fn($l) => $l[1] > 0);
    if (!$avecRemise && !($globalePct > 0)) {
        return null;
    }
    [$peut, $max] = pos_droit_remise();
    if (!$peut) {
        return "Vous n'avez pas le droit d'accorder des remises : demandez à un administrateur.";
    }
    if ($max !== null) {
        foreach ($avecRemise as [$nom, $pct]) {
            if ($pct > $max + 0.001) {
                return 'Remise de ' . quantite_fr($pct) . ' % sur « ' . $nom . ' » : votre remise maximale est de ' . quantite_fr($max) . ' %.';
            }
        }
        if ($globalePct !== null && $globalePct > $max + 0.001) {
            return 'Remise globale de ' . quantite_fr(round($globalePct, 2)) . ' % : votre remise maximale est de ' . quantite_fr($max) . ' %.';
        }
    }
    return null;
}

/** Mode de paiement « Espèces » : le seul sur lequel on peut rendre la monnaie. */
function pos_est_especes(array $mode): bool
{
    $texte = mb_strtolower(($mode['Code'] ?? '') . ' ' . ($mode['Libelle'] ?? ''));
    return (bool) preg_match('/\b(esp|espèces?|especes?|cash|liquide)\b/u', $texte);
}

/**
 * Image envoyée par un formulaire (logo, photo de produit) : null si aucun fichier,
 * message d'erreur, ou ['type' => mime, 'donnees' => contenu]. JPG, PNG, WEBP ou GIF.
 */
function image_televersee(string $champ, int $maxOctets = 1048576): array|string|null
{
    $f = $_FILES[$champ] ?? null;
    if (!$f || ($f['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_NO_FILE) {
        return null;
    }
    if ($f['error'] !== UPLOAD_ERR_OK || $f['size'] > $maxOctets) {
        return 'Image trop lourde : ' . round($maxOctets / 1048576, 1) . ' Mo au plus.';
    }
    $info = @getimagesize($f['tmp_name']);
    $types = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
    if (!$info || !in_array($info['mime'], $types, true)) {
        return "Format d'image non reconnu : utilisez une image JPG, PNG, WEBP ou GIF.";
    }
    return ['type' => $info['mime'], 'donnees' => (string) file_get_contents($f['tmp_name'])];
}

/**
 * Enregistre (ou supprime) l'image d'un produit ou le logo d'une société, et note la date
 * de mise à jour qui sert à la fois d'indicateur de présence et de version dans l'adresse.
 */
function enregistrer_image(string $quoi, int $id, ?array $image, bool $supprimer): void
{
    [$table, $cle, $parent, $colonne] = $quoi === 'logo'
        ? ['TenantLogos', 'TenantId', 'Tenants', 'LogoMaj']
        : ['ProduitImages', 'ProduitId', 'Produits', 'ImageMaj'];
    if ($image) {
        run("REPLACE INTO $table ($cle, TypeContenu, Donnees) VALUES (?, ?, ?)", [$id, $image['type'], $image['donnees']]);
        run("UPDATE $parent SET $colonne = NOW() WHERE Id = ?", [$id]);
    } elseif ($supprimer) {
        run("DELETE FROM $table WHERE $cle = ?", [$id]);
        run("UPDATE $parent SET $colonne = NULL WHERE Id = ?", [$id]);
    }
}

/** Adresse de l'image d'un produit (null sans image) ; la version évite un cache périmé. */
function url_image_produit(array $p): ?string
{
    return empty($p['ImageMaj']) ? null : url('image/produit', ['id' => $p['Id'], 'v' => strtotime($p['ImageMaj'])]);
}

/** Adresse du logo d'une société (null sans logo). */
function url_logo(?array $t): ?string
{
    return empty($t['LogoMaj']) ? null : url('image/societe', ['id' => $t['Id'], 'v' => strtotime($t['LogoMaj'])]);
}

/** Société de l'utilisateur connecté (ou consultée par le SuperAdmin), null pour « toutes ». */
function societe_courante(): ?array
{
    return tenant_id() === 0 ? null : q1('SELECT * FROM Tenants WHERE Id = ?', [tenant_id()]);
}

/** Lignes de coordonnées d'une société : adresse, « ville, pays », téléphone, e-mail, NIF. */
function societe_coordonnees(?array $t): array
{
    if (!$t) {
        return [];
    }
    $texte = fn(string $cle) => trim((string) ($t[$cle] ?? ''));
    $lignes = [
        $texte('Adresse'),
        implode(', ', array_filter([$texte('Ville'), $texte('Pays')])),
        implode(' · ', array_filter([$texte('Telephone') !== '' ? 'Tél. ' . $texte('Telephone') : '', $texte('Email')])),
        $texte('NIF') !== '' ? 'NIF : ' . $texte('NIF') : '',
    ];
    return array_values(array_filter($lignes, fn($l) => $l !== ''));
}

/** Taxes de la société, la TVA en premier. */
function taxes_liste(?int $tenant = null): array
{
    $where = $tenant === null ? tf() : 'TenantId = ' . (int) $tenant;
    return q("SELECT * FROM Taxes WHERE $where ORDER BY ParDefaut DESC, Taux DESC, Code");
}

/** Taxes de départ d'une nouvelle société : TVA 18 % (par défaut) et CSS 1 %. */
function taxes_initiales(int $tenant): void
{
    run("INSERT INTO Taxes (TenantId, Code, Libelle, Taux, ParDefaut) VALUES (?, 'TVA', 'Taxe sur la valeur ajoutée', 18, 1), (?, 'CSS', 'Contribution spéciale de solidarité', 1, 0)",
        [$tenant, $tenant]);
}

// Unités de vente de départ d'une nouvelle société (nom affiché sur le ticket => libellé).
const UNITES_INITIALES = [
    'Unité' => "Article vendu à l'unité", 'Pièce' => 'Pièce', 'Kg' => 'Kilogramme', 'g' => 'Gramme', 'Litre' => 'Litre',
    'cl' => 'Centilitre', 'Mètre' => 'Mètre', 'Carton' => 'Carton', 'Paquet' => 'Paquet', 'Boîte' => 'Boîte', 'Sac' => 'Sac',
    'Bouteille' => 'Bouteille', 'Page' => 'Page (impression, photocopie)', 'Heure' => 'Heure (service)',
];

function unites_initiales(int $tenant): void
{
    foreach (UNITES_INITIALES as $nom => $libelle) {
        run('INSERT IGNORE INTO Unites (TenantId, Nom, Libelle) VALUES (?, ?, ?)', [$tenant, $nom, $libelle]);
    }
}

/** Noms des unités actives de la société consultée (« Unité » en premier). */
function unites_actives(): array
{
    return array_column(q("SELECT DISTINCT Nom FROM Unites WHERE Actif = 1 AND " . tf() . " ORDER BY Nom = 'Unité' DESC, Nom"), 'Nom');
}

/** Ajoute l'unité à la liste de la société si elle n'y est pas (saisie par import Excel, par exemple). */
function unite_assurer(string $nom, int $tenant): void
{
    if (trim($nom) !== '' && $tenant > 0) {
        run('INSERT IGNORE INTO Unites (TenantId, Nom) VALUES (?, ?)', [$tenant, $nom]);
    }
}

/** Taxes d'un produit (Id, Code, Taux), indexées par Id. */
function produit_taxes(int $produitId): array
{
    $taxes = [];
    foreach (q('SELECT t.Id, t.Code, t.Taux FROM ProduitTaxes pt JOIN Taxes t ON t.Id = pt.TaxeId WHERE pt.ProduitId = ? ORDER BY t.ParDefaut DESC, t.Taux DESC, t.Code', [$produitId]) as $t) {
        $taxes[(int) $t['Id']] = $t;
    }
    return $taxes;
}

/** Remplace les taxes d'un produit et met à jour son taux total (Produits.TauxTVA). */
function produit_enregistrer_taxes(int $produitId, array $taxeIds, int $tenant): void
{
    run('DELETE FROM ProduitTaxes WHERE ProduitId = ?', [$produitId]);
    foreach (array_unique(array_map('intval', $taxeIds)) as $taxeId) {
        if (q1('SELECT Id FROM Taxes WHERE Id = ? AND TenantId = ?', [$taxeId, $tenant])) {
            run('INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (?, ?)', [$produitId, $taxeId]);
        }
    }
    taxes_recalculer('p.Id = ?', [$produitId]);
}

/** Taux total des produits désignés = somme des taux de leurs taxes. */
function taxes_recalculer(string $condition, array $params): void
{
    run("UPDATE Produits p SET p.TauxTVA = (SELECT COALESCE(SUM(t.Taux), 0) FROM ProduitTaxes pt JOIN Taxes t ON t.Id = pt.TaxeId WHERE pt.ProduitId = p.Id)
         WHERE $condition", $params);
}

/**
 * Détail des taxes d'une ligne vendue : chaque taxe est calculée sur le HT de la ligne
 * (HT = TTC / (1 + taux total)) ; le code et le taux sont figés au moment de la vente.
 */
function ligne_enregistrer_taxes(int $ligneId, array $taxes, float $totalTtc, int $tenant): void
{
    $total = array_sum(array_map(fn($t) => (float) $t['Taux'], $taxes));
    if ($total <= 0) {
        return;
    }
    $ht = $totalTtc / (1 + $total / 100);
    foreach ($taxes as $t) {
        run('INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (?, ?, ?, ?, ?, ?)',
            [$tenant, $ligneId, $t['TaxeId'] ?? $t['Id'], $t['Code'], $t['Taux'], round($ht * (float) $t['Taux'] / 100, 2)]);
    }
}

/**
 * Taxes d'une vente regroupées par code et taux (« TVA 18 % » => montant). Les lignes
 * vendues avant le détail des taxes sont comptées en TVA à leur taux total.
 */
function vente_taxes(int $commandeId): array
{
    $lignes = q(
        'SELECT x.Code, x.Taux, SUM(x.Montant) AS Montant FROM LignesCommandePosTaxes x
         JOIN LignesCommandePos l ON l.Id = x.LigneCommandePosId WHERE l.CommandePosId = ?
         GROUP BY x.Code, x.Taux
         UNION ALL
         SELECT \'TVA\', l.TauxTVA, SUM(l.TotalTTC - l.TotalTTC / (1 + l.TauxTVA / 100)) FROM LignesCommandePos l
         WHERE l.CommandePosId = ? AND l.TauxTVA > 0
           AND NOT EXISTS (SELECT 1 FROM LignesCommandePosTaxes x WHERE x.LigneCommandePosId = l.Id)
         GROUP BY l.TauxTVA',
        [$commandeId, $commandeId]
    );
    $taxes = [];
    foreach ($lignes as $t) {
        $cle = $t['Code'] . ' ' . quantite_fr($t['Taux']) . ' %';
        $taxes[$cle] = ($taxes[$cle] ?? 0) + (float) $t['Montant'];
    }
    return $taxes;
}

/**
 * Dépôt par défaut de la société : reçoit le stock initial des produits et sert aux caisses sans
 * dépôt choisi. Créé (« Dépôt principal ») s'il n'existe pas encore, par exemple pour une
 * nouvelle société.
 */
function depot_par_defaut(int $tenant): int
{
    $id = qv('SELECT Id FROM Depots WHERE TenantId = ? ORDER BY ParDefaut DESC, Id LIMIT 1', [$tenant]);
    if ($id) {
        run('UPDATE Depots SET ParDefaut = 1 WHERE Id = ? AND ParDefaut = 0', [$id]);
        return (int) $id;
    }
    return (int) run("INSERT INTO Depots (TenantId, Code, Nom, Actif, ParDefaut) VALUES (?, 'DEP01', 'Dépôt principal', 1, 1)", [$tenant]);
}

/**
 * Dépôt des achats de la société (laverie : « Magasin des produits d'entretien ») : les achats y
 * entrent et les consommations en sortent ; il ne sert à aucune caisse. Créé au besoin.
 */
function depot_des_achats(int $tenant): array
{
    $d = q1('SELECT * FROM Depots WHERE TenantId = ? AND DepotAchats = 1 ORDER BY Id LIMIT 1', [$tenant]);
    if ($d) {
        if (!$d['Actif']) {
            run('UPDATE Depots SET Actif = 1 WHERE Id = ?', [$d['Id']]);
            $d['Actif'] = 1;
        }
        return $d;
    }
    depot_par_defaut($tenant);
    $n = 1;
    while (qv('SELECT COUNT(*) FROM Depots WHERE TenantId = ? AND Code = ?', [$tenant, sprintf('ACH%02d', $n)])) {
        $n++;
    }
    $id = run("INSERT INTO Depots (TenantId, Code, Nom, Actif, ParDefaut, DepotAchats) VALUES (?, ?, 'Magasin des produits d''entretien', 1, 0, 1)",
        [$tenant, sprintf('ACH%02d', $n)]);
    return q1('SELECT * FROM Depots WHERE Id = ?', [$id]);
}

/** Dépôt d'une caisse : celui choisi sur la caisse, sinon le dépôt par défaut de la société. */
function depot_caisse(int $caisseId): int
{
    $c = q1('SELECT DepotId, TenantId FROM Caisses WHERE ID = ?', [$caisseId]);
    return $c && $c['DepotId'] ? (int) $c['DepotId'] : depot_par_defaut((int) ($c['TenantId'] ?? tenant_id()));
}

/**
 * Dépôts où vend une caisse : son dépôt principal, puis ses dépôts secondaires actifs dans l'ordre
 * choisi (complément quand le stock du principal ne suffit pas).
 */
function depots_caisse(int $caisseId): array
{
    $principal = depot_caisse($caisseId);
    $secondaires = array_map('intval', array_column(q(
        'SELECT cd.DepotId FROM CaissesDepots cd JOIN Depots d ON d.Id = cd.DepotId
         WHERE cd.CaisseId = ? AND d.Actif = 1 AND cd.DepotId <> ? ORDER BY cd.Ordre, cd.DepotId',
        [$caisseId, $principal]
    ), 'DepotId'));
    return array_merge([$principal], $secondaires);
}

/** Stock disponible d'un produit pour une caisse : total de ses dépôts (principal et secondaires). */
function stock_caisse(int $produitId, array $depots): float
{
    $marques = implode(',', array_fill(0, count($depots), '?'));
    return (float) (qv("SELECT SUM(Quantite) FROM StocksDepots WHERE ProduitId = ? AND DepotId IN ($marques)",
        array_merge([$produitId], $depots)) ?? 0);
}

/**
 * Sortie de stock d'une vente (quantité positive) répartie entre les dépôts de la caisse : le dépôt
 * principal d'abord, puis les secondaires dans l'ordre, chacun à hauteur de son stock ; ce qui manque
 * encore (vente sans stock autorisée) sort du principal. Un mouvement par dépôt utilisé.
 */
function sortie_stock_caisse(int $produitId, float $quantite, string $type, ?string $reference, ?int $commandeId,
                             ?string $commentaire, array $depots): void
{
    $p = q1('SELECT SuiviStock FROM Produits WHERE Id = ? FOR UPDATE', [$produitId]);
    if (!$p || !$p['SuiviStock'] || $quantite < 0.0001) {
        return;
    }
    $parts = [];
    $reste = $quantite;
    foreach ($depots as $depot) {
        if ($reste < 0.0001) {
            break;
        }
        $prend = min($reste, max(0.0, stock_depot($produitId, (int) $depot)));
        if ($prend >= 0.0001) {
            $parts[(int) $depot] = $prend;
            $reste -= $prend;
        }
    }
    if ($reste >= 0.0001) {
        $parts[(int) $depots[0]] = ($parts[(int) $depots[0]] ?? 0) + $reste;
    }
    foreach ($parts as $depot => $q) {
        mouvement_stock($produitId, -round($q, 4), $type, $reference, $commandeId, $commentaire, $depot);
    }
}

/**
 * Annulation d'une vente : chaque quantité sortie revient dans le dépôt d'où elle est sortie
 * (d'après les mouvements « Vente » de la vente).
 */
function remise_stock_annulation(int $commandeId, string $reference, ?string $commentaire): void
{
    foreach (q("SELECT ProduitId, DepotId, SUM(Quantite) AS Q FROM MouvementsStock
                WHERE CommandePosId = ? AND TypeMouvement = 'Vente' GROUP BY ProduitId, DepotId ORDER BY ProduitId, DepotId", [$commandeId]) as $m) {
        mouvement_stock((int) $m['ProduitId'], -(float) $m['Q'], 'Annulation', $reference, $commandeId, $commentaire,
            $m['DepotId'] !== null ? (int) $m['DepotId'] : null);
    }
}

/** Quantité d'un produit dans un dépôt. */
function stock_depot(int $produitId, int $depotId): float
{
    return (float) (qv('SELECT Quantite FROM StocksDepots WHERE DepotId = ? AND ProduitId = ?', [$depotId, $produitId]) ?? 0);
}

/**
 * Mouvement de stock d'un produit suivi dans un dépôt (dépôt par défaut de la société si non
 * précisé) : met à jour le stock du dépôt et le stock total du produit, puis l'enregistre dans
 * l'historique (quantité signée : + entrée, − sortie ; « stock après » = stock du dépôt).
 * Sans effet pour un produit dont le stock n'est pas suivi. À appeler dans la transaction de l'opération.
 */
function mouvement_stock(int $produitId, float $quantite, string $type, ?string $reference = null,
                         ?int $commandeId = null, ?string $commentaire = null, ?int $depotId = null): void
{
    $p = q1('SELECT Id, TenantId, SuiviStock FROM Produits WHERE Id = ? FOR UPDATE', [$produitId]);
    if (!$p || !$p['SuiviStock'] || abs($quantite) < 0.0001) {
        return;
    }
    $depot = $depotId ?: depot_par_defaut((int) $p['TenantId']);
    run('UPDATE Produits SET StockActuel = StockActuel + ? WHERE Id = ?', [$quantite, $produitId]);
    run('INSERT INTO StocksDepots (DepotId, ProduitId, Quantite) VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE Quantite = Quantite + VALUES(Quantite)', [$depot, $produitId, $quantite]);
    run(
        'INSERT INTO MouvementsStock (TenantId, ProduitId, DepotId, DateMouvement, TypeMouvement, Quantite, StockApres,
            Reference, CommandePosId, UtilisateurId, Commentaire)
         VALUES (?, ?, ?, NOW(), ?, ?, (SELECT Quantite FROM StocksDepots WHERE DepotId = ? AND ProduitId = ?), ?, ?, ?, ?)',
        [$p['TenantId'], $produitId, $depot, $type, $quantite, $depot, $produitId, $reference, $commandeId, user()['id'] ?? null, $commentaire]
    );
}

require_once __DIR__ . '/combo.php';

/**
 * La société (toutes en mode « toutes les sociétés ») a-t-elle une caisse Restaurant ou Bar ? Sinon,
 * les éléments propres au restaurant (écran cuisine / bar, poste de préparation…) sont masqués.
 */
function restaurant_actif(): bool
{
    static $actif = null;
    return $actif ??= (bool) qv("SELECT COUNT(*) FROM Caisses WHERE TypePointVente IN ('Restaurant', 'Bar') AND " . tf());
}

/** La société (toutes en mode « toutes les sociétés ») a-t-elle une caisse Laverie ? (dépôts de linge, achats de produits) */
function laverie_actif(): bool
{
    static $actif = null;
    return $actif ??= (bool) qv("SELECT COUNT(*) FROM Caisses WHERE TypePointVente = 'Laverie' AND " . tf());
}

/**
 * Produits d'entretien à racheter (laverie) : consommables actifs dont le stock dans le dépôt des
 * achats est au niveau ou sous le seuil d'alerte. Vide si la société n'a pas de caisse Laverie ou
 * pas encore de dépôt des achats. Calculé une fois par page.
 */
function entretien_en_alerte(): array
{
    static $alertes = null;
    if ($alertes === null) {
        $alertes = laverie_actif() ? q(
            'SELECT p.Id, p.Code, p.Nom, p.Unite, p.SeuilAlerte, COALESCE(sd.Quantite, 0) AS Stock
             FROM Produits p JOIN Depots d ON d.TenantId = p.TenantId AND d.DepotAchats = 1
             LEFT JOIN StocksDepots sd ON sd.ProduitId = p.Id AND sd.DepotId = d.Id
             WHERE p.Consommable = 1 AND p.Actif = 1 AND p.SuiviStock = 1 AND p.SeuilAlerte IS NOT NULL
               AND COALESCE(sd.Quantite, 0) <= p.SeuilAlerte AND ' . tf('p') . '
             ORDER BY COALESCE(sd.Quantite, 0) - p.SeuilAlerte, p.Nom'
        ) : [];
    }
    return $alertes;
}

/**
 * Notifications de la cloche (barre du haut) : ce qui attend une action, toutes caisses confondues.
 * Pour tous : opérations en attente de validation, décaissements sans justificatif, journées ouvertes
 * depuis plus de 24 h (lien vers la plus ancienne journée concernée) ; module Point de vente :
 * livraisons à livrer (ventes payées pas encore livrées) et à encaisser (commandes confiées à un
 * livreur). Administrateurs, module Point
 * de vente : produits sous le seuil d'alerte (hors produits d'entretien), et en laverie, produits
 * d'entretien à racheter et dépôts de linge en retard. Chaque entrée : n, texte, url, icone, couleur.
 */
function notifications(): array
{
    $s = fn(int $n, string $mot) => $n . ' ' . preg_replace('/(\w+)%s/u', $n > 1 ? '$1s' : '$1', $mot);
    $liste = [];
    $ajouter = function (int $n, string $texte, string $url, string $icone, string $couleur) use (&$liste, $s): void {
        if ($n > 0) {
            $liste[] = ['n' => $n, 'texte' => $s($n, $texte), 'url' => $url, 'icone' => $icone, 'couleur' => $couleur];
        }
    };
    $base = 'FROM OperationsCaisses o JOIN JourneesCaisses j ON j.Id = o.JourneeCaisseId WHERE ' . tf('o');
    foreach ([["o.StatutValidation = 'En attente'", 'opération%s en attente de validation', 'fa-hourglass-half', '#c2410c'],
              ["o.TypeOperation = 'Décaissement' AND o.EstJustifie = 0 AND o.StatutValidation <> '" . STATUT_REJETE . "'", 'décaissement%s sans justificatif', 'fa-file-circle-exclamation', '#b45309']] as [$cond, $texte, $icone, $couleur]) {
        $n = (int) qv("SELECT COUNT(*) $base AND $cond");
        if ($n) {
            $ajouter($n, $texte, url('journee/details', ['id' => qv("SELECT o.JourneeCaisseId $base AND $cond ORDER BY o.DateOperation LIMIT 1")]), $icone, $couleur);
        }
    }
    $limite = date('Y-m-d H:i:s', time() - 86400);
    $n = (int) qv("SELECT COUNT(*) FROM JourneesCaisses j WHERE " . tf('j') . " AND j.Statut = 'Ouverte' AND j.DateOuverture < ?", [$limite]);
    if ($n) {
        $id = qv("SELECT j.Id FROM JourneesCaisses j WHERE " . tf('j') . " AND j.Statut = 'Ouverte' AND j.DateOuverture < ? ORDER BY j.DateOuverture LIMIT 1", [$limite]);
        $ajouter($n, 'journée%s ouverte%s depuis plus de 24 h', url('journee/details', ['id' => $id]), 'fa-clock', '#7c2d12');
    }
    // Livraisons à livrer : ventes payées confiées à un livreur, pas encore marquées « Livrée » (montant
    // frais compris). Administrateur : rapport des livraisons filtré ; sinon écran de vente de la journée
    // (Commandes en attente › Marquer livrée), ou la vente si sa journée est clôturée.
    if (module_pos_actif()) {
        $aLivrer = q("SELECT c.Id, c.JourneeCaisseId, c.DateCommande, c.TotalTTC + c.FraisLivraison AS Montant, j.Statut FROM CommandesPos c
                      JOIN JourneesCaisses j ON j.Id = c.JourneeCaisseId
                      WHERE c.StatutLivraison = 'À livrer' AND c.Statut <> 'Annulée' AND " . tf('c') . ' ORDER BY c.DateCommande, c.Id');
        if ($aLivrer) {
            $p = $aLivrer[0];
            $url = is_admin()
                ? url('rapportlivraison/index', ['statut' => 'À livrer', 'du' => substr($p['DateCommande'], 0, 10), 'au' => date('Y-m-d')])
                : ($p['Statut'] === 'Ouverte' ? url('pos/index', ['journee' => $p['JourneeCaisseId']]) : url('vente/details', ['id' => $p['Id']]));
            $ajouter(count($aLivrer), 'livraison%s à livrer (' . fcfa(array_sum(array_column($aLivrer, 'Montant'))) . ' FCFA)', $url, 'fa-route', '#0f766e');
        }
    }
    // Livraisons à encaisser : commandes confiées à un livreur, encaissées à son retour (montant attendu,
    // frais de livraison compris). Administrateur : rapport des livraisons filtré ; sinon écran de vente.
    if (module_pos_actif()) {
        $attentes = q('SELECT a.JourneeCaisseId, a.DateCreation, a.Total, a.Contenu, j.Statut FROM CommandesAttente a
                       JOIN JourneesCaisses j ON j.Id = a.JourneeCaisseId WHERE a.LivreurId IS NOT NULL AND ' . tf('a') . ' ORDER BY a.DateCreation');
        if ($attentes) {
            $montant = array_sum(array_map(fn($a) => (float) $a['Total'] + (float) (json_decode((string) $a['Contenu'], true)['livraison']['frais'] ?? 0), $attentes));
            $url = is_admin()
                ? url('rapportlivraison/index', ['statut' => 'À encaisser', 'du' => substr($attentes[0]['DateCreation'], 0, 10), 'au' => date('Y-m-d')])
                : url('pos/index', $attentes[0]['Statut'] === 'Ouverte' ? ['journee' => $attentes[0]['JourneeCaisseId']] : []);
            $ajouter(count($attentes), 'livraison%s à encaisser (' . fcfa($montant) . ' FCFA)', $url, 'fa-truck-fast', '#0369a1');
        }
    }
    if (is_admin() && module_pos_actif()) {
        // Ventes faites hors ligne avec des écarts (après clôture, prix, stock, plafond) à vérifier.
        $n = (int) qv('SELECT COUNT(*) FROM CommandesPos WHERE AlerteHorsLigne IS NOT NULL AND AlerteHorsLigneVue IS NULL AND ' . tf());
        if ($n) {
            $ajouter($n, 'vente%s hors ligne à vérifier', url('synchro/index'), 'fa-wifi', '#b45309');
        }
        // Postes qui ont des opérations faites hors ligne pas encore envoyées (page Synchronisation).
        $ajouter((int) qv('SELECT COUNT(*) FROM PostesHorsLigne WHERE EnAttente > 0 AND ' . tf()), 'poste%s avec des opérations hors ligne à envoyer', url('synchro/index'), 'fa-cloud-arrow-up', '#c2410c');
        $ajouter((int) qv('SELECT COUNT(*) FROM Produits WHERE SuiviStock = 1 AND Actif = 1 AND EstModele = 0 AND Consommable = 0
                           AND SeuilAlerte IS NOT NULL AND StockActuel <= SeuilAlerte AND ' . tf()),
            'produit%s sous le seuil d\'alerte', url('stock/index'), 'fa-boxes-stacked', '#dc2626');
        $ajouter(count(entretien_en_alerte()), 'produit%s d\'entretien à racheter', url('achat/stock'), 'fa-bottle-droplet', '#dc2626');
        if (laverie_actif()) {
            $ajouter((int) qv("SELECT COUNT(*) FROM DepotsLinge WHERE Statut IN ('En cours', 'Prêt') AND DateRetraitPrevue < CURDATE() AND " . tf()),
                'dépôt%s de linge en retard', url('rapportlinge/index', ['statut' => 'En retard']), 'fa-shirt', '#7c3aed');
        }
    }
    return $liste;
}

/** Option de la société : vente autorisée quand le stock est épuisé ? */
function vente_sans_stock(int $tenant): bool
{
    return (bool) (qv('SELECT PosVenteSansStock FROM Tenants WHERE Id = ?', [$tenant]) ?? 1);
}


// ---------------------------------------------------------------------------
// Clients en compte (vente à crédit)
// ---------------------------------------------------------------------------

/**
 * Soldes dus des clients en compte : [ClientId => montant]. Solde = ventes payées « par compte »
 * (retours crédités au compte déduits, ventes annulées exclues) − règlements (hors rejetés).
 * $client : un seul client ; $au (AAAA-MM-JJ) : solde à la fin de cette journée.
 */
function compte_soldes(int $tenant, ?int $client = null, ?string $au = null): array
{
    $fv = $fr = '';
    if ($au !== null) {
        $fv = ' AND cmd.DateCommande < DATE_ADD(?, INTERVAL 1 DAY)';
        $fr = ' AND o.DateOperation < DATE_ADD(?, INTERVAL 1 DAY)';
    }
    $sql = "SELECT cmd.ClientId AS Id, SUM(p.Montant) AS Montant FROM PaiementsPos p
            JOIN CommandesPos cmd ON cmd.Id = p.CommandePosId JOIN ModesPaiement m ON m.Id = p.ModePaiementId
            WHERE m.EstCompte = 1 AND cmd.Statut <> 'Annulée' AND cmd.ClientId IS NOT NULL AND cmd.TenantId = ?$fv"
        . ($client ? ' AND cmd.ClientId = ?' : '') . ' GROUP BY cmd.ClientId';
    $pv = $au !== null ? [$tenant, $au] : [$tenant];
    if ($client) {
        $pv[] = $client;
    }
    $soldes = [];
    foreach (q($sql, $pv) as $r) {
        $soldes[(int) $r['Id']] = (float) $r['Montant'];
    }
    $sql = "SELECT o.ClientId AS Id, SUM(o.Montant) AS Montant FROM OperationsCaisses o
            WHERE o.ReglementCompte = 1 AND o.StatutValidation <> 'Rejeté' AND o.ClientId IS NOT NULL AND o.TenantId = ?$fr"
        . ($client ? ' AND o.ClientId = ?' : '') . ' GROUP BY o.ClientId';
    foreach (q($sql, $pv) as $r) {
        $soldes[(int) $r['Id']] = ($soldes[(int) $r['Id']] ?? 0.0) - (float) $r['Montant'];
    }
    return $soldes;
}

/** Solde dû d'un client en compte. */
function compte_solde(int $tenant, int $client, ?string $au = null): float
{
    return compte_soldes($tenant, $client, $au)[$client] ?? 0.0;
}

/** Mode « Compte client » d'une nouvelle société (vente par compte des clients en compte). */
function compte_mode_initial(int $tenant): void
{
    run("INSERT INTO ModesPaiement (Code, Libelle, Actif, TenantId, EstCompte) VALUES ('CPT', 'Compte client', 1, ?, 1)", [$tenant]);
}
