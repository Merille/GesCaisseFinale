-- Page Synchronisation (administrateurs) : état de la file hors ligne de chaque poste (navigateur),
-- envoyé par le poste quand il est connecté. Code : identifiant du poste (celui des numéros
-- provisoires H-code-n°). EnAttente / Refusees / MontantEnAttente : opérations faites hors ligne pas
-- encore envoyées (dont refusées par le serveur) ; PlusAncien : date de la plus ancienne ; Detail :
-- liste de ces opérations (JSON). Compatible MySQL 5.7+ et MariaDB 10.2+.

CREATE TABLE IF NOT EXISTS PostesHorsLigne (
    Id INT NOT NULL AUTO_INCREMENT,
    TenantId INT NOT NULL,
    Code VARCHAR(10) NOT NULL,
    UtilisateurId INT NULL,
    Navigateur VARCHAR(150) NULL,
    EnAttente INT NOT NULL DEFAULT 0,
    Refusees INT NOT NULL DEFAULT 0,
    MontantEnAttente DECIMAL(18,2) NOT NULL DEFAULT 0,
    PlusAncien DATETIME NULL,
    DernierEnvoi DATETIME NULL,
    DernierRapport DATETIME NOT NULL,
    Detail TEXT NULL,
    PRIMARY KEY (Id),
    UNIQUE KEY IX_PostesHorsLigne_TenantId_Code (TenantId, Code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
