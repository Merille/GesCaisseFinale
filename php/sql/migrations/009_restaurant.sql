-- Restaurant et bar (comme le point de vente restaurant d'Odoo) : chaque caisse a un type
-- (Boutique, Restaurant ou Bar). En restaurant / bar : salles et tables sur un plan, commande
-- ouverte sur la table jusqu'au paiement (partagée entre serveurs et appareils), bons de
-- préparation envoyés en cuisine ou au bar selon la catégorie, addition, partage, pourboire.
ALTER TABLE Caisses
    ADD COLUMN TypePointVente VARCHAR(20) NOT NULL DEFAULT 'Boutique',
    ADD COLUMN ImprimerBons TINYINT(1) NOT NULL DEFAULT 1;

-- Poste de préparation des produits de la catégorie : Cuisine, Bar ou Aucun (pas de bon).
ALTER TABLE Categories
    ADD COLUMN Preparation VARCHAR(20) NOT NULL DEFAULT 'Cuisine';

CREATE TABLE IF NOT EXISTS Salles (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    CaisseId INT NOT NULL,
    Nom VARCHAR(50) NOT NULL,
    Ordre INT NOT NULL DEFAULT 0,
    KEY IX_Salles_Caisse (CaisseId),
    CONSTRAINT FK_Salles_Caisses FOREIGN KEY (CaisseId) REFERENCES Caisses (ID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Position et taille en points sur un plan de 1000 × 600.
CREATE TABLE IF NOT EXISTS TablesRestaurant (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    SalleId INT NOT NULL,
    Nom VARCHAR(30) NOT NULL,
    Places INT NOT NULL DEFAULT 4,
    Forme VARCHAR(10) NOT NULL DEFAULT 'carree',
    PosX INT NOT NULL DEFAULT 20,
    PosY INT NOT NULL DEFAULT 20,
    Largeur INT NOT NULL DEFAULT 100,
    Hauteur INT NOT NULL DEFAULT 100,
    Actif TINYINT(1) NOT NULL DEFAULT 1,
    KEY IX_TablesRestaurant_Salle (SalleId),
    CONSTRAINT FK_TablesRestaurant_Salles FOREIGN KEY (SalleId) REFERENCES Salles (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Commande en cours sur une table (Contenu : lignes, client et remise en JSON). Version :
-- contrôle des modifications faites en même temps sur deux appareils.
CREATE TABLE IF NOT EXISTS CommandesOuvertes (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    CaisseId INT NOT NULL,
    JourneeCaisseId INT NOT NULL,
    TableId INT NULL,
    Couverts INT NOT NULL DEFAULT 1,
    UtilisateurId INT NULL,
    DateOuverture DATETIME NOT NULL,
    DateMaj DATETIME NOT NULL,
    Version INT NOT NULL DEFAULT 1,
    AdditionImprimee TINYINT(1) NOT NULL DEFAULT 0,
    Contenu MEDIUMTEXT NOT NULL,
    UNIQUE KEY UX_CommandesOuvertes_Table (TableId),
    KEY IX_CommandesOuvertes_Journee (JourneeCaisseId),
    CONSTRAINT FK_CommandesOuvertes_Journees FOREIGN KEY (JourneeCaisseId) REFERENCES JourneesCaisses (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Bons de préparation (cuisine / bar) : imprimés et affichés sur l'écran cuisine / bar.
CREATE TABLE IF NOT EXISTS BonsPreparation (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    CaisseId INT NOT NULL,
    JourneeCaisseId INT NOT NULL,
    CommandeOuverteId INT NULL,
    Numero INT NOT NULL DEFAULT 0,
    Poste VARCHAR(20) NOT NULL,
    TableNom VARCHAR(60) NULL,
    Couverts INT NULL,
    Serveur VARCHAR(100) NULL,
    DateEnvoi DATETIME NOT NULL,
    Statut VARCHAR(20) NOT NULL DEFAULT 'À préparer',
    DatePret DATETIME NULL,
    KEY IX_BonsPreparation_Caisse (CaisseId, Statut),
    CONSTRAINT FK_BonsPreparation_Journees FOREIGN KEY (JourneeCaisseId) REFERENCES JourneesCaisses (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Quantité négative : article annulé après l'envoi.
CREATE TABLE IF NOT EXISTS LignesBonPreparation (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    BonPreparationId INT NOT NULL,
    Libelle VARCHAR(200) NOT NULL,
    Quantite DECIMAL(18,2) NOT NULL DEFAULT 0,
    Note VARCHAR(200) NULL,
    KEY IX_LignesBonPreparation_Bon (BonPreparationId),
    CONSTRAINT FK_LignesBonPreparation_Bons FOREIGN KEY (BonPreparationId) REFERENCES BonsPreparation (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Vente servie à table : table, couverts et pourboire (en plus du total TTC).
ALTER TABLE CommandesPos
    ADD COLUMN TableNom VARCHAR(60) NULL,
    ADD COLUMN Couverts INT NULL,
    ADD COLUMN Pourboire DECIMAL(18,2) NOT NULL DEFAULT 0;

-- Note de l'article (« sans oignon », « bien cuit »).
ALTER TABLE LignesCommandePos
    ADD COLUMN Note VARCHAR(200) NULL;
