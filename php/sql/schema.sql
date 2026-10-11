-- GesCaisse (version PHP / MySQL) : structure de la base.
-- Les noms de tables et de colonnes reprennent ceux de la version .NET
-- (SQL Server) pour faciliter une éventuelle reprise des données.
--
-- Utilisation : créer une base vide (ex. gescaisse), puis importer ce fichier
-- (phpMyAdmin > Importer, ou : mysql -u root -p gescaisse < schema.sql).

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS Tenants (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    Nom VARCHAR(200) NOT NULL,
    Code VARCHAR(50) NOT NULL,
    Actif TINYINT(1) NOT NULL DEFAULT 1,
    ModeAcces VARCHAR(20) NOT NULL DEFAULT 'Licence',   -- Licence / Abonnement
    DateExpiration DATE NULL,
    DateCreation DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS Utilisateurs (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    NomUtilisateur VARCHAR(100) NOT NULL,
    MotPasse VARCHAR(255) NOT NULL,
    NomComplet VARCHAR(200) NOT NULL,
    Profil VARCHAR(30) NOT NULL,                        -- SuperAdmin / Admin / Caissier
    PeutValiderOperations TINYINT(1) NOT NULL DEFAULT 0,
    TenantId INT NULL,                                  -- NULL = SuperAdmin (toutes les sociétés)
    UNIQUE KEY UX_Utilisateurs_Nom (NomUtilisateur),
    CONSTRAINT FK_Utilisateurs_Tenants FOREIGN KEY (TenantId) REFERENCES Tenants (Id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS Caisses (
    ID INT AUTO_INCREMENT PRIMARY KEY,
    ChkCode VARCHAR(50) NULL,
    ChkDescription VARCHAR(200) NULL,
    StCode VARCHAR(50) NULL,
    SalesPersonDefault INT NULL,
    CashierDefault INT NULL,
    CustomerDefaultCode VARCHAR(50) NULL DEFAULT 'C0001',
    JournalDefaultCode VARCHAR(50) NULL DEFAULT 'J0001',
    CompteComptable VARCHAR(50) NULL,                   -- contrepartie caisse pour l'export Sage
    TenantId INT NOT NULL DEFAULT 0,
    KEY IX_Caisses_Tenant (TenantId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS Clients (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    CodeClient VARCHAR(50) NOT NULL,
    NomSociete VARCHAR(200) NOT NULL,
    Adresse VARCHAR(300) NULL,
    Telephone VARCHAR(50) NULL,
    Email VARCHAR(150) NULL,
    Type VARCHAR(50) NULL,                              -- Client / Fournisseur / Salarié / Autre
    CompteGeneral VARCHAR(50) NULL,
    NomContact VARCHAR(150) NULL,
    FonctionContact VARCHAR(150) NULL,
    TelephoneContact VARCHAR(50) NULL,
    EmailContact VARCHAR(150) NULL,
    KEY IX_Clients_Tenant (TenantId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS Motifs (
    ID INT AUTO_INCREMENT PRIMARY KEY,
    LibelleMotif VARCHAR(200) NULL,
    TypeModif VARCHAR(50) NULL,
    CG_Num VARCHAR(50) NULL,                            -- compte général (export Sage)
    TenantId INT NOT NULL DEFAULT 0,
    KEY IX_Motifs_Tenant (TenantId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ModesPaiement (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    Code VARCHAR(30) NULL,
    Libelle VARCHAR(100) NULL,
    Actif TINYINT(1) NOT NULL DEFAULT 1,
    TenantId INT NOT NULL DEFAULT 0,
    KEY IX_ModesPaiement_Tenant (TenantId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS JourneesCaisses (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    CaisseId INT NOT NULL,
    NumeroJournee VARCHAR(50) NOT NULL,
    DateJournee DATE NOT NULL,
    DateOuverture DATETIME NOT NULL,
    DateFermeture DATETIME NULL,
    SoldeInitial DECIMAL(18,2) NOT NULL DEFAULT 0,
    SoldeFinal DECIMAL(18,2) NOT NULL DEFAULT 0,
    EcartCloture DECIMAL(18,2) NULL,
    NoteCloture VARCHAR(500) NULL,
    Statut VARCHAR(20) NOT NULL DEFAULT 'Ouverte',     -- Ouverte / Cloturee
    KEY IX_Journees_Tenant (TenantId),
    KEY IX_Journees_Caisse (CaisseId),
    CONSTRAINT FK_Journees_Caisses FOREIGN KEY (CaisseId) REFERENCES Caisses (ID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS OperationsCaisses (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    JourneeCaisseId INT NOT NULL,
    DateOperation DATETIME NOT NULL,
    TypeOperation VARCHAR(20) NOT NULL,                 -- Encaissement / Décaissement
    Montant DECIMAL(18,2) NOT NULL DEFAULT 0,
    Libelle VARCHAR(300) NULL,
    ClientId INT NULL,
    MotifId INT NULL,
    ModePaiementId INT NULL,
    UtilisateurId INT NOT NULL,
    EstJustifie TINYINT(1) NOT NULL DEFAULT 0,
    StatutValidation VARCHAR(20) NOT NULL DEFAULT 'En attente',  -- En attente / Validé / Rejeté
    Valideur VARCHAR(200) NULL,
    Observation VARCHAR(500) NULL,
    KEY IX_Operations_Tenant (TenantId),
    KEY IX_Operations_Journee (JourneeCaisseId),
    KEY IX_Operations_Date (DateOperation),
    CONSTRAINT FK_Operations_Journees FOREIGN KEY (JourneeCaisseId) REFERENCES JourneesCaisses (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ComptagesCloture (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    JourneeCaisseId INT NOT NULL,
    ModePaiementId INT NULL,
    MontantTheorique DECIMAL(18,2) NOT NULL DEFAULT 0,
    MontantCompte DECIMAL(18,2) NOT NULL DEFAULT 0,
    TenantId INT NOT NULL DEFAULT 0,
    KEY IX_Comptages_Journee (JourneeCaisseId),
    CONSTRAINT FK_Comptages_Journees FOREIGN KEY (JourneeCaisseId) REFERENCES JourneesCaisses (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS Factures (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    Numero VARCHAR(50) NOT NULL,
    DateFacture DATETIME NOT NULL,
    ClientId INT NOT NULL,
    MontantHT DECIMAL(18,2) NOT NULL DEFAULT 0,
    TauxTVA DECIMAL(5,2) NOT NULL DEFAULT 0,
    MontantTVA DECIMAL(18,2) NOT NULL DEFAULT 0,
    MontantTTC DECIMAL(18,2) NOT NULL DEFAULT 0,
    MontantPaye DECIMAL(18,2) NOT NULL DEFAULT 0,
    Statut VARCHAR(20) NOT NULL DEFAULT 'Brouillon',   -- Brouillon / Validée
    KEY IX_Factures_Tenant (TenantId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS LignesFactures (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    FactureId INT NOT NULL,
    Designation VARCHAR(300) NOT NULL,
    Quantite DECIMAL(18,2) NOT NULL DEFAULT 0,
    PrixUnitaire DECIMAL(18,2) NOT NULL DEFAULT 0,
    TotalLigne DECIMAL(18,2) NOT NULL DEFAULT 0,
    KEY IX_Lignes_Facture (FactureId),
    CONSTRAINT FK_Lignes_Factures FOREIGN KEY (FactureId) REFERENCES Factures (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------------
-- Données de départ (identiques à la version .NET) :
--   superadmin / 123  (toutes les sociétés)
--   admin / 123       (Société de démonstration)
-- Changez ces mots de passe après la première connexion.
-- Les mots de passe sont stockés au format SHA-256 + Base64 de la version
-- .NET ; ils sont automatiquement convertis en bcrypt à la première connexion.
-- ---------------------------------------------------------------------------
INSERT INTO Tenants (Id, Nom, Code, Actif, ModeAcces)
SELECT 1, 'Société de démonstration', 'DEMO', 1, 'Licence'
WHERE NOT EXISTS (SELECT 1 FROM Tenants);

INSERT INTO Utilisateurs (NomUtilisateur, MotPasse, NomComplet, Profil, PeutValiderOperations, TenantId)
SELECT 'superadmin', 'pmWkWSBCL51Bfkhn79xPuKBKHz//H6B+mY6G9/eieuM=', 'Super Administrateur', 'SuperAdmin', 1, NULL
WHERE NOT EXISTS (SELECT 1 FROM Utilisateurs WHERE NomUtilisateur = 'superadmin');

INSERT INTO Utilisateurs (NomUtilisateur, MotPasse, NomComplet, Profil, PeutValiderOperations, TenantId)
SELECT 'admin', 'pmWkWSBCL51Bfkhn79xPuKBKHz//H6B+mY6G9/eieuM=', 'Administrateur', 'Admin', 1, 1
WHERE NOT EXISTS (SELECT 1 FROM Utilisateurs WHERE NomUtilisateur = 'admin');

INSERT INTO Caisses (ChkCode, ChkDescription, StCode, SalesPersonDefault, CashierDefault, CustomerDefaultCode, JournalDefaultCode, TenantId)
SELECT 'CASH1', 'Caisse principale', 'ST01', NULL, NULL, 'CUST001', 'JRN01', 1
WHERE NOT EXISTS (SELECT 1 FROM Caisses);
