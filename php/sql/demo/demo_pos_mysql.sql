-- =====================================================================
-- GesCaisse : données de démonstration du point de vente — MySQL (version PHP)
-- 10 catégories, 30 produits, livraisons de stock (J-15 et J-7) et environ
-- 151 ventes réparties sur les 14 derniers jours (une journée clôturée par jour).
--
-- À exécuter UNE SEULE FOIS, sur la base LOCALE de test (jamais en production).
-- Société : EASYTECH AFRICA GABON - LBV (pour en choisir une autre, modifiez le nom dans la ligne « SET @t = ... »).
-- Tout est fait dans une transaction : en cas d'erreur, rien n'est enregistré.
-- Pour retirer ces données : script demo_pos_supprimer_mysql.sql.
-- =====================================================================

SET NAMES utf8mb4;
START TRANSACTION;

-- Société visée : nom exact, tel qu'il apparaît dans Sociétés (à modifier ci-dessous) ; s'il est introuvable,
-- la première société qui possède une caisse est utilisée.
SET @t = COALESCE((SELECT MIN(Id) FROM Tenants WHERE Nom = 'EASYTECH AFRICA GABON - LBV'),
                  (SELECT MIN(TenantId) FROM Caisses WHERE TenantId > 0));

-- Caisse : la première de la société, sinon une caisse « DEMO » est créée
INSERT INTO Caisses (ChkCode, ChkDescription, TenantId) SELECT 'DEMO', 'Caisse de démonstration', @t FROM DUAL
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

-- Modes de paiement Espèces et Mobile Money (créés s'ils manquent)
INSERT INTO ModesPaiement (Code, Libelle, Actif, TenantId) SELECT 'ESP', 'Espèces', 1, @t FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM ModesPaiement WHERE TenantId = @t AND Actif = 1 AND (Code = 'ESP' OR Libelle LIKE 'Esp%'));
INSERT INTO ModesPaiement (Code, Libelle, Actif, TenantId) SELECT 'MM', 'Mobile Money', 1, @t FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM ModesPaiement WHERE TenantId = @t AND Actif = 1 AND (Code = 'MM' OR Libelle LIKE '%Mobile%'));
SET @esp = (SELECT MIN(Id) FROM ModesPaiement WHERE TenantId = @t AND Actif = 1 AND (Code = 'ESP' OR Libelle LIKE 'Esp%'));
SET @mm = (SELECT MIN(Id) FROM ModesPaiement WHERE TenantId = @t AND Actif = 1 AND (Code = 'MM' OR Libelle LIKE '%Mobile%'));

INSERT INTO Motifs (LibelleMotif, TypeModif, TenantId) SELECT 'Vente POS', 'Client', @t FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM Motifs WHERE LibelleMotif = 'Vente POS' AND TenantId = @t);
SET @motif = (SELECT MIN(ID) FROM Motifs WHERE LibelleMotif = 'Vente POS' AND TenantId = @t);

-- 10 catégories (une catégorie existante du même nom est réutilisée)
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, 'Boissons', '#195d84', 1 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = 'Boissons');
SET @c1 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = 'Boissons');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, 'Épicerie', '#0f7a4a', 2 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = 'Épicerie');
SET @c2 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = 'Épicerie');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, 'Boulangerie', '#c2410c', 3 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = 'Boulangerie');
SET @c3 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = 'Boulangerie');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, 'Produits laitiers', '#6d28d9', 4 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = 'Produits laitiers');
SET @c4 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = 'Produits laitiers');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, 'Hygiène', '#0e7490', 5 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = 'Hygiène');
SET @c5 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = 'Hygiène');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, 'Entretien', '#a16207', 6 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = 'Entretien');
SET @c6 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = 'Entretien');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, 'Papeterie', '#be185d', 7 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = 'Papeterie');
SET @c7 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = 'Papeterie');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, 'Électronique', '#334155', 8 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = 'Électronique');
SET @c8 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = 'Électronique');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, 'Snacks', '#9333ea', 9 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = 'Snacks');
SET @c9 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = 'Snacks');
INSERT INTO Categories (TenantId, Nom, Couleur, Ordre) SELECT @t, 'Services', '#64748b', 10 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM Categories WHERE TenantId = @t AND Nom = 'Services');
SET @c10 = (SELECT MIN(Id) FROM Categories WHERE TenantId = @t AND Nom = 'Services');

-- 30 produits (prix TTC, TVA 18 %) ; le stock arrive par les livraisons ci-dessous
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'BOI01', '2000000000015', 'Coca-Cola 33 cl', @c1, 600, 18, 1, 0, 24, 1); SET @p1 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'BOI02', '2000000000022', 'Eau minérale 1,5 L', @c1, 500, 18, 1, 0, 24, 1); SET @p2 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'BOI03', '2000000000039', 'Jus d''orange 1 L', @c1, 1500, 18, 1, 0, 10, 1); SET @p3 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'EPI01', '2000000000046', 'Riz parfumé 5 kg', @c2, 7500, 18, 1, 0, 5, 1); SET @p4 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'EPI02', '2000000000053', 'Huile végétale 1 L', @c2, 1800, 18, 1, 0, 8, 1); SET @p5 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'EPI03', '2000000000060', 'Sucre en poudre 1 kg', @c2, 1200, 18, 1, 0, 8, 1); SET @p6 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'BOU01', '2000000000077', 'Pain baguette', @c3, 250, 18, 1, 0, 30, 1); SET @p7 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'BOU02', '2000000000084', 'Croissant', @c3, 400, 18, 1, 0, 15, 1); SET @p8 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'BOU03', '2000000000091', 'Pain de mie', @c3, 1200, 18, 1, 0, 6, 1); SET @p9 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'LAI01', '2000000000107', 'Lait concentré sucré 397 g', @c4, 800, 18, 1, 0, 12, 1); SET @p10 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'LAI02', '2000000000114', 'Yaourt nature', @c4, 500, 18, 1, 0, 12, 1); SET @p11 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'LAI03', '2000000000121', 'Fromage fondu 8 portions', @c4, 1500, 18, 1, 0, 6, 1); SET @p12 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'HYG01', '2000000000138', 'Savon de toilette', @c5, 500, 18, 1, 0, 12, 1); SET @p13 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'HYG02', '2000000000145', 'Dentifrice 75 ml', @c5, 1200, 18, 1, 0, 6, 1); SET @p14 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'HYG03', '2000000000152', 'Papier toilette x4', @c5, 1500, 18, 1, 0, 6, 1); SET @p15 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'ENT01', '2000000000169', 'Eau de javel 1 L', @c6, 900, 18, 1, 0, 6, 1); SET @p16 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'ENT02', '2000000000176', 'Lessive en poudre 1 kg', @c6, 2000, 18, 1, 0, 6, 1); SET @p17 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'ENT03', '2000000000183', 'Liquide vaisselle 750 ml', @c6, 1300, 18, 1, 0, 6, 1); SET @p18 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'PAP01', '2000000000190', 'Ramette papier A4', @c7, 4500, 18, 1, 0, 4, 1); SET @p19 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'PAP02', '2000000000206', 'Stylo bille bleu', @c7, 200, 18, 1, 0, 20, 1); SET @p20 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'PAP03', '2000000000213', 'Cahier 100 pages', @c7, 600, 18, 1, 0, 10, 1); SET @p21 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'ELE01', '2000000000220', 'Piles AA x4', @c8, 1500, 18, 1, 0, 6, 1); SET @p22 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'ELE02', '2000000000237', 'Chargeur USB', @c8, 3500, 18, 1, 0, 3, 1); SET @p23 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'ELE03', '2000000000244', 'Écouteurs filaires', @c8, 2500, 18, 1, 0, 3, 1); SET @p24 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'SNA01', '2000000000251', 'Biscuits secs', @c9, 300, 18, 1, 0, 20, 1); SET @p25 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'SNA02', '2000000000268', 'Chips 150 g', @c9, 1000, 18, 1, 0, 10, 1); SET @p26 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'SNA03', '2000000000275', 'Tablette de chocolat', @c9, 1200, 18, 1, 0, 8, 1); SET @p27 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'SER01', NULL, 'Photocopie (la page)', @c10, 100, 18, 0, 0, NULL, 1); SET @p28 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'SER02', NULL, 'Impression couleur (la page)', @c10, 250, 18, 0, 0, NULL, 1); SET @p29 = LAST_INSERT_ID();
INSERT INTO Produits (TenantId, Code, CodeBarres, Nom, CategorieId, PrixVente, TauxTVA, SuiviStock, StockActuel, SeuilAlerte, Actif)
    VALUES (@t, 'SER03', NULL, 'Saisie de document (la page)', @c10, 1000, 18, 0, 0, NULL, 1); SET @p30 = LAST_INSERT_ID();

