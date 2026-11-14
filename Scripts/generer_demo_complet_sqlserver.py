# Écrit Scripts/gescaisse_demo_complet_sqlserver.sql : la base de démonstration COMPLÈTE de la
# version .NET (SQL Server), avec les mêmes données que la version PHP
# (php/sql/demo/gescaisse_demo_complet_mysql.sql).
#   - structure : celle que l'application crée sur une base vide (dotnet ef dbcontext script),
#     migrations notées comme appliquées dans __EFMigrationsHistory ;
#   - données : reprises du fichier MySQL (mêmes identifiants).
# Usage (depuis la racine du dépôt, outil dotnet-ef installé) :
#   python3 Scripts/generer_demo_complet_sqlserver.py
# À relancer après chaque mise à jour de la base de démonstration MySQL ou du modèle.
import hashlib, base64, os, re, subprocess, sys, tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(RACINE, 'php/sql/demo/gescaisse_demo_complet_mysql.sql')
CIBLE = os.path.join(RACINE, 'Scripts/gescaisse_demo_complet_sqlserver.sql')
TABLES_PHP_SEULEMENT = {'MigrationsAppliquees'}
# Mot de passe « 123 » au format de la version .NET (SHA-256 en base 64).
HASH_123 = base64.b64encode(hashlib.sha256(b'123').digest()).decode()
PAR_INSERT = 200


def ddl():
    with tempfile.TemporaryDirectory() as d:
        sortie = os.path.join(d, 'ddl.sql')
        ef = os.path.expanduser('~/.dotnet/tools/dotnet-ef')
        subprocess.run([ef if os.path.exists(ef) else 'dotnet-ef', 'dbcontext', 'script', '-o', sortie],
                       cwd=RACINE, check=True, capture_output=True)
        return open(sortie, encoding='utf-8-sig').read().strip()


def migrations():
    noms = sorted(f[:-3] for f in os.listdir(os.path.join(RACINE, 'Migrations'))
                  if re.match(r'^\d{14}_.*\.cs$', f) and not f.endswith('.Designer.cs'))
    version = re.search(r'"ProductVersion", "([^"]+)"', open(os.path.join(RACINE, 'Migrations/AppDbContextModelSnapshot.cs')).read()).group(1)
    return noms, version


def valeurs(texte, i):
    """Lit les n-uplets « (v1,v2,...),(...) » à partir de texte[i] ; renvoie la liste des lignes."""
    lignes, n = [], len(texte)
    while i < n and texte[i] != ';':
        if texte[i] in ', \n':
            i += 1
            continue
        assert texte[i] == '(', texte[i:i + 40]
        i += 1
        ligne = []
        while True:
            c = texte[i]
            if c == "'":
                i += 1
                morceaux = []
                while True:
                    c = texte[i]
                    if c == '\\':
                        e = texte[i + 1]
                        morceaux.append({'n': '\n', 'r': '\r', 't': '\t', '0': '\0', 'Z': '\x1a'}.get(e, e))
                        i += 2
                    elif c == "'":
                        if texte[i + 1] == "'":
                            morceaux.append("'")
                            i += 2
                        else:
                            i += 1
                            break
                    else:
                        j = i
                        while texte[j] not in "\\'":
                            j += 1
                        morceaux.append(texte[i:j])
                        i = j
                ligne.append(('s', ''.join(morceaux)))
            else:
                j = i
                while texte[j] not in ',)':
                    j += 1
                brut = texte[i:j].strip()
                i = j
                if brut == 'NULL':
                    ligne.append(('n', None))
                elif brut.startswith('0x'):
                    ligne.append(('x', brut))
                else:
                    ligne.append(('v', brut))
            if texte[i] == ',':
                i += 1
                continue
            assert texte[i] == ')'
            i += 1
            break
        lignes.append(ligne)
    return lignes, i


def lire_donnees():
    texte = open(SOURCE, encoding='utf-8').read()
    tables = []
    for m in re.finditer(r'^INSERT INTO `(\w+)` \(([^)]*)\) VALUES ', texte, re.M):
        colonnes = [c.strip(' `') for c in m.group(2).split(',')]
        lignes, _ = valeurs(texte, m.end())
        tables.append((m.group(1), colonnes, lignes))
    return tables


def sql_valeur(table, colonne, v):
    genre, x = v
    if genre == 'n':
        return 'NULL'
    if genre == 'x':
        return x
    if genre == 'v':
        return x
    if table == 'Utilisateurs' and colonne == 'MotPasse' and x.startswith('$2'):
        x = HASH_123  # mot de passe PHP (bcrypt) : remplacé par « 123 » au format .NET
    return "N'" + x.replace("'", "''") + "'"


