# Écrit le catalogue du pressing Hob's-Marie (grille tarifaire) pour une société de GesCaisse :
#   php/sql/catalogues/catalogue_hobs_marie_mysql.sql   (version PHP / MySQL, phpMyAdmin)
#   Scripts/catalogue_hobs_marie_sqlserver.sql          (version .NET / SQL Server, SSMS)
# Chaque article devient un produit « modèle » avec l'attribut « Prestation » et 4 variantes
# (Lavage, Express, Repassage, Enfants), chacune avec son prix — comme si on l'avait saisi dans
# Configuration › Produits › Variantes. Prestations sans suivi de stock, unité « Pièce ».
# Usage (depuis la racine du dépôt) : python3 Scripts/catalogues/generer_catalogue_hobs_marie.py
# À relancer après une correction de la grille : les prix sont mis à jour à chaque exécution.
import os

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PREFIXE = 'HM'
PRESTATIONS = ['Lavage', 'Express', 'Repassage', 'Enfants']

# Familles d'articles du pressing (logiciel utilisé jusqu'ici, codes FA00001 à FA00031), dans leur ordre et
# en majuscules : elles deviennent les catégories de GesCaisse (onglets de l'écran de vente). Doublons de ce
# logiciel regroupés : « Costume » avec COSTUMES, « chemise » avec CHEMISES, « tee short » avec TEE-SHIRTS.
FAMILLES = ['ACCESSOIRES', 'JUPES', 'ROBES', 'CHEMISES', 'PANTALONS', 'JEANS', 'VESTES', 'TENUES AFRICAINES', 'DRAPS',
            'COSTUMES', 'ENSEMBLES ROBES', 'TAILLEURS', 'BLOUSONS', 'TEE-SHIRTS', 'RIDEAUX', 'ACCESSOIRES DE NUIT', 'SPORTS',
            'ROBES DE MARIÉE', 'NAPPES', 'SERVIETTES', 'ENSEMBLES', 'ENFANTS', 'ACCESSOIRES MÉDICAUX', 'TEINTURE', 'SHORTS', 'SMOKINGS']
COULEURS = ['#be185d', '#7c3aed', '#c026d3', '#0369a1', '#0f766e', '#1d4ed8', '#4338ca', '#b45309', '#2563eb', '#334155',
            '#db2777', '#9333ea', '#6d28d9', '#0891b2', '#15803d', '#831843', '#16a34a', '#a21caf', '#0e7490', '#0284c7',
            '#c2410c', '#ea580c', '#dc2626', '#a16207', '#047857', '#1e293b']
# Catégories de la première version du catalogue : retirées si elles ne contiennent plus aucun produit.
ANCIENNES = ['Chemises et hauts', 'Vestes et blousons', 'Bas', 'Tenues et costumes', 'Linge de maison', 'Accessoires et sous-vêtements']

