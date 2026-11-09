# Écrit les scripts de la société de démonstration « Laverie » (MySQL et SQL Server) :
#   php/sql/demo/demo_laverie_mysql.sql et Scripts/demo_laverie_sqlserver.sql.
# Usage : python3 Scripts/images_demo/generer_demo_laverie.py  (depuis la racine du dépôt)
# Les images viennent de Scripts/images_demo/<CODE>.jpg (generer_images_demo.js LAV PRE LIN KIL OPT PRO).
import os

D = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(D))
HASH_123 = 'pmWkWSBCL51Bfkhn79xPuKBKHz//H6B+mY6G9/eieuM='

SOCIETE = {'Nom': 'Laverie Éclat Blanc', 'Code': 'LAVERIE', 'Adresse': 'Avenue de la Laverie, BP 4321', 'Ville': 'Libreville',
           'Pays': 'Gabon', 'Email': 'contact@laverie.demo', 'Telephone': '+241 01 98 76 54'}
UTILISATEURS = [('laverie', 'Gérant de la laverie', 'Admin', 1), ('laverie.caisse', 'Caissière de la laverie', 'Caissier', 1)]
UNITES = [('Unité', "Article vendu à l'unité"), ('Pièce', 'Pièce'), ('Kg', 'Kilogramme'), ('g', 'Gramme'), ('Litre', 'Litre'),
          ('cl', 'Centilitre'), ('Mètre', 'Mètre'), ('Carton', 'Carton'), ('Paquet', 'Paquet'), ('Boîte', 'Boîte'), ('Sac', 'Sac'),
          ('Bouteille', 'Bouteille'), ('Page', 'Page (impression, photocopie)'), ('Heure', 'Heure (service)')]
CATEGORIES = [  # nom, couleur, articles : code, nom, prix TTC, unité, stock (None = prestation sans suivi de stock)
    ('Lavage & repassage', '#0369a1', [
        ('LAV01', 'Chemise (lavage + repassage)', 1000, 'Pièce', None),
        ('LAV02', 'Pantalon (lavage + repassage)', 1200, 'Pièce', None),
        ('LAV03', 'Robe simple (lavage + repassage)', 1500, 'Pièce', None),
        ('LAV04', 'Tenue traditionnelle / boubou', 2000, 'Pièce', None)]),
    ('Pressing', '#7c3aed', [
        ('PRE01', 'Costume 2 pièces (nettoyage à sec)', 4000, 'Pièce', None),
        ('PRE02', 'Veste / blazer (nettoyage à sec)', 2500, 'Pièce', None),
        ('PRE03', 'Robe de soirée (nettoyage à sec)', 5000, 'Pièce', None),
        ('PRE04', 'Robe de mariée (nettoyage à sec)', 15000, 'Pièce', None)]),
    ('Linge de maison', '#0f766e', [
        ('LIN01', 'Drap (lavage + repassage)', 1500, 'Pièce', None),
        ('LIN02', 'Couette / couverture', 5000, 'Pièce', None),
        ('LIN03', 'Rideau (lavage + repassage)', 2000, 'Pièce', None),
        ('LIN04', 'Tapis (nettoyage)', 6000, 'Pièce', None)]),
    ('Lavage au kilo', '#2563eb', [
        ('KIL01', 'Linge au kilo : lavage + séchage', 1000, 'Kg', None),
        ('KIL02', 'Linge au kilo : lavage + séchage + pliage', 1500, 'Kg', None),
        ('KIL03', 'Machine libre-service 8 kg', 2500, 'Unité', None),
        ('KIL04', 'Séchoir libre-service (30 min)', 1500, 'Unité', None)]),
    ('Options & services', '#c2410c', [
        ('OPT01', 'Service express (24 h)', 2000, 'Unité', None),
        ('OPT02', 'Détachage', 1000, 'Pièce', None),
        ('OPT03', 'Repassage seul', 500, 'Pièce', None),
        ('OPT04', 'Collecte et livraison à domicile', 1500, 'Unité', None)]),
    ('Produits', '#a16207', [
        ('PRO01', 'Lessive liquide 1 L', 3000, 'Bouteille', 24),
        ('PRO02', 'Assouplissant 1 L', 2500, 'Bouteille', 18),
        ('PRO03', 'Détachant 500 ml', 2000, 'Bouteille', 12),
        ('PRO04', 'Housse de protection pour vêtement', 1000, 'Unité', 40)]),
]
TIERS = [('LAVC001', 'Hôtel Le Palmier', 'Entreprise', 'Client', 'Quartier Glass, Libreville', '+241 01 11 22 33'),
         ('LAVC002', 'Nadia Ondo', 'Particulier', 'Client', 'Akanda', '+241 06 12 34 56'),
         ('LAVC003', 'Pierre Nguema', 'Particulier', 'Client', 'Owendo', '+241 07 65 43 21'),
         ('LAVF001', 'Chimie Propre SARL', 'Entreprise', 'Fournisseur', 'Zone industrielle d\'Oloumi', '+241 01 44 55 66')]


