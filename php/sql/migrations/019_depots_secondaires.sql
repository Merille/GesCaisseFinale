-- Dépôts secondaires d'une caisse : en plus de son dépôt principal (Caisses.DepotId), une caisse
-- peut puiser dans d'autres dépôts, dans l'ordre indiqué, quand le stock du principal ne suffit pas.
-- Un même dépôt peut être secondaire de plusieurs caisses.
-- Compatible MySQL 5.7+ et MariaDB 10.2+.

CREATE TABLE IF NOT EXISTS CaissesDepots (
    CaisseId INT NOT NULL,
    DepotId INT NOT NULL,
    Ordre INT NOT NULL DEFAULT 1,
    PRIMARY KEY (CaisseId, DepotId),
    KEY IX_CaissesDepots_DepotId (DepotId),
    CONSTRAINT FK_CaissesDepots_Caisses FOREIGN KEY (CaisseId) REFERENCES Caisses (ID) ON DELETE CASCADE,
    CONSTRAINT FK_CaissesDepots_Depots FOREIGN KEY (DepotId) REFERENCES Depots (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