# Grille tarifaire complète (n° 1 à 84 ; le n° 67, doublon du 66, n'est pas repris) :
# famille, n°, article, prix Lavage, Express, Repassage, Enfants (XAF ; None = case vide de la grille).
# Prix repris tels qu'imprimés, sauf l'express des n° 25, 44, 47, 52 et 75 (imprimé plus bas que le lavage) :
# fixé à 2 fois le lavage, à la demande du pressing. Un article avec un seul prix (Teinture, Pull fantaisie) est un produit simple.
ARTICLES = [
    ('SHORTS', 1, 'Bermuda', 2000, 4000, 1000, 1000),
    ('BLOUSONS', 2, 'Blouson épais', 4000, 8000, 2000, 3000),
    ('BLOUSONS', 3, 'Blouson fantaisiste', 5000, 10000, 3000, 3000),
    ('BLOUSONS', 4, 'Blouson simple', 4000, 8000, 2000, 3000),
    ('TENUES AFRICAINES', 5, 'Boubou', 3500, 7000, 2000, 2000),
    ('CHEMISES', 6, 'Bustier simple', 2500, 5000, 1500, 2000),
    ('CHEMISES', 7, 'Bustier soie', 3000, 6000, 2000, 2000),
    ('ACCESSOIRES', 8, 'Caleçon', 10000, 20000, 5000, 1000),
    ('ACCESSOIRES', 9, 'Châles', 3000, 6000, 1500, 2000),
    ('ACCESSOIRES', 10, 'Chaussettes', 1500, 3000, 1500, 1000),
    ('CHEMISES', 11, 'Chemise cintrée', 2100, 4200, 1500, 1500),
    ('CHEMISES', 12, 'Chemise pliée', 2300, 4600, 1500, 1500),
    ('CHEMISES', 13, 'Chemisier fantaisiste', 2500, 5000, 1500, 2000),
    ('CHEMISES', 14, 'Chemisier lin', 2500, 5000, 1500, 2000),
    ('CHEMISES', 15, 'Chemisier simple', 2000, 4000, 1000, 1000),
    ('ENSEMBLES', 16, 'Combinaison', 4000, 8000, 2500, 2000),
    ('CHEMISES', 17, 'Corsage', 2000, 4000, 1000, 1000),
    ('COSTUMES', 18, 'Costume manche courte', 5000, 10000, 2000, 2500),
    ('COSTUMES', 19, 'Costume simple', 5500, 11000, 3000, 2500),
    ('DRAPS', 20, 'Couette', 14000, 28000, 5000, 5000),
    ('DRAPS', 21, 'Couverture', 15000, 30000, 6000, 2000),
    ('ACCESSOIRES', 22, 'Cravate', 2000, 4000, 1000, 1000),
    ('DRAPS', 23, 'Draps', 2500, 5000, 2000, 1500),
    ('ENSEMBLES', 24, 'Ensemble jupe', 5000, 10000, 3000, 2500),
    ('ENSEMBLES', 25, 'Ensemble jupe fantaisiste', 7000, 14000, 4000, 3000),
    ('ENSEMBLES', 26, 'Ensemble jupe soie', 7000, 14000, 4000, 3000),
    ('ENSEMBLES ROBES', 27, 'Ensemble robe simple', 7000, 14000, 4000, 3000),
    ('ACCESSOIRES', 28, 'Foulard GM', 2000, 4000, 1500, None),
    ('ACCESSOIRES', 29, 'Foulard simple', 1000, 2000, 500, None),
    ('ACCESSOIRES', 30, 'Foulard soie', 2000, 4000, 1000, None),
    ('COSTUMES', 31, 'Gilet costume', 2000, 4000, 1500, None),
    ('VESTES', 32, 'Gilet maille', 2000, 4000, 1500, None),
    ('DRAPS', 33, 'Housse de couette', 5000, 10000, 3000, None),
    ('JEANS', 34, 'Jeans', 2500, 5000, 2000, 2500),
    ('JUPES', 35, 'Jupe courte', 2500, 5000, 1500, 2000),
    ('JUPES', 36, 'Jupe longue', 3000, 6000, 2000, 2000),
    ('JUPES', 37, 'Jupe plissée', 4500, 9000, 2000, 2500),
    ('JUPES', 38, 'Jupe soie', 4500, 9000, 2000, 2500),
    ('VESTES', 39, 'Manteau cape', 7500, 15000, 3000, 2500),
    ('NAPPES', 40, 'Nappe salon 12', 10500, 21000, 6000, 1000),
    ('NAPPES', 41, 'Nappe salon 6', 8500, 17000, 4000, None),
    ('ACCESSOIRES', 42, 'Noeud papillon', 1000, 2000, 500, None),
    ('PANTALONS', 43, 'Pantalon', 2000, 5000, 1500, 2000),
    ('ACCESSOIRES DE NUIT', 44, 'Peignoir de bain', 4000, 8000, 500, 2000),
    ('ENFANTS', 45, 'Peluche GM', 6000, 12000, 2500, 2000),
    ('ENFANTS', 46, 'Peluche PM', 3500, 7000, 2000, None),
    ('TEE-SHIRTS', 47, 'Polo', 4000, 8000, 1000, 1500),
    ('VESTES', 48, 'Pull épais', 3000, 5000, 1500, 1500),
    ('VESTES', 49, 'Pull fantaisie', 3000, None, None, None),
    ('VESTES', 50, 'Pull fin', 2500, 6000, 2000, 1500),
    ('ACCESSOIRES DE NUIT', 51, 'Pyjama', 3500, 7000, 2000, 2500),
    ('RIDEAUX', 52, 'Rideaux panneaux', 15000, 30000, 4000, None),
    ('RIDEAUX', 53, 'Rideaux simple', 4000, 8000, 2500, None),
    ('ROBES', 54, 'Robe fantaisiste', 8000, 16000, 4000, 4000),
    ('ROBES DE MARIÉE', 55, 'Robe mariée luxueuse', 34000, 68000, 17000, 4000),
    ('ROBES DE MARIÉE', 56, 'Robe mariée sans traîne', 25000, 50000, 13000, 4000),
    ('ROBES DE MARIÉE', 57, 'Robe mariée simple', 25000, 50000, 17000, 5000),
    ('ROBES', 58, 'Robe simple', 3500, 7000, 2000, 4000),
    ('ROBES', 59, 'Robe soie', 7000, 14000, 4000, 3000),
    ('ROBES', 60, 'Robe soirée', 17000, 34000, 8000, 5000),
    ('SERVIETTES', 61, 'Serviette de bain GM', 3000, 6000, 2000, 2000),
    ('SERVIETTES', 62, 'Serviette de bain PM', 2500, 5000, 2000, 2000),
    ('SERVIETTES', 63, 'Serviette de plage', 4000, 8000, 2000, 2000),
    ('SHORTS', 64, 'Short', 1500, 3000, 1000, 1000),
    ('SMOKINGS', 65, 'Smoking', 7000, 14000, 4000, 3000),
    ('SPORTS', 66, 'Survêtement jogging', 5000, 10000, 3000, 3000),
    ('DRAPS', 68, "Taie d'oreiller", 1000, 2000, 500, 1000),
    ('TAILLEURS', 69, 'Tailleur jupe fantaisiste', 7000, 14000, 3500, 3000),
    ('TAILLEURS', 70, 'Tailleur jupe soie', 5000, 10000, 3000, 3000),
    ('TAILLEURS', 71, 'Tailleur pantalon', 5000, 10000, 3000, 3000),
    ('TAILLEURS', 72, 'Tailleur pantalon fantaisiste', 7000, 14000, 3500, 3000),
    ('TAILLEURS', 73, 'Tailleur pantalon soie', 7000, 14000, 3500, 3000),
    ('TEINTURE', 74, 'Teinture', 10000, None, None, None),
    ('TENUES AFRICAINES', 75, 'Tenue AFB 2 pièces', 5000, 10000, 2500, 2500),
    ('TENUES AFRICAINES', 76, 'Tenue AFB 3 pièces', 7000, 14000, 4000, 3000),
    ('TENUES AFRICAINES', 77, 'Tenue AFB simple', 2500, 5000, 1500, 2000),
    ('TEE-SHIRTS', 78, 'T-shirt', 2000, 4000, 1500, 1500),
    ('VESTES', 79, 'Veste cuir', 4000, 8000, 2000, 2000),
    ('SPORTS', 80, 'Veste jogging', 1500, 3000, 1000, 2000),
    ('VESTES', 81, 'Veste manche courte', 2500, 5000, 2000, 1500),
    ('VESTES', 82, 'Veste simple', 3000, 6000, 2000, 2000),
    ('VESTES', 83, 'Veste tricot', 1500, 3000, 1000, 500),
    ('RIDEAUX', 84, 'Voilage', 2500, 5000, 2000, None),
]
CATEGORIES = [(f, COULEURS[k % len(COULEURS)], [a[1:] for a in ARTICLES if a[0] == f]) for k, f in enumerate(FAMILLES)]
assert all(a[0] in FAMILLES for a in ARTICLES)