-- Livraison initiale (J-15)
UPDATE Produits SET StockActuel = StockActuel + 48 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 48, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p1;
UPDATE Produits SET StockActuel = StockActuel + 54 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 54, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p2;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 18, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p3;
UPDATE Produits SET StockActuel = StockActuel + 6 WHERE Id = @p4;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 6, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p4;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p5;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p5;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p6;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p6;
UPDATE Produits SET StockActuel = StockActuel + 60 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 60, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p7;
UPDATE Produits SET StockActuel = StockActuel + 60 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 60, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p8;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p9;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p9;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 18, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p10;
UPDATE Produits SET StockActuel = StockActuel + 30 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 30, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p11;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p12;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p12;
UPDATE Produits SET StockActuel = StockActuel + 60 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 60, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p13;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p14;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p14;
UPDATE Produits SET StockActuel = StockActuel + 30 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 30, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p15;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p16;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p17;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p17;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p18;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p18;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p19;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p19;
UPDATE Produits SET StockActuel = StockActuel + 24 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 24, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p20;
UPDATE Produits SET StockActuel = StockActuel + 24 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 24, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p21;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p22;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p22;
UPDATE Produits SET StockActuel = StockActuel + 6 WHERE Id = @p23;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 6, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p23;
UPDATE Produits SET StockActuel = StockActuel + 6 WHERE Id = @p24;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 6, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p24;
UPDATE Produits SET StockActuel = StockActuel + 54 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 54, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p25;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 18, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p26;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p27;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 15 DAY) + INTERVAL 960 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-001', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p27;

