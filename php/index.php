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
    'taxe'        => ['index', 'save', 'delete'],
    'utilisateur' => ['index', 'create', 'edit', 'delete'],
    'tenant'      => ['index', 'create', 'edit', 'prolonger', 'consulter'],
    'rapport'     => ['operations', 'preview', 'sage'],
    'facture'     => ['index', 'create', 'edit', 'ligne', 'supprimerligne', 'valider', 'print'],
    'pos'         => ['index', 'vendre', 'ticket'],
    'vente'       => ['index', 'details', 'facture', 'retour', 'annuler'],
    'stock'       => ['index', 'entree', 'inventaire', 'option'],
    'posrapport'  => ['index', 'preview', 'excel'],
    'produit'     => ['index', 'create', 'edit', 'delete', 'export', 'import'],
    'categorie'   => ['index', 'save', 'delete'],
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

// Modules d'administration (et catalogue du point de vente) réservés aux profils Admin et SuperAdmin.
if (in_array($module, ['utilisateur', 'motif', 'modepaiement', 'taxe', 'produit', 'categorie', 'stock', 'posrapport'], true)) {
    require_admin();
}

require __DIR__ . '/app/controllers/' . $module . '.php';

try {
    schema_a_jour();
    ($module . '_' . $action)();
} catch (PDOException $e) {
    error_log('[GesCaisse] ' . $e->getMessage());
    http_response_code(500);
    // Cause la plus probable, sans dévoiler le détail technique (affiché seulement en mode debug).
    $message = match ((string) $e->getCode()) {
        '1045' => "Connexion à MySQL refusée : vérifiez db_user et db_pass dans config.php.",
        '1044', '1049' => "La base indiquée dans config.php (db_name) n'existe pas ou n'est pas accessible à cet utilisateur.",
        '2002', '2005', '2006' => "Serveur MySQL injoignable : vérifiez db_host et db_port dans config.php (chez un hébergeur, souvent « localhost »).",
        '42S02' => "Une table est introuvable dans la base. Importez sql/schema.sql (ou la sauvegarde) dans la base de config.php. "
            . "Sur un serveur Linux, les noms de tables doivent garder leurs majuscules (Utilisateurs, et non utilisateurs).",
        default => "Une erreur de base de données est survenue. Vérifiez la configuration (config.php) et que le fichier sql/schema.sql a bien été importé.",
    };
    if (!empty($CONFIG['debug'])) {
        $message .= "\n\nDétail : " . $e->getMessage();
    }
    render('erreur', ['titre' => 'Erreur', 'message' => $message], user() !== null);
}
