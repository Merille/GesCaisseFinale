-- Variantes de produits (attributs combinés, comme Odoo) : le produit « modèle » porte les
-- attributs (Taille : S, M, L ; Couleur : Rouge, Bleu) ; chaque combinaison est un produit
-- « variante » (ParentId = modèle) avec son code, son code-barres, son stock et un supplément
-- de prix. Le modèle n'est plus vendu ni stocké directement.
ALTER TABLE Produits
    ADD COLUMN ParentId INT NULL,
    ADD COLUMN EstModele TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN Supplement DECIMAL(18,2) NOT NULL DEFAULT 0,
    ADD COLUMN LibelleVariante VARCHAR(150) NULL,
    ADD KEY IX_Produits_Parent (ParentId);

CREATE TABLE IF NOT EXISTS ProduitAttributs (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    ProduitId INT NOT NULL,
    Nom VARCHAR(50) NOT NULL,
    Ordre INT NOT NULL DEFAULT 0,
    KEY IX_ProduitAttributs_Produit (ProduitId),
    CONSTRAINT FK_ProduitAttributs_Produits FOREIGN KEY (ProduitId) REFERENCES Produits (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ProduitAttributValeurs (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    ProduitAttributId INT NOT NULL,
    Valeur VARCHAR(50) NOT NULL,
    Ordre INT NOT NULL DEFAULT 0,
    KEY IX_ProduitAttributValeurs_Attribut (ProduitAttributId),
    CONSTRAINT FK_ProduitAttributValeurs_Attributs FOREIGN KEY (ProduitAttributId) REFERENCES ProduitAttributs (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Combinaison de valeurs de chaque variante.
CREATE TABLE IF NOT EXISTS VarianteValeurs (
    VarianteId INT NOT NULL,
    ValeurId INT NOT NULL,
    PRIMARY KEY (VarianteId, ValeurId),
    KEY IX_VarianteValeurs_Valeur (ValeurId),
    CONSTRAINT FK_VarianteValeurs_Produits FOREIGN KEY (VarianteId) REFERENCES Produits (Id) ON DELETE CASCADE,
    CONSTRAINT FK_VarianteValeurs_Valeurs FOREIGN KEY (ValeurId) REFERENCES ProduitAttributValeurs (Id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Remise globale du ticket (montant, et taux si elle a été saisie en %), répartie sur les
-- lignes au prorata : TotalTTC des lignes est net de remise, la part de chacune est gardée.
ALTER TABLE CommandesPos
    ADD COLUMN RemiseGlobale DECIMAL(18,2) NOT NULL DEFAULT 0,
    ADD COLUMN RemiseGlobaleTaux DECIMAL(5,2) NULL;

ALTER TABLE LignesCommandePos
    ADD COLUMN RemiseGlobale DECIMAL(18,2) NOT NULL DEFAULT 0;