def main():
    structure = ddl()
    identites = set(re.findall(r'CREATE TABLE \[(\w+)\] \((?:(?!\);).)*?IDENTITY', structure, re.S))
    noms, version = migrations()
    donnees = [t for t in lire_donnees() if t[0] not in TABLES_PHP_SEULEMENT]
    entete = open(SOURCE, encoding='utf-8').read().split('\nSET NAMES')[0]
    resume = [l for l in entete.splitlines() if l.startswith('--   ')]

    L = []
    a = L.append
    a('-- GesCaisse (version .NET / SQL Server) : base COMPLÈTE et à jour, avec données de démonstration.')
    a('-- Structure identique à celle que crée l\'application (toutes les migrations Entity Framework notées')
    a('-- comme appliquées) et mêmes données fictives que la version PHP (gescaisse_demo_complet_mysql.sql) :')
    L.extend(resume)
    a('--')
    a('-- Utilisation : créer une base VIDE (ex. GesCaisseDemo), puis exécuter ce script sur cette base')
    a('-- (SSMS : ouvrir le fichier, choisir la base, Exécuter ; ou : sqlcmd -S serveur -d GesCaisseDemo -f 65001 -i gescaisse_demo_complet_sqlserver.sql).')
    a('-- Faire pointer ensuite la chaîne de connexion de l\'application sur cette base.')
    a('-- Ne jamais l\'exécuter sur une base en production : ce sont des données d\'essai.')
    a('--')
    a('-- Comptes (mot de passe 123, à changer) : superadmin, admin, caissier, vendeur ; laverie et laverie.caisse (société Laverie).')
    a('-- Généré par Scripts/generer_demo_complet_sqlserver.py.')
    a('')
    a('SET NOCOUNT ON;')
    a('SET XACT_ABORT ON;')
    # Options exigées par les index filtrés (sqlcmd ne les active pas par défaut, contrairement à SSMS).
    a('SET QUOTED_IDENTIFIER ON;')
    a('SET ANSI_NULLS ON;')
    a('SET ANSI_PADDING ON;')
    a('SET ANSI_WARNINGS ON;')
    a('SET CONCAT_NULL_YIELDS_NULL ON;')
    a('SET ARITHABORT ON;')
    # Base non vide : message d'erreur, puis plus rien n'est exécuté (NOEXEC vaut pour toute la session).
    a("IF EXISTS (SELECT 1 FROM sys.tables WHERE name IN ('Tenants', '__EFMigrationsHistory'))")
    a('BEGIN')
    a("    RAISERROR(N'La base n''est pas vide : créez une base vide pour la démonstration. Rien n''a été modifié.', 16, 1);")
    a('    SET NOEXEC ON;')
    a('END')
    a('GO')
    a('')
    a('-- =====================================================================')
    a('-- Structure')
    a('-- =====================================================================')
    a(structure)
    a('')
    a('CREATE TABLE [__EFMigrationsHistory] (')
    a('    [MigrationId] nvarchar(150) NOT NULL,')
    a('    [ProductVersion] nvarchar(32) NOT NULL,')
    a('    CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])')
    a(');')
    a('INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES')
    a(',\n'.join("    (N'%s', N'%s')" % (n, version) for n in noms) + ';')
    a('GO')
    a('')
    a('-- =====================================================================')
    a('-- Données')
    a('-- =====================================================================')
    toutes = sorted(re.findall(r'CREATE TABLE \[(\w+)\]', structure))
    for t in toutes:
        a('ALTER TABLE [%s] NOCHECK CONSTRAINT ALL;' % t)
    a('GO')
    for table, colonnes, lignes in donnees:
        a('')
        a('-- %s (%d)' % (table, len(lignes)))
        if table in identites:
            a('SET IDENTITY_INSERT [%s] ON;' % table)
        cols = ', '.join('[%s]' % c for c in colonnes)
        for k in range(0, len(lignes), PAR_INSERT):
            bloc = lignes[k:k + PAR_INSERT]
            a('INSERT INTO [%s] (%s) VALUES' % (table, cols))
            a(',\n'.join('(' + ', '.join(sql_valeur(table, c, v) for c, v in zip(colonnes, l)) + ')' for l in bloc) + ';')
        if table in identites:
            a('SET IDENTITY_INSERT [%s] OFF;' % table)
        a('GO')
    a('')
    # Profils et droits : la démonstration MySQL est antérieure aux profils (créés par la migration 028
    # au premier chargement en PHP) ; ici, mêmes profils Caissier et Vendeur et rattachement des comptes.
    a('-- Profils Caissier et Vendeur de chaque société, comptes rattachés (comme la migration ProfilsDroits)')
    a("INSERT INTO Profils (TenantId, Nom, Description, Droits) SELECT t.Id, n.Nom, N'Caisse, ventes et tiers', N'tableau_bord,caisses,caisses.a,caisses.m,caisses.s,journees,journees.a,journees.m,journees.s,tiers,tiers.a,tiers.m,tiers.s,rapports,vendre,ventes,ventes.a,ventes.m,ventes.s,cuisine,cuisine.m'")
    a("FROM Tenants t CROSS JOIN (VALUES (N'Caissier'), (N'Vendeur')) AS n(Nom) WHERE NOT EXISTS (SELECT 1 FROM Profils p WHERE p.TenantId = t.Id AND p.Nom = n.Nom);")
    a("UPDATE u SET u.ProfilId = p.Id FROM Utilisateurs u JOIN Profils p ON p.TenantId = u.TenantId AND p.Nom = u.Profil")
    a("WHERE u.Profil NOT IN (N'Admin', N'SuperAdmin') AND u.ProfilId IS NULL;")
    a('GO')
    for t in toutes:
        a('ALTER TABLE [%s] WITH CHECK CHECK CONSTRAINT ALL;' % t)
    a('GO')
    a("SELECT N'Base de démonstration prête : connectez-vous avec le compte admin (mot de passe 123).' AS Resultat;")
    a('SET NOEXEC OFF;')
    with open(CIBLE, 'w', encoding='utf-8-sig', newline='\n') as f:
        f.write('\n'.join(L) + '\n')
    print(CIBLE, ':', len(donnees), 'tables,', sum(len(t[2]) for t in donnees), 'lignes')


if __name__ == '__main__':
    sys.exit(main())
