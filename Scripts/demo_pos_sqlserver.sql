-- =====================================================================
-- GesCaisse : données de démonstration du point de vente — SQL Server (version .NET)
-- 10 catégories, 30 produits, livraisons de stock (J-15 et J-7) et environ
-- 151 ventes réparties sur les 14 derniers jours (une journée clôturée par jour).
--
-- À exécuter UNE SEULE FOIS, sur la base LOCALE de test (jamais en production),
-- après avoir lancé une fois l'application (elle crée les tables des taxes).
-- Société : EASYTECH AFRICA GABON - LBV (pour en choisir une autre, modifiez le nom dans la ligne « SET @t = ... »).
-- Tout est fait dans une transaction : en cas d'erreur, rien n'est enregistré.
-- Pour retirer ces données : script demo_pos_supprimer_sqlserver.sql.
-- =====================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @societe NVARCHAR(200), @t INT, @tva INT, @l INT, @caisse INT, @code NVARCHAR(50), @u1 INT, @u2 INT;
DECLARE @esp INT, @mm INT, @motif INT, @j INT, @cmd INT, @op INT, @dstr NVARCHAR(8), @num NVARCHAR(50);
DECLARE @c1 INT, @c2 INT, @c3 INT, @c4 INT, @c5 INT, @c6 INT, @c7 INT, @c8 INT;
DECLARE @c9 INT, @c10 INT, @p1 INT, @p2 INT, @p3 INT, @p4 INT, @p5 INT, @p6 INT;
DECLARE @p7 INT, @p8 INT, @p9 INT, @p10 INT, @p11 INT, @p12 INT, @p13 INT, @p14 INT;
DECLARE @p15 INT, @p16 INT, @p17 INT, @p18 INT, @p19 INT, @p20 INT, @p21 INT, @p22 INT;
DECLARE @p23 INT, @p24 INT, @p25 INT, @p26 INT, @p27 INT, @p28 INT, @p29 INT, @p30 INT;
BEGIN TRANSACTION;

-- Société visée : nom exact, tel qu'il apparaît dans Sociétés (à modifier ci-dessous) ; s'il est introuvable,
-- la première société qui possède une caisse est utilisée.
SET @t = COALESCE((SELECT MIN(Id) FROM Tenants WHERE Nom = N'EASYTECH AFRICA GABON - LBV'),
                  (SELECT MIN(TenantId) FROM Caisses WHERE TenantId > 0));
IF @t IS NULL THROW 50000, N'Société introuvable : vérifiez le nom dans la ligne SET @t.', 1;

-- Caisse : la première de la société, sinon une caisse « DEMO » est créée
INSERT INTO Caisses (ChkCode, ChkDescription, TenantId) SELECT N'DEMO', N'Caisse de démonstration', @t
    WHERE NOT EXISTS (SELECT 1 FROM Caisses WHERE TenantId = @t);
SET @caisse = (SELECT MIN(ID) FROM Caisses WHERE TenantId = @t);
SET @code = COALESCE((SELECT ChkCode FROM Caisses WHERE ID = @caisse), 'CAISSE');

-- Utilisateurs : un vendeur (ou caissier) et un administrateur de la société
SET @u2 = (SELECT MIN(Id) FROM Utilisateurs WHERE TenantId = @t AND Profil = 'Admin');
SET @u1 = COALESCE((SELECT MIN(Id) FROM Utilisateurs WHERE TenantId = @t AND Profil = 'Vendeur'),
                   (SELECT MIN(Id) FROM Utilisateurs WHERE TenantId = @t AND Profil = 'Caissier'),
                   @u2, (SELECT MIN(Id) FROM Utilisateurs WHERE TenantId = @t),
                   (SELECT MIN(Id) FROM Utilisateurs WHERE Profil = 'SuperAdmin'));
SET @u2 = COALESCE(@u2, @u1);
IF @u1 IS NULL THROW 50000, N'Aucun utilisateur trouvé : créez au moins un utilisateur dans la société.', 1;

-- Modes de paiement Espèces et Mobile Money (créés s'ils manquent)
INSERT INTO ModesPaiement (Code, Libelle, Actif, TenantId) SELECT 'ESP', N'Espèces', 1, @t
    WHERE NOT EXISTS (SELECT 1 FROM ModesPaiement WHERE TenantId = @t AND Actif = 1 AND (Code = 'ESP' OR Libelle LIKE N'Esp%'));
INSERT INTO ModesPaiement (Code, Libelle, Actif, TenantId) SELECT 'MM', 'Mobile Money', 1, @t
    WHERE NOT EXISTS (SELECT 1 FROM ModesPaiement WHERE TenantId = @t AND Actif = 1 AND (Code = 'MM' OR Libelle LIKE '%Mobile%'));
SET @esp = (SELECT MIN(Id) FROM ModesPaiement WHERE TenantId = @t AND Actif = 1 AND (Code = 'ESP' OR Libelle LIKE N'Esp%'));
SET @mm = (SELECT MIN(Id) FROM ModesPaiement WHERE TenantId = @t AND Actif = 1 AND (Code = 'MM' OR Libelle LIKE '%Mobile%'));

INSERT INTO Motifs (LibelleMotif, TypeModif, TenantId) SELECT 'Vente POS', 'Client', @t
    WHERE NOT EXISTS (SELECT 1 FROM Motifs WHERE LibelleMotif = 'Vente POS' AND TenantId = @t);
SET @motif = (SELECT MIN(ID) FROM Motifs WHERE LibelleMotif = 'Vente POS' AND TenantId = @t);

-- 10 catégories (une catégorie existante du même nom est réutilisée)
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, N'Boissons', '#195d84', 1
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = N'Boissons');
SET @c1 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = N'Boissons');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, N'Épicerie', '#0f7a4a', 2
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = N'Épicerie');
SET @c2 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = N'Épicerie');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, N'Boulangerie', '#c2410c', 3
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = N'Boulangerie');
SET @c3 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = N'Boulangerie');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, N'Produits laitiers', '#6d28d9', 4
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = N'Produits laitiers');
SET @c4 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = N'Produits laitiers');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, N'Hygiène', '#0e7490', 5
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = N'Hygiène');
SET @c5 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = N'Hygiène');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, N'Entretien', '#a16207', 6
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = N'Entretien');
SET @c6 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = N'Entretien');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, N'Papeterie', '#be185d', 7
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = N'Papeterie');
SET @c7 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = N'Papeterie');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, N'Électronique', '#334155', 8
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = N'Électronique');
SET @c8 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = N'Électronique');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, N'Snacks', '#9333ea', 9
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = N'Snacks');
SET @c9 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = N'Snacks');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, N'Services', '#64748b', 10
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = N'Services');
SET @c10 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = N'Services');

-- Taxe TVA 18 % de la société (créée si elle manque)
INSERT INTO Taxes (TenantId, Code, Libelle, Taux, ParDefaut) SELECT @t, 'TVA', N'Taxe sur la valeur ajoutée', 18, 1
    WHERE NOT EXISTS (SELECT 1 FROM Taxes WHERE TenantId = @t AND Code = 'TVA' AND Taux = 18);
