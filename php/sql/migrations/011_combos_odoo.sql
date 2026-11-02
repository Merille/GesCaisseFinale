-- Combos comme dans le point de vente Odoo : un combo est un élément réutilisable (ex. « Plats » :
-- Poulet, Poisson + 500 ; « Boissons » : Coca, Eau), géré dans Configuration › Combos. Un produit
-- combo (ex. « Menu midi ») se compose d'une liste de combos (table ProduitCombos).
-- Les groupes créés sur les produits (010) deviennent des combos, reliés à leur produit.
--
-- Compatible MySQL 5.7+ et MariaDB 10.2+ (pas de RENAME COLUMN), et reprenable : chaque étape
-- vérifie d'abord si elle a déjà été faite, ce qui permet de relancer la migration après un
-- arrêt en cours de route (MySQL n'annule pas les modifications de structure déjà faites).

SET @fait = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ComboGroupes');
SET @sql = IF(@fait > 0, 'RENAME TABLE ComboGroupes TO Combos', 'DO 0');
PREPARE etape FROM @sql;
EXECUTE etape;
DEALLOCATE PREPARE etape;

CREATE TABLE IF NOT EXISTS ProduitCombos (
    ProduitId INT NOT NULL,
    ComboId INT NOT NULL,
    Ordre INT NOT NULL DEFAULT 0,
    PRIMARY KEY (ProduitId, ComboId),
    KEY IX_ProduitCombos_Combo (ComboId),
    CONSTRAINT FK_ProduitCombos_Produits FOREIGN KEY (ProduitId) REFERENCES Produits (Id) ON DELETE CASCADE,
    CONSTRAINT FK_ProduitCombos_Combos FOREIGN KEY (ComboId) REFERENCES Combos (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Ancienne colonne Combos.ProduitId (groupe rattaché à un produit) : liens recopiés, puis colonne retirée.
SET @col = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'Combos' AND COLUMN_NAME = 'ProduitId');
SET @sql = IF(@col > 0, 'INSERT IGNORE INTO ProduitCombos (ProduitId, ComboId, Ordre) SELECT ProduitId, Id, Ordre FROM Combos', 'DO 0');
PREPARE etape FROM @sql;
EXECUTE etape;
DEALLOCATE PREPARE etape;

SET @fk = (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'Combos' AND CONSTRAINT_NAME = 'FK_ComboGroupes_Produits' AND CONSTRAINT_TYPE = 'FOREIGN KEY');
SET @sql = IF(@fk > 0, 'ALTER TABLE Combos DROP FOREIGN KEY FK_ComboGroupes_Produits', 'DO 0');
PREPARE etape FROM @sql;
EXECUTE etape;
DEALLOCATE PREPARE etape;

SET @sql = IF(@col > 0, 'ALTER TABLE Combos DROP COLUMN ProduitId', 'DO 0');
PREPARE etape FROM @sql;
EXECUTE etape;
DEALLOCATE PREPARE etape;

-- ComboChoix.GroupeId devient ComboId (CHANGE COLUMN : accepté par toutes les versions).
SET @col = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ComboChoix' AND COLUMN_NAME = 'GroupeId');
SET @sql = IF(@col > 0, 'ALTER TABLE ComboChoix CHANGE COLUMN GroupeId ComboId INT NOT NULL', 'DO 0');
PREPARE etape FROM @sql;
EXECUTE etape;
DEALLOCATE PREPARE etape;
