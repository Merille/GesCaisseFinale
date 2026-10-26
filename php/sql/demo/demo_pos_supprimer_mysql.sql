-- GesCaisse : suppression des données de démonstration du point de vente — MySQL (version PHP)
-- Retire les journées « -DEMO » (avec leurs ventes et encaissements), les 30 produits
-- de démonstration (avec leurs mouvements de stock) et les 10 catégories si elles sont vides.
-- À exécuter sur la base LOCALE de test, comme le script de création.
-- Les ventes réelles de ces produits sont conservées (le produit y est simplement détaché).

SET NAMES utf8mb4;
START TRANSACTION;
SET @t = (SELECT MIN(TenantId) FROM Caisses WHERE TenantId > 0);
DELETE pp FROM PaiementsPos pp JOIN CommandesPos c ON c.Id = pp.CommandePosId JOIN JourneesCaisses j ON j.Id = c.JourneeCaisseId WHERE j.TenantId = @t AND j.NumeroJournee LIKE '%-DEMO';
DELETE l FROM LignesCommandePos l JOIN CommandesPos c ON c.Id = l.CommandePosId JOIN JourneesCaisses j ON j.Id = c.JourneeCaisseId WHERE j.TenantId = @t AND j.NumeroJournee LIKE '%-DEMO';
DELETE c FROM CommandesPos c JOIN JourneesCaisses j ON j.Id = c.JourneeCaisseId WHERE j.TenantId = @t AND j.NumeroJournee LIKE '%-DEMO';
DELETE o FROM OperationsCaisses o JOIN JourneesCaisses j ON j.Id = o.JourneeCaisseId WHERE j.TenantId = @t AND j.NumeroJournee LIKE '%-DEMO';
DELETE FROM JourneesCaisses WHERE TenantId = @t AND NumeroJournee LIKE '%-DEMO';
UPDATE LignesCommandePos l JOIN Produits p ON p.Id = l.ProduitId SET l.ProduitId = NULL WHERE p.TenantId = @t AND p.Code IN ('BOI01', 'BOI02', 'BOI03', 'EPI01', 'EPI02', 'EPI03', 'BOU01', 'BOU02', 'BOU03', 'LAI01', 'LAI02', 'LAI03', 'HYG01', 'HYG02', 'HYG03', 'ENT01', 'ENT02', 'ENT03', 'PAP01', 'PAP02', 'PAP03', 'ELE01', 'ELE02', 'ELE03', 'SNA01', 'SNA02', 'SNA03', 'SER01', 'SER02', 'SER03');
DELETE m FROM MouvementsStock m JOIN Produits p ON p.Id = m.ProduitId WHERE p.TenantId = @t AND p.Code IN ('BOI01', 'BOI02', 'BOI03', 'EPI01', 'EPI02', 'EPI03', 'BOU01', 'BOU02', 'BOU03', 'LAI01', 'LAI02', 'LAI03', 'HYG01', 'HYG02', 'HYG03', 'ENT01', 'ENT02', 'ENT03', 'PAP01', 'PAP02', 'PAP03', 'ELE01', 'ELE02', 'ELE03', 'SNA01', 'SNA02', 'SNA03', 'SER01', 'SER02', 'SER03');
DELETE FROM Produits WHERE TenantId = @t AND Code IN ('BOI01', 'BOI02', 'BOI03', 'EPI01', 'EPI02', 'EPI03', 'BOU01', 'BOU02', 'BOU03', 'LAI01', 'LAI02', 'LAI03', 'HYG01', 'HYG02', 'HYG03', 'ENT01', 'ENT02', 'ENT03', 'PAP01', 'PAP02', 'PAP03', 'ELE01', 'ELE02', 'ELE03', 'SNA01', 'SNA02', 'SNA03', 'SER01', 'SER02', 'SER03');
DELETE c FROM Categories c LEFT JOIN Produits p ON p.CategorieId = c.Id
    WHERE c.TenantId = @t AND c.Nom IN ('Boissons', 'Épicerie', 'Boulangerie', 'Produits laitiers', 'Hygiène', 'Entretien', 'Papeterie', 'Électronique', 'Snacks', 'Services') AND p.Id IS NULL;
COMMIT;
