-- Combos comme dans le point de vente Odoo : un combo est un élément réutilisable (ex. « Plats » :
-- Poulet, Poisson + 500 ; « Boissons » : Coca, Eau), géré dans Configuration › Combos. Un produit
-- combo (ex. « Menu midi ») se compose d'une liste de combos (table ProduitCombos).
-- Les groupes créés sur les produits (010) deviennent des combos, reliés à leur produit.
RENAME TABLE ComboGroupes TO Combos;

CREATE TABLE IF NOT EXISTS ProduitCombos (
    ProduitId INT NOT NULL,
    ComboId INT NOT NULL,
    Ordre INT NOT NULL DEFAULT 0,
    PRIMARY KEY (ProduitId, ComboId),
    KEY IX_ProduitCombos_Combo (ComboId),
    CONSTRAINT FK_ProduitCombos_Produits FOREIGN KEY (ProduitId) REFERENCES Produits (Id) ON DELETE CASCADE,
    CONSTRAINT FK_ProduitCombos_Combos FOREIGN KEY (ComboId) REFERENCES Combos (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO ProduitCombos (ProduitId, ComboId, Ordre)
SELECT ProduitId, Id, Ordre FROM Combos;

ALTER TABLE Combos
    DROP FOREIGN KEY FK_ComboGroupes_Produits,
    DROP COLUMN ProduitId;

ALTER TABLE ComboChoix
    RENAME COLUMN GroupeId TO ComboId;