SET @tva = (SELECT MIN(Id) FROM Taxes WHERE TenantId = @t AND Code = 'TVA' AND Taux = 18);

-- 30 produits (prix TTC, TVA 18 %) ; le stock arrive par les livraisons ci-dessous
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'BOI01', '2000000000015', N'Coca-Cola 33 cl', @c1, 600, 18, 1, 0, 24, 1); SET @p1 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p1, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'BOI02', '2000000000022', N'Eau minérale 1,5 L', @c1, 500, 18, 1, 0, 24, 1); SET @p2 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p2, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'BOI03', '2000000000039', N'Jus d''orange 1 L', @c1, 1500, 18, 1, 0, 10, 1); SET @p3 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p3, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'EPI01', '2000000000046', N'Riz parfumé 5 kg', @c2, 7500, 18, 1, 0, 5, 1); SET @p4 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p4, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'EPI02', '2000000000053', N'Huile végétale 1 L', @c2, 1800, 18, 1, 0, 8, 1); SET @p5 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p5, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'EPI03', '2000000000060', N'Sucre en poudre 1 kg', @c2, 1200, 18, 1, 0, 8, 1); SET @p6 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p6, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'BOU01', '2000000000077', N'Pain baguette', @c3, 250, 18, 1, 0, 30, 1); SET @p7 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p7, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'BOU02', '2000000000084', N'Croissant', @c3, 400, 18, 1, 0, 15, 1); SET @p8 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p8, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'BOU03', '2000000000091', N'Pain de mie', @c3, 1200, 18, 1, 0, 6, 1); SET @p9 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p9, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'LAI01', '2000000000107', N'Lait concentré sucré 397 g', @c4, 800, 18, 1, 0, 12, 1); SET @p10 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p10, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'LAI02', '2000000000114', N'Yaourt nature', @c4, 500, 18, 1, 0, 12, 1); SET @p11 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p11, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'LAI03', '2000000000121', N'Fromage fondu 8 portions', @c4, 1500, 18, 1, 0, 6, 1); SET @p12 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p12, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'HYG01', '2000000000138', N'Savon de toilette', @c5, 500, 18, 1, 0, 12, 1); SET @p13 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p13, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'HYG02', '2000000000145', N'Dentifrice 75 ml', @c5, 1200, 18, 1, 0, 6, 1); SET @p14 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p14, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'HYG03', '2000000000152', N'Papier toilette x4', @c5, 1500, 18, 1, 0, 6, 1); SET @p15 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p15, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'ENT01', '2000000000169', N'Eau de javel 1 L', @c6, 900, 18, 1, 0, 6, 1); SET @p16 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p16, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'ENT02', '2000000000176', N'Lessive en poudre 1 kg', @c6, 2000, 18, 1, 0, 6, 1); SET @p17 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p17, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'ENT03', '2000000000183', N'Liquide vaisselle 750 ml', @c6, 1300, 18, 1, 0, 6, 1); SET @p18 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p18, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'PAP01', '2000000000190', N'Ramette papier A4', @c7, 4500, 18, 1, 0, 4, 1); SET @p19 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p19, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'PAP02', '2000000000206', N'Stylo bille bleu', @c7, 200, 18, 1, 0, 20, 1); SET @p20 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p20, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'PAP03', '2000000000213', N'Cahier 100 pages', @c7, 600, 18, 1, 0, 10, 1); SET @p21 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p21, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'ELE01', '2000000000220', N'Piles AA x4', @c8, 1500, 18, 1, 0, 6, 1); SET @p22 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p22, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'ELE02', '2000000000237', N'Chargeur USB', @c8, 3500, 18, 1, 0, 3, 1); SET @p23 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p23, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'ELE03', '2000000000244', N'Écouteurs filaires', @c8, 2500, 18, 1, 0, 3, 1); SET @p24 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p24, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'SNA01', '2000000000251', N'Biscuits secs', @c9, 300, 18, 1, 0, 20, 1); SET @p25 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p25, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'SNA02', '2000000000268', N'Chips 150 g', @c9, 1000, 18, 1, 0, 10, 1); SET @p26 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p26, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'SNA03', '2000000000275', N'Tablette de chocolat', @c9, 1200, 18, 1, 0, 8, 1); SET @p27 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p27, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'SER01', NULL, N'Photocopie (la page)', @c10, 100, 18, 0, 0, NULL, 1); SET @p28 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p28, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'SER02', NULL, N'Impression couleur (la page)', @c10, 250, 18, 0, 0, NULL, 1); SET @p29 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p29, @tva);
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'SER03', NULL, N'Saisie de document (la page)', @c10, 1000, 18, 0, 0, NULL, 1); SET @p30 = SCOPE_IDENTITY();
INSERT INTO ProduitTaxes (ProduitId, TaxeId) VALUES (@p30, @tva);

