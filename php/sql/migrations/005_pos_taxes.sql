-- Point de vente : plusieurs taxes par produit (ex. TVA 18 % + CSS 1 %).
-- Les taxes s'additionnent sur le HT ; le prix de vente reste saisi TTC.
-- Produits.TauxTVA conserve le taux total (somme des taxes du produit).
CREATE TABLE IF NOT EXISTS Taxes (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    Code VARCHAR(20) NOT NULL,
    Libelle VARCHAR(100) NOT NULL,
    Taux DECIMAL(5,2) NOT NULL DEFAULT 0,
    ParDefaut TINYINT(1) NOT NULL DEFAULT 0,
    KEY IX_Taxes_Tenant (TenantId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ProduitTaxes (
    ProduitId INT NOT NULL,
    TaxeId INT NOT NULL,
    PRIMARY KEY (ProduitId, TaxeId),
    KEY IX_ProduitTaxes_Taxe (TaxeId),
    CONSTRAINT FK_ProduitTaxes_Produits FOREIGN KEY (ProduitId) REFERENCES Produits (Id) ON DELETE CASCADE,
    CONSTRAINT FK_ProduitTaxes_Taxes FOREIGN KEY (TaxeId) REFERENCES Taxes (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Détail des taxes de chaque ligne vendue (code et taux figés au moment de la vente).
CREATE TABLE IF NOT EXISTS LignesCommandePosTaxes (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    LigneCommandePosId INT NOT NULL,
    TaxeId INT NULL,
    Code VARCHAR(20) NOT NULL,
    Taux DECIMAL(5,2) NOT NULL DEFAULT 0,
    Montant DECIMAL(18,2) NOT NULL DEFAULT 0,
    KEY IX_LignesCommandePosTaxes_Ligne (LigneCommandePosId),
    CONSTRAINT FK_LignesCommandePosTaxes_Lignes FOREIGN KEY (LigneCommandePosId) REFERENCES LignesCommandePos (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Taxes de départ de chaque société : TVA 18 % (proposée par défaut) et CSS 1 %.
INSERT INTO Taxes (TenantId, Code, Libelle, Taux, ParDefaut)
SELECT Id, 'TVA', 'Taxe sur la valeur ajoutée', 18, 1 FROM Tenants;
INSERT INTO Taxes (TenantId, Code, Libelle, Taux, ParDefaut)
SELECT Id, 'CSS', 'Contribution spéciale de solidarité', 1, 0 FROM Tenants;

-- Autres taux de TVA déjà utilisés par des produits (ex. TVA10 pour 10 %).
INSERT INTO Taxes (TenantId, Code, Libelle, Taux, ParDefaut)
SELECT DISTINCT p.TenantId,
       CONCAT('TVA', REPLACE(TRIM(TRAILING '.' FROM TRIM(TRAILING '0' FROM CAST(p.TauxTVA AS CHAR))), '.', ',')),
       'Taxe sur la valeur ajoutée', p.TauxTVA, 0
FROM Produits p
WHERE p.TauxTVA > 0 AND p.TauxTVA <> 18;

-- Chaque produit reçoit la TVA correspondant à son taux actuel.
INSERT INTO ProduitTaxes (ProduitId, TaxeId)
SELECT p.Id, MIN(t.Id)
FROM Produits p
JOIN Taxes t ON t.TenantId = p.TenantId AND t.Taux = p.TauxTVA AND t.Code LIKE 'TVA%'
WHERE p.TauxTVA > 0
GROUP BY p.Id;