-- Journée J-14 (clôturée)
SET @dstr = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 14 DAY), '%Y%m%d');
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATE_SUB(CURDATE(), INTERVAL 14 DAY), (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 450 MINUTE), (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 1230 MINUTE), 50000, 50000, 0, 'Journée de démonstration', 'Cloturee'); SET @j = LAST_INSERT_ID();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 596 MINUTE), 6356, 1144, 7500, 7500, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 7, 500, 0, 18, 3500);
UPDATE Produits SET StockActuel = StockActuel - 7 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 596 MINUTE), 'Vente', -7, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p2;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 25, 100, 0, 18, 2500);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 3, 500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 596 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 596 MINUTE), 'Encaissement', 3800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3800, 3800, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 596 MINUTE), 'Encaissement', 3700, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3700, 3700, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 777 MINUTE), 4661, 839, 5500, 5500, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p17, 'Lessive en poudre 1 kg', 1, 2000, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p17;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 777 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p17;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, 'Jus d''orange 1 L', 2, 1500, 0, 18, 3000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 777 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p3;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 2, 250, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 777 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 777 MINUTE), 'Encaissement', 5500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 5500, 5500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 812 MINUTE), 7627, 1373, 9000, 9000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 42, 100, 0, 18, 4200);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p9, 'Pain de mie', 4, 1200, 0, 18, 4800);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p9;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 812 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p9;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 812 MINUTE), 'Encaissement', 9000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 9000, 9000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 1106 MINUTE), 254, 46, 300, 300, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 1, 300, 0, 18, 300);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 1106 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 1106 MINUTE), 'Encaissement', 300, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 300, 300, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 1121 MINUTE), 6102, 1098, 7200, 7200, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p14, 'Dentifrice 75 ml', 6, 1200, 0, 18, 7200);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p14;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 1121 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p14;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 1121 MINUTE), 'Encaissement', 7200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 7200, 7200, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 1128 MINUTE), 7627, 1373, 9000, 9000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p15, 'Papier toilette x4', 6, 1500, 0, 18, 9000);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 1128 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p15;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 1128 MINUTE), 'Encaissement', 9000, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 9000, 9000, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 1175 MINUTE), 5085, 915, 6000, 6000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p22, 'Piles AA x4', 2, 1500, 0, 18, 3000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p22;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 1175 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p22;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 30, 100, 0, 18, 3000);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 1175 MINUTE), 'Encaissement', 6000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 6000, 6000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 1179 MINUTE), 3220, 580, 3800, 3800, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 38, 100, 0, 18, 3800);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 14 DAY) + INTERVAL 1179 MINUTE), 'Encaissement', 3800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3800, 3800, @op FROM ModesPaiement WHERE Id = @mm;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-13 (clôturée)
SET @dstr = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 13 DAY), '%Y%m%d');
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATE_SUB(CURDATE(), INTERVAL 13 DAY), (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 450 MINUTE), (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1230 MINUTE), 50000, 50000, 0, 'Journée de démonstration', 'Cloturee'); SET @j = LAST_INSERT_ID();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 533 MINUTE), 1610, 290, 1900, 1900, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 4, 250, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 533 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, 'Eau de javel 1 L', 1, 900, 0, 18, 900);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 533 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p16;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 533 MINUTE), 'Encaissement', 1900, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1900, 1900, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 568 MINUTE), 1610, 290, 1900, 2000, 100, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 1, 300, 0, 18, 300);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 568 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 1, 600, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 568 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 568 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 568 MINUTE), 'Encaissement', 1900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2000, 1900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 764 MINUTE), 4068, 732, 4800, 4800, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p21, 'Cahier 100 pages', 3, 600, 0, 18, 1800);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 764 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p21;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 6, 500, 0, 18, 3000);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 764 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 764 MINUTE), 'Encaissement', 4800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4800, 4800, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 800 MINUTE), 636, 114, 750, 750, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 3, 250, 0, 18, 750);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 800 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 800 MINUTE), 'Encaissement', 750, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 750, 750, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1055 MINUTE), 1610, 290, 1900, 2000, 100, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 1, 300, 0, 18, 300);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1055 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 4, 400, 0, 18, 1600);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1055 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1055 MINUTE), 'Encaissement', 1900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2000, 1900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1078 MINUTE), 1525, 275, 1800, 1800, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p21, 'Cahier 100 pages', 3, 600, 0, 18, 1800);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1078 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p21;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1078 MINUTE), 'Encaissement', 900, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 900, 900, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1078 MINUTE), 'Encaissement', 900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 900, 900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1109 MINUTE), 847, 153, 1000, 1000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1109 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1109 MINUTE), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1129 MINUTE), 9831, 1769, 11600, 12000, 400, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p26, 'Chips 150 g', 1, 1000, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1129 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p26;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 4, 400, 0, 18, 1600);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1129 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p15, 'Papier toilette x4', 2, 1500, 0, 18, 3000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1129 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p15;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, 'Jus d''orange 1 L', 4, 1500, 0, 18, 6000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1129 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p3;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1129 MINUTE), 'Encaissement', 11600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 12000, 11600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1131 MINUTE), 2034, 366, 2400, 2400, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 6, 400, 0, 18, 2400);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1131 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 13 DAY) + INTERVAL 1131 MINUTE), 'Encaissement', 2400, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2400, 2400, @op FROM ModesPaiement WHERE Id = @mm;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-12 (clôturée)
SET @dstr = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 12 DAY), '%Y%m%d');
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATE_SUB(CURDATE(), INTERVAL 12 DAY), (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 450 MINUTE), (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 1230 MINUTE), 50000, 50000, 0, 'Journée de démonstration', 'Cloturee'); SET @j = LAST_INSERT_ID();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 504 MINUTE), 3051, 549, 3600, 4000, 400, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 2, 300, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 504 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 6, 500, 0, 18, 3000);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 504 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 504 MINUTE), 'Encaissement', 3600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4000, 3600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 610 MINUTE), 4068, 732, 4800, 4800, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 18, 100, 0, 18, 1800);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 6, 500, 0, 18, 3000);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 610 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 610 MINUTE), 'Encaissement', 4800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4800, 4800, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 684 MINUTE), 1610, 290, 1900, 1900, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p12, 'Fromage fondu 8 portions', 1, 1500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p12;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 684 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p12;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 1, 400, 0, 18, 400);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 684 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 684 MINUTE), 'Encaissement', 1900, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1900, 1900, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 747 MINUTE), 9153, 1647, 10800, 10800, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p19, 'Ramette papier A4', 2, 4500, 0, 18, 9000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p19;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 747 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p19;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p5, 'Huile végétale 1 L', 1, 1800, 0, 18, 1800);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p5;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 747 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p5;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 747 MINUTE), 'Encaissement', 10800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 10800, 10800, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 791 MINUTE), 2966, 534, 3500, 4000, 500, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 3, 600, 0, 18, 1800);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 791 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p6, 'Sucre en poudre 1 kg', 1, 1200, 0, 18, 1200);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p6;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 791 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p6;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 791 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 791 MINUTE), 'Encaissement', 3500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4000, 3500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 851 MINUTE), 1695, 305, 2000, 2000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 4, 500, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 851 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 851 MINUTE), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 851 MINUTE), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 1093 MINUTE), 11864, 2136, 14000, 14000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 1093 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p19, 'Ramette papier A4', 3, 4500, 0, 18, 13500);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p19;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 1093 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p19;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 1093 MINUTE), 'Encaissement', 14000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 14000, 14000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 1106 MINUTE), 847, 153, 1000, 1000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 1106 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 1106 MINUTE), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 1137 MINUTE), 3136, 564, 3700, 3700, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 37, 100, 0, 18, 3700);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 12 DAY) + INTERVAL 1137 MINUTE), 'Encaissement', 3700, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3700, 3700, @op FROM ModesPaiement WHERE Id = @mm;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-11 (clôturée)
SET @dstr = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 11 DAY), '%Y%m%d');
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATE_SUB(CURDATE(), INTERVAL 11 DAY), (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 450 MINUTE), (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1230 MINUTE), 50000, 50000, 0, 'Journée de démonstration', 'Cloturee'); SET @j = LAST_INSERT_ID();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 438 MINUTE), 424, 76, 500, 1000, 500, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 438 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 438 MINUTE), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 454 MINUTE), 1144, 206, 1350, 1350, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 3, 250, 0, 18, 750);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 454 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 2, 300, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 454 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 454 MINUTE), 'Encaissement', 1350, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1350, 1350, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 559 MINUTE), 2881, 519, 3400, 4000, 600, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 4, 600, 0, 18, 2400);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 559 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p26, 'Chips 150 g', 1, 1000, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 559 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p26;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 559 MINUTE), 'Encaissement', 3400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4000, 3400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 792 MINUTE), 5339, 961, 6300, 6300, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 792 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p19, 'Ramette papier A4', 1, 4500, 0, 18, 4500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p19;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 792 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p19;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p18, 'Liquide vaisselle 750 ml', 1, 1300, 0, 18, 1300);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p18;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 792 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p18;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 792 MINUTE), 'Encaissement', 6300, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 6300, 6300, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 798 MINUTE), 1441, 259, 1700, 1700, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 798 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 2, 600, 0, 18, 1200);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 798 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 798 MINUTE), 'Encaissement', 1700, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1700, 1700, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 832 MINUTE), 8898, 1602, 10500, 11000, 500, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p29, 'Impression couleur (la page)', 30, 250, 0, 18, 7500);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p12, 'Fromage fondu 8 portions', 2, 1500, 0, 18, 3000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p12;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 832 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p12;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 832 MINUTE), 'Encaissement', 10500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 11000, 10500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 843 MINUTE), 8729, 1571, 10300, 11000, 700, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 40, 100, 0, 18, 4000);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p29, 'Impression couleur (la page)', 24, 250, 0, 18, 6000);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 1, 300, 0, 18, 300);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 843 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 843 MINUTE), 'Encaissement', 10300, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 11000, 10300, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1040 MINUTE), 1780, 320, 2100, 2100, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p21, 'Cahier 100 pages', 1, 600, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1040 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p21;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1040 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1040 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1040 MINUTE), 'Encaissement', 2100, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2100, 2100, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1076 MINUTE), 1907, 343, 2250, 2250, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 4, 500, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1076 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 1, 250, 0, 18, 250);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1076 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1076 MINUTE), 'Encaissement', 2250, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2250, 2250, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1083 MINUTE), 1695, 305, 2000, 2000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 1, 400, 0, 18, 400);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1083 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, 'Lait concentré sucré 397 g', 2, 800, 0, 18, 1600);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1083 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1083 MINUTE), 'Encaissement', 2000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2000, 2000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D011');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1197 MINUTE), 3051, 549, 3600, 3600, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p21, 'Cahier 100 pages', 6, 600, 0, 18, 3600);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1197 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p21;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1197 MINUTE), 'Encaissement', 1800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1800, 1800, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 11 DAY) + INTERVAL 1197 MINUTE), 'Encaissement', 1800, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1800, 1800, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-10 (clôturée)
SET @dstr = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 10 DAY), '%Y%m%d');
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATE_SUB(CURDATE(), INTERVAL 10 DAY), (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 450 MINUTE), (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1230 MINUTE), 50000, 50000, 0, 'Journée de démonstration', 'Cloturee'); SET @j = LAST_INSERT_ID();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 473 MINUTE), 2119, 381, 2500, 3000, 500, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p24, 'Écouteurs filaires', 1, 2500, 0, 18, 2500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p24;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 473 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p24;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 473 MINUTE), 'Encaissement', 2500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3000, 2500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 572 MINUTE), 5847, 1053, 6900, 6900, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 12, 100, 0, 18, 1200);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 3, 400, 0, 18, 1200);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 572 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p15, 'Papier toilette x4', 3, 1500, 0, 18, 4500);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 572 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p15;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 572 MINUTE), 'Encaissement', 6900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 6900, 6900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 606 MINUTE), 7373, 1327, 8700, 9000, 300, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p9, 'Pain de mie', 2, 1200, 0, 18, 2400);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p9;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 606 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p9;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 3, 300, 0, 18, 900);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 606 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 30, 100, 0, 18, 3000);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 6, 400, 0, 18, 2400);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 606 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 606 MINUTE), 'Encaissement', 8700, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 9000, 8700, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 638 MINUTE), 2627, 473, 3100, 3100, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 2, 300, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 638 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 4, 250, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 638 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 3, 500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 638 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 638 MINUTE), 'Encaissement', 3100, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3100, 3100, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 661 MINUTE), 2754, 496, 3250, 4000, 750, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 1, 250, 0, 18, 250);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 661 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 30, 100, 0, 18, 3000);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 661 MINUTE), 'Encaissement', 3250, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4000, 3250, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 680 MINUTE), 5763, 1037, 6800, 6800, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 39, 100, 0, 18, 3900);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 3, 300, 0, 18, 900);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 680 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 4, 500, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 680 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 680 MINUTE), 'Encaissement', 6800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 6800, 6800, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 754 MINUTE), 3814, 686, 4500, 4500, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 6, 300, 0, 18, 1800);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 754 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, 'Eau de javel 1 L', 3, 900, 0, 18, 2700);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 754 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p16;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 754 MINUTE), 'Encaissement', 4500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4500, 4500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 811 MINUTE), 2458, 442, 2900, 3000, 100, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 6, 400, 0, 18, 2400);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 811 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 811 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 811 MINUTE), 'Encaissement', 2900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3000, 2900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 844 MINUTE), 2034, 366, 2400, 3000, 600, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 6, 400, 0, 18, 2400);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 844 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 844 MINUTE), 'Encaissement', 2400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3000, 2400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 859 MINUTE), 2966, 534, 3500, 4000, 500, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p23, 'Chargeur USB', 1, 3500, 0, 18, 3500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p23;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 859 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p23;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 859 MINUTE), 'Encaissement', 3500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4000, 3500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D011');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1081 MINUTE), 8475, 1525, 10000, 10000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p17, 'Lessive en poudre 1 kg', 2, 2000, 0, 18, 4000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p17;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1081 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p17;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p30, 'Saisie de document (la page)', 6, 1000, 0, 18, 6000);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1081 MINUTE), 'Encaissement', 10000, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 10000, 10000, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D012');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1089 MINUTE), 3729, 671, 4400, 4400, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 34, 100, 0, 18, 3400);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1089 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1089 MINUTE), 'Encaissement', 4400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4400, 4400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D013');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1090 MINUTE), 8136, 1464, 9600, 9600, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 4, 500, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1090 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p11;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 4, 600, 0, 18, 2400);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1090 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p24, 'Écouteurs filaires', 2, 2500, 0, 18, 5000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p24;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1090 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p24;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p20, 'Stylo bille bleu', 1, 200, 0, 18, 200);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1090 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p20;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1090 MINUTE), 'Encaissement', 9600, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 9600, 9600, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D014');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1155 MINUTE), 4915, 885, 5800, 6000, 200, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 3, 500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1155 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 2, 250, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1155 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 38, 100, 0, 18, 3800);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 10 DAY) + INTERVAL 1155 MINUTE), 'Encaissement', 5800, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 6000, 5800, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-9 (clôturée)
SET @dstr = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 9 DAY), '%Y%m%d');
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATE_SUB(CURDATE(), INTERVAL 9 DAY), (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 450 MINUTE), (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1230 MINUTE), 50000, 50000, 0, 'Journée de démonstration', 'Cloturee'); SET @j = LAST_INSERT_ID();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 721 MINUTE), 720, 130, 850, 1000, 150, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 1, 250, 0, 18, 250);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 721 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 1, 600, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 721 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p1;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 721 MINUTE), 'Encaissement', 850, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 850, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 747 MINUTE), 636, 114, 750, 750, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 747 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 1, 250, 0, 18, 250);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 747 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 747 MINUTE), 'Encaissement', 750, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 750, 750, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 769 MINUTE), 1441, 259, 1700, 1700, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, 'Eau de javel 1 L', 1, 900, 0, 18, 900);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 769 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p16;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 769 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 1, 300, 0, 18, 300);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 769 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 769 MINUTE), 'Encaissement', 1700, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1700, 1700, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 803 MINUTE), 508, 92, 600, 600, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 1, 600, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 803 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 803 MINUTE), 'Encaissement', 600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 600, 600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 994 MINUTE), 2203, 397, 2600, 2600, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 1, 600, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 994 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 4, 500, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 994 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 994 MINUTE), 'Encaissement', 2600, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2600, 2600, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1035 MINUTE), 2542, 458, 3000, 3000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 18, 100, 0, 18, 1800);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 4, 300, 0, 18, 1200);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1035 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1035 MINUTE), 'Encaissement', 3000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3000, 3000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1088 MINUTE), 8305, 1495, 9800, 10000, 200, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p15, 'Papier toilette x4', 6, 1500, 0, 18, 9000);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1088 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p15;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 2, 400, 0, 18, 800);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1088 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1088 MINUTE), 'Encaissement', 9800, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 10000, 9800, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1088 MINUTE), 1610, 290, 1900, 2000, 100, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 4, 400, 0, 18, 1600);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1088 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 1, 300, 0, 18, 300);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1088 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1088 MINUTE), 'Encaissement', 1900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2000, 1900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1093 MINUTE), 3559, 641, 4200, 4200, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 4, 500, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1093 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 22, 100, 0, 18, 2200);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1093 MINUTE), 'Encaissement', 4200, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4200, 4200, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1123 MINUTE), 5508, 992, 6500, 7000, 500, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 2, 250, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1123 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p15, 'Papier toilette x4', 4, 1500, 0, 18, 6000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1123 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p15;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1123 MINUTE), 'Encaissement', 6500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 7000, 6500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D011');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1134 MINUTE), 2373, 427, 2800, 3000, 200, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p22, 'Piles AA x4', 1, 1500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p22;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1134 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p22;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1134 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, 'Lait concentré sucré 397 g', 1, 800, 0, 18, 800);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1134 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1134 MINUTE), 'Encaissement', 2800, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3000, 2800, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D012');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1186 MINUTE), 4322, 778, 5100, 5100, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 7, 500, 0, 18, 3500);
UPDATE Produits SET StockActuel = StockActuel - 7 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1186 MINUTE), 'Vente', -7, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p18, 'Liquide vaisselle 750 ml', 1, 1300, 0, 18, 1300);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p18;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1186 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p18;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 1, 300, 0, 18, 300);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1186 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 9 DAY) + INTERVAL 1186 MINUTE), 'Encaissement', 5100, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 5100, 5100, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-8 (clôturée)
SET @dstr = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 8 DAY), '%Y%m%d');
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATE_SUB(CURDATE(), INTERVAL 8 DAY), (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 450 MINUTE), (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 1230 MINUTE), 50000, 50000, 0, 'Journée de démonstration', 'Cloturee'); SET @j = LAST_INSERT_ID();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 528 MINUTE), 2034, 366, 2400, 2400, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 4, 500, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 528 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 1, 400, 0, 18, 400);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 528 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 528 MINUTE), 'Encaissement', 2400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2400, 2400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 586 MINUTE), 3898, 702, 4600, 5000, 400, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 6, 600, 0, 18, 3600);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 586 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 586 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 2, 250, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 586 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 586 MINUTE), 'Encaissement', 4600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 5000, 4600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 619 MINUTE), 5720, 1030, 6750, 7000, 250, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p19, 'Ramette papier A4', 1, 4500, 0, 18, 4500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p19;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 619 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p19;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 1, 250, 0, 18, 250);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 619 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p26, 'Chips 150 g', 2, 1000, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 619 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p26;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 619 MINUTE), 'Encaissement', 6750, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 7000, 6750, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 825 MINUTE), 3390, 610, 4000, 4000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p26, 'Chips 150 g', 4, 1000, 0, 18, 4000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 825 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p26;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 825 MINUTE), 'Encaissement', 4000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4000, 4000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 825 MINUTE), 4576, 824, 5400, 5400, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p6, 'Sucre en poudre 1 kg', 2, 1200, 0, 18, 2400);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p6;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 825 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p6;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, 'Jus d''orange 1 L', 2, 1500, 0, 18, 3000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 825 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p3;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 825 MINUTE), 'Encaissement', 5400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 5400, 5400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 1064 MINUTE), 1102, 198, 1300, 1300, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p18, 'Liquide vaisselle 750 ml', 1, 1300, 0, 18, 1300);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p18;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 1064 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p18;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 1064 MINUTE), 'Encaissement', 1300, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1300, 1300, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 1095 MINUTE), 6271, 1129, 7400, 8000, 600, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p17, 'Lessive en poudre 1 kg', 1, 2000, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p17;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 1095 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p17;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p29, 'Impression couleur (la page)', 17, 250, 0, 18, 4250);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, 'Eau de javel 1 L', 1, 900, 0, 18, 900);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 1095 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p16;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 1, 250, 0, 18, 250);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 1095 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 1095 MINUTE), 'Encaissement', 7400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 8000, 7400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 1173 MINUTE), 424, 76, 500, 500, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 1173 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 8 DAY) + INTERVAL 1173 MINUTE), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 500, 500, @op FROM ModesPaiement WHERE Id = @mm;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Réassort (J-7, avant l'ouverture)
UPDATE Produits SET StockActuel = StockActuel + 42 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 42, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p1;
UPDATE Produits SET StockActuel = StockActuel + 54 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 54, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p2;
UPDATE Produits SET StockActuel = StockActuel + 15 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 15, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p3;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p5;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p5;
UPDATE Produits SET StockActuel = StockActuel + 24 WHERE Id = @p6;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 24, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p6;
UPDATE Produits SET StockActuel = StockActuel + 66 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 66, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p7;
UPDATE Produits SET StockActuel = StockActuel + 48 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 48, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p8;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p9;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 18, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p9;
UPDATE Produits SET StockActuel = StockActuel + 24 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 24, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p10;
UPDATE Produits SET StockActuel = StockActuel + 36 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 36, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p11;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p12;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 18, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p12;
UPDATE Produits SET StockActuel = StockActuel + 66 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 66, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p13;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p15;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p16;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p17;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p17;
UPDATE Produits SET StockActuel = StockActuel + 6 WHERE Id = @p18;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 6, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p18;
UPDATE Produits SET StockActuel = StockActuel + 6 WHERE Id = @p19;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 6, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p19;
UPDATE Produits SET StockActuel = StockActuel + 30 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 30, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p20;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 18, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p21;
UPDATE Produits SET StockActuel = StockActuel + 12 WHERE Id = @p22;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 12, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p22;
UPDATE Produits SET StockActuel = StockActuel + 6 WHERE Id = @p24;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 6, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p24;
UPDATE Produits SET StockActuel = StockActuel + 48 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 48, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p25;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 18, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p26;
UPDATE Produits SET StockActuel = StockActuel + 18 WHERE Id = @p27;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 420 MINUTE), 'Entrée', 18, StockActuel, 'BL-DEMO-002', NULL, @u2, 'Livraison fournisseur (démo)' FROM Produits WHERE Id = @p27;

