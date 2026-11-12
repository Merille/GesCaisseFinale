-- Hors ligne (étape 3) : commande mise en attente sans connexion, envoyée au retour de la connexion.
-- Clé du poste : un envoi refait ne crée pas une seconde commande en attente.
ALTER TABLE CommandesAttente ADD COLUMN CleClient VARCHAR(64) NULL;
