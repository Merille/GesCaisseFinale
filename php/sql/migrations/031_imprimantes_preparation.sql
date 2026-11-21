-- Imprimantes de préparation (cuisine, bar) en réseau : la caisse leur envoie les bons des catégories choisies.
CREATE TABLE IF NOT EXISTS ImprimantesPreparation (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    Nom VARCHAR(100) NOT NULL,
    Type VARCHAR(20) NOT NULL DEFAULT 'Epson',
    AdresseIp VARCHAR(100) NOT NULL,
    Port INT NULL,
    Largeur INT NOT NULL DEFAULT 80,
    Encodage VARCHAR(20) NOT NULL DEFAULT 'PC850',
    Bip TINYINT(1) NOT NULL DEFAULT 0,
    CaisseId INT NULL,
    Actif TINYINT(1) NOT NULL DEFAULT 1,
    KEY IX_ImprimantesPreparation_Tenant (TenantId),
    KEY FK_ImprimantesPreparation_Caisses (CaisseId),
    CONSTRAINT FK_ImprimantesPreparation_Caisses FOREIGN KEY (CaisseId) REFERENCES Caisses (ID) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ImprimantesPreparationCategories (
    ImprimantePreparationId INT NOT NULL,
    CategorieId INT NOT NULL,
    PRIMARY KEY (ImprimantePreparationId, CategorieId),
    KEY FK_ImprimantesPreparationCategories_Categories (CategorieId),
    CONSTRAINT FK_ImprimantesPreparationCategories_Imprimantes FOREIGN KEY (ImprimantePreparationId) REFERENCES ImprimantesPreparation (Id) ON DELETE CASCADE,
    CONSTRAINT FK_ImprimantesPreparationCategories_Categories FOREIGN KEY (CategorieId) REFERENCES Categories (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Catégorie de l'article sur chaque ligne de bon : chaque imprimante n'imprime que ses catégories.
ALTER TABLE LignesBonPreparation ADD COLUMN CategorieId INT NULL AFTER Note;