-- Journée J-7 (clôturée)
SET @dstr = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '%Y%m%d');
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATE_SUB(CURDATE(), INTERVAL 7 DAY), (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 450 MINUTE), (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1230 MINUTE), 50000, 50000, 0, 'Journée de démonstration', 'Cloturee'); SET @j = LAST_INSERT_ID();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 514 MINUTE), 2542, 458, 3000, 3000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 6, 500, 0, 18, 3000);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 514 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 514 MINUTE), 'Encaissement', 3000, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3000, 3000, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 722 MINUTE), 2288, 412, 2700, 3000, 300, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 3, 400, 0, 18, 1200);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 722 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 6, 250, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 722 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 722 MINUTE), 'Encaissement', 2700, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3000, 2700, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 854 MINUTE), 8390, 1510, 9900, 9900, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p19, 'Ramette papier A4', 2, 4500, 0, 18, 9000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p19;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 854 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p19;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, 'Eau de javel 1 L', 1, 900, 0, 18, 900);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 854 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p16;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 854 MINUTE), 'Encaissement', 9900, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 9900, 9900, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1025 MINUTE), 13390, 2410, 15800, 15800, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p5, 'Huile végétale 1 L', 1, 1800, 0, 18, 1800);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p5;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1025 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p5;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, 'Jus d''orange 1 L', 6, 1500, 0, 18, 9000);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1025 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p3;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p22, 'Piles AA x4', 3, 1500, 0, 18, 4500);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p22;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1025 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p22;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1025 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1025 MINUTE), 'Encaissement', 15800, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 15800, 15800, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1095 MINUTE), 678, 122, 800, 1000, 200, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 2, 300, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1095 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p20, 'Stylo bille bleu', 1, 200, 0, 18, 200);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1095 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p20;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1095 MINUTE), 'Encaissement', 800, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 800, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1105 MINUTE), 14237, 2563, 16800, 17000, 200, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p6, 'Sucre en poudre 1 kg', 12, 1200, 0, 18, 14400);
UPDATE Produits SET StockActuel = StockActuel - 12 WHERE Id = @p6;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1105 MINUTE), 'Vente', -12, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p6;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 6, 400, 0, 18, 2400);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1105 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1105 MINUTE), 'Encaissement', 16800, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 17000, 16800, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1117 MINUTE), 847, 153, 1000, 1000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1117 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1117 MINUTE), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1120 MINUTE), 2542, 458, 3000, 3000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 6, 500, 0, 18, 3000);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1120 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1120 MINUTE), 'Encaissement', 3000, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3000, 3000, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1132 MINUTE), 3559, 641, 4200, 5000, 800, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 24, 100, 0, 18, 2400);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 6, 300, 0, 18, 1800);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1132 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 7 DAY) + INTERVAL 1132 MINUTE), 'Encaissement', 4200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 5000, 4200, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-6 (clôturée)
SET @dstr = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 6 DAY), '%Y%m%d');
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATE_SUB(CURDATE(), INTERVAL 6 DAY), (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 450 MINUTE), (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1230 MINUTE), 50000, 50000, 0, 'Journée de démonstration', 'Cloturee'); SET @j = LAST_INSERT_ID();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 554 MINUTE), 10085, 1815, 11900, 11900, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p12, 'Fromage fondu 8 portions', 6, 1500, 0, 18, 9000);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p12;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 554 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p12;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 554 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p27, 'Tablette de chocolat', 2, 1200, 0, 18, 2400);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p27;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 554 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p27;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 554 MINUTE), 'Encaissement', 11900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 11900, 11900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 733 MINUTE), 1864, 336, 2200, 2200, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 6, 300, 0, 18, 1800);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 733 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p20, 'Stylo bille bleu', 2, 200, 0, 18, 400);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 733 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p20;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 733 MINUTE), 'Encaissement', 2200, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2200, 2200, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 759 MINUTE), 10424, 1876, 12300, 13000, 700, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p27, 'Tablette de chocolat', 4, 1200, 0, 18, 4800);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p27;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 759 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p27;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 3, 500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 759 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p12, 'Fromage fondu 8 portions', 4, 1500, 0, 18, 6000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p12;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 759 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p12;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 759 MINUTE), 'Encaissement', 12300, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 13000, 12300, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 790 MINUTE), 5508, 992, 6500, 6500, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p30, 'Saisie de document (la page)', 3, 1000, 0, 18, 3000);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p26, 'Chips 150 g', 2, 1000, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 790 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p26;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 3, 500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 790 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 790 MINUTE), 'Encaissement', 6500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 6500, 6500, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 825 MINUTE), 339, 61, 400, 1000, 600, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 1, 400, 0, 18, 400);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 825 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 825 MINUTE), 'Encaissement', 400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 968 MINUTE), 1441, 259, 1700, 2000, 300, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 3, 400, 0, 18, 1200);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 968 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 968 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 968 MINUTE), 'Encaissement', 1700, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2000, 1700, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 974 MINUTE), 9534, 1716, 11250, 11250, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p29, 'Impression couleur (la page)', 11, 250, 0, 18, 2750);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 974 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p4, 'Riz parfumé 5 kg', 1, 7500, 0, 18, 7500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p4;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 974 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p4;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 974 MINUTE), 'Encaissement', 11250, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 11250, 11250, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1081 MINUTE), 8178, 1472, 9650, 9650, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p4, 'Riz parfumé 5 kg', 1, 7500, 0, 18, 7500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p4;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1081 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p4;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 7, 250, 0, 18, 1750);
UPDATE Produits SET StockActuel = StockActuel - 7 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1081 MINUTE), 'Vente', -7, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 1, 400, 0, 18, 400);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1081 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1081 MINUTE), 'Encaissement', 9650, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 9650, 9650, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1099 MINUTE), 11864, 2136, 14000, 14000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p5, 'Huile végétale 1 L', 1, 1800, 0, 18, 1800);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p5;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1099 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p5;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 32, 100, 0, 18, 3200);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, 'Jus d''orange 1 L', 6, 1500, 0, 18, 9000);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1099 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p3;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1099 MINUTE), 'Encaissement', 14000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 14000, 14000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1105 MINUTE), 1017, 183, 1200, 2000, 800, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p14, 'Dentifrice 75 ml', 1, 1200, 0, 18, 1200);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p14;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1105 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p14;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1105 MINUTE), 'Encaissement', 1200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2000, 1200, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D011');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1114 MINUTE), 847, 153, 1000, 1000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1114 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 2, 250, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1114 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1114 MINUTE), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D012');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1161 MINUTE), 4237, 763, 5000, 5000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 4, 500, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1161 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p2;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, 'Jus d''orange 1 L', 2, 1500, 0, 18, 3000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1161 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p3;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 6 DAY) + INTERVAL 1161 MINUTE), 'Encaissement', 5000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 5000, 5000, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-5 (clôturée)
SET @dstr = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 5 DAY), '%Y%m%d');
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATE_SUB(CURDATE(), INTERVAL 5 DAY), (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 450 MINUTE), (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1230 MINUTE), 50000, 50000, 0, 'Journée de démonstration', 'Cloturee'); SET @j = LAST_INSERT_ID();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 515 MINUTE), 1186, 214, 1400, 1400, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 515 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 1, 400, 0, 18, 400);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 515 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 515 MINUTE), 'Encaissement', 1400, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1400, 1400, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 693 MINUTE), 4492, 808, 5300, 5300, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p24, 'Écouteurs filaires', 1, 2500, 0, 18, 2500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p24;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 693 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p24;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 4, 500, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 693 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p20, 'Stylo bille bleu', 4, 200, 0, 18, 800);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 693 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p20;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 693 MINUTE), 'Encaissement', 5300, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 5300, 5300, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 733 MINUTE), 6356, 1144, 7500, 7500, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p15, 'Papier toilette x4', 3, 1500, 0, 18, 4500);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 733 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p15;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p12, 'Fromage fondu 8 portions', 1, 1500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p12;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 733 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p12;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 3, 500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 733 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 733 MINUTE), 'Encaissement', 7500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 7500, 7500, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 767 MINUTE), 593, 107, 700, 700, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 7, 100, 0, 18, 700);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 767 MINUTE), 'Encaissement', 700, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 700, 700, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 806 MINUTE), 1695, 305, 2000, 2000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 4, 500, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 806 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 806 MINUTE), 'Encaissement', 2000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2000, 2000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1036 MINUTE), 551, 99, 650, 650, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 1, 400, 0, 18, 400);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1036 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 1, 250, 0, 18, 250);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1036 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1036 MINUTE), 'Encaissement', 650, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 650, 650, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1109 MINUTE), 7034, 1266, 8300, 9000, 700, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 2, 600, 0, 18, 1200);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1109 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 2, 300, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1109 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1109 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p2;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, 'Jus d''orange 1 L', 4, 1500, 0, 18, 6000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1109 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p3;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1109 MINUTE), 'Encaissement', 8300, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 9000, 8300, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1156 MINUTE), 1949, 351, 2300, 3000, 700, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 23, 100, 0, 18, 2300);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1156 MINUTE), 'Encaissement', 2300, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3000, 2300, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1168 MINUTE), 6949, 1251, 8200, 9000, 800, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 4, 600, 0, 18, 2400);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1168 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1168 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p11;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p23, 'Chargeur USB', 1, 3500, 0, 18, 3500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p23;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1168 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p23;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 6, 300, 0, 18, 1800);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1168 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1168 MINUTE), 'Encaissement', 8200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 9000, 8200, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1173 MINUTE), 8898, 1602, 10500, 11000, 500, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p4, 'Riz parfumé 5 kg', 1, 7500, 0, 18, 7500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p4;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1173 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p4;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 6, 500, 0, 18, 3000);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1173 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 5 DAY) + INTERVAL 1173 MINUTE), 'Encaissement', 10500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 11000, 10500, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-4 (clôturée)
SET @dstr = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 4 DAY), '%Y%m%d');
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATE_SUB(CURDATE(), INTERVAL 4 DAY), (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 450 MINUTE), (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1230 MINUTE), 50000, 50000, 0, 'Journée de démonstration', 'Cloturee'); SET @j = LAST_INSERT_ID();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 443 MINUTE), 1102, 198, 1300, 1300, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 443 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 2, 400, 0, 18, 800);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 443 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 443 MINUTE), 'Encaissement', 1300, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1300, 1300, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 497 MINUTE), 1949, 351, 2300, 2300, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 1, 400, 0, 18, 400);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 497 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, 'Eau de javel 1 L', 1, 900, 0, 18, 900);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 497 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p16;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p20, 'Stylo bille bleu', 1, 200, 0, 18, 200);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 497 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p20;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, 'Lait concentré sucré 397 g', 1, 800, 0, 18, 800);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 497 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 497 MINUTE), 'Encaissement', 1200, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1200, 1200, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 497 MINUTE), 'Encaissement', 1100, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1100, 1100, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 503 MINUTE), 3814, 686, 4500, 4500, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, 'Eau de javel 1 L', 1, 900, 0, 18, 900);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 503 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p16;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p5, 'Huile végétale 1 L', 2, 1800, 0, 18, 3600);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p5;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 503 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p5;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 503 MINUTE), 'Encaissement', 4500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4500, 4500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 552 MINUTE), 847, 153, 1000, 1000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 552 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 552 MINUTE), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 500, 500, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 552 MINUTE), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 500, 500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 725 MINUTE), 847, 153, 1000, 1000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 725 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 725 MINUTE), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 741 MINUTE), 2712, 488, 3200, 4000, 800, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, 'Lait concentré sucré 397 g', 4, 800, 0, 18, 3200);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 741 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 741 MINUTE), 'Encaissement', 3200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4000, 3200, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 781 MINUTE), 847, 153, 1000, 1000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 781 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 781 MINUTE), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 814 MINUTE), 10593, 1907, 12500, 12500, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p27, 'Tablette de chocolat', 4, 1200, 0, 18, 4800);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p27;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 814 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p27;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p18, 'Liquide vaisselle 750 ml', 2, 1300, 0, 18, 2600);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p18;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 814 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p18;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 36, 100, 0, 18, 3600);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 3, 500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 814 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 814 MINUTE), 'Encaissement', 12500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 12500, 12500, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 964 MINUTE), 6186, 1114, 7300, 7300, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p17, 'Lessive en poudre 1 kg', 3, 2000, 0, 18, 6000);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p17;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 964 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p17;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p18, 'Liquide vaisselle 750 ml', 1, 1300, 0, 18, 1300);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p18;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 964 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p18;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 964 MINUTE), 'Encaissement', 7300, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 7300, 7300, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1044 MINUTE), 508, 92, 600, 600, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 1, 600, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1044 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1044 MINUTE), 'Encaissement', 600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 600, 600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D011');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1084 MINUTE), 1525, 275, 1800, 1800, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p21, 'Cahier 100 pages', 3, 600, 0, 18, 1800);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1084 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p21;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1084 MINUTE), 'Encaissement', 900, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 900, 900, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1084 MINUTE), 'Encaissement', 900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 900, 900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D012');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1087 MINUTE), 1949, 351, 2300, 2300, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 2, 400, 0, 18, 800);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1087 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p15, 'Papier toilette x4', 1, 1500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p15;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1087 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p15;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1087 MINUTE), 'Encaissement', 2300, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2300, 2300, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D013');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1094 MINUTE), 1610, 290, 1900, 2000, 100, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 2, 250, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1094 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, 'Lait concentré sucré 397 g', 1, 800, 0, 18, 800);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1094 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 2, 300, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1094 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1094 MINUTE), 'Encaissement', 1900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2000, 1900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D014');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1182 MINUTE), 847, 153, 1000, 1000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1182 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 4 DAY) + INTERVAL 1182 MINUTE), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-3 (clôturée)
SET @dstr = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 3 DAY), '%Y%m%d');
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATE_SUB(CURDATE(), INTERVAL 3 DAY), (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 450 MINUTE), (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 1230 MINUTE), 50000, 50000, 0, 'Journée de démonstration', 'Cloturee'); SET @j = LAST_INSERT_ID();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 509 MINUTE), 4746, 854, 5600, 5600, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p24, 'Écouteurs filaires', 2, 2500, 0, 18, 5000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p24;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 509 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p24;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p21, 'Cahier 100 pages', 1, 600, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p21;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 509 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p21;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 509 MINUTE), 'Encaissement', 5600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 5600, 5600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 534 MINUTE), 8051, 1449, 9500, 9500, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p29, 'Impression couleur (la page)', 38, 250, 0, 18, 9500);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 534 MINUTE), 'Encaissement', 9500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 9500, 9500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 674 MINUTE), 1017, 183, 1200, 1200, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p9, 'Pain de mie', 1, 1200, 0, 18, 1200);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p9;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 674 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p9;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 674 MINUTE), 'Encaissement', 1200, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1200, 1200, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 731 MINUTE), 3305, 595, 3900, 4000, 100, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 3, 500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 731 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p9, 'Pain de mie', 2, 1200, 0, 18, 2400);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p9;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 731 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p9;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 731 MINUTE), 'Encaissement', 3900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4000, 3900, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 766 MINUTE), 6356, 1144, 7500, 7500, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p9, 'Pain de mie', 6, 1200, 0, 18, 7200);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p9;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 766 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p9;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 1, 300, 0, 18, 300);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 766 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 766 MINUTE), 'Encaissement', 7500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 7500, 7500, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 767 MINUTE), 1356, 244, 1600, 2000, 400, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 4, 250, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 767 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p20, 'Stylo bille bleu', 3, 200, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 767 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p20;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 767 MINUTE), 'Encaissement', 1600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2000, 1600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 779 MINUTE), 508, 92, 600, 600, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 1, 600, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 779 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 779 MINUTE), 'Encaissement', 600, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 600, 600, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 815 MINUTE), 508, 92, 600, 1000, 400, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 1, 600, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 815 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p1;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 815 MINUTE), 'Encaissement', 600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 819 MINUTE), 508, 92, 600, 1000, 400, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p20, 'Stylo bille bleu', 1, 200, 0, 18, 200);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p20;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 819 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p20;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 1, 400, 0, 18, 400);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 819 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 819 MINUTE), 'Encaissement', 600, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 600, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 825 MINUTE), 5254, 946, 6200, 7000, 800, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 5, 500, 0, 18, 2500);
UPDATE Produits SET StockActuel = StockActuel - 5 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 825 MINUTE), 'Vente', -5, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 825 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, 'Lait concentré sucré 397 g', 4, 800, 0, 18, 3200);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 825 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 825 MINUTE), 'Encaissement', 6200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 7000, 6200, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D011');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 1022 MINUTE), 424, 76, 500, 500, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 1022 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 1022 MINUTE), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 500, 500, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D012');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 1049 MINUTE), 508, 92, 600, 600, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 2, 300, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 1049 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p25;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 1049 MINUTE), 'Encaissement', 600, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 600, 600, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D013');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 1096 MINUTE), 2458, 442, 2900, 3000, 100, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 3, 500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 1096 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 1, 400, 0, 18, 400);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 1096 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 4, 250, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 1096 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 3 DAY) + INTERVAL 1096 MINUTE), 'Encaissement', 2900, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3000, 2900, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-2 (clôturée)
SET @dstr = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '%Y%m%d');
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATE_SUB(CURDATE(), INTERVAL 2 DAY), (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 450 MINUTE), (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1230 MINUTE), 50000, 50000, 0, 'Journée de démonstration', 'Cloturee'); SET @j = LAST_INSERT_ID();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 475 MINUTE), 1780, 320, 2100, 3000, 900, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 1, 600, 0, 18, 600);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 475 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p22, 'Piles AA x4', 1, 1500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p22;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 475 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p22;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 475 MINUTE), 'Encaissement', 2100, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 3000, 2100, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 697 MINUTE), 847, 153, 1000, 1000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 697 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 697 MINUTE), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 500, 500, @op FROM ModesPaiement WHERE Id = @mm;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 697 MINUTE), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 500, 500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 758 MINUTE), 2712, 488, 3200, 4000, 800, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 4, 500, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 758 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 3, 400, 0, 18, 1200);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 758 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 758 MINUTE), 'Encaissement', 3200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4000, 3200, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 830 MINUTE), 3475, 625, 4100, 5000, 900, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p27, 'Tablette de chocolat', 3, 1200, 0, 18, 3600);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p27;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 830 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p27;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 2, 250, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 830 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 830 MINUTE), 'Encaissement', 4100, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 5000, 4100, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1050 MINUTE), 6017, 1083, 7100, 7100, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p29, 'Impression couleur (la page)', 15, 250, 0, 18, 3750);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 4, 400, 0, 18, 1600);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1050 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 1, 250, 0, 18, 250);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1050 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p22, 'Piles AA x4', 1, 1500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p22;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1050 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p22;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1050 MINUTE), 'Encaissement', 7100, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 7100, 7100, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1084 MINUTE), 1695, 305, 2000, 2000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, 'Lait concentré sucré 397 g', 1, 800, 0, 18, 800);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1084 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 2, 600, 0, 18, 1200);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1084 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p1;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1084 MINUTE), 'Encaissement', 2000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2000, 2000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1118 MINUTE), 2881, 519, 3400, 4000, 600, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p1, 'Coca-Cola 33 cl', 4, 600, 0, 18, 2400);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p1;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1118 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p1;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 5, 100, 0, 18, 500);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1118 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1118 MINUTE), 'Encaissement', 3400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4000, 3400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1150 MINUTE), 1907, 343, 2250, 2250, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 3, 250, 0, 18, 750);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1150 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 3, 500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1150 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1150 MINUTE), 'Encaissement', 2250, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2250, 2250, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1195 MINUTE), 1186, 214, 1400, 1400, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p16, 'Eau de javel 1 L', 1, 900, 0, 18, 900);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p16;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1195 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p16;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1195 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 2 DAY) + INTERVAL 1195 MINUTE), 'Encaissement', 1400, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1400, 1400, @op FROM ModesPaiement WHERE Id = @mm;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

