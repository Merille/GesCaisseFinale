-- Profils et droits d'accès : l'administrateur crée des profils (Caissier, Serveur, Gérant…) et coche
-- les droits de chacun ; chaque utilisateur non administrateur reçoit un profil. Droits : codes séparés
-- par des virgules (voir droits_catalogue() dans bootstrap.php). Les comptes Admin et SuperAdmin
-- gardent tous les droits. Les profils Caissier et Vendeur existants deviennent des profils de la
-- société, avec les droits qu'ils avaient déjà.
CREATE TABLE IF NOT EXISTS Profils (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    TenantId INT NOT NULL,
    Nom VARCHAR(50) NOT NULL,
    Description VARCHAR(200) NULL,
    Droits VARCHAR(1000) NOT NULL DEFAULT '',
    UNIQUE KEY UX_Profils_Nom (TenantId, Nom)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE Utilisateurs ADD COLUMN ProfilId INT NULL, ADD KEY IX_Utilisateurs_ProfilId (ProfilId), MODIFY Profil VARCHAR(50) NOT NULL;

INSERT INTO Profils (TenantId, Nom, Description, Droits)
SELECT Id, 'Caissier', 'Caisse, ventes et tiers', 'tableau_bord,caisses,caisses_gerer,tiers,rapports,vendre,ventes,cuisine' FROM Tenants;
INSERT INTO Profils (TenantId, Nom, Description, Droits)
SELECT Id, 'Vendeur', 'Caisse, ventes et tiers', 'tableau_bord,caisses,caisses_gerer,tiers,rapports,vendre,ventes,cuisine' FROM Tenants;

UPDATE Utilisateurs u JOIN Profils p ON p.TenantId = u.TenantId AND p.Nom = u.Profil
SET u.ProfilId = p.Id WHERE u.Profil NOT IN ('Admin', 'SuperAdmin');
