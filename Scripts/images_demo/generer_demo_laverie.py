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
TIERS = [  # code, nom, genre, type, adresse, téléphone, client en compte, plafond de crédit
    ('LAVC001', 'Hôtel Le Palmier', 'Entreprise', 'Client', 'Quartier Glass, Libreville', '+241 01 11 22 33', 1, 300000),
    ('LAVC002', 'Nadia Ondo', 'Particulier', 'Client', 'Akanda', '+241 06 12 34 56', 1, 50000),
    ('LAVC003', 'Pierre Nguema', 'Particulier', 'Client', 'Owendo', '+241 07 65 43 21', 0, None),
    ('LAVF001', 'Chimie Propre SARL', 'Entreprise', 'Fournisseur', 'Zone industrielle d\'Oloumi', '+241 01 44 55 66', 0, None)]


# 20 ventes : 5 par tiers, réparties sur 5 journées clôturées (J-5 à J-1, 4 ventes par jour).
# Chaque vente : lignes, TVA 18 % incluse, paiement, encaissement « Vente POS » au nom du tiers
# et, pour les produits en stock, sortie du dépôt de la caisse.
VENTES = [  # jour (J-n), minute de la journée, tiers, mode de paiement (CPT : par compte), lignes (code, quantité)
    (5, 545, 'LAVC001', 'CPT', [('LIN01', 12), ('LIN03', 4)]),
    (5, 640, 'LAVC002', 'ESP', [('LAV01', 3), ('LAV02', 2)]),
    (5, 830, 'LAVC003', 'ESP', [('KIL01', 4.5), ('OPT03', 2)]),
    (5, 1010, 'LAVF001', 'CB', [('LIN04', 2), ('PRE02', 1)]),
    (4, 520, 'LAVC002', 'CPT', [('PRE03', 1), ('OPT02', 1)]),
    (4, 700, 'LAVC001', 'CPT', [('LIN01', 20), ('LIN02', 6), ('OPT04', 1)]),
    (4, 905, 'LAVC003', 'ESP', [('KIL02', 6), ('PRO01', 1)]),
    (4, 1080, 'LAVF001', 'ESP', [('LAV01', 5), ('PRO04', 5)]),
    (3, 560, 'LAVC003', 'MM', [('PRE01', 1), ('LAV01', 2)]),
    (3, 760, 'LAVC001', 'CPT', [('LIN03', 8), ('OPT01', 1)]),
    (3, 880, 'LAVC002', 'ESP', [('KIL03', 2), ('KIL04', 2), ('PRO02', 1)]),
    (3, 1050, 'LAVF001', 'CB', [('PRE01', 2), ('PRE02', 2)]),
    (2, 600, 'LAVC002', 'CB', [('PRE04', 1)]),
    (2, 735, 'LAVF001', 'MM', [('KIL01', 10)]),
    (2, 915, 'LAVC001', 'CPT', [('LIN01', 15), ('LIN02', 4), ('OPT04', 1)]),
    (2, 1100, 'LAVC003', 'ESP', [('LAV03', 2), ('LAV04', 1), ('PRO03', 1)]),
    (1, 515, 'LAVC001', 'CPT', [('LIN04', 3), ('OPT01', 1)]),
    (1, 690, 'LAVC003', 'MM', [('KIL02', 3.5)]),
    (1, 860, 'LAVF001', 'ESP', [('LAV02', 4), ('OPT03', 6)]),
    (1, 1040, 'LAVC002', 'CPT', [('LAV01', 4), ('LAV03', 1), ('PRO04', 2)]),
]
# Règlements des clients en compte : jour (J-n), minute, tiers, mode, montant.
REGLEMENTS = [(2, 1000, 'LAVC001', 'ESP', 100000), (1, 1100, 'LAVC002', 'MM', 10000)]
# Dépôts de linge payés au retrait : jour du dépôt (J-n), minute, client, téléphone, statut,
# retrait prévu (jours depuis aujourd'hui), acompte (espèces), lignes (code, quantité, note).
DEPOTS = [
    (3, 600, 'Jeanne Moussavou', '077 45 12 30', 'Prêt', -1, 0, [('LAV01', 4, ''), ('LAV02', 2, 'Pli marqué')]),
    (1, 700, 'Hervé Nzé', '066 20 30 40', 'En cours', 1, 2000, [('PRE01', 1, 'Tache au revers'), ('LAV01', 2, '')]),
    (1, 960, 'Clarisse Obiang', '074 88 77 66', 'En cours', 2, 0, [('KIL01', 4.5, ''), ('LAV04', 1, 'Couleurs vives : à part')]),
]
SOLDE_INITIAL = 20000