-- Journée J-1 (clôturée)
SET @dstr = DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '%Y%m%d');
INSERT INTO JourneesCaisses (TenantId, CaisseId, NumeroJournee, DateJournee, DateOuverture, DateFermeture, SoldeInitial, SoldeFinal, EcartCloture, NoteCloture, Statut)
    VALUES (@t, @caisse, CONCAT(@code, '-', @dstr, '-DEMO'), DATE_SUB(CURDATE(), INTERVAL 1 DAY), (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 450 MINUTE), (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1230 MINUTE), 50000, 50000, 0, 'Journée de démonstration', 'Cloturee'); SET @j = LAST_INSERT_ID();
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D001');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 430 MINUTE), 1186, 214, 1400, 1400, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p25, 'Biscuits secs', 3, 300, 0, 18, 900);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p25;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 430 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p25;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 430 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 430 MINUTE), 'Encaissement', 1400, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1400, 1400, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D002');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 551 MINUTE), 847, 153, 1000, 1000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p26, 'Chips 150 g', 1, 1000, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 551 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p26;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 551 MINUTE), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D003');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 552 MINUTE), 5085, 915, 6000, 6000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p30, 'Saisie de document (la page)', 6, 1000, 0, 18, 6000);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 552 MINUTE), 'Encaissement', 6000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 6000, 6000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D004');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 613 MINUTE), 847, 153, 1000, 1000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 613 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 613 MINUTE), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D005');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 734 MINUTE), 847, 153, 1000, 1000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 734 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 734 MINUTE), 'Encaissement', 1000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 1000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D006');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 793 MINUTE), 424, 76, 500, 1000, 500, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 793 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 793 MINUTE), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D007');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 963 MINUTE), 8475, 1525, 10000, 10000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p4, 'Riz parfumé 5 kg', 1, 7500, 0, 18, 7500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p4;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 963 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p4;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p7, 'Pain baguette', 2, 250, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p7;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 963 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p7;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p26, 'Chips 150 g', 2, 1000, 0, 18, 2000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p26;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 963 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p26;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 963 MINUTE), 'Encaissement', 10000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 10000, 10000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D008');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1022 MINUTE), 9322, 1678, 11000, 11000, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p17, 'Lessive en poudre 1 kg', 4, 2000, 0, 18, 8000);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p17;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1022 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p17;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p3, 'Jus d''orange 1 L', 2, 1500, 0, 18, 3000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p3;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1022 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p3;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1022 MINUTE), 'Encaissement', 11000, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 11000, 11000, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D009');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1102 MINUTE), 4407, 793, 5200, 6000, 800, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p8, 'Croissant', 4, 400, 0, 18, 1600);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p8;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1102 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p8;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 36, 100, 0, 18, 3600);
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1102 MINUTE), 'Encaissement', 5200, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 6000, 5200, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D010');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1105 MINUTE), 3559, 641, 4200, 4200, 0, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p10, 'Lait concentré sucré 397 g', 4, 800, 0, 18, 3200);
UPDATE Produits SET StockActuel = StockActuel - 4 WHERE Id = @p10;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1105 MINUTE), 'Vente', -4, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p10;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p13, 'Savon de toilette', 2, 500, 0, 18, 1000);
UPDATE Produits SET StockActuel = StockActuel - 2 WHERE Id = @p13;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1105 MINUTE), 'Vente', -2, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p13;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1105 MINUTE), 'Encaissement', 4200, CONCAT('Vente POS ', @num), NULL, @motif, @mm, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 4200, 4200, @op FROM ModesPaiement WHERE Id = @mm;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D011');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1165 MINUTE), 13136, 2364, 15500, 16000, 500, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1165 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p29, 'Impression couleur (la page)', 36, 250, 0, 18, 9000);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p28, 'Photocopie (la page)', 30, 100, 0, 18, 3000);
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 6, 500, 0, 18, 3000);
UPDATE Produits SET StockActuel = StockActuel - 6 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1165 MINUTE), 'Vente', -6, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1165 MINUTE), 'Encaissement', 15500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 16000, 15500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D012');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u2, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1165 MINUTE), 424, 76, 500, 1000, 500, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p11, 'Yaourt nature', 1, 500, 0, 18, 500);
UPDATE Produits SET StockActuel = StockActuel - 1 WHERE Id = @p11;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1165 MINUTE), 'Vente', -1, StockActuel, @num, @cmd, @u2, NULL FROM Produits WHERE Id = @p11;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1165 MINUTE), 'Encaissement', 500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u2, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 1000, 500, @op FROM ModesPaiement WHERE Id = @esp;
SET @num = CONCAT('POS-', @code, '-', @dstr, '-D013');
INSERT INTO CommandesPos (TenantId, Numero, CleClient, JourneeCaisseId, ClientId, UtilisateurId, DateCommande, TotalHT, TotalTVA, TotalTTC, MontantRecu, MonnaieRendue, Statut)
    VALUES (@t, @num, CONCAT('demo-', @num), @j, NULL, @u1, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1197 MINUTE), 1271, 229, 1500, 2000, 500, 'Payée'); SET @cmd = LAST_INSERT_ID();