def ecrire(sqlserver):
    N = "N" if sqlserver else ""
    def s(v):
        return 'NULL' if v is None else N + "'" + str(v).replace("'", "''") + "'"
    maintenant = 'GETDATE()' if sqlserver else 'NOW()'
    dual = '' if sqlserver else ' FROM DUAL'
    L = []
    a = L.append
    a('-- =====================================================================')
    a('-- GesCaisse : société de démonstration « Laverie » — ' + ('SQL Server (version .NET)' if sqlserver else 'MySQL (version PHP)'))
    a('-- Société « %s » avec sa caisse LAV1 de type Laverie, son dépôt, ses modes de paiement,' % SOCIETE['Nom'])
    a('-- 6 catégories et 24 articles avec leur image (20 prestations sans suivi de stock et 4 produits')
    a('-- en stock), et 4 tiers (entreprises et particuliers). La société de démonstration existante')
    a('-- n\'est pas modifiée.')
    a('--')
    a('-- À exécuter sur la base LOCALE de test (jamais en production), après avoir lancé une fois l\'application.')
    a('-- Le script peut être relancé : ce qui existe déjà (société de code LAVERIE, comptes, articles…) est conservé.')
    a('-- Comptes (mot de passe 123, à changer) : laverie (administrateur), laverie.caisse (caissière).')
    a('-- Pour vendre : Caisses > LAV1 > ouvrir une journée, puis Vendre.')
    a('-- Généré par Scripts/images_demo/generer_demo_laverie.py.')
    a('-- =====================================================================')
    a('')
    if sqlserver:
        a('SET NOCOUNT ON;')
        a('SET XACT_ABORT ON;')
        a('DECLARE @t INT, @admin INT, @caissier INT, @dep INT, @tva INT, @c INT;')
        a('BEGIN TRANSACTION;')
    else:
        a('SET NAMES utf8mb4;')
        a('START TRANSACTION;')
    a('')
    a('-- Société (code LAVERIE)')
    a('INSERT INTO Tenants (Nom, Code, Actif, ModeAcces, DateCreation, PosVenteSansStock, ModulePointVente, Adresse, Ville, Pays, Email, Telephone)')
    a('    SELECT %s, %s, 1, %s, %s, 1, 1, %s, %s, %s, %s, %s%s' % (s(SOCIETE['Nom']), s(SOCIETE['Code']), s('Licence'), maintenant,
      s(SOCIETE['Adresse']), s(SOCIETE['Ville']), s(SOCIETE['Pays']), s(SOCIETE['Email']), s(SOCIETE['Telephone']), dual))
    a("    WHERE NOT EXISTS (SELECT 1 FROM Tenants WHERE Code = 'LAVERIE');")
    a("SET @t = (SELECT MIN(Id) FROM Tenants WHERE Code = 'LAVERIE');")
    a('')
    a('-- Comptes : administrateur et caissière (mot de passe 123)')
    for nom, complet, profil, valide in UTILISATEURS:
        a('INSERT INTO Utilisateurs (NomUtilisateur, MotPasse, NomComplet, Profil, PeutValiderOperations, TenantId)')
        a('    SELECT %s, %s, %s, %s, %d, @t%s WHERE NOT EXISTS (SELECT 1 FROM Utilisateurs WHERE NomUtilisateur = %s);'
          % (s(nom), s(HASH_123), s(complet), s(profil), valide, dual, s(nom)))
    a("SET @admin = (SELECT MIN(Id) FROM Utilisateurs WHERE TenantId = @t AND Profil = 'Admin');")
    a("SET @caissier = (SELECT MIN(Id) FROM Utilisateurs WHERE TenantId = @t AND Profil = 'Caissier');")
    a('')
    a('-- Unités de vente, taxes (TVA 18 % par défaut, CSS 1 %), modes de paiement et motif des ventes')
    for nom, lib in UNITES:
        a('INSERT INTO Unites (TenantId, Nom, Libelle, Actif) SELECT @t, %s, %s, 1%s WHERE NOT EXISTS (SELECT 1 FROM Unites WHERE TenantId = @t AND Nom = %s);'
          % (s(nom), s(lib), dual, s(nom)))
    for code, lib, taux, defaut in [('TVA', 'Taxe sur la valeur ajoutée', 18, 1), ('CSS', 'Contribution spéciale de solidarité', 1, 0)]:
        a('INSERT INTO Taxes (TenantId, Code, Libelle, Taux, ParDefaut) SELECT @t, %s, %s, %d, %d%s WHERE NOT EXISTS (SELECT 1 FROM Taxes WHERE TenantId = @t AND Code = %s);'
          % (s(code), s(lib), taux, defaut, dual, s(code)))
    a("SET @tva = (SELECT MIN(Id) FROM Taxes WHERE TenantId = @t AND Code = 'TVA');")
    for code, lib in [('ESP', 'Espèces'), ('MM', 'Mobile Money'), ('CB', 'Carte bancaire')]:
        a('INSERT INTO ModesPaiement (Code, Libelle, Actif, TenantId) SELECT %s, %s, 1, @t%s WHERE NOT EXISTS (SELECT 1 FROM ModesPaiement WHERE TenantId = @t AND Code = %s);'
          % (s(code), s(lib), dual, s(code)))
    a("INSERT INTO Motifs (LibelleMotif, TypeModif, TenantId) SELECT 'Vente POS', 'Client', @t%s WHERE NOT EXISTS (SELECT 1 FROM Motifs WHERE TenantId = @t AND LibelleMotif = 'Vente POS');" % dual)
    a('')
    a('-- Dépôt par défaut et caisse LAV1 de type Laverie')
    a("INSERT INTO Depots (TenantId, Code, Nom, Adresse, Actif, ParDefaut) SELECT @t, 'DEP01', %s, %s, 1, 1%s WHERE NOT EXISTS (SELECT 1 FROM Depots WHERE TenantId = @t);"
      % (s('Réserve de la laverie'), s(SOCIETE['Adresse']), dual))
    a('SET @dep = (SELECT MIN(Id) FROM Depots WHERE TenantId = @t AND ParDefaut = 1);')
    a('INSERT INTO Caisses (ChkCode, ChkDescription, CashierDefault, CustomerDefaultCode, JournalDefaultCode, TenantId, TypePointVente, ImprimerBons, DepotId)')
    a("    SELECT 'LAV1', %s, @caissier, 'C0001', 'J0001', @t, 'Laverie', 0, @dep%s WHERE NOT EXISTS (SELECT 1 FROM Caisses WHERE TenantId = @t AND ChkCode = 'LAV1');"
      % (s('Comptoir de la laverie'), dual))
    a('')
    a('-- Catégories et articles (prix TTC, TVA 18 %)')
    for ordre, (cat, couleur, articles) in enumerate(CATEGORIES, 1):
        a('INSERT INTO Categories (TenantId, Nom, Couleur, Ordre, Preparation) SELECT @t, %s, %s, %d, %s%s WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = %s);'
          % (s(cat), s(couleur), ordre, s('Aucun'), dual, s(cat)))
        a('SET @c = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = %s);' % s(cat))
        for code, nom, prix, unite, stock in articles:
            a('INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif, Cout, Unite, EstModele, Supplement, EstCombo)')
            a('    SELECT @t, %s, NULL, %s, @c, %d, 18, %d, 0, %s, 1, %s, %s, 0, 0, 0%s WHERE NOT EXISTS (SELECT 1 FROM Produits WHERE TenantId = @t AND Code = %s);'
              % (s(code), s(nom), prix, 1 if stock is not None else 0, '5' if stock is not None else 'NULL',
                 str(round(prix * 0.55)) if stock is not None else 'NULL', s(unite), dual, s(code)))
    codes = [art[0] for _, _, arts in CATEGORIES for art in arts]
    liste = ', '.join("'%s'" % c for c in codes)
    a('INSERT INTO ProduitTaxes (ProduitId, TaxeId) SELECT p.Id, @tva FROM Produits p WHERE p.TenantId = @t AND p.Code IN (%s)' % liste)
    a('    AND NOT EXISTS (SELECT 1 FROM ProduitTaxes x WHERE x.ProduitId = p.Id);')
    a('')
    a('-- Stock de départ des produits vendus (livraison du fournisseur dans le dépôt par défaut)')
    for _, _, arts in CATEGORIES:
        for code, nom, prix, unite, stock in arts:
            if stock is None:
                continue
            a("UPDATE Produits SET StockActuel = %d WHERE TenantId = @t AND Code = '%s' AND NOT EXISTS (SELECT 1 FROM StocksDepots s WHERE s.ProduitId = Produits.Id);" % (stock, code))
            a('INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, UtilisateurId, DepotId, Commentaire)')
            a("    SELECT @t, p.Id, %s, %s, %d, %d, 'BL-LAV-001', @admin, @dep, %s FROM Produits p WHERE p.TenantId = @t AND p.Code = '%s'"
              % (maintenant, s('Entrée'), stock, stock, s('Stock de départ (démo)'), code))
            a('    AND NOT EXISTS (SELECT 1 FROM StocksDepots s WHERE s.ProduitId = p.Id);')
            a("INSERT INTO StocksDepots (DepotId, ProduitId, Quantite) SELECT @dep, p.Id, %d FROM Produits p WHERE p.TenantId = @t AND p.Code = '%s'" % (stock, code))
            a('    AND NOT EXISTS (SELECT 1 FROM StocksDepots s WHERE s.ProduitId = p.Id);')
    a('')
    a('-- Images des articles (illustrations générées par Scripts/images_demo/generer_images_demo.js)')
    for c in codes:
        hexa = open(os.path.join(D, c + '.jpg'), 'rb').read().hex().upper()
        a("INSERT INTO ProduitImages (ProduitId, TypeContenu, Donnees) SELECT p.Id, 'image/jpeg', 0x%s FROM Produits p WHERE p.TenantId = @t AND p.Code = '%s'" % (hexa, c))
        a('    AND NOT EXISTS (SELECT 1 FROM ProduitImages i WHERE i.ProduitId = p.Id);')
    a('UPDATE Produits SET ImageMaj = %s WHERE TenantId = @t AND ImageMaj IS NULL AND Code IN (%s);' % (maintenant, liste))
    a('')
    a('-- Tiers : entreprises et particuliers')
    for code, nom, genre, typ, adr, tel in TIERS:
        a('INSERT INTO Clients (TenantId, CodeClient, NomSociete, Adresse, Telephone, Type, Genre) SELECT @t, %s, %s, %s, %s, %s, %s%s'
          % (s(code), s(nom), s(adr), s(tel), s(typ), s(genre), dual))
        a('    WHERE NOT EXISTS (SELECT 1 FROM Clients WHERE TenantId = @t AND CodeClient = %s);' % s(code))
    a('')
    a('COMMIT;' if not sqlserver else 'COMMIT TRANSACTION;')
    a("SELECT 'Société de démonstration « Laverie » prête : connectez-vous avec le compte laverie (mot de passe 123).' AS Resultat;"
      .replace("SELECT '", "SELECT " + N + "'"))
    return '\n'.join(L) + '\n'


for chemin, sqlserver, enc in [('php/sql/demo/demo_laverie_mysql.sql', False, 'utf-8'), ('Scripts/demo_laverie_sqlserver.sql', True, 'utf-8-sig')]:
    with open(os.path.join(RACINE, chemin), 'w', encoding=enc, newline='\n') as f:
        f.write(ecrire(sqlserver))
    print(chemin)
