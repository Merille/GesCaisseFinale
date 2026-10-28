-- Unités de vente gérées par société (Kg, Litre, Carton…) : ajout, modification, activation.
-- Produits.Unite garde le nom de l'unité (affiché sur le ticket) ; renommer une unité met
-- à jour les produits qui l'utilisent.
CREATE TABLE IF NOT EXISTS Unites (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL DEFAULT 0,
    Nom VARCHAR(20) NOT NULL,
    Libelle VARCHAR(100) NULL,
    Actif TINYINT(1) NOT NULL DEFAULT 1,
    UNIQUE KEY UX_Unites_Tenant_Nom (TenantId, Nom)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Unités de départ de chaque société.
INSERT IGNORE INTO Unites (TenantId, Nom, Libelle)
SELECT t.Id, u.Nom, u.Libelle
FROM Tenants t
CROSS JOIN (
    SELECT 'Unité' AS Nom, 'Article vendu à l''unité' AS Libelle UNION ALL
    SELECT 'Pièce', 'Pièce' UNION ALL
    SELECT 'Kg', 'Kilogramme' UNION ALL
    SELECT 'g', 'Gramme' UNION ALL
    SELECT 'Litre', 'Litre' UNION ALL
    SELECT 'cl', 'Centilitre' UNION ALL
    SELECT 'Mètre', 'Mètre' UNION ALL
    SELECT 'Carton', 'Carton' UNION ALL
    SELECT 'Paquet', 'Paquet' UNION ALL
    SELECT 'Boîte', 'Boîte' UNION ALL
    SELECT 'Sac', 'Sac' UNION ALL
    SELECT 'Bouteille', 'Bouteille' UNION ALL
    SELECT 'Page', 'Page (impression, photocopie)' UNION ALL
    SELECT 'Heure', 'Heure (service)'
) u;

-- Autres unités déjà saisies sur des produits.
INSERT IGNORE INTO Unites (TenantId, Nom)
SELECT DISTINCT p.TenantId, p.Unite FROM Produits p WHERE TRIM(p.Unite) <> '';
