-- Limite des tentatives de connexion : échecs récents par nom d'utilisateur et adresse IP.
CREATE TABLE IF NOT EXISTS TentativesConnexion (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    NomUtilisateur VARCHAR(100) NOT NULL,
    AdresseIp VARCHAR(45) NOT NULL,
    DateTentative DATETIME NOT NULL,
    KEY IX_TentativesConnexion_Adresse (AdresseIp, DateTentative),
    KEY IX_TentativesConnexion_Nom (NomUtilisateur, DateTentative)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