def ventes(a, s, sqlserver):
    articles = {art[0]: art for _, _, arts in CATEGORIES for art in arts}
    N = 'N' if sqlserver else ''
    def jour(n, minute):
        if sqlserver:
            return 'DATEADD(MINUTE, %d, CAST(DATEADD(DAY, -%d, CAST(GETDATE() AS date)) AS datetime2))' % (minute, n)
        return '(DATE_SUB(CURDATE(), INTERVAL %d DAY) + INTERVAL %d MINUTE)' % (n, minute)
    def dstr(n):
        if sqlserver:
            return "FORMAT(DATEADD(DAY, -%d, GETDATE()), 'yyyyMMdd')" % n
        return "DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL %d DAY), '%%Y%%m%%d')" % n
    def concat(*parts):
        return ('CONCAT(%s)' % ', '.join(parts)) if not sqlserver else ' + '.join(parts)
    # MySQL : chaque instruction est conditionnée par « @ventes = 0 » ; SQL Server : un bloc IF.
    g = '' if sqlserver else ' AND @ventes = 0'
    w = '' if sqlserver else ' WHERE @ventes = 0'
    dual = '' if sqlserver else ' FROM DUAL'
    last = 'SCOPE_IDENTITY()' if sqlserver else 'LAST_INSERT_ID()'

    a('-- Ventes de démonstration aux tiers (une seule fois : ignorées si elles existent déjà)')
    # Caisse de la laverie (LAV1, ou la caisse de type Laverie si elle a été renommée) et son code.
    a("SET @caisse = COALESCE((SELECT MIN(ID) FROM Caisses WHERE TenantId = @t AND ChkCode = 'LAV1'),")
    a("                       (SELECT MIN(ID) FROM Caisses WHERE TenantId = @t AND TypePointVente = 'Laverie'),")
    a("                       (SELECT MIN(ID) FROM Caisses WHERE TenantId = @t));")
    a("SET @code = (SELECT ChkCode FROM Caisses WHERE ID = @caisse);")
    # Modes de paiement (repli sur le premier mode actif s'ils ont été renommés).
    for v, code in [('@esp', 'ESP'), ('@mm', 'MM'), ('@cb', 'CB')]:
        a("SET %s = COALESCE((SELECT MIN(Id) FROM ModesPaiement WHERE TenantId = @t AND Code = '%s'), (SELECT MIN(Id) FROM ModesPaiement WHERE TenantId = @t AND Actif = 1));" % (v, code))
    a("SET @cpt = (SELECT MIN(Id) FROM ModesPaiement WHERE TenantId = @t AND EstCompte = 1);")
    a("SET @motif = (SELECT MIN(ID) FROM Motifs WHERE TenantId = @t AND LibelleMotif = 'Vente POS');")
    a("INSERT INTO Motifs (LibelleMotif, TypeModif, TenantId) SELECT %s, 'Client', @t%s WHERE NOT EXISTS (SELECT 1 FROM Motifs WHERE TenantId = @t AND LibelleMotif = %s);"
      % (N + "'Règlement client'", dual, N + "'Règlement client'"))
    a("SET @motifRegl = (SELECT MIN(ID) FROM Motifs WHERE TenantId = @t AND LibelleMotif = %s);" % (N + "'Règlement client'"))
    a("SET @ventes = (SELECT COUNT(*) FROM CommandesPos WHERE TenantId = @t AND CleClient LIKE 'demo-lav-%');")
    if sqlserver:
        a('IF @ventes = 0')
        a('BEGIN')
    for n in sorted({v[0] for v in VENTES}, reverse=True):
        du_jour = [v for v in VENTES if v[0] == n]
        # Fond de caisse en fin de journée : ventes payées (hors compte) et règlements reçus.
        total = 0
        for v in du_jour:
            if v[3] != 'CPT':
                total += sum(round(articles[c][2] * q) for c, q in v[4])
        total += sum(r[4] for r in REGLEMENTS if r[0] == n)
        num_j = concat('@code', "'-'", dstr(n), "'-DEMO'")
        a('')
        a('-- Journée J-%d (clôturée)' % n)
        a('INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)')
        a("    SELECT @t, @caisse, %s, %s, %s, %s, %d, %d, 0, %s, 'Cloturee'%s%s;"
          % (num_j, ('CAST(DATEADD(DAY, -%d, GETDATE()) AS date)' % n) if sqlserver else 'DATE_SUB(CURDATE(), INTERVAL %d DAY)' % n,
             jour(n, 480), jour(n, 1170), SOLDE_INITIAL, SOLDE_INITIAL + total, N + "'Journée de démonstration'", dual, w))
        a('SET @j = %s;' % last)
        for k, (_, minute, tiers, mode, lignes) in enumerate(du_jour, 1):
            num = concat("'POS-'", '@code', "'-'", dstr(n), "'-D%03d'" % k)
            ttc = sum(round(articles[c][2] * q) for c, q in lignes)
            taxes = [round(round(articles[c][2] * q) - round(articles[c][2] * q) / 1.18, 2) for c, q in lignes]
            tva = round(sum(taxes))
            date = jour(n, minute)
            a('INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut, RemiseGlobale, Pourboire)')
            a("    SELECT @t, %s, %s, @j, (SELECT MIN(Id) FROM Clients WHERE TenantId = @t AND CodeClient = '%s'), @caissier, %s, %d, %d, %d, %d, 0, %s, 0, 0%s%s;"
              % (num, concat("'demo-lav-'", num), tiers, date, ttc - tva, tva, ttc, ttc, N + "'Payée'", dual, w))
            a('SET @cmd = %s;' % last)
            for (c, q), taxe in zip(lignes, taxes):
                code, nom, prix, unite, stock = articles[c]
                qte = ('%g' % q).replace(',', '.')
                ligne_ttc = round(prix * q)
                a('INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC, RemiseGlobale)')
                a("    SELECT @t, @cmd, Id, Nom, %s, %d, 0, 18, %d, 0 FROM Produits WHERE TenantId = @t AND Code = '%s'%s;" % (qte, prix, ligne_ttc, c, g))
                a('SET @l = %s;' % last)
                a("INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) SELECT @t, @l, @tva, 'TVA', 18, %.2f%s%s;" % (taxe, dual, w))
                if stock is not None:
                    a("UPDATE Produits SET StockActuel = StockActuel - %s WHERE TenantId = @t AND Code = '%s'%s;" % (qte, c, g))
                    a("UPDATE StocksDepots SET Quantite = Quantite - %s WHERE DepotId = @dep AND ProduitId = (SELECT Id FROM Produits WHERE TenantId = @t AND Code = '%s')%s;" % (qte, c, g))
                    a('INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, DepotId, Commentaire)')
                    a("    SELECT @t, p.Id, %s, 'Vente', -%s, s.Quantite, %s, @cmd, @caissier, @dep, NULL FROM Produits p JOIN StocksDepots s ON s.ProduitId = p.Id AND s.DepotId = @dep"
                      % (date, qte, num))
                    a("    WHERE p.TenantId = @t AND p.Code = '%s'%s;" % (c, g))
            mv = {'ESP': '@esp', 'MM': '@mm', 'CB': '@cb', 'CPT': '@cpt'}[mode]
            if mode == 'CPT':
                # Vente par compte : pas d'encaissement en caisse, le montant s'ajoute au solde dû.
                a('INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)')
                a("    SELECT @t, @cmd, Id, Libelle, %d, %d, NULL FROM ModesPaiement WHERE Id = @cpt%s;" % (ttc, ttc, g))
                continue
            a('INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)')
            a("    SELECT @t, @j, %s, 'Encaissement', %d, %s, (SELECT MIN(Id) FROM Clients WHERE TenantId = @t AND CodeClient = '%s'), @motif, %s, @caissier, 1, %s, 'Point de vente'%s%s;"
              % (date, ttc, concat("'Vente POS '", num), tiers, mv, N + "'Validé'", dual, w))
            a('SET @op = %s;' % last)
            a('INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)')
            a("    SELECT @t, @cmd, Id, Libelle, %d, %d, @op FROM ModesPaiement WHERE Id = %s%s;" % (ttc, ttc, mv, g))
        for jr, minute, tiers, mode, montant in [r for r in REGLEMENTS if r[0] == n]:
            nom = [t[1] for t in TIERS if t[0] == tiers][0]
            a('INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur, ReglementCompte)')
            a("    SELECT @t, @j, %s, 'Encaissement', %d, %s, (SELECT MIN(Id) FROM Clients WHERE TenantId = @t AND CodeClient = '%s'), @motifRegl, %s, @caissier, 1, %s, %s, 1%s%s;"
              % (jour(n, minute), montant, N + "'Règlement compte client %s — %s'" % (tiers, nom.replace("'", "''")), tiers,
                 {'ESP': '@esp', 'MM': '@mm', 'CB': '@cb'}[mode], N + "'Validé'", N + "'Caissière de la laverie'", dual, w))
    if sqlserver:
        a('END')
    depots(a, sqlserver, jour, concat, dstr, dual, last)


