-- Module Point de vente optionnel par société (choisi par le SuperAdmin) : sans ce module, la
-- société n'a que la gestion de caisse (journées, opérations, tiers, factures, rapports).
-- Les sociétés existantes gardent le module.
ALTER TABLE Tenants
    ADD COLUMN ModulePointVente TINYINT(1) NOT NULL DEFAULT 1;
