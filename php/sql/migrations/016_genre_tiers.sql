-- Genre des tiers : Entreprise (personne morale) ou Particulier (personne physique).
-- Les tiers existants passent « Entreprise ».
ALTER TABLE Clients
    ADD COLUMN Genre VARCHAR(20) NOT NULL DEFAULT 'Entreprise';
