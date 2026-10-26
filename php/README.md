# GesCaisse – version PHP / MySQL

Copie de l'application GesCaisse (.NET) en **PHP 8 sans framework** et **MySQL**.
Elle reprend les mêmes écrans et les mêmes règles : multi-société avec licences,
tableau de bord, caisses et journées (opérations, validation, clôture avec comptage),
tiers, factures, motifs, modes de paiement, utilisateurs, rapports, impressions et
export Sage.

## Prérequis

- PHP **8.1 ou plus**, avec les extensions `pdo_mysql`, `zip`, `mbstring` et `simplexml`
  (toutes activées par défaut dans XAMPP et WAMP).
- MySQL 5.7+ / 8, ou MariaDB 10.4+.
- Un navigateur avec accès Internet (Bootstrap, Font Awesome et Chart.js sont chargés depuis un CDN).

## Installation (XAMPP / WAMP)

1. Copiez le dossier `php/` dans `htdocs/` (XAMPP) ou `www/` (WAMP), et renommez-le par exemple `gescaisse`.
2. Ouvrez **phpMyAdmin** et créez une base vide nommée `gescaisse` (interclassement `utf8mb4_unicode_ci`).
3. Dans cette base, onglet **Importer**, choisissez le fichier `sql/schema.sql` et validez.
4. Ouvrez `config.php` et vérifiez l'hôte, le nom de la base, l'utilisateur et le mot de passe MySQL.
5. Ouvrez http://localhost/gescaisse/ dans le navigateur.

Mises à jour : les nouvelles tables des versions suivantes (point de vente…) sont
créées automatiquement au premier chargement d'une page, à partir des fichiers
`sql/migrations/*.sql` ; ceux déjà appliqués sont notés dans la table `MigrationsAppliquees`.

Comptes créés par `schema.sql` (mot de passe `123`, **à changer** après la première connexion) :

| Utilisateur  | Profil      | Société                  |
|--------------|-------------|--------------------------|
| `superadmin` | SuperAdmin  | toutes                   |
| `admin`      | Admin       | Société de démonstration |

## Installation sur un hébergement web

Même principe : envoyez le contenu de `php/` par FTP, créez la base MySQL depuis le panneau
de l'hébergeur, importez `sql/schema.sql` et renseignez `config.php`.
Les fichiers `.htaccess` fournis bloquent l'accès direct à `config.php`, `app/` et `sql/`
sur Apache. Sur Nginx, interdisez ces chemins dans la configuration du site.

Exemple Hostinger (hPanel → Bases de données MySQL) : la base et l'utilisateur portent un
préfixe, par exemple `u123456789_gescaisse`. Dans `config.php` :

```php
'db_host' => 'localhost',
'db_name' => 'u123456789_gescaisse',   // nom complet, avec le préfixe
'db_user' => 'u123456789_gescaisse',   // utilisateur créé avec la base
'db_pass' => 'mot de passe choisi dans hPanel',
```

Importez le fichier SQL dans cette base depuis phpMyAdmin (bouton « Importer »).
Les serveurs Linux distinguent majuscules et minuscules dans les noms de tables : importez
`sql/schema.sql` ou le fichier de reprise des données, et non un export fait depuis
XAMPP sous Windows (qui écrit les noms de tables en minuscules).

En cas de message « Une erreur de base de données », la page indique la cause probable
(identifiants, base, serveur ou table manquante). Pour voir le détail technique,
passez temporairement `'debug' => true` dans `config.php`, puis remettez `false`.

## Organisation du code

```
php/
├── index.php            point d'entrée unique : index.php?r=module/action
├── config.php           connexion MySQL, fuseau horaire
├── app/
│   ├── bootstrap.php    base de données, session, société courante, CSRF, mots de passe, aides
│   ├── xlsx.php         lecture / écriture Excel (.xlsx) sans bibliothèque externe
│   ├── controllers/     un fichier par module (fonctions module_action)
│   └── views/           pages HTML (layout.php = menu latéral et barre du haut)
├── assets/              CSS (thème M-ITECH AFRICA, menu, tableau de bord) et image de connexion
└── sql/schema.sql       structure de la base et données de départ
```

## Différences avec la version .NET

- **PDF** : les impressions (opérations d'une journée, journées d'une caisse, liste des caisses,
  rapport, facture) sont des pages prêtes à imprimer. Le bouton « Imprimer / enregistrer en PDF »
  ouvre l'impression du navigateur, qui permet d'enregistrer en PDF. Aucun outil externe
  (wkhtmltopdf) n'est nécessaire.
- **Mots de passe** : stockés avec bcrypt. Les mots de passe repris de la version .NET (SHA-256)
  restent valides et sont convertis automatiquement à la première connexion.
- **Suppressions protégées** : une caisse avec des journées, un tiers, un motif, un mode de
  paiement ou un utilisateur déjà utilisés ne peuvent pas être supprimés (message explicatif).
  On ne peut pas non plus supprimer son propre compte.
- **SuperAdmin** : en mode « Toutes les sociétés », il doit d'abord choisir une société dans le
  menu avant de créer des données (caisses, tiers, factures…), pour qu'elles soient rattachées
  à la bonne société.
- **Rapport des opérations** : la date de fin est incluse, et le montant initial correspond au
  solde initial de la première journée de chaque caisse sur la période (comme le tableau de bord).
- **Droits** : les pages Utilisateurs, Motifs et Modes de paiement sont réservées aux profils
  Admin et SuperAdmin (comme la version .NET), Sociétés au SuperAdmin. Un caissier ne voit pas la
  section « Administration » du menu.
- **Sécurité** : tous les formulaires sont protégés contre les envois frauduleux (jeton CSRF),
  et chaque requête vérifie que les données appartiennent à la société de l'utilisateur.

## Reprendre les données de la version .NET

Les tables et colonnes portent les mêmes noms que dans la base SQL Server. Pour migrer :
exportez chaque table depuis SQL Server (SSMS > Tâches > Exporter des données, au format CSV),
puis importez les CSV dans les tables MySQL correspondantes via phpMyAdmin, en commençant par
`Tenants`, puis `Utilisateurs`, `Caisses`, `Clients`, `Motifs`, `ModesPaiement`,
`JourneesCaisses`, `OperationsCaisses`, `ComptagesCloture`, `Factures`, `LignesFactures`.

## Données de démonstration du point de vente (base locale uniquement)

`sql/demo/demo_pos_mysql.sql` crée 10 catégories, 30 produits, deux livraisons de stock et environ
150 ventes sur les 14 derniers jours (une journée clôturée « -DEMO » par jour, sur la première
caisse de la société). La société visée est indiquée par son nom au début du script
(EASYTECH AFRICA GABON - LBV par défaut) ; une caisse « DEMO » et les modes Espèces / Mobile Money
sont créés s'ils manquent. À importer une seule fois dans phpMyAdmin, sur la base locale de test ;
`sql/demo/demo_pos_supprimer_mysql.sql` retire ces données. Les mêmes scripts pour SQL Server
(version .NET) sont dans le dossier `Scripts` à la racine. Ne pas envoyer `sql/demo` sur le serveur.