INSERT INTO LignesCommandePos (TenantId, CommandePosId, ProduitId, Libelle, Quantite, PrixUnitaire, Remise, TauxTVA, TotalTTC)
    VALUES (@t, @cmd, @p2, 'Eau minérale 1,5 L', 3, 500, 0, 18, 1500);
UPDATE Produits SET StockActuel = StockActuel - 3 WHERE Id = @p2;
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Reference, CommandePosId, UtilisateurId, Commentaire)
    SELECT @t, Id, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1197 MINUTE), 'Vente', -3, StockActuel, @num, @cmd, @u1, NULL FROM Produits WHERE Id = @p2;
INSERT INTO OperationsCaisses (TenantId, JourneeCaisseId, DateOperation, TypeOperation, Montant, Libelle, ClientId, MotifId, ModePaiementId, UtilisateurId, EstJustifie, StatutValidation, Valideur)
    VALUES (@t, @j, (DATE_SUB(CURDATE(), INTERVAL 1 DAY) + INTERVAL 1197 MINUTE), 'Encaissement', 1500, CONCAT('Vente POS ', @num), NULL, @motif, @esp, @u1, 1, 'Validé', 'Point de vente'); SET @op = LAST_INSERT_ID();
INSERT INTO PaiementsPos (TenantId, CommandePosId, ModePaiementId, Libelle, MontantRecu, Montant, OperationCaisseId)
    SELECT @t, @cmd, Id, COALESCE(Libelle, Code, 'Espèces'), 2000, 1500, @op FROM ModesPaiement WHERE Id = @esp;
UPDATE JourneesCaisses SET SoldeFinal = SoldeInitial + COALESCE((SELECT SUM(o.Montant) FROM OperationsCaisses o
    WHERE o.JourneeCaisseId = @j AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'), 0), EcartCloture = 0 WHERE Id = @j;

COMMIT;
SELECT CONCAT('Données de démonstration enregistrées pour la société ', (SELECT Nom FROM Tenants WHERE Id = @t), ' (Id ', @t, ').') AS Resultat;
