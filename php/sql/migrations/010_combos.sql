-- Combos (menus, formules), comme dans le point de vente Odoo : un produit « combo » a un prix
-- et des groupes de choix (ex. Entrée : 1 au choix parmi Salade, Soupe ; Plat : 1 au choix ;
-- Boisson : 1 au choix), chaque choix pouvant ajouter un supplément au prix.
ALTER TABLE Produits
    ADD COLUMN EstCombo TINYINT(1) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS ComboGroupes (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    ProduitId INT NOT NULL,
    Nom VARCHAR(50) NOT NULL,
    Quantite INT NOT NULL DEFAULT 1,
    Ordre INT NOT NULL DEFAULT 0,
    KEY IX_ComboGroupes_Produit (ProduitId),
    CONSTRAINT FK_ComboGroupes_Produits FOREIGN KEY (ProduitId) REFERENCES Produits (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Produit proposé dans un groupe (supplément ajouté au prix du combo).
CREATE TABLE IF NOT EXISTS ComboChoix (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    GroupeId INT NOT NULL,
    ProduitId INT NOT NULL,
    Supplement DECIMAL(18,2) NOT NULL DEFAULT 0,
    Ordre INT NOT NULL DEFAULT 0,
    KEY IX_ComboChoix_Groupe (GroupeId),
    KEY IX_ComboChoix_Produit (ProduitId),
    CONSTRAINT FK_ComboChoix_Groupes FOREIGN KEY (GroupeId) REFERENCES ComboGroupes (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Composition d'un combo vendu (JSON : produit, libellé, quantité par combo, supplément) :
-- stock des composants, bons de préparation, ticket, retours.
ALTER TABLE LignesCommandePos
    ADD COLUMN Composants TEXT NULL;
