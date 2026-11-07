-- Moyen de livraison des livreurs : Moto, Voiture, Vélo ou Autre. Les livreurs existants passent « Moto ».
ALTER TABLE Livreurs
    ADD COLUMN MoyenLivraison VARCHAR(20) NOT NULL DEFAULT 'Moto';
