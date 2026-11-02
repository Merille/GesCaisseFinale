-- Dépôts de stockage : le stock de chaque produit est suivi par dépôt (StocksDepots) ;
-- Produits.StockActuel reste le total de tous les dépôts. Chaque caisse est rattachée à un dépôt
-- (ses ventes en sortent) et chaque mouvement de stock indique son dépôt.
-- Données existantes : un « Dépôt principal » par société reçoit tout le stock actuel,
-- l'historique des mouvements et toutes les caisses.
-- Compatible MySQL 5.7+ et MariaDB 10.2+.

CREATE TABLE IF NOT EXISTS Depots (
    Id INT NOT NULL AUTO_INCREMENT,
    TenantId INT NOT NULL,
    Code VARCHAR(20) NOT NULL,
    Nom VARCHAR(100) NOT NULL,
    Adresse VARCHAR(200) NULL,
    Responsable VARCHAR(100) NULL,
    Actif TINYINT(1) NOT NULL DEFAULT 1,
    ParDefaut TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (Id),
    UNIQUE KEY IX_Depots_TenantId_Code (TenantId, Code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS StocksDepots (
    DepotId INT NOT NULL,
    ProduitId INT NOT NULL,
    Quantite DECIMAL(18,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (DepotId, ProduitId),
    KEY IX_StocksDepots_ProduitId (ProduitId),
    CONSTRAINT FK_StocksDepots_Depots FOREIGN KEY (DepotId) REFERENCES Depots (Id),
    CONSTRAINT FK_StocksDepots_Produits FOREIGN KEY (ProduitId) REFERENCES Produits (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO Depots (TenantId, Code, Nom, Actif, ParDefaut)
SELECT t.Id, 'DEP01', 'Dépôt principal', 1, 1 FROM Tenants t
WHERE NOT EXISTS (SELECT 1 FROM Depots d WHERE d.TenantId = t.Id);

INSERT IGNORE INTO StocksDepots (DepotId, ProduitId, Quantite)
SELECT d.Id, p.Id, p.StockActuel FROM Produits p
JOIN Depots d ON d.TenantId = p.TenantId AND d.ParDefaut = 1
WHERE p.StockActuel <> 0;

ALTER TABLE Caisses
    ADD COLUMN DepotId INT NULL,
    ADD KEY IX_Caisses_DepotId (DepotId),
    ADD CONSTRAINT FK_Caisses_Depots FOREIGN KEY (DepotId) REFERENCES Depots (Id);

UPDATE Caisses c JOIN Depots d ON d.TenantId = c.TenantId AND d.ParDefaut = 1 SET c.DepotId = d.Id;

ALTER TABLE MouvementsStock
    ADD COLUMN DepotId INT NULL,
    ADD KEY IX_MouvementsStock_DepotId (DepotId),
    ADD CONSTRAINT FK_MouvementsStock_Depots FOREIGN KEY (DepotId) REFERENCES Depots (Id);

UPDATE MouvementsStock m JOIN Depots d ON d.TenantId = m.TenantId AND d.ParDefaut = 1 SET m.DepotId = d.Id;
