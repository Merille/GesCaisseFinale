-- Achats (laverie : lessive, javel, assouplissant…) : bon d'achat d'un fournisseur (tiers de type
-- Fournisseur) dont les lignes entrent en stock dans un dépôt (mouvement « Achat ») et mettent à
-- jour le coût du produit (coût moyen pondéré). Règlements : par la caisse (décaissement dans une
-- journée ouverte), hors caisse (virement, chèque…) ou plus tard (achat à crédit).
-- Consommation : sortie de stock des produits utilisés pour le service (mouvement « Consommation »).
-- Produits.Consommable : produit d'usage interne, jamais proposé à la vente en caisse.
-- Compatible MySQL 5.7+ et MariaDB 10.2+.

ALTER TABLE Produits ADD COLUMN Consommable TINYINT(1) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS Achats (
    Id INT NOT NULL AUTO_INCREMENT,
    TenantId INT NOT NULL,
    Numero INT NOT NULL,
    DateAchat DATE NOT NULL,
    FournisseurId INT NULL,
    DepotId INT NOT NULL,
    Reference VARCHAR(100) NULL,
    Commentaire VARCHAR(300) NULL,
    Total DECIMAL(18,2) NOT NULL DEFAULT 0,
    Statut VARCHAR(20) NOT NULL DEFAULT 'Validé',
    UtilisateurId INT NULL,
    DateCreation DATETIME NOT NULL,
    DateAnnulation DATETIME NULL,
    PRIMARY KEY (Id),
    UNIQUE KEY IX_Achats_TenantId_Numero (TenantId, Numero),
    KEY IX_Achats_TenantId_DateAchat (TenantId, DateAchat)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS LignesAchats (
    Id INT NOT NULL AUTO_INCREMENT,
    AchatId INT NOT NULL,
    ProduitId INT NOT NULL,
    Quantite DECIMAL(18,2) NOT NULL DEFAULT 0,
    PrixUnitaire DECIMAL(18,2) NOT NULL DEFAULT 0,
    Montant DECIMAL(18,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (Id),
    KEY IX_LignesAchats_AchatId (AchatId),
    CONSTRAINT FK_LignesAchats_Achats_AchatId FOREIGN KEY (AchatId) REFERENCES Achats (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ReglementsAchats (
    Id INT NOT NULL AUTO_INCREMENT,
    AchatId INT NOT NULL,
    DateReglement DATETIME NOT NULL,
    Montant DECIMAL(18,2) NOT NULL DEFAULT 0,
    ModePaiementId INT NULL,
    OperationCaisseId INT NULL,
    UtilisateurId INT NULL,
    PRIMARY KEY (Id),
    KEY IX_ReglementsAchats_AchatId (AchatId),
    CONSTRAINT FK_ReglementsAchats_Achats_AchatId FOREIGN KEY (AchatId) REFERENCES Achats (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
