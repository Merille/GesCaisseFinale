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

# Catégorie (couleur des tuiles) et articles : n° de la grille, nom, prix Lavage, Express, Repassage, Enfants (XAF).
CATEGORIES = [
    ('Chemises et hauts', '#0369a1', [
        (6, 'Bustier simple', 2500, 5000, 1500, 2000),
        (7, 'Bustier soie', 3000, 6000, 2000, 2000),
        (11, 'Chemise cintrée', 2100, 4200, 1500, 1500),
        (12, 'Chemise pliée', 2300, 4600, 1500, 1500),
        (13, 'Chemisier fantaisiste', 2500, 5000, 1500, 2000),
        (14, 'Chemisier lin', 2500, 5000, 1500, 2000),
        (15, 'Chemisier simple', 2000, 4000, 1000, 1000),
        (17, 'Corsage', 2000, 4000, 1000, 1000)]),
    ('Vestes et blousons', '#7c3aed', [
        (2, 'Blouson épais', 4000, 8000, 2000, 3000),
        (3, 'Blouson fantaisiste', 5000, 10000, 3000, 3000),
        (4, 'Blouson simple', 4000, 8000, 2000, 3000)]),
    ('Bas', '#0f766e', [
        (1, 'Bermuda', 2000, 4000, 1000, 1000)]),
    ('Tenues et costumes', '#b45309', [
        (5, 'Boubou', 3500, 7000, 2000, 2000),
        (16, 'Combinaison', 4000, 8000, 2500, 2000),
        (18, 'Costume manche courte', 5000, 10000, 2000, 2500),
        (19, 'Costume simple', 5500, 11000, 3000, 2500)]),
    ('Linge de maison', '#2563eb', [
        (20, 'Couette', 14000, 28000, 5000, 5000)]),
    ('Accessoires et sous-vêtements', '#be185d', [
        (8, 'Caleçon', 10000, 20000, 5000, 1000),
        (9, 'Châles', 3000, 6000, 1500, 2000),
        (10, 'Chaussettes', 1500, 3000, 1500, 1000)]),
]


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
    a('-- %d articles, chacun avec l\'attribut « Prestation » et 4 variantes : Lavage, Express, Repassage,' % nb)
    a('-- Enfants (prix de la grille, en FCFA). À la caisse, une tuile par article, puis le choix de la')
    a('-- prestation. Prestations sans suivi de stock, unité « Pièce », TVA de la société si elle existe.')
    a('-- Catégories : %s.' % ', '.join(c for c, _, _ in CATEGORIES))
    a('--')
    a('-- 1. Indiquez ci-dessous le CODE de la société (Administration › Sociétés) à la place de LAVERIE, puis exécutez le script')
    a('--    sur la base de l\'application (' + ('SSMS : ouvrir le fichier, choisir la base, Exécuter' if sqlserver else 'phpMyAdmin › Importer, ou onglet SQL') + ').')
    a('-- 2. Le script peut être relancé : rien n\'est dupliqué et les prix sont remis à ceux de la grille.')
    a('-- Codes produits : %s01 à %s%02d (modèles), suivis de -01 Lavage, -02 Express, -03 Repassage, -04 Enfants.' % (PREFIXE, PREFIXE, nb))
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
          % (s(cat), s(couleur), 10 + ordre, s('Aucun'), dual, s(cat), garde))
        a('SET @c = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = %s);' % s(cat))
        for num, nom, *prix in articles:
            n += 1
            code = '%s%02d' % (PREFIXE, num)
            lavage = prix[0]
            # Modèle : prix de base = lavage ; une variante par prestation (prix = base + supplément).
            a('INSERT INTO Produits (TenantId, Code, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, Actif, Unite, EstModele, Supplement, EstCombo)')
            a("    SELECT @t, '%s', %s, @c, %d, @taux, 0, 0, 1, %s, 1, 0, 0%s WHERE NOT EXISTS (SELECT 1 FROM Produits WHERE TenantId = @t AND Code = '%s')%s;"
              % (code, s(nom), lavage, s('Pièce'), dual, code, garde))
            a("UPDATE Produits SET Nom = %s, CategorieId = @c, PrixVente = %d, EstModele = 1 WHERE TenantId = @t AND Code = '%s';" % (s(nom), lavage, code))
            modele = "(SELECT Id FROM Produits WHERE TenantId = @t AND Code = '%s')" % code
            a("INSERT INTO ProduitAttributs (ProduitId, Nom, Ordre) SELECT Id, %s, 0 FROM Produits WHERE TenantId = @t AND Code = '%s'" % (s('Prestation'), code))
            a("    AND NOT EXISTS (SELECT 1 FROM ProduitAttributs pa WHERE pa.ProduitId = Produits.Id AND pa.Nom = %s);" % s('Prestation'))
            attribut = "(SELECT MIN(Id) FROM ProduitAttributs WHERE ProduitId = %s AND Nom = %s)" % (modele, s('Prestation'))
            for k, (prestation, p) in enumerate(zip(PRESTATIONS, prix)):
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
    a('-- TVA de la société (si elle existe) sur les modèles et leurs variantes')
    a("INSERT INTO ProduitTaxes (ProduitId, TaxeId) SELECT p.Id, @tva FROM Produits p WHERE p.TenantId = @t AND @tva IS NOT NULL")
    a("    AND (p.Code IN (%s) OR p.ParentId IN (SELECT Id FROM Produits WHERE TenantId = @t AND Code IN (%s)))" % (codes, codes))
    a('    AND NOT EXISTS (SELECT 1 FROM ProduitTaxes x WHERE x.ProduitId = p.Id);')
    if sqlserver:
        a('COMMIT TRANSACTION;')
        a("SELECT N'Catalogue Hob''s-Marie installé : ' + CAST((SELECT COUNT(*) FROM Produits WHERE TenantId = @t AND Code LIKE '%s%%' AND EstModele = 1) AS nvarchar(10))" % PREFIXE)
        a("    + N' articles, ' + CAST((SELECT COUNT(*) FROM Produits WHERE TenantId = @t AND Code LIKE '%s%%-0_') AS nvarchar(10)) + N' variantes.' AS Resultat;" % PREFIXE)
        a('END')
    else:
        a('COMMIT;')
        a("SELECT IF(@t IS NULL, 'Rien n''a été modifié : société introuvable.', CONCAT('Catalogue Hob''s-Marie installé : ',")
        a("    (SELECT COUNT(*) FROM Produits WHERE TenantId = @t AND Code LIKE '%s%%' AND EstModele = 1), ' articles, '," % PREFIXE)
        a("    (SELECT COUNT(*) FROM Produits WHERE TenantId = @t AND Code LIKE '%s%%-0_'), ' variantes.')) AS Resultat;" % PREFIXE)
    return '\n'.join(l for l in L if l is not None) + '\n'


for chemin, sqlserver, enc in [('php/sql/catalogues/catalogue_hobs_marie_mysql.sql', False, 'utf-8'),
                               ('Scripts/catalogue_hobs_marie_sqlserver.sql', True, 'utf-8-sig')]:
    with open(os.path.join(RACINE, chemin), 'w', encoding=enc, newline='\n') as f:
        f.write(ecrire(sqlserver))
    print(chemin)
