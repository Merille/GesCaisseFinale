-- Point de vente, étape 3 : ventes (commandes, lignes, règlements).
CREATE TABLE IF NOT EXISTS CommandesPos (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    Numero VARCHAR(50) NOT NULL,
    CleClient VARCHAR(64) NOT NULL,
    JourneeCaisseId INT NOT NULL,
    ClientId INT NULL,
    UtilisateurId INT NOT NULL,
    DateCommande DATETIME NOT NULL,
    TotalHT DECIMAL(18,2) NOT NULL DEFAULT 0,
    TotalTVA DECIMAL(18,2) NOT NULL DEFAULT 0,
    TotalTTC DECIMAL(18,2) NOT NULL DEFAULT 0,
    MontantRecu DECIMAL(18,2) NOT NULL DEFAULT 0,
    MonnaieRendue DECIMAL(18,2) NOT NULL DEFAULT 0,
    Statut VARCHAR(20) NOT NULL DEFAULT 'Payée',
    FactureId INT NULL,
    UNIQUE KEY UX_CommandesPos_Numero (TenantId, Numero),
    UNIQUE KEY UX_CommandesPos_Cle (TenantId, CleClient),
    KEY IX_CommandesPos_Journee (JourneeCaisseId),
    CONSTRAINT FK_CommandesPos_Journees FOREIGN KEY (JourneeCaisseId) REFERENCES JourneesCaisses (Id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS LignesCommandePos (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    CommandePosId INT NOT NULL,
    ProduitId INT NULL,
    Libelle VARCHAR(200) NOT NULL,
    Quantite DECIMAL(18,2) NOT NULL DEFAULT 0,
    PrixUnitaire DECIMAL(18,2) NOT NULL DEFAULT 0,
    Remise DECIMAL(5,2) NOT NULL DEFAULT 0,
    TauxTVA DECIMAL(5,2) NOT NULL DEFAULT 0,
    TotalTTC DECIMAL(18,2) NOT NULL DEFAULT 0,
    KEY IX_LignesCommandePos_Commande (CommandePosId),
    CONSTRAINT FK_LignesCommandePos_Commandes FOREIGN KEY (CommandePosId) REFERENCES CommandesPos (Id) ON DELETE CASCADE,
    CONSTRAINT FK_LignesCommandePos_Produits FOREIGN KEY (ProduitId) REFERENCES Produits (Id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Montant = part encaissée (monnaie déduite) ; MontantRecu = somme remise par le client.
CREATE TABLE IF NOT EXISTS PaiementsPos (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    CommandePosId INT NOT NULL,
    ModePaiementId INT NULL,
    Libelle VARCHAR(100) NOT NULL,
    MontantRecu DECIMAL(18,2) NOT NULL DEFAULT 0,
    Montant DECIMAL(18,2) NOT NULL DEFAULT 0,
    OperationCaisseId INT NULL,
    KEY IX_PaiementsPos_Commande (CommandePosId),
    CONSTRAINT FK_PaiementsPos_Commandes FOREIGN KEY (CommandePosId) REFERENCES CommandesPos (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
