-- Livraisons : livreurs (sans compte de connexion), commandes mises en attente au point de vente
-- (gardées sur le serveur, visibles depuis tous les postes de la journée) et livraison d'une vente
-- (livreur, destinataire, statut « À livrer » puis « Livrée »).
-- Compatible MySQL 5.7+ et MariaDB 10.2+.

CREATE TABLE IF NOT EXISTS Livreurs (
    Id INT NOT NULL AUTO_INCREMENT,
    TenantId INT NOT NULL,
    Nom VARCHAR(100) NOT NULL,
    Telephone VARCHAR(30) NULL,
    Actif TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (Id),
    KEY IX_Livreurs_TenantId (TenantId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS CommandesAttente (
    Id INT NOT NULL AUTO_INCREMENT,
    TenantId INT NOT NULL,
    JourneeCaisseId INT NOT NULL,
    Numero INT NOT NULL,
    DateCreation DATETIME NOT NULL,
    UtilisateurId INT NOT NULL,
    ClientId INT NULL,
    Contenu MEDIUMTEXT NOT NULL,
    Total DECIMAL(18,2) NOT NULL DEFAULT 0,
    NbArticles INT NOT NULL DEFAULT 0,
    LivreurId INT NULL,
    NomLivraison VARCHAR(100) NULL,
    TelephoneLivraison VARCHAR(30) NULL,
    AdresseLivraison VARCHAR(200) NULL,
    PRIMARY KEY (Id),
    KEY IX_CommandesAttente_JourneeCaisseId_Numero (JourneeCaisseId, Numero),
    KEY IX_CommandesAttente_LivreurId (LivreurId),
    CONSTRAINT FK_CommandesAttente_JourneesCaisses FOREIGN KEY (JourneeCaisseId) REFERENCES JourneesCaisses (Id) ON DELETE CASCADE,
    CONSTRAINT FK_CommandesAttente_Livreurs FOREIGN KEY (LivreurId) REFERENCES Livreurs (Id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE CommandesPos
    ADD COLUMN LivreurId INT NULL,
    ADD COLUMN NomLivraison VARCHAR(100) NULL,
    ADD COLUMN TelephoneLivraison VARCHAR(30) NULL,
    ADD COLUMN AdresseLivraison VARCHAR(200) NULL,
    ADD COLUMN StatutLivraison VARCHAR(20) NULL,
    ADD COLUMN DateLivraison DATETIME NULL,
    ADD KEY IX_CommandesPos_LivreurId (LivreurId),
    ADD CONSTRAINT FK_CommandesPos_Livreurs FOREIGN KEY (LivreurId) REFERENCES Livreurs (Id);
