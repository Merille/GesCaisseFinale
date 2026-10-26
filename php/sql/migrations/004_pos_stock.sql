-- Point de vente, étape 5 : historique des mouvements de stock et option « vente sans stock ».
CREATE TABLE IF NOT EXISTS MouvementsStock (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    ProduitId INT NOT NULL,
    DateMouvement DATETIME NOT NULL,
    TypeMouvement VARCHAR(20) NOT NULL,
    Quantite DECIMAL(18,2) NOT NULL DEFAULT 0,
    StockApres DECIMAL(18,2) NOT NULL DEFAULT 0,
    Reference VARCHAR(100) NULL,
    CommandePosId INT NULL,
    UtilisateurId INT NULL,
    Commentaire VARCHAR(300) NULL,
    KEY IX_MouvementsStock_Produit (ProduitId, DateMouvement),
    KEY IX_MouvementsStock_Tenant (TenantId, DateMouvement),
    CONSTRAINT FK_MouvementsStock_Produits FOREIGN KEY (ProduitId) REFERENCES Produits (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 1 = la vente reste possible quand le stock est épuisé (avec un avertissement) ; 0 = interdite.
ALTER TABLE Tenants ADD COLUMN PosVenteSansStock TINYINT(1) NOT NULL DEFAULT 1;

-- Point de départ de l'historique : stock actuel des produits suivis.
INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Commentaire)
SELECT TenantId, Id, NOW(), 'Stock initial', StockActuel, StockActuel, 'Stock au démarrage de l''historique'
FROM Produits WHERE SuiviStock = 1;
