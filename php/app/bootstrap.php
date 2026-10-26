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

/** Mode de paiement « Espèces » : le seul sur lequel on peut rendre la monnaie. */
function pos_est_especes(array $mode): bool
{
    $texte = mb_strtolower(($mode['Code'] ?? '') . ' ' . ($mode['Libelle'] ?? ''));
    return (bool) preg_match('/\b(esp|espèces?|especes?|cash|liquide)\b/u', $texte);
}

/**
 * Mouvement de stock d'un produit suivi : met à jour son stock et l'enregistre dans
 * l'historique (quantité signée : + entrée, − sortie). Sans effet pour un produit
 * dont le stock n'est pas suivi. À appeler dans la transaction de l'opération.
 */
function mouvement_stock(int $produitId, float $quantite, string $type, ?string $reference = null,
                         ?int $commandeId = null, ?string $commentaire = null): void
{
    $p = q1('SELECT Id, TenantId, SuiviStock FROM Produits WHERE Id = ? FOR UPDATE', [$produitId]);
    if (!$p || !$p['SuiviStock'] || abs($quantite) < 0.0001) {
        return;
    }
    run('UPDATE Produits SET StockActuel = StockActuel + ? WHERE Id = ?', [$quantite, $produitId]);
    run(
        'INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres,
            Reference, CommandePosId, UtilisateurId, Commentaire)
         VALUES (?, ?, NOW(), ?, ?, (SELECT StockActuel FROM Produits WHERE Id = ?), ?, ?, ?, ?)',
        [$p['TenantId'], $produitId, $type, $quantite, $produitId, $reference, $commandeId, user()['id'] ?? null, $commentaire]
    );
}

/** Option de la société : vente autorisée quand le stock est épuisé ? */
function vente_sans_stock(int $tenant): bool
{
    return (bool) (qv('SELECT PosVenteSansStock FROM Tenants WHERE Id = ?', [$tenant]) ?? 1);
}

