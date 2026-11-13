-- Droit d'accorder des remises (remise sur un article et remise globale du ticket), donné par
-- l'administrateur sur la fiche de l'utilisateur, avec un pourcentage maximal facultatif.
-- Les administrateurs ont toujours ce droit, sans limite. Les utilisateurs existants le gardent
-- (ils pouvaient déjà faire des remises sur les articles) ; un nouvel utilisateur ne l'a pas.
ALTER TABLE Utilisateurs ADD COLUMN PeutRemise TINYINT(1) NOT NULL DEFAULT 0;
ALTER TABLE Utilisateurs ADD COLUMN RemiseMax DECIMAL(5,2) NULL;
UPDATE Utilisateurs SET PeutRemise = 1;