-- Livraison initiale (J-15)
UPDATE Produits SET StockActuel = StockActuel + 48 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 48, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p1;
UPDATE Produits SET StockActuel = StockActuel + 54 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 54, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p2;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 18, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p3;
UPDATE Produits SET StockActuel = StockActuel + 6 WHERE Id = @p4;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 6, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p4;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p5;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p5;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p6;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p6;
UPDATE Produits SET StockActuel = StockActuel + 60 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 60, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p7;
UPDATE Produits SET StockActuel = StockActuel + 60 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 60, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p8;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p9;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p9;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 18, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p10;
UPDATE Produits SET StockActuel = StockActuel + 30 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 30, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p11;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p12;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p12;
UPDATE Produits SET StockActuel = StockActuel + 60 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 60, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p13;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p14;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p14;
UPDATE Produits SET StockActuel = StockActuel + 30 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 30, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p15;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p16;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p17;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p17;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p18;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p18;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p19;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p19;
UPDATE Produits SET StockActuel = StockActuel + 24 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 24, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p20;
UPDATE Produits SET StockActuel = StockActuel + 24 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 24, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p21;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p22;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p22;
UPDATE Produits SET StockActuel = StockActuel + 6 WHERE Id = @p23;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 6, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p23;
UPDATE Produits SET StockActuel = StockActuel + 6 WHERE Id = @p24;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 6, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p24;
UPDATE Produits SET StockActuel = StockActuel + 54 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 54, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p25;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 18, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p26;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p27;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 960, CAST(DATEADD(DAY, -15, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p27;

-- Journée J-14 (clôturée)
SET @dstr = CONVERT(char(8), DATEADD(DAY, -14, CAST(GETDATE() AS date)), 112);
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATEADD(DAY, -14, CAST(GETDATE() AS date)), DATEADD(MINUTE, 450, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), DATEADD(MINUTE, 1230, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 50000, 50000, 0, N'Journée de démonstration', 'Cloturee'); SET @j = SCOPE_IDENTITY();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 596, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 6356, 1144, 7500, 7500, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 7, 500, 0, 18, 3500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 533.90);
UPDATE Produits SET StockActuel = StockActuel - 7 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 596, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -7, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p2;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 25, 100, 0, 18, 2500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 381.36);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 3, 500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 596, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 596, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3800, 3800, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 596, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3700, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3700, 3700, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 777, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 4661, 839, 5500, 5500, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p17, N'Lessive en poudre 1 kg', 1, 2000, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p17;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 777, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p17;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, N'Jus d''orange 1 L', 2, 1500, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 777, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p3;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 2, 250, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 777, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 777, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 5500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 5500, 5500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 812, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 7627, 1373, 9000, 9000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 42, 100, 0, 18, 4200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 640.68);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p9, N'Pain de mie', 4, 1200, 0, 18, 4800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 732.20);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p9;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 812, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p9;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 812, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 9000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 9000, 9000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1106, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 254, 46, 300, 300, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 1, 300, 0, 18, 300); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 45.76);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1106, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1106, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 300, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 300, 300, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1121, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 6102, 1098, 7200, 7200, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p14, N'Dentifrice 75 ml', 6, 1200, 0, 18, 7200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1098.31);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p14;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1121, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p14;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1121, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 7200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 7200, 7200, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1128, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 7627, 1373, 9000, 9000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p15, N'Papier toilette x4', 6, 1500, 0, 18, 9000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1372.88);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1128, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p15;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1128, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 9000, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 9000, 9000, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1175, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 5085, 915, 6000, 6000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p22, N'Piles AA x4', 2, 1500, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p22;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1175, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p22;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 30, 100, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1175, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 6000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 6000, 6000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1179, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 3220, 580, 3800, 3800, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 38, 100, 0, 18, 3800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 579.66);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1179, CAST(DATEADD(DAY, -14, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3800, 3800, @op FROM ModesPaiement WHERE Id = @mm;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> N'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-13 (clôturée)
SET @dstr = CONVERT(char(8), DATEADD(DAY, -13, CAST(GETDATE() AS date)), 112);
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATEADD(DAY, -13, CAST(GETDATE() AS date)), DATEADD(MINUTE, 450, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), DATEADD(MINUTE, 1230, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 50000, 50000, 0, N'Journée de démonstration', 'Cloturee'); SET @j = SCOPE_IDENTITY();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 533, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 1610, 290, 1900, 1900, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 4, 250, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 533, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, N'Eau de javel 1 L', 1, 900, 0, 18, 900); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 137.29);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 533, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p16;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 533, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1900, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1900, 1900, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 568, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 1610, 290, 1900, 2000, 100, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 1, 300, 0, 18, 300); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 45.76);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 568, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 1, 600, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 568, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 568, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 568, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2000, 1900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 764, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 4068, 732, 4800, 4800, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p21, N'Cahier 100 pages', 3, 600, 0, 18, 1800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 274.58);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 764, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p21;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 6, 500, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 764, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 764, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 4800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4800, 4800, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 800, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 636, 114, 750, 750, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 3, 250, 0, 18, 750); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 114.41);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 800, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 800, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 750, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 750, 750, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1055, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 1610, 290, 1900, 2000, 100, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 1, 300, 0, 18, 300); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 45.76);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1055, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 4, 400, 0, 18, 1600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 244.07);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1055, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1055, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2000, 1900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1078, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 1525, 275, 1800, 1800, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p21, N'Cahier 100 pages', 3, 600, 0, 18, 1800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 274.58);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1078, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p21;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1078, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 900, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 900, 900, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1078, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 900, 900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1109, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 847, 153, 1000, 1000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1109, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1109, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1129, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 9831, 1769, 11600, 12000, 400, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p26, N'Chips 150 g', 1, 1000, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1129, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p26;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 4, 400, 0, 18, 1600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 244.07);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1129, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p15, N'Papier toilette x4', 2, 1500, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1129, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p15;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, N'Jus d''orange 1 L', 4, 1500, 0, 18, 6000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 915.25);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1129, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p3;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1129, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 11600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 12000, 11600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1131, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 2034, 366, 2400, 2400, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 6, 400, 0, 18, 2400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 366.10);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1131, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1131, CAST(DATEADD(DAY, -13, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2400, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2400, 2400, @op FROM ModesPaiement WHERE Id = @mm;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> N'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-12 (clôturée)
SET @dstr = CONVERT(char(8), DATEADD(DAY, -12, CAST(GETDATE() AS date)), 112);
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATEADD(DAY, -12, CAST(GETDATE() AS date)), DATEADD(MINUTE, 450, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), DATEADD(MINUTE, 1230, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 50000, 50000, 0, N'Journée de démonstration', 'Cloturee'); SET @j = SCOPE_IDENTITY();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 504, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 3051, 549, 3600, 4000, 400, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 2, 300, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 504, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 6, 500, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 504, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 504, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4000, 3600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 610, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 4068, 732, 4800, 4800, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 18, 100, 0, 18, 1800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 274.58);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 6, 500, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 610, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 610, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 4800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4800, 4800, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 684, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 1610, 290, 1900, 1900, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p12, N'Fromage fondu 8 portions', 1, 1500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p12;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 684, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p12;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 1, 400, 0, 18, 400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 61.02);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 684, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 684, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1900, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1900, 1900, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 747, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 9153, 1647, 10800, 10800, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p19, N'Ramette papier A4', 2, 4500, 0, 18, 9000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1372.88);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p19;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 747, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p19;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p5, N'Huile végétale 1 L', 1, 1800, 0, 18, 1800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 274.58);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p5;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 747, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p5;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 747, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 10800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 10800, 10800, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 791, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 2966, 534, 3500, 4000, 500, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 3, 600, 0, 18, 1800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 274.58);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 791, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p6, N'Sucre en poudre 1 kg', 1, 1200, 0, 18, 1200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 183.05);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p6;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 791, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p6;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 791, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 791, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4000, 3500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 851, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 1695, 305, 2000, 2000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 4, 500, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 851, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 851, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 851, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1093, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 11864, 2136, 14000, 14000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1093, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p19, N'Ramette papier A4', 3, 4500, 0, 18, 13500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 2059.32);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p19;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1093, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p19;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1093, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 14000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 14000, 14000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1106, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 847, 153, 1000, 1000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1106, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1106, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1137, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 3136, 564, 3700, 3700, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 37, 100, 0, 18, 3700); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 564.41);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1137, CAST(DATEADD(DAY, -12, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3700, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3700, 3700, @op FROM ModesPaiement WHERE Id = @mm;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> N'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-11 (clôturée)
SET @dstr = CONVERT(char(8), DATEADD(DAY, -11, CAST(GETDATE() AS date)), 112);
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATEADD(DAY, -11, CAST(GETDATE() AS date)), DATEADD(MINUTE, 450, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), DATEADD(MINUTE, 1230, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 50000, 50000, 0, N'Journée de démonstration', 'Cloturee'); SET @j = SCOPE_IDENTITY();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 438, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 424, 76, 500, 1000, 500, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 438, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 438, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 454, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 1144, 206, 1350, 1350, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 3, 250, 0, 18, 750); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 114.41);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 454, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 2, 300, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 454, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 454, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1350, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1350, 1350, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 559, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 2881, 519, 3400, 4000, 600, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 4, 600, 0, 18, 2400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 366.10);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 559, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p26, N'Chips 150 g', 1, 1000, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 559, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p26;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 559, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4000, 3400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 792, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 5339, 961, 6300, 6300, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 792, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p19, N'Ramette papier A4', 1, 4500, 0, 18, 4500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 686.44);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p19;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 792, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p19;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p18, N'Liquide vaisselle 750 ml', 1, 1300, 0, 18, 1300); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 198.31);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p18;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 792, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p18;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 792, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 6300, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 6300, 6300, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 798, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 1441, 259, 1700, 1700, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 798, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 2, 600, 0, 18, 1200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 183.05);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 798, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 798, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1700, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1700, 1700, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 832, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 8898, 1602, 10500, 11000, 500, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p29, N'Impression couleur (la page)', 30, 250, 0, 18, 7500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1144.07);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p12, N'Fromage fondu 8 portions', 2, 1500, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p12;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 832, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p12;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 832, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 10500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 11000, 10500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 843, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 8729, 1571, 10300, 11000, 700, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 40, 100, 0, 18, 4000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 610.17);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p29, N'Impression couleur (la page)', 24, 250, 0, 18, 6000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 915.25);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 1, 300, 0, 18, 300); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 45.76);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 843, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 843, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 10300, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 11000, 10300, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1040, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 1780, 320, 2100, 2100, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p21, N'Cahier 100 pages', 1, 600, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1040, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p21;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1040, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1040, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1040, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2100, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2100, 2100, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1076, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 1907, 343, 2250, 2250, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 4, 500, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1076, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 1, 250, 0, 18, 250); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 38.14);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1076, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1076, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2250, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2250, 2250, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1083, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 1695, 305, 2000, 2000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 1, 400, 0, 18, 400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 61.02);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1083, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, N'Lait concentré sucré 397 g', 2, 800, 0, 18, 1600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 244.07);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1083, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1083, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2000, 2000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D011');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1197, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 3051, 549, 3600, 3600, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p21, N'Cahier 100 pages', 6, 600, 0, 18, 3600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 549.15);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1197, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p21;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1197, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1800, 1800, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1197, CAST(DATEADD(DAY, -11, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1800, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1800, 1800, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> N'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-10 (clôturée)
SET @dstr = CONVERT(char(8), DATEADD(DAY, -10, CAST(GETDATE() AS date)), 112);
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATEADD(DAY, -10, CAST(GETDATE() AS date)), DATEADD(MINUTE, 450, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), DATEADD(MINUTE, 1230, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 50000, 50000, 0, N'Journée de démonstration', 'Cloturee'); SET @j = SCOPE_IDENTITY();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 473, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 2119, 381, 2500, 3000, 500, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p24, N'Écouteurs filaires', 1, 2500, 0, 18, 2500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 381.36);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p24;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 473, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p24;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 473, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3000, 2500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 572, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 5847, 1053, 6900, 6900, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 12, 100, 0, 18, 1200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 183.05);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 3, 400, 0, 18, 1200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 183.05);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 572, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p15, N'Papier toilette x4', 3, 1500, 0, 18, 4500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 686.44);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 572, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p15;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 572, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 6900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 6900, 6900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 606, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 7373, 1327, 8700, 9000, 300, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p9, N'Pain de mie', 2, 1200, 0, 18, 2400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 366.10);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p9;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 606, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p9;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 3, 300, 0, 18, 900); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 137.29);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 606, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 30, 100, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 6, 400, 0, 18, 2400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 366.10);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 606, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 606, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 8700, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 9000, 8700, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 638, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 2627, 473, 3100, 3100, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 2, 300, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 638, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 4, 250, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 638, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 3, 500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 638, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 638, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3100, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3100, 3100, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 661, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 2754, 496, 3250, 4000, 750, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 1, 250, 0, 18, 250); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 38.14);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 661, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 30, 100, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 661, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3250, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4000, 3250, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 680, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 5763, 1037, 6800, 6800, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 39, 100, 0, 18, 3900); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 594.92);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 3, 300, 0, 18, 900); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 137.29);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 680, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 4, 500, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 680, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 680, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 6800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 6800, 6800, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 754, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 3814, 686, 4500, 4500, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 6, 300, 0, 18, 1800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 274.58);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 754, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, N'Eau de javel 1 L', 3, 900, 0, 18, 2700); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 411.86);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 754, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p16;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 754, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 4500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4500, 4500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 811, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 2458, 442, 2900, 3000, 100, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 6, 400, 0, 18, 2400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 366.10);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 811, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 811, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 811, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3000, 2900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 844, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 2034, 366, 2400, 3000, 600, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 6, 400, 0, 18, 2400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 366.10);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 844, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 844, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3000, 2400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 859, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 2966, 534, 3500, 4000, 500, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p23, N'Chargeur USB', 1, 3500, 0, 18, 3500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 533.90);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p23;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 859, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p23;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 859, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4000, 3500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D011');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1081, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 8475, 1525, 10000, 10000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p17, N'Lessive en poudre 1 kg', 2, 2000, 0, 18, 4000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 610.17);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p17;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1081, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p17;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p30, N'Saisie de document (la page)', 6, 1000, 0, 18, 6000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 915.25);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1081, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 10000, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 10000, 10000, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D012');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1089, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 3729, 671, 4400, 4400, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 34, 100, 0, 18, 3400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 518.64);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1089, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1089, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 4400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4400, 4400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D013');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1090, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 8136, 1464, 9600, 9600, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 4, 500, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1090, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p11;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 4, 600, 0, 18, 2400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 366.10);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1090, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p24, N'Écouteurs filaires', 2, 2500, 0, 18, 5000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 762.71);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p24;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1090, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p24;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p20, N'Stylo bille bleu', 1, 200, 0, 18, 200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 30.51);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1090, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p20;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1090, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 9600, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 9600, 9600, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D014');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1155, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 4915, 885, 5800, 6000, 200, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 3, 500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1155, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 2, 250, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1155, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 38, 100, 0, 18, 3800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 579.66);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1155, CAST(DATEADD(DAY, -10, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 5800, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 6000, 5800, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> N'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-9 (clôturée)
SET @dstr = CONVERT(char(8), DATEADD(DAY, -9, CAST(GETDATE() AS date)), 112);
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATEADD(DAY, -9, CAST(GETDATE() AS date)), DATEADD(MINUTE, 450, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), DATEADD(MINUTE, 1230, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 50000, 50000, 0, N'Journée de démonstration', 'Cloturee'); SET @j = SCOPE_IDENTITY();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 721, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 720, 130, 850, 1000, 150, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 1, 250, 0, 18, 250); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 38.14);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 721, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 1, 600, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 721, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p1;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 721, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 850, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 850, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 747, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 636, 114, 750, 750, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 747, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 1, 250, 0, 18, 250); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 38.14);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 747, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 747, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 750, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 750, 750, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 769, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 1441, 259, 1700, 1700, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, N'Eau de javel 1 L', 1, 900, 0, 18, 900); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 137.29);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 769, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p16;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 769, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 1, 300, 0, 18, 300); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 45.76);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 769, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 769, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1700, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1700, 1700, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 803, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 508, 92, 600, 600, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 1, 600, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 803, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 803, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 600, 600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 994, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 2203, 397, 2600, 2600, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 1, 600, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 994, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 4, 500, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 994, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 994, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2600, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2600, 2600, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1035, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 2542, 458, 3000, 3000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 18, 100, 0, 18, 1800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 274.58);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 4, 300, 0, 18, 1200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 183.05);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1035, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1035, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3000, 3000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1088, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 8305, 1495, 9800, 10000, 200, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p15, N'Papier toilette x4', 6, 1500, 0, 18, 9000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1372.88);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1088, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p15;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 2, 400, 0, 18, 800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 122.03);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1088, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1088, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 9800, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 10000, 9800, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1088, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 1610, 290, 1900, 2000, 100, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 4, 400, 0, 18, 1600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 244.07);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1088, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 1, 300, 0, 18, 300); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 45.76);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1088, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1088, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2000, 1900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1093, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 3559, 641, 4200, 4200, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 4, 500, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1093, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 22, 100, 0, 18, 2200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 335.59);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1093, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 4200, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4200, 4200, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1123, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 5508, 992, 6500, 7000, 500, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 2, 250, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1123, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p15, N'Papier toilette x4', 4, 1500, 0, 18, 6000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 915.25);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1123, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p15;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1123, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 6500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 7000, 6500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D011');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1134, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 2373, 427, 2800, 3000, 200, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p22, N'Piles AA x4', 1, 1500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p22;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1134, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p22;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1134, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, N'Lait concentré sucré 397 g', 1, 800, 0, 18, 800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 122.03);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1134, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1134, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2800, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3000, 2800, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D012');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1186, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 4322, 778, 5100, 5100, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 7, 500, 0, 18, 3500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 533.90);
UPDATE Produits SET StockActuel = StockActuel - 7 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1186, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -7, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p18, N'Liquide vaisselle 750 ml', 1, 1300, 0, 18, 1300); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 198.31);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p18;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1186, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p18;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 1, 300, 0, 18, 300); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 45.76);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1186, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1186, CAST(DATEADD(DAY, -9, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 5100, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 5100, 5100, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> N'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-8 (clôturée)
SET @dstr = CONVERT(char(8), DATEADD(DAY, -8, CAST(GETDATE() AS date)), 112);
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATEADD(DAY, -8, CAST(GETDATE() AS date)), DATEADD(MINUTE, 450, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), DATEADD(MINUTE, 1230, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 50000, 50000, 0, N'Journée de démonstration', 'Cloturee'); SET @j = SCOPE_IDENTITY();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 528, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 2034, 366, 2400, 2400, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 4, 500, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 528, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 1, 400, 0, 18, 400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 61.02);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 528, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 528, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2400, 2400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 586, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 3898, 702, 4600, 5000, 400, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 6, 600, 0, 18, 3600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 549.15);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 586, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 586, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 2, 250, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 586, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 586, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 4600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 5000, 4600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 619, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 5720, 1030, 6750, 7000, 250, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p19, N'Ramette papier A4', 1, 4500, 0, 18, 4500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 686.44);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p19;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 619, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p19;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 1, 250, 0, 18, 250); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 38.14);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 619, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p26, N'Chips 150 g', 2, 1000, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 619, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p26;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 619, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 6750, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 7000, 6750, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 825, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 3390, 610, 4000, 4000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p26, N'Chips 150 g', 4, 1000, 0, 18, 4000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 610.17);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 825, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p26;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 825, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 4000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4000, 4000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 825, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 4576, 824, 5400, 5400, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p6, N'Sucre en poudre 1 kg', 2, 1200, 0, 18, 2400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 366.10);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p6;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 825, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p6;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, N'Jus d''orange 1 L', 2, 1500, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 825, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p3;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 825, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 5400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 5400, 5400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1064, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 1102, 198, 1300, 1300, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p18, N'Liquide vaisselle 750 ml', 1, 1300, 0, 18, 1300); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 198.31);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p18;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1064, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p18;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1064, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1300, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1300, 1300, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1095, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 6271, 1129, 7400, 8000, 600, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p17, N'Lessive en poudre 1 kg', 1, 2000, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p17;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1095, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p17;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p29, N'Impression couleur (la page)', 17, 250, 0, 18, 4250); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 648.31);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, N'Eau de javel 1 L', 1, 900, 0, 18, 900); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 137.29);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1095, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p16;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 1, 250, 0, 18, 250); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 38.14);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1095, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1095, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 7400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 8000, 7400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1173, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 424, 76, 500, 500, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1173, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1173, CAST(DATEADD(DAY, -8, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 500, 500, @op FROM ModesPaiement WHERE Id = @mm;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> N'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Réassort (J-7, avant l'ouverture)
UPDATE Produits SET StockActuel = StockActuel + 42 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 42, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p1;
UPDATE Produits SET StockActuel = StockActuel + 54 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 54, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p2;
UPDATE Produits SET StockActuel = StockActuel + 15 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 15, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p3;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p5;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p5;
UPDATE Produits SET StockActuel = StockActuel + 24 WHERE Id = @p6;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 24, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p6;
UPDATE Produits SET StockActuel = StockActuel + 66 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 66, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p7;
UPDATE Produits SET StockActuel = StockActuel + 48 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 48, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p8;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p9;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 18, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p9;
UPDATE Produits SET StockActuel = StockActuel + 24 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 24, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p10;
UPDATE Produits SET StockActuel = StockActuel + 36 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 36, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p11;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p12;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 18, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p12;
UPDATE Produits SET StockActuel = StockActuel + 66 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 66, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p13;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p15;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p16;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p17;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p17;
UPDATE Produits SET StockActuel = StockActuel + 6 WHERE Id = @p18;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 6, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p18;
UPDATE Produits SET StockActuel = StockActuel + 6 WHERE Id = @p19;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 6, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p19;
UPDATE Produits SET StockActuel = StockActuel + 30 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 30, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p20;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 18, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p21;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p22;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 12, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p22;
UPDATE Produits SET StockActuel = StockActuel + 6 WHERE Id = @p24;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 6, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p24;
UPDATE Produits SET StockActuel = StockActuel + 48 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 48, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p25;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 18, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p26;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p27;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 420, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), N'Entrée', 18, StockActuel, 'BL-DEMO-002', NULL, @u2, N'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p27;

