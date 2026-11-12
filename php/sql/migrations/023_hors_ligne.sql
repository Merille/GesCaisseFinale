-- Mode hors ligne (étape 2) : ventes et dépôts de linge enregistrés sur le poste sans connexion, puis
-- envoyés au retour de la connexion. NumeroHorsLigne : numéro provisoire du ticket imprimé hors
-- ligne. AlerteHorsLigne : écarts constatés à l'envoi (arrivée après la clôture, prix modifié depuis,
-- stock insuffisant, plafond de crédit dépassé), à vérifier par un administrateur (AlerteHorsLigneVue).
-- Compatible MySQL 5.7+ et MariaDB 10.2+.

ALTER TABLE CommandesPos ADD COLUMN NumeroHorsLigne VARCHAR(30) NULL;
ALTER TABLE CommandesPos ADD COLUMN AlerteHorsLigne VARCHAR(500) NULL;
ALTER TABLE CommandesPos ADD COLUMN AlerteHorsLigneVue DATETIME NULL;
ALTER TABLE DepotsLinge ADD COLUMN NumeroHorsLigne VARCHAR(30) NULL;