def depots(a, sqlserver, jour, concat, dstr, dual, last):
    """Dépôts de linge de démonstration (une seule fois) ; l'acompte est encaissé dans la journée du dépôt."""
    articles = {art[0]: art for _, _, arts in CATEGORIES for art in arts}
    N = 'N' if sqlserver else ''
    g = '' if sqlserver else ' AND @depots = 0'
    w = '' if sqlserver else ' WHERE @depots = 0'
    a('')
    a('-- Dépôts de linge payés au retrait (une seule fois : ignorés s\'ils existent déjà)')
    a("SET @depots = (SELECT COUNT(*) FROM DepotsLinge WHERE TenantId = @t AND CleClient LIKE 'demo-lav-%');")
    a('SET @num = (SELECT COALESCE(MAX(Numero), 0) FROM DepotsLinge WHERE TenantId = @t);')
    a("INSERT INTO Motifs (LibelleMotif, TypeModif, TenantId) SELECT 'Acompte laverie', 'Client', @t%s WHERE NOT EXISTS (SELECT 1 FROM Motifs WHERE TenantId = @t AND LibelleMotif = 'Acompte laverie');" % dual)
    a("SET @motifAcompte = (SELECT MIN(ID) FROM Motifs WHERE TenantId = @t AND LibelleMotif = 'Acompte laverie');")
    if sqlserver:
        a('IF @depots = 0')
        a('BEGIN')
    for k, (n, minute, nom, tel, statut, retrait, acompte, lignes) in enumerate(DEPOTS, 1):
        a("SET @jd = (SELECT MIN(Id) FROM JourneesCaisses WHERE TenantId = @t AND CaisseId = @caisse AND NumeroJournee = %s);" % concat('@code', "'-'", dstr(n), "'-DEMO'"))
        total = sum(round(articles[c][2] * q) for c, q, _ in lignes)
        def entier(sql_id):
            return ('CAST(%s AS nvarchar(20))' % sql_id) if sqlserver else sql_id
        parties = []
        for i, (c, q, note) in enumerate(lignes, 1):
            code, nomart, prix, unite, _ = articles[c]
            parties.append("'%s{\"uid\":\"demo-lav-d%d-%d\",\"produitId\":'" % (',' if i > 1 else '', k, i))
            parties.append(entier("(SELECT Id FROM Produits WHERE TenantId = @t AND Code = '%s')" % c))
            parties.append(N + "',\"nom\":\"%s\",\"qte\":%s,\"prix\":%d,\"remise\":0,\"tva\":18,\"unite\":\"%s\",\"note\":\"%s\",\"envoye\":0,\"composants\":[]}'"
                           % (nomart.replace("'", "''"), ('%g' % q), prix, unite, note.replace("'", "''")))
        contenu = concat(N + "'{\"lignes\":['", *parties, "']" + ',\"clientId\":null,\"remise\":null}' + "'")
        date = jour(n, minute)
        retrait_sql = ('CAST(DATEADD(DAY, %d, GETDATE()) AS date)' % retrait) if sqlserver else ('DATE_ADD(CURDATE(), INTERVAL %d DAY)' % retrait)
        op = 'NULL'
        if acompte:
            a('INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)')
            a("    SELECT @t, @jd, %s, 'Encaissement', %d, %s, NULL, @motifAcompte, @esp, @caissier, 1, %s, 'Point de vente'%s%s;"
              % (date, acompte, concat(N + "'Acompte dépôt de linge n° '", entier('@num + %d' % k), N + "' (%s)'" % nom), N + "'Validé'", dual, w))
            a('SET @op = %s;' % last)
            a('UPDATE JourneesCaisses SET SoldeFinal = SoldeFinal + %d WHERE Id = @jd%s;' % (acompte, g))
            op = '@op'
        a('INSERT INTO DepotsLinge (TenantId, CaisseId, JourneeCaisseId, Numero, CleClient, DateDepot, DateRetraitPrevue, NomClient, TelephoneClient, ClientId, UtilisateurId,')
        a('    Contenu, Total, NbArticles, Acompte, AcompteModePaiementId, AcompteOperationId, Statut, DatePret)')
        a("    SELECT @t, @caisse, @jd, @num + %d, 'demo-lav-depot-%d', %s, %s, %s, '%s', NULL, @caissier, %s, %d, %s, %d, %s, %s, %s, %s%s%s;"
          % (k, k, date, retrait_sql, N + "'%s'" % nom.replace("'", "''"), tel, contenu, total, '%g' % sum(q for _, q, _ in lignes), acompte,
             '@esp' if acompte else 'NULL', op, N + "'%s'" % statut, jour(max(n - 1, 0), 900) if statut == 'Prêt' else 'NULL', dual, w))
    if sqlserver:
        a('END')


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
    a('-- en stock), 4 tiers (entreprises et particuliers, dont 2 clients en compte) et 20 ventes à ces')
    a('-- tiers (5 chacun, dont 7 par compte, et 2 règlements) sur les 5 jours précédant l\'exécution,')
    a('-- en journées clôturées. Mode « Compte client » créé. La société de démonstration existante')
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
        a('DECLARE @caisse INT, @code NVARCHAR(50), @motif INT, @motifRegl INT, @ventes INT, @j INT, @cmd INT, @l INT, @op INT, @esp INT, @mm INT, @cb INT, @cpt INT;')
        a('DECLARE @depots INT, @num INT, @jd INT, @motifAcompte INT;')
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
    # Mode « Compte client » (vente par compte des clients en compte).
    a("INSERT INTO ModesPaiement (Code, Libelle, Actif, TenantId, EstCompte) SELECT 'CPT', %s, 1, @t, 1%s WHERE NOT EXISTS (SELECT 1 FROM ModesPaiement WHERE TenantId = @t AND EstCompte = 1);"
      % (s('Compte client'), dual))
    a("INSERT INTO Motifs (LibelleMotif, TypeModif, TenantId) SELECT 'Vente POS', 'Client', @t%s WHERE NOT EXISTS (SELECT 1 FROM Motifs WHERE TenantId = @t AND LibelleMotif = 'Vente POS');" % dual)
    a('')
    a('-- Dépôt par défaut et caisse LAV1 de type Laverie (créés seulement si la société n\'en a pas encore)')
    a("INSERT INTO Depots (TenantId, Code, Nom, Adresse, Actif, ParDefaut) SELECT @t, 'DEP01', %s, %s, 1, 1%s WHERE NOT EXISTS (SELECT 1 FROM Depots WHERE TenantId = @t);"
      % (s('Réserve de la laverie'), s(SOCIETE['Adresse']), dual))
    a('SET @dep = (SELECT MIN(Id) FROM Depots WHERE TenantId = @t AND ParDefaut = 1);')
    a('INSERT INTO Caisses (ChkCode, ChkDescription, CashierDefault, CustomerDefaultCode, JournalDefaultCode, TenantId, TypePointVente, ImprimerBons, DepotId)')
    a("    SELECT 'LAV1', %s, @caissier, 'C0001', 'J0001', @t, 'Laverie', 0, @dep%s WHERE NOT EXISTS (SELECT 1 FROM Caisses WHERE TenantId = @t);"
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
    a('-- Tiers : entreprises et particuliers (deux clients en compte, avec plafond de crédit)')
    for code, nom, genre, typ, adr, tel, en_compte, plafond in TIERS:
        a('INSERT INTO Clients (TenantId, CodeClient, NomSociete, Adresse, Telephone, Type, Genre, EnCompte, PlafondCredit) SELECT @t, %s, %s, %s, %s, %s, %s, %d, %s%s'
          % (s(code), s(nom), s(adr), s(tel), s(typ), s(genre), en_compte, 'NULL' if plafond is None else plafond, dual))
        a('    WHERE NOT EXISTS (SELECT 1 FROM Clients WHERE TenantId = @t AND CodeClient = %s);' % s(code))
    a('')
    ventes(a, s, sqlserver)
    a('')
    a('COMMIT;' if not sqlserver else 'COMMIT TRANSACTION;')
    a("SELECT 'Société de démonstration « Laverie » prête : connectez-vous avec le compte laverie (mot de passe 123).' AS Resultat;"
      .replace("SELECT '", "SELECT " + N + "'"))
    return '\n'.join(L) + '\n'


for chemin, sqlserver, enc in [('php/sql/demo/demo_laverie_mysql.sql', False, 'utf-8'), ('Scripts/demo_laverie_sqlserver.sql', True, 'utf-8-sig')]:
    with open(os.path.join(RACINE, chemin), 'w', encoding=enc, newline='\n') as f:
        f.write(ecrire(sqlserver))
    print(chemin)
