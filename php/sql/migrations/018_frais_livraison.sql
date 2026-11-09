-- Frais de livraison : montant proposé par défaut (société) et frais de chaque vente livrée,
-- en plus du total TTC (hors taxes), comme le pourboire.
ALTER TABLE Tenants
    ADD COLUMN FraisLivraisonDefaut DECIMAL(18,2) NOT NULL DEFAULT 0;
ALTER TABLE CommandesPos
    ADD COLUMN FraisLivraison DECIMAL(18,2) NOT NULL DEFAULT 0;
