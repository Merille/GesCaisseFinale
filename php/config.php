<?php
// Paramètres de connexion à la base MySQL. Adaptez-les à votre serveur.
// Valeurs par défaut de XAMPP / WAMP : utilisateur "root", mot de passe vide.
return [
    'db_host' => '127.0.0.1',
    'db_port' => 3306,
    'db_name' => 'gescaisse',
    'db_user' => 'root',
    'db_pass' => '',

    // Fuseau horaire utilisé pour les dates des opérations.
    'timezone' => 'Africa/Libreville',

    // Mettre à true pendant la mise au point pour afficher les erreurs PHP.
    'debug' => false,
];
