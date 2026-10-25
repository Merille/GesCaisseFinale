-- GesCaisse : mise à jour d'une base existante pour le point de vente (étape 1).
-- À importer une seule fois dans la base (phpMyAdmin > Importer) ; sans effet si
-- les tables existent déjà. Aucune donnée existante n'est modifiée.

SET NAMES utf8mb4;

-- Point de vente (POS) - étape 1 : catalogue produits.
CREATE TABLE IF NOT EXISTS Categories (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    Nom VARCHAR(100) NOT NULL,
    Couleur VARCHAR(7) NOT NULL DEFAULT '#195d84',
    Ordre INT NOT NULL DEFAULT 0,
    KEY IX_Categories_Tenant (TenantId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Prix de vente saisi TTC ; la TVA est calculée à partir du TTC.
CREATE TABLE IF NOT EXISTS Produits (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    Code VARCHAR(50) NOT NULL,
    CodeBarres VARCHAR(50) NULL,
    Nom VARCHAR(200) NOT NULL,
    CategorieId INT NULL,
    PrixVente DECIMAL(18,2) NOT NULL DEFAULT 0,
    TauxTVA DECIMAL(5,2) NOT NULL DEFAULT 18,
    SuiviStock TINYINT(1) NOT NULL DEFAULT 1,
    StockActuel DECIMAL(18,2) NOT NULL DEFAULT 0,
    SeuilAlerte DECIMAL(18,2) NULL,
    Actif TINYINT(1) NOT NULL DEFAULT 1,
    UNIQUE KEY UX_Produits_Code (TenantId, Code),
    KEY IX_Produits_CodeBarres (CodeBarres),
    KEY IX_Produits_Categorie (CategorieId),
    CONSTRAINT FK_Produits_Categories FOREIGN KEY (CategorieId) REFERENCES Categories (Id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
