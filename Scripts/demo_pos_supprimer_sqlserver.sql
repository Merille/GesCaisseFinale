-- GesCaisse : suppression des données de démonstration du point de vente — SQL Server (version .NET)
-- Retire les journées « -DEMO » (avec leurs ventes et encaissements), les 30 produits
-- de démonstration (avec leurs mouvements de stock) et les 10 catégories si elles sont vides.
-- À exécuter sur la base LOCALE de test, comme le script de création.
-- Les ventes réelles de ces produits sont conservées (le produit y est simplement détaché).

SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @t INT;
BEGIN TRANSACTION;
SET @t = COALESCE((SELECT MIN(Id) FROM Tenants WHERE Nom = N'EASYTECH AFRICA GABON - LBV'),
                  (SELECT MIN(TenantId) FROM Caisses WHERE TenantId > 0));
DELETE FROM PaiementsPos WHERE CommandePosId IN (SELECT Id FROM CommandesPos WHERE JourneeCaisseId IN (SELECT Id FROM JourneesCaisses WHERE TenantId = @t AND NumeroJournee LIKE '%-DEMO'));
DELETE FROM LignesCommandePos WHERE CommandePosId IN (SELECT Id FROM CommandesPos WHERE JourneeCaisseId IN (SELECT Id FROM JourneesCaisses WHERE TenantId = @t AND NumeroJournee LIKE '%-DEMO'));
DELETE FROM CommandesPos WHERE JourneeCaisseId IN (SELECT Id FROM JourneesCaisses WHERE TenantId = @t AND NumeroJournee LIKE '%-DEMO');
DELETE FROM OperationsCaisses WHERE JourneeCaisseId IN (SELECT Id FROM JourneesCaisses WHERE TenantId = @t AND NumeroJournee LIKE '%-DEMO');
DELETE FROM JourneesCaisses WHERE TenantId = @t AND NumeroJournee LIKE '%-DEMO';
UPDATE LignesCommandePos SET ProduitId = NULL WHERE ProduitId IN (SELECT Id FROM Produits WHERE TenantId = @t AND Code IN ('BOI01', 'BOI02', 'BOI03', 'EPI01', 'EPI02', 'EPI03', 'BOU01', 'BOU02', 'BOU03', 'LAI01', 'LAI02', 'LAI03', 'HYG01', 'HYG02', 'HYG03', 'ENT01', 'ENT02', 'ENT03', 'PAP01', 'PAP02', 'PAP03', 'ELE01', 'ELE02', 'ELE03', 'SNA01', 'SNA02', 'SNA03', 'SER01', 'SER02', 'SER03'));
DELETE FROM MouvementsStock WHERE ProduitId IN (SELECT Id FROM Produits WHERE TenantId = @t AND Code IN ('BOI01', 'BOI02', 'BOI03', 'EPI01', 'EPI02', 'EPI03', 'BOU01', 'BOU02', 'BOU03', 'LAI01', 'LAI02', 'LAI03', 'HYG01', 'HYG02', 'HYG03', 'ENT01', 'ENT02', 'ENT03', 'PAP01', 'PAP02', 'PAP03', 'ELE01', 'ELE02', 'ELE03', 'SNA01', 'SNA02', 'SNA03', 'SER01', 'SER02', 'SER03'));
DELETE FROM Produits WHERE TenantId = @t AND Code IN ('BOI01', 'BOI02', 'BOI03', 'EPI01', 'EPI02', 'EPI03', 'BOU01', 'BOU02', 'BOU03', 'LAI01', 'LAI02', 'LAI03', 'HYG01', 'HYG02', 'HYG03', 'ENT01', 'ENT02', 'ENT03', 'PAP01', 'PAP02', 'PAP03', 'ELE01', 'ELE02', 'ELE03', 'SNA01', 'SNA02', 'SNA03', 'SER01', 'SER02', 'SER03');
DELETE FROM Caisses WHERE TenantId = @t AND ChkCode = 'DEMO' AND NOT EXISTS (SELECT 1 FROM JourneesCaisses j WHERE j.CaisseId = Caisses.ID);
DELETE FROM Categories WHERE TenantId = @t AND Nom IN (N'Boissons', N'Épicerie', N'Boulangerie', N'Produits laitiers', N'Hygiène', N'Entretien', N'Papeterie', N'Électronique', N'Snacks', N'Services')
    AND NOT EXISTS (SELECT 1 FROM Produits p WHERE p.CategorieId = Categories.Id);
COMMIT;
