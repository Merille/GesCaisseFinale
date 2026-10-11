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
