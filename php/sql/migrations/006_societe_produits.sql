-- Coordonnées de la société (en-tête des tickets, factures et impressions) et logo.
ALTER TABLE Tenants
    ADD COLUMN Adresse VARCHAR(250) NULL,
    ADD COLUMN Ville VARCHAR(100) NULL,
    ADD COLUMN Pays VARCHAR(100) NULL,
    ADD COLUMN Email VARCHAR(150) NULL,
    ADD COLUMN Telephone VARCHAR(50) NULL,
    ADD COLUMN NIF VARCHAR(50) NULL,
    ADD COLUMN LogoMaj DATETIME NULL;

-- Images enregistrées dans la base (aucun dossier à copier lors d'une mise à jour du site).
CREATE TABLE IF NOT EXISTS TenantLogos (
    TenantId INT NOT NULL PRIMARY KEY,
    TypeContenu VARCHAR(30) NOT NULL,
    Donnees MEDIUMBLOB NOT NULL,
    CONSTRAINT FK_TenantLogos_Tenants FOREIGN KEY (TenantId) REFERENCES Tenants (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Produits : coût d'achat (HT), unité de vente et image.
ALTER TABLE Produits
    ADD COLUMN Cout DECIMAL(18,2) NULL,
    ADD COLUMN Unite VARCHAR(20) NOT NULL DEFAULT 'Unité',
    ADD COLUMN ImageMaj DATETIME NULL;

CREATE TABLE IF NOT EXISTS ProduitImages (
    ProduitId INT NOT NULL PRIMARY KEY,
    TypeContenu VARCHAR(30) NOT NULL,
    Donnees MEDIUMBLOB NOT NULL,
    CONSTRAINT FK_ProduitImages_Produits FOREIGN KEY (ProduitId) REFERENCES Produits (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
