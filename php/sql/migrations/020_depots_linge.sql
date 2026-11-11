-- Laverie : dépôts de linge payés au retrait. Au dépôt, la commande est enregistrée (numéro de
-- dépôt, client, téléphone, retrait prévu, acompte facultatif encaissé dans la journée) et un
-- ticket « NON PAYÉ » est imprimé ; au retrait, le dépôt est encaissé dans la journée du jour
-- (vente normale, acompte déduit). Statuts : En cours, Prêt, Retiré, Annulé.
-- Compatible MySQL 5.7+ et MariaDB 10.2+.

CREATE TABLE IF NOT EXISTS DepotsLinge (
    Id INT NOT NULL AUTO_INCREMENT,
    TenantId INT NOT NULL,
    CaisseId INT NOT NULL,
    JourneeCaisseId INT NOT NULL,
    Numero INT NOT NULL,
    CleClient VARCHAR(64) NULL,
    DateDepot DATETIME NOT NULL,
    DateRetraitPrevue DATE NULL,
    NomClient VARCHAR(100) NOT NULL,
    TelephoneClient VARCHAR(30) NULL,
    ClientId INT NULL,
    UtilisateurId INT NULL,
    Contenu LONGTEXT NOT NULL,
    Total DECIMAL(18,2) NOT NULL DEFAULT 0,
    NbArticles DECIMAL(18,2) NOT NULL DEFAULT 0,
    Acompte DECIMAL(18,2) NOT NULL DEFAULT 0,
    AcompteModePaiementId INT NULL,
    AcompteOperationId INT NULL,
    Statut VARCHAR(20) NOT NULL DEFAULT 'En cours',
    DatePret DATETIME NULL,
    DateRetrait DATETIME NULL,
    DateAnnulation DATETIME NULL,
    CommandePosId INT NULL,
    PRIMARY KEY (Id),
    UNIQUE KEY IX_DepotsLinge_TenantId_Numero (TenantId, Numero),
    KEY IX_DepotsLinge_TenantId_Statut (TenantId, Statut)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
