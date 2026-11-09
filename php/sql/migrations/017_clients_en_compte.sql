-- Clients en compte : vente « par compte » (à crédit) au point de vente et règlements.
--   Clients.EnCompte / PlafondCredit : client autorisé à payer par compte, plafond facultatif ;
--   ModesPaiement.EstCompte : mode « Compte client » (pas d'encaissement en caisse) ;
--   OperationsCaisses.ReglementCompte : encaissement qui règle le compte d'un client.
ALTER TABLE Clients
    ADD COLUMN EnCompte TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN PlafondCredit DECIMAL(18,2) NULL;
ALTER TABLE ModesPaiement
    ADD COLUMN EstCompte TINYINT(1) NOT NULL DEFAULT 0;
ALTER TABLE OperationsCaisses
    ADD COLUMN ReglementCompte TINYINT(1) NOT NULL DEFAULT 0;
-- Mode « Compte client » : un mode existant nommé « compte » est repris, sinon il est créé.
UPDATE ModesPaiement SET EstCompte = 1
    WHERE Code IN ('CPT', 'COMPTE') OR Libelle LIKE '%compte%';
INSERT INTO ModesPaiement (Code, Libelle, Actif, TenantId, EstCompte)
    SELECT 'CPT', 'Compte client', 1, t.Id, 1 FROM Tenants t
    WHERE NOT EXISTS (SELECT 1 FROM ModesPaiement m WHERE m.TenantId = t.Id AND m.EstCompte = 1);
