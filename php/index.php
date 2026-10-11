<?php
// Point d'entrée unique : index.php?r=module/action
// (aucune réécriture d'URL nécessaire : fonctionne sur tout hébergement PHP).

require __DIR__ . '/app/bootstrap.php';

$routes = [
    'auth'        => ['login', 'logout', 'suspendue'],
    'dashboard'   => ['index'],
    'caisse'      => ['index', 'create', 'edit', 'delete', 'details', 'print'],
    'journee'     => ['create', 'details', 'operation', 'validation', 'cloturer', 'supprimer', 'printoperations', 'printjournees'],
    'client'      => ['index', 'create', 'edit', 'delete', 'export', 'import'],
    'motif'       => ['index', 'save', 'delete'],
    'modepaiement'=> ['index', 'save', 'delete'],
    'utilisateur' => ['index', 'create', 'edit', 'delete'],
    'tenant'      => ['index', 'create', 'edit', 'prolonger', 'consulter'],
    'rapport'     => ['operations', 'preview', 'sage'],
    'facture'     => ['index', 'create', 'edit', 'ligne', 'supprimerligne', 'valider', 'print'],
];

$route = (string) ($_GET['r'] ?? (user() ? 'dashboard/index' : 'auth/login'));
[$module, $action] = array_pad(explode('/', strtolower($route), 2), 2, 'index');

if (!isset($routes[$module]) || !in_array($action, $routes[$module], true)) {
    http_response_code(404);
    exit('Page introuvable.');
}

// Toutes les pages exigent une connexion, sauf l'authentification elle-même.
if ($module !== 'auth') {
    require_login();
}

csrf_check();

require __DIR__ . '/app/controllers/' . $module . '.php';

try {
    ($module . '_' . $action)();
} catch (PDOException $e) {
    error_log('[GesCaisse] ' . $e->getMessage());
    http_response_code(500);
    $message = !empty($CONFIG['debug'])
        ? $e->getMessage()
        : "Une erreur de base de données est survenue. Vérifiez la configuration (config.php) et que le fichier sql/schema.sql a bien été importé.";
    render('erreur', ['titre' => 'Erreur', 'message' => $message], user() !== null);
}
