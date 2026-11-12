-- Laverie : dépôt des achats (« Magasin des produits d'entretien »). Les achats y entrent et les
-- consommations en sortent ; il n'est ni dépôt par défaut ni dépôt d'une caisse : la vente n'y
-- puise jamais. Un seul par société, créé au besoin à l'ouverture du module Achats.
-- Compatible MySQL 5.7+ et MariaDB 10.2+.

ALTER TABLE Depots ADD COLUMN DepotAchats TINYINT(1) NOT NULL DEFAULT 0;