def ecrire(sqlserver):
    N = 'N' if sqlserver else ''
    def s(v):
        return N + "'" + str(v).replace("'", "''") + "'"
    dual = '' if sqlserver else ' FROM DUAL'
    garde = '' if sqlserver else ' AND @t IS NOT NULL'
    L = []
    a = L.append
    nb = sum(len(arts) for _, _, arts in CATEGORIES)
    a('-- =====================================================================')
    a("-- GesCaisse : catalogue du pressing Hob's-Marie (grille tarifaire) — " + ('SQL Server (version .NET)' if sqlserver else 'MySQL (version PHP)'))
    a('-- %d articles de la grille tarifaire, chacun avec l\'attribut « Prestation » et une variante par prix de' % nb)
    a('-- la grille : Lavage, Express, Repassage, Enfants (FCFA) ; un article avec un seul prix est un produit simple.')
    a('-- À la caisse, une tuile par article, puis le choix de la prestation. Sans suivi de stock, unité « Pièce »,')
    a('-- TVA de la société si elle existe.')
    a('-- Catégories : les %d familles d\'articles du pressing (%s).' % (len(FAMILLES), ', '.join(FAMILLES)))
    a('--')
    a('-- 1. Indiquez ci-dessous le CODE de la société (Administration › Sociétés) à la place de LAVERIE, puis exécutez le script')
    a('--    sur la base de l\'application (' + ('SSMS : ouvrir le fichier, choisir la base, Exécuter' if sqlserver else 'phpMyAdmin › Importer, ou onglet SQL') + ').')
    a('-- 2. Le script peut être relancé : rien n\'est dupliqué et les prix sont remis à ceux de la grille.')
    a('-- Codes produits : %s + n° de la grille (%s01 à %s84), suivis de -01 Lavage, -02 Express, -03 Repassage, -04 Enfants.' % (PREFIXE, PREFIXE, PREFIXE))
    a('-- Généré par Scripts/catalogues/generer_catalogue_hobs_marie.py.')
    a('-- =====================================================================')
    a('')
    if sqlserver:
        a('SET NOCOUNT ON;')
        a('SET XACT_ABORT ON;')
        a('DECLARE @societe NVARCHAR(20) = N\'LAVERIE\';   -- <== code de la société')
        a('DECLARE @t INT, @tva INT, @taux DECIMAL(18,2), @c INT;')
    else:
        a("SET NAMES utf8mb4;")
        # Code en clair dans la requête (une variable texte peut poser un conflit de collation sous MySQL).
        a("SET @t = (SELECT MIN(Id) FROM Tenants WHERE Code = 'LAVERIE');   -- <== code de la société, entre apostrophes")
    if sqlserver:
        a('SET @t = (SELECT MIN(Id) FROM Tenants WHERE Code = @societe);')
    a("SET @tva = (SELECT MIN(Id) FROM Taxes WHERE TenantId = @t AND Code = 'TVA');")
    a('SET @taux = COALESCE((SELECT Taux FROM Taxes WHERE Id = @tva), 0);')
    if sqlserver:
        a('IF @t IS NULL')
        a("    RAISERROR(N'Société introuvable : indiquez son code dans la variable @societe en haut du script. Rien n''a été modifié.', 16, 1);")
        a('ELSE')
        a('BEGIN')
        a('BEGIN TRANSACTION;')
    else:
        a("SELECT IF(@t IS NULL, 'Société introuvable : indiquez son code en haut du script (à la place de LAVERIE). Rien ne sera modifié.', CONCAT('Société trouvée (Id ', @t, ').')) AS Verification;")
        a('START TRANSACTION;')
    n = 0
    for ordre, (cat, couleur, articles) in enumerate(CATEGORIES, 1):
        a('')
        a('-- %s' % cat)
        a('INSERT INTO Categories (TenantId, Nom, Couleur, Ordre, Preparation) SELECT @t, %s, %s, %d, %s%s WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = %s)%s;'
          % (s(cat), s(couleur), ordre, s('Aucun'), dual, s(cat), garde))
        a("UPDATE Categories SET Nom = %s, Ordre = %d WHERE TenantId = @t AND Nom = %s;" % (s(cat), ordre, s(cat)))
        a('SET @c = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = %s);' % s(cat))
        for num, nom, *prix in articles:
            n += 1
            code = '%s%02d' % (PREFIXE, num)
            lavage = prix[0]
            simple = all(p is None for p in prix[1:])
            # Modèle : prix de base = lavage ; une variante par prestation de la grille (prix = base + supplément).
            # Un seul prix : produit simple, sans variante.
            a('INSERT INTO Produits (TenantId, Code, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, Actif, Unite, EstModele, Supplement, EstCombo)')
            a("    SELECT @t, '%s', %s, @c, %d, @taux, 0, 0, 1, %s, %d, 0, 0%s WHERE NOT EXISTS (SELECT 1 FROM Produits WHERE TenantId = @t AND Code = '%s')%s;"
              % (code, s(nom), lavage, s('Pièce'), 0 if simple else 1, dual, code, garde))
            a("UPDATE Produits SET Nom = %s, CategorieId = @c, PrixVente = %d, EstModele = %d WHERE TenantId = @t AND Code = '%s';" % (s(nom), lavage, 0 if simple else 1, code))
            if simple:
                continue
            modele = "(SELECT Id FROM Produits WHERE TenantId = @t AND Code = '%s')" % code
            a("INSERT INTO ProduitAttributs (ProduitId, Nom, Ordre) SELECT Id, %s, 0 FROM Produits WHERE TenantId = @t AND Code = '%s'" % (s('Prestation'), code))
            a("    AND NOT EXISTS (SELECT 1 FROM ProduitAttributs pa WHERE pa.ProduitId = Produits.Id AND pa.Nom = %s);" % s('Prestation'))
            attribut = "(SELECT MIN(Id) FROM ProduitAttributs WHERE ProduitId = %s AND Nom = %s)" % (modele, s('Prestation'))
            for k, (prestation, p) in enumerate(zip(PRESTATIONS, prix)):
                if p is None:
                    continue
                vcode = '%s-%02d' % (code, k + 1)
                a('INSERT INTO ProduitAttributValeurs (ProduitAttributId, Valeur, Ordre) SELECT %s, %s, %d%s WHERE NOT EXISTS (SELECT 1 FROM ProduitAttributValeurs WHERE ProduitAttributId = %s AND Valeur = %s)%s;'
                  % (attribut, s(prestation), k, dual, attribut, s(prestation), garde))
                a('INSERT INTO Produits (TenantId, Code, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, Actif, Unite, ParentId, EstModele, Supplement, LibelleVariante, EstCombo)')
                a("    SELECT @t, '%s', %s, @c, %d, @taux, 0, 0, 1, %s, %s, 0, %d, %s, 0%s WHERE NOT EXISTS (SELECT 1 FROM Produits WHERE TenantId = @t AND Code = '%s')%s;"
                  % (vcode, s(nom + ' ' + prestation), p, s('Pièce'), modele, p - lavage, s(prestation), dual, vcode, garde))
                a("UPDATE Produits SET Nom = %s, CategorieId = @c, PrixVente = %d, Supplement = %d, LibelleVariante = %s WHERE TenantId = @t AND Code = '%s';"
                  % (s(nom + ' ' + prestation), p, p - lavage, s(prestation), vcode))
                a("INSERT INTO VarianteValeurs (VarianteId, ValeurId) SELECT v.Id, (SELECT MIN(Id) FROM ProduitAttributValeurs WHERE ProduitAttributId = %s AND Valeur = %s)" % (attribut, s(prestation)))
                a("    FROM Produits v WHERE v.TenantId = @t AND v.Code = '%s' AND NOT EXISTS (SELECT 1 FROM VarianteValeurs x WHERE x.VarianteId = v.Id);" % vcode)
    codes = ', '.join("'%s%02d'" % (PREFIXE, num) for _, _, arts in CATEGORIES for num, *_ in arts)
    a('')
    a('-- Catégories de la première version du catalogue, devenues vides')
    vides = ', '.join(s(c) for c in ANCIENNES)
    if sqlserver:
        a('DELETE FROM Categories WHERE TenantId = @t AND Nom IN (%s) AND NOT EXISTS (SELECT 1 FROM Produits p WHERE p.CategorieId = Categories.Id);' % vides)
    else:
        a('DELETE c FROM Categories c LEFT JOIN Produits p ON p.CategorieId = c.Id WHERE c.TenantId = @t AND c.Nom IN (%s) AND p.Id IS NULL;' % vides)
    a('')
    a('-- TVA de la société (si elle existe) sur les modèles et leurs variantes')
    a("INSERT INTO ProduitTaxes (ProduitId, TaxeId) SELECT p.Id, @tva FROM Produits p WHERE p.TenantId = @t AND @tva IS NOT NULL")
    a("    AND (p.Code IN (%s) OR p.ParentId IN (SELECT Id FROM Produits WHERE TenantId = @t AND Code IN (%s)))" % (codes, codes))
    a('    AND NOT EXISTS (SELECT 1 FROM ProduitTaxes x WHERE x.ProduitId = p.Id);')
    if sqlserver:
        a('COMMIT TRANSACTION;')
        a("SELECT N'Catalogue Hob''s-Marie installé : ' + CAST((SELECT COUNT(*) FROM Produits WHERE TenantId = @t AND Code LIKE '%s%%' AND ParentId IS NULL) AS nvarchar(10))" % PREFIXE)
        a("    + N' articles, ' + CAST((SELECT COUNT(*) FROM Produits WHERE TenantId = @t AND Code LIKE '%s%%-0_') AS nvarchar(10)) + N' variantes.' AS Resultat;" % PREFIXE)
        a('END')
    else:
        a('COMMIT;')
        a("SELECT IF(@t IS NULL, 'Rien n''a été modifié : société introuvable.', CONCAT('Catalogue Hob''s-Marie installé : ',")
        a("    (SELECT COUNT(*) FROM Produits WHERE TenantId = @t AND Code LIKE '%s%%' AND ParentId IS NULL), ' articles, '," % PREFIXE)
        a("    (SELECT COUNT(*) FROM Produits WHERE TenantId = @t AND Code LIKE '%s%%-0_'), ' variantes.')) AS Resultat;" % PREFIXE)
    return '\n'.join(l for l in L if l is not None) + '\n'


for chemin, sqlserver, enc in [('php/sql/catalogues/catalogue_hobs_marie_mysql.sql', False, 'utf-8'),
                               ('Scripts/catalogue_hobs_marie_sqlserver.sql', True, 'utf-8-sig')]:
    with open(os.path.join(RACINE, chemin), 'w', encoding=enc, newline='\n') as f:
        f.write(ecrire(sqlserver))
    print(chemin)