-- Journée J-7 (clôturée)
SET @dstr = CONVERT(char(8), DATEADD(DAY, -7, CAST(GETDATE() AS date)), 112);
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATEADD(DAY, -7, CAST(GETDATE() AS date)), DATEADD(MINUTE, 450, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), DATEADD(MINUTE, 1230, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 50000, 50000, 0, N'Journée de démonstration', 'Cloturee'); SET @j = SCOPE_IDENTITY();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 514, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 2542, 458, 3000, 3000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 6, 500, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 514, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 514, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3000, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3000, 3000, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 722, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 2288, 412, 2700, 3000, 300, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 3, 400, 0, 18, 1200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 183.05);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 722, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 6, 250, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 722, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 722, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2700, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3000, 2700, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 854, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 8390, 1510, 9900, 9900, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p19, N'Ramette papier A4', 2, 4500, 0, 18, 9000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1372.88);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p19;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 854, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p19;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, N'Eau de javel 1 L', 1, 900, 0, 18, 900); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 137.29);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 854, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p16;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 854, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 9900, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 9900, 9900, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1025, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 13390, 2410, 15800, 15800, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p5, N'Huile végétale 1 L', 1, 1800, 0, 18, 1800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 274.58);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p5;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1025, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p5;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, N'Jus d''orange 1 L', 6, 1500, 0, 18, 9000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1372.88);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1025, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p3;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p22, N'Piles AA x4', 3, 1500, 0, 18, 4500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 686.44);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p22;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1025, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p22;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1025, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1025, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 15800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 15800, 15800, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1095, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 678, 122, 800, 1000, 200, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 2, 300, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1095, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p20, N'Stylo bille bleu', 1, 200, 0, 18, 200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 30.51);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1095, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p20;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1095, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 800, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 800, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1105, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 14237, 2563, 16800, 17000, 200, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p6, N'Sucre en poudre 1 kg', 12, 1200, 0, 18, 14400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 2196.61);
UPDATE Produits SET StockActuel = StockActuel - 12 WHERE Id = @p6;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1105, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -12, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p6;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 6, 400, 0, 18, 2400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 366.10);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1105, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1105, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 16800, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 17000, 16800, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1117, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 847, 153, 1000, 1000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1117, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1117, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1120, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 2542, 458, 3000, 3000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 6, 500, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1120, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1120, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3000, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3000, 3000, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1132, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 3559, 641, 4200, 5000, 800, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 24, 100, 0, 18, 2400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 366.10);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 6, 300, 0, 18, 1800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 274.58);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1132, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1132, CAST(DATEADD(DAY, -7, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 4200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 5000, 4200, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> N'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-6 (clôturée)
SET @dstr = CONVERT(char(8), DATEADD(DAY, -6, CAST(GETDATE() AS date)), 112);
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATEADD(DAY, -6, CAST(GETDATE() AS date)), DATEADD(MINUTE, 450, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), DATEADD(MINUTE, 1230, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 50000, 50000, 0, N'Journée de démonstration', 'Cloturee'); SET @j = SCOPE_IDENTITY();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 554, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 10085, 1815, 11900, 11900, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p12, N'Fromage fondu 8 portions', 6, 1500, 0, 18, 9000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1372.88);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p12;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 554, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p12;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 554, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p27, N'Tablette de chocolat', 2, 1200, 0, 18, 2400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 366.10);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p27;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 554, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p27;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 554, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 11900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 11900, 11900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 733, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 1864, 336, 2200, 2200, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 6, 300, 0, 18, 1800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 274.58);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 733, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p20, N'Stylo bille bleu', 2, 200, 0, 18, 400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 61.02);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 733, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p20;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 733, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2200, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2200, 2200, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 759, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 10424, 1876, 12300, 13000, 700, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p27, N'Tablette de chocolat', 4, 1200, 0, 18, 4800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 732.20);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p27;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 759, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p27;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 3, 500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 759, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p12, N'Fromage fondu 8 portions', 4, 1500, 0, 18, 6000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 915.25);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p12;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 759, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p12;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 759, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 12300, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 13000, 12300, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 790, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 5508, 992, 6500, 6500, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p30, N'Saisie de document (la page)', 3, 1000, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p26, N'Chips 150 g', 2, 1000, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 790, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p26;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 3, 500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 790, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 790, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 6500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 6500, 6500, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 825, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 339, 61, 400, 1000, 600, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 1, 400, 0, 18, 400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 61.02);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 825, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 825, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 968, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 1441, 259, 1700, 2000, 300, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 3, 400, 0, 18, 1200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 183.05);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 968, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 968, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 968, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1700, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2000, 1700, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 974, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 9534, 1716, 11250, 11250, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p29, N'Impression couleur (la page)', 11, 250, 0, 18, 2750); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 419.49);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 974, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p4, N'Riz parfumé 5 kg', 1, 7500, 0, 18, 7500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1144.07);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p4;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 974, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p4;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 974, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 11250, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 11250, 11250, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1081, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 8178, 1472, 9650, 9650, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p4, N'Riz parfumé 5 kg', 1, 7500, 0, 18, 7500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1144.07);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p4;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1081, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p4;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 7, 250, 0, 18, 1750); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 266.95);
UPDATE Produits SET StockActuel = StockActuel - 7 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1081, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -7, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 1, 400, 0, 18, 400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 61.02);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1081, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1081, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 9650, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 9650, 9650, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1099, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 11864, 2136, 14000, 14000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p5, N'Huile végétale 1 L', 1, 1800, 0, 18, 1800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 274.58);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p5;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1099, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p5;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 32, 100, 0, 18, 3200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 488.14);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, N'Jus d''orange 1 L', 6, 1500, 0, 18, 9000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1372.88);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1099, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p3;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1099, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 14000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 14000, 14000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1105, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 1017, 183, 1200, 2000, 800, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p14, N'Dentifrice 75 ml', 1, 1200, 0, 18, 1200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 183.05);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p14;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1105, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p14;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1105, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2000, 1200, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D011');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1114, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 847, 153, 1000, 1000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1114, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 2, 250, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1114, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1114, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D012');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1161, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 4237, 763, 5000, 5000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 4, 500, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1161, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p2;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, N'Jus d''orange 1 L', 2, 1500, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1161, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p3;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1161, CAST(DATEADD(DAY, -6, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 5000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 5000, 5000, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> N'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-5 (clôturée)
SET @dstr = CONVERT(char(8), DATEADD(DAY, -5, CAST(GETDATE() AS date)), 112);
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATEADD(DAY, -5, CAST(GETDATE() AS date)), DATEADD(MINUTE, 450, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), DATEADD(MINUTE, 1230, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 50000, 50000, 0, N'Journée de démonstration', 'Cloturee'); SET @j = SCOPE_IDENTITY();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 515, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 1186, 214, 1400, 1400, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 515, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 1, 400, 0, 18, 400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 61.02);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 515, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 515, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1400, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1400, 1400, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 693, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 4492, 808, 5300, 5300, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p24, N'Écouteurs filaires', 1, 2500, 0, 18, 2500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 381.36);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p24;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 693, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p24;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 4, 500, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 693, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p20, N'Stylo bille bleu', 4, 200, 0, 18, 800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 122.03);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 693, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p20;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 693, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 5300, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 5300, 5300, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 733, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 6356, 1144, 7500, 7500, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p15, N'Papier toilette x4', 3, 1500, 0, 18, 4500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 686.44);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 733, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p15;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p12, N'Fromage fondu 8 portions', 1, 1500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p12;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 733, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p12;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 3, 500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 733, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 733, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 7500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 7500, 7500, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 767, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 593, 107, 700, 700, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 7, 100, 0, 18, 700); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 106.78);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 767, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 700, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 700, 700, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 806, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 1695, 305, 2000, 2000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 4, 500, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 806, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 806, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2000, 2000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1036, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 551, 99, 650, 650, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 1, 400, 0, 18, 400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 61.02);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1036, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 1, 250, 0, 18, 250); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 38.14);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1036, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1036, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 650, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 650, 650, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1109, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 7034, 1266, 8300, 9000, 700, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 2, 600, 0, 18, 1200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 183.05);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1109, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 2, 300, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1109, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1109, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p2;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, N'Jus d''orange 1 L', 4, 1500, 0, 18, 6000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 915.25);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1109, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p3;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1109, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 8300, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 9000, 8300, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1156, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 1949, 351, 2300, 3000, 700, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 23, 100, 0, 18, 2300); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 350.85);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1156, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2300, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3000, 2300, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1168, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 6949, 1251, 8200, 9000, 800, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 4, 600, 0, 18, 2400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 366.10);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1168, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1168, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p11;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p23, N'Chargeur USB', 1, 3500, 0, 18, 3500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 533.90);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p23;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1168, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p23;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 6, 300, 0, 18, 1800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 274.58);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1168, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1168, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 8200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 9000, 8200, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1173, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 8898, 1602, 10500, 11000, 500, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p4, N'Riz parfumé 5 kg', 1, 7500, 0, 18, 7500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1144.07);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p4;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1173, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p4;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 6, 500, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1173, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1173, CAST(DATEADD(DAY, -5, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 10500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 11000, 10500, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> N'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-4 (clôturée)
SET @dstr = CONVERT(char(8), DATEADD(DAY, -4, CAST(GETDATE() AS date)), 112);
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATEADD(DAY, -4, CAST(GETDATE() AS date)), DATEADD(MINUTE, 450, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), DATEADD(MINUTE, 1230, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 50000, 50000, 0, N'Journée de démonstration', 'Cloturee'); SET @j = SCOPE_IDENTITY();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 443, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 1102, 198, 1300, 1300, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 443, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 2, 400, 0, 18, 800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 122.03);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 443, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 443, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1300, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1300, 1300, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 497, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 1949, 351, 2300, 2300, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 1, 400, 0, 18, 400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 61.02);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 497, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, N'Eau de javel 1 L', 1, 900, 0, 18, 900); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 137.29);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 497, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p16;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p20, N'Stylo bille bleu', 1, 200, 0, 18, 200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 30.51);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 497, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p20;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, N'Lait concentré sucré 397 g', 1, 800, 0, 18, 800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 122.03);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 497, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 497, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1200, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1200, 1200, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 497, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1100, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1100, 1100, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 503, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 3814, 686, 4500, 4500, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, N'Eau de javel 1 L', 1, 900, 0, 18, 900); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 137.29);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 503, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p16;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p5, N'Huile végétale 1 L', 2, 1800, 0, 18, 3600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 549.15);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p5;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 503, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p5;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 503, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 4500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4500, 4500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 552, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 847, 153, 1000, 1000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 552, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 552, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 500, 500, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 552, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 500, 500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 725, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 847, 153, 1000, 1000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 725, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 725, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 741, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 2712, 488, 3200, 4000, 800, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, N'Lait concentré sucré 397 g', 4, 800, 0, 18, 3200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 488.14);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 741, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 741, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4000, 3200, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 781, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 847, 153, 1000, 1000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 781, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 781, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 814, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 10593, 1907, 12500, 12500, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p27, N'Tablette de chocolat', 4, 1200, 0, 18, 4800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 732.20);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p27;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 814, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p27;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p18, N'Liquide vaisselle 750 ml', 2, 1300, 0, 18, 2600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 396.61);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p18;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 814, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p18;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 36, 100, 0, 18, 3600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 549.15);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 3, 500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 814, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 814, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 12500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 12500, 12500, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 964, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 6186, 1114, 7300, 7300, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p17, N'Lessive en poudre 1 kg', 3, 2000, 0, 18, 6000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 915.25);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p17;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 964, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p17;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p18, N'Liquide vaisselle 750 ml', 1, 1300, 0, 18, 1300); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 198.31);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p18;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 964, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p18;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 964, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 7300, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 7300, 7300, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1044, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 508, 92, 600, 600, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 1, 600, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1044, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1044, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 600, 600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D011');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1084, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 1525, 275, 1800, 1800, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p21, N'Cahier 100 pages', 3, 600, 0, 18, 1800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 274.58);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1084, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p21;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1084, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 900, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 900, 900, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1084, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 900, 900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D012');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1087, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 1949, 351, 2300, 2300, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 2, 400, 0, 18, 800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 122.03);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1087, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p15, N'Papier toilette x4', 1, 1500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1087, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p15;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1087, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2300, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2300, 2300, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D013');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1094, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 1610, 290, 1900, 2000, 100, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 2, 250, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1094, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, N'Lait concentré sucré 397 g', 1, 800, 0, 18, 800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 122.03);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1094, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 2, 300, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1094, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1094, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2000, 1900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D014');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1182, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 847, 153, 1000, 1000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1182, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1182, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> N'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-3 (clôturée)
SET @dstr = CONVERT(char(8), DATEADD(DAY, -3, CAST(GETDATE() AS date)), 112);
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATEADD(DAY, -3, CAST(GETDATE() AS date)), DATEADD(MINUTE, 450, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), DATEADD(MINUTE, 1230, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 50000, 50000, 0, N'Journée de démonstration', 'Cloturee'); SET @j = SCOPE_IDENTITY();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 509, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 4746, 854, 5600, 5600, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p24, N'Écouteurs filaires', 2, 2500, 0, 18, 5000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 762.71);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p24;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 509, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p24;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p21, N'Cahier 100 pages', 1, 600, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 509, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p21;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 509, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 5600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 5600, 5600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 534, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 8051, 1449, 9500, 9500, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p29, N'Impression couleur (la page)', 38, 250, 0, 18, 9500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1449.15);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 534, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 9500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 9500, 9500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 674, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 1017, 183, 1200, 1200, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p9, N'Pain de mie', 1, 1200, 0, 18, 1200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 183.05);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p9;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 674, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p9;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 674, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1200, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1200, 1200, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 731, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 3305, 595, 3900, 4000, 100, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 3, 500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 731, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p9, N'Pain de mie', 2, 1200, 0, 18, 2400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 366.10);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p9;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 731, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p9;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 731, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4000, 3900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 766, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 6356, 1144, 7500, 7500, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p9, N'Pain de mie', 6, 1200, 0, 18, 7200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1098.31);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p9;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 766, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p9;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 1, 300, 0, 18, 300); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 45.76);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 766, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 766, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 7500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 7500, 7500, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 767, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 1356, 244, 1600, 2000, 400, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 4, 250, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 767, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p20, N'Stylo bille bleu', 3, 200, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 767, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p20;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 767, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2000, 1600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 779, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 508, 92, 600, 600, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 1, 600, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 779, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 779, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 600, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 600, 600, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 815, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 508, 92, 600, 1000, 400, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 1, 600, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 815, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p1;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 815, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 819, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 508, 92, 600, 1000, 400, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p20, N'Stylo bille bleu', 1, 200, 0, 18, 200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 30.51);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 819, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p20;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 1, 400, 0, 18, 400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 61.02);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 819, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 819, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 825, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 5254, 946, 6200, 7000, 800, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 5, 500, 0, 18, 2500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 381.36);
UPDATE Produits SET StockActuel = StockActuel - 5 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 825, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -5, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 825, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, N'Lait concentré sucré 397 g', 4, 800, 0, 18, 3200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 488.14);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 825, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 825, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 6200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 7000, 6200, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D011');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1022, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 424, 76, 500, 500, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1022, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1022, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 500, 500, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D012');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1049, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 508, 92, 600, 600, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 2, 300, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1049, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1049, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 600, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 600, 600, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D013');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1096, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 2458, 442, 2900, 3000, 100, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 3, 500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1096, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 1, 400, 0, 18, 400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 61.02);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1096, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 4, 250, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1096, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1096, CAST(DATEADD(DAY, -3, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3000, 2900, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> N'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-2 (clôturée)
SET @dstr = CONVERT(char(8), DATEADD(DAY, -2, CAST(GETDATE() AS date)), 112);
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATEADD(DAY, -2, CAST(GETDATE() AS date)), DATEADD(MINUTE, 450, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), DATEADD(MINUTE, 1230, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 50000, 50000, 0, N'Journée de démonstration', 'Cloturee'); SET @j = SCOPE_IDENTITY();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 475, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 1780, 320, 2100, 3000, 900, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 1, 600, 0, 18, 600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 91.53);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 475, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p22, N'Piles AA x4', 1, 1500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p22;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 475, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p22;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 475, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2100, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 3000, 2100, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 697, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 847, 153, 1000, 1000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 697, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 697, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 500, 500, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 697, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 500, 500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 758, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 2712, 488, 3200, 4000, 800, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 4, 500, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 758, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 3, 400, 0, 18, 1200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 183.05);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 758, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 758, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4000, 3200, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 830, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 3475, 625, 4100, 5000, 900, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p27, N'Tablette de chocolat', 3, 1200, 0, 18, 3600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 549.15);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p27;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 830, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p27;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 2, 250, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 830, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 830, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 4100, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 5000, 4100, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1050, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 6017, 1083, 7100, 7100, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p29, N'Impression couleur (la page)', 15, 250, 0, 18, 3750); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 572.03);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 4, 400, 0, 18, 1600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 244.07);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1050, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 1, 250, 0, 18, 250); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 38.14);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1050, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p22, N'Piles AA x4', 1, 1500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p22;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1050, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p22;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1050, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 7100, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 7100, 7100, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1084, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 1695, 305, 2000, 2000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, N'Lait concentré sucré 397 g', 1, 800, 0, 18, 800); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 122.03);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1084, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 2, 600, 0, 18, 1200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 183.05);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1084, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1084, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2000, 2000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1118, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 2881, 519, 3400, 4000, 600, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, N'Coca-Cola 33 cl', 4, 600, 0, 18, 2400); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 366.10);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1118, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 5, 100, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1118, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1118, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 3400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4000, 3400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1150, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 1907, 343, 2250, 2250, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 3, 250, 0, 18, 750); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 114.41);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1150, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 3, 500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1150, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1150, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 2250, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2250, 2250, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1195, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 1186, 214, 1400, 1400, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, N'Eau de javel 1 L', 1, 900, 0, 18, 900); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 137.29);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1195, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p16;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1195, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1195, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1400, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1400, 1400, @op FROM ModesPaiement WHERE Id = @mm;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> N'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-1 (clôturée)
SET @dstr = CONVERT(char(8), DATEADD(DAY, -1, CAST(GETDATE() AS date)), 112);
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATEADD(DAY, -1, CAST(GETDATE() AS date)), DATEADD(MINUTE, 450, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), DATEADD(MINUTE, 1230, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 50000, 50000, 0, N'Journée de démonstration', 'Cloturee'); SET @j = SCOPE_IDENTITY();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 430, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 1186, 214, 1400, 1400, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, N'Biscuits secs', 3, 300, 0, 18, 900); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 137.29);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 430, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 430, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 430, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1400, 1400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 551, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 847, 153, 1000, 1000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p26, N'Chips 150 g', 1, 1000, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 551, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p26;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 551, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 552, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 5085, 915, 6000, 6000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p30, N'Saisie de document (la page)', 6, 1000, 0, 18, 6000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 915.25);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 552, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 6000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 6000, 6000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 613, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 847, 153, 1000, 1000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 613, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 613, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 734, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 847, 153, 1000, 1000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 734, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 734, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 793, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 424, 76, 500, 1000, 500, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 793, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 793, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 963, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 8475, 1525, 10000, 10000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p4, N'Riz parfumé 5 kg', 1, 7500, 0, 18, 7500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1144.07);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p4;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 963, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p4;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, N'Pain baguette', 2, 250, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 963, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p26, N'Chips 150 g', 2, 1000, 0, 18, 2000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 305.08);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 963, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p26;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 963, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 10000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 10000, 10000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1022, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 9322, 1678, 11000, 11000, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p17, N'Lessive en poudre 1 kg', 4, 2000, 0, 18, 8000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1220.34);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p17;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1022, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p17;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, N'Jus d''orange 1 L', 2, 1500, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1022, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p3;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1022, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 11000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 11000, 11000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1102, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 4407, 793, 5200, 6000, 800, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, N'Croissant', 4, 400, 0, 18, 1600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 244.07);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1102, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 36, 100, 0, 18, 3600); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 549.15);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1102, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 5200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 6000, 5200, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1105, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 3559, 641, 4200, 4200, 0, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, N'Lait concentré sucré 397 g', 4, 800, 0, 18, 3200); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 488.14);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1105, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, N'Savon de toilette', 2, 500, 0, 18, 1000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 152.54);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1105, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1105, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 4200, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 4200, 4200, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D011');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1165, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 13136, 2364, 15500, 16000, 500, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1165, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p29, N'Impression couleur (la page)', 36, 250, 0, 18, 9000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 1372.88);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, N'Photocopie (la page)', 30, 100, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 6, 500, 0, 18, 3000); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 457.63);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1165, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1165, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 15500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 16000, 15500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D012');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, DATEADD(MINUTE, 1165, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 424, 76, 500, 1000, 500, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, N'Yaourt nature', 1, 500, 0, 18, 500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 76.27);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1165, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1165, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 1000, 500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D013');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, DATEADD(MINUTE, 1197, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 1271, 229, 1500, 2000, 500, N'Payée'); SET @cmd = SCOPE_IDENTITY();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, N'Eau minérale 1,5 L', 3, 500, 0, 18, 1500); SET @l = SCOPE_IDENTITY();
INSERT INTO LignesCommandePosTaxes (TenantId, LigneCommandePosId, TaxeId, Code, Taux, Montant) VALUES (@t, @l, @tva, 'TVA', 18, 228.81);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, DATEADD(MINUTE, 1197, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, DATEADD(MINUTE, 1197, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS date)) AS datetime2)), 'Encaissement', 1500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, N'Validé', 'Point de vente'); SET @op = SCOPE_IDENTITY();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, N'Espèces'), 2000, 1500, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> N'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

COMMIT;
SET @societe = (SELECT Nom FROM Tenants WHERE Id = @t);
PRINT CONCAT(N'Données de démonstration enregistrées pour la société ', @societe, N' (Id ', @t, N').');
