-- GesCaisse (version PHP / MySQL) : remet les majuscules aux noms des tables.
--
-- À utiliser quand la base a été exportée depuis Windows (XAMPP, WampServer…) : les noms de tables y sont
-- en minuscules (produits, utilisateurs…), alors qu'un serveur Linux comme Hostinger les distingue
-- (Produits, Utilisateurs…). Symptômes : « Can't create table Produits (errno: 121) », « Duplicate foreign
-- key constraint name », « table introuvable », ou le message de GesCaisse sur les tables en minuscules.
--
-- Utilisation : phpMyAdmin › base de GesCaisse › onglet SQL › coller ce fichier (ou Importer) › Exécuter.
-- Sauvegardez d'abord la base (onglet Exporter). Les données ne sont pas modifiées :
--   - une table dont le nom ne diffère que par les majuscules est renommée (produits → Produits) ;
--   - si la table au bon nom existe déjà mais est VIDE (créée par une mise à jour qui a échoué),
--     elle est supprimée puis remplacée par l'ancienne table et ses données ;
--   - si les deux tables contiennent des données, rien n'est touché : elles sont listées à la fin.
-- Le script peut être relancé sans risque. Tables connues : 49.

-- Achats
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Achats') AND BINARY TABLE_NAME <> BINARY 'Achats');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Achats');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Achats`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Achats`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Achats`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- BonsPreparation
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('BonsPreparation') AND BINARY TABLE_NAME <> BINARY 'BonsPreparation');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'BonsPreparation');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `BonsPreparation`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `BonsPreparation`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `BonsPreparation`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- Caisses
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Caisses') AND BINARY TABLE_NAME <> BINARY 'Caisses');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Caisses');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Caisses`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Caisses`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Caisses`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- CaissesDepots
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('CaissesDepots') AND BINARY TABLE_NAME <> BINARY 'CaissesDepots');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'CaissesDepots');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `CaissesDepots`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `CaissesDepots`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `CaissesDepots`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- Categories
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Categories') AND BINARY TABLE_NAME <> BINARY 'Categories');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Categories');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Categories`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Categories`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Categories`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- Clients
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Clients') AND BINARY TABLE_NAME <> BINARY 'Clients');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Clients');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Clients`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Clients`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Clients`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- ComboChoix
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('ComboChoix') AND BINARY TABLE_NAME <> BINARY 'ComboChoix');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'ComboChoix');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `ComboChoix`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `ComboChoix`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `ComboChoix`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- Combos
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Combos') AND BINARY TABLE_NAME <> BINARY 'Combos');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Combos');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Combos`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Combos`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Combos`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- CommandesAttente
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('CommandesAttente') AND BINARY TABLE_NAME <> BINARY 'CommandesAttente');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'CommandesAttente');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `CommandesAttente`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `CommandesAttente`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `CommandesAttente`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- CommandesOuvertes
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('CommandesOuvertes') AND BINARY TABLE_NAME <> BINARY 'CommandesOuvertes');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'CommandesOuvertes');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `CommandesOuvertes`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `CommandesOuvertes`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `CommandesOuvertes`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- CommandesPos
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('CommandesPos') AND BINARY TABLE_NAME <> BINARY 'CommandesPos');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'CommandesPos');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `CommandesPos`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `CommandesPos`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `CommandesPos`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- ComptagesCloture
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('ComptagesCloture') AND BINARY TABLE_NAME <> BINARY 'ComptagesCloture');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'ComptagesCloture');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `ComptagesCloture`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `ComptagesCloture`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `ComptagesCloture`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- Depots
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Depots') AND BINARY TABLE_NAME <> BINARY 'Depots');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Depots');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Depots`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Depots`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Depots`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- DepotsLinge
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('DepotsLinge') AND BINARY TABLE_NAME <> BINARY 'DepotsLinge');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'DepotsLinge');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `DepotsLinge`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `DepotsLinge`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `DepotsLinge`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- Factures
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Factures') AND BINARY TABLE_NAME <> BINARY 'Factures');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Factures');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Factures`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Factures`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Factures`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- ImprimantesPreparation
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('ImprimantesPreparation') AND BINARY TABLE_NAME <> BINARY 'ImprimantesPreparation');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'ImprimantesPreparation');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `ImprimantesPreparation`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `ImprimantesPreparation`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `ImprimantesPreparation`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- ImprimantesPreparationCategories
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('ImprimantesPreparationCategories') AND BINARY TABLE_NAME <> BINARY 'ImprimantesPreparationCategories');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'ImprimantesPreparationCategories');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `ImprimantesPreparationCategories`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `ImprimantesPreparationCategories`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `ImprimantesPreparationCategories`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- JourneesCaisses
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('JourneesCaisses') AND BINARY TABLE_NAME <> BINARY 'JourneesCaisses');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'JourneesCaisses');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `JourneesCaisses`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `JourneesCaisses`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `JourneesCaisses`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- LignesAchats
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('LignesAchats') AND BINARY TABLE_NAME <> BINARY 'LignesAchats');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'LignesAchats');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `LignesAchats`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `LignesAchats`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `LignesAchats`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- LignesBonPreparation
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('LignesBonPreparation') AND BINARY TABLE_NAME <> BINARY 'LignesBonPreparation');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'LignesBonPreparation');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `LignesBonPreparation`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `LignesBonPreparation`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `LignesBonPreparation`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- LignesCommandePos
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('LignesCommandePos') AND BINARY TABLE_NAME <> BINARY 'LignesCommandePos');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'LignesCommandePos');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `LignesCommandePos`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `LignesCommandePos`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `LignesCommandePos`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- LignesCommandePosTaxes
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('LignesCommandePosTaxes') AND BINARY TABLE_NAME <> BINARY 'LignesCommandePosTaxes');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'LignesCommandePosTaxes');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `LignesCommandePosTaxes`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `LignesCommandePosTaxes`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `LignesCommandePosTaxes`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- LignesFactures
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('LignesFactures') AND BINARY TABLE_NAME <> BINARY 'LignesFactures');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'LignesFactures');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `LignesFactures`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `LignesFactures`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `LignesFactures`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- Livreurs
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Livreurs') AND BINARY TABLE_NAME <> BINARY 'Livreurs');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Livreurs');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Livreurs`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Livreurs`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Livreurs`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- MigrationsAppliquees
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('MigrationsAppliquees') AND BINARY TABLE_NAME <> BINARY 'MigrationsAppliquees');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'MigrationsAppliquees');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `MigrationsAppliquees`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `MigrationsAppliquees`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `MigrationsAppliquees`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- ModesPaiement
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('ModesPaiement') AND BINARY TABLE_NAME <> BINARY 'ModesPaiement');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'ModesPaiement');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `ModesPaiement`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `ModesPaiement`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `ModesPaiement`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- Motifs
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Motifs') AND BINARY TABLE_NAME <> BINARY 'Motifs');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Motifs');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Motifs`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Motifs`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Motifs`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- MouvementsStock
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('MouvementsStock') AND BINARY TABLE_NAME <> BINARY 'MouvementsStock');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'MouvementsStock');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `MouvementsStock`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `MouvementsStock`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `MouvementsStock`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- OperationsCaisses
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('OperationsCaisses') AND BINARY TABLE_NAME <> BINARY 'OperationsCaisses');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'OperationsCaisses');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `OperationsCaisses`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `OperationsCaisses`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `OperationsCaisses`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- PaiementsPos
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('PaiementsPos') AND BINARY TABLE_NAME <> BINARY 'PaiementsPos');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'PaiementsPos');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `PaiementsPos`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `PaiementsPos`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `PaiementsPos`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- PostesHorsLigne
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('PostesHorsLigne') AND BINARY TABLE_NAME <> BINARY 'PostesHorsLigne');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'PostesHorsLigne');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `PostesHorsLigne`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `PostesHorsLigne`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `PostesHorsLigne`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- ProduitAttributValeurs
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('ProduitAttributValeurs') AND BINARY TABLE_NAME <> BINARY 'ProduitAttributValeurs');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'ProduitAttributValeurs');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `ProduitAttributValeurs`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `ProduitAttributValeurs`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `ProduitAttributValeurs`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- ProduitAttributs
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('ProduitAttributs') AND BINARY TABLE_NAME <> BINARY 'ProduitAttributs');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'ProduitAttributs');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `ProduitAttributs`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `ProduitAttributs`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `ProduitAttributs`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- ProduitCombos
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('ProduitCombos') AND BINARY TABLE_NAME <> BINARY 'ProduitCombos');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'ProduitCombos');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `ProduitCombos`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `ProduitCombos`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `ProduitCombos`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- ProduitImages
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('ProduitImages') AND BINARY TABLE_NAME <> BINARY 'ProduitImages');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'ProduitImages');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `ProduitImages`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `ProduitImages`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `ProduitImages`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- ProduitTaxes
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('ProduitTaxes') AND BINARY TABLE_NAME <> BINARY 'ProduitTaxes');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'ProduitTaxes');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `ProduitTaxes`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `ProduitTaxes`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `ProduitTaxes`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- Produits
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Produits') AND BINARY TABLE_NAME <> BINARY 'Produits');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Produits');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Produits`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Produits`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Produits`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- Profils
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Profils') AND BINARY TABLE_NAME <> BINARY 'Profils');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Profils');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Profils`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Profils`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Profils`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- ReglementsAchats
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('ReglementsAchats') AND BINARY TABLE_NAME <> BINARY 'ReglementsAchats');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'ReglementsAchats');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `ReglementsAchats`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `ReglementsAchats`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `ReglementsAchats`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- Salles
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Salles') AND BINARY TABLE_NAME <> BINARY 'Salles');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Salles');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Salles`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Salles`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Salles`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- StocksDepots
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('StocksDepots') AND BINARY TABLE_NAME <> BINARY 'StocksDepots');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'StocksDepots');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `StocksDepots`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `StocksDepots`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `StocksDepots`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- TablesRestaurant
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('TablesRestaurant') AND BINARY TABLE_NAME <> BINARY 'TablesRestaurant');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'TablesRestaurant');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `TablesRestaurant`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `TablesRestaurant`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `TablesRestaurant`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- Taxes
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Taxes') AND BINARY TABLE_NAME <> BINARY 'Taxes');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Taxes');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Taxes`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Taxes`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Taxes`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- TenantLogos
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('TenantLogos') AND BINARY TABLE_NAME <> BINARY 'TenantLogos');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'TenantLogos');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `TenantLogos`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `TenantLogos`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `TenantLogos`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- Tenants
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Tenants') AND BINARY TABLE_NAME <> BINARY 'Tenants');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Tenants');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Tenants`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Tenants`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Tenants`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- TentativesConnexion
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('TentativesConnexion') AND BINARY TABLE_NAME <> BINARY 'TentativesConnexion');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'TentativesConnexion');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `TentativesConnexion`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `TentativesConnexion`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `TentativesConnexion`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- Unites
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Unites') AND BINARY TABLE_NAME <> BINARY 'Unites');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Unites');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Unites`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Unites`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Unites`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- Utilisateurs
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('Utilisateurs') AND BINARY TABLE_NAME <> BINARY 'Utilisateurs');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'Utilisateurs');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `Utilisateurs`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `Utilisateurs`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `Utilisateurs`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
-- VarianteValeurs
SET @src = (SELECT MIN(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER('VarianteValeurs') AND BINARY TABLE_NAME <> BINARY 'VarianteValeurs');
SET @dst = (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND BINARY TABLE_NAME = BINARY 'VarianteValeurs');
SET @n = 0;
SET @s = IF(@src IS NOT NULL AND @dst = 1, 'SELECT COUNT(*) INTO @n FROM `VarianteValeurs`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND @dst = 1 AND @n = 0, 'DROP TABLE `VarianteValeurs`', 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;
SET @s = IF(@src IS NOT NULL AND (@dst = 0 OR @n = 0), CONCAT('RENAME TABLE `', @src, '` TO `VarianteValeurs`'), 'DO 0');
PREPARE r FROM @s; EXECUTE r; DEALLOCATE PREPARE r;

-- Contrôle : doit être vide. Sinon, deux tables portent le même nom avec des données : à régler à la main.
SELECT TABLE_NAME AS `Tables restant à corriger` FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) IN ('achats', 'bonspreparation', 'caisses', 'caissesdepots', 'categories', 'clients', 'combochoix', 'combos', 'commandesattente', 'commandesouvertes', 'commandespos', 'comptagescloture', 'depots', 'depotslinge', 'factures', 'imprimantespreparation', 'imprimantespreparationcategories', 'journeescaisses', 'lignesachats', 'lignesbonpreparation', 'lignescommandepos', 'lignescommandepostaxes', 'lignesfactures', 'livreurs', 'migrationsappliquees', 'modespaiement', 'motifs', 'mouvementsstock', 'operationscaisses', 'paiementspos', 'posteshorsligne', 'produitattributvaleurs', 'produitattributs', 'produitcombos', 'produitimages', 'produittaxes', 'produits', 'profils', 'reglementsachats', 'salles', 'stocksdepots', 'tablesrestaurant', 'taxes', 'tenantlogos', 'tenants', 'tentativesconnexion', 'unites', 'utilisateurs', 'variantevaleurs') AND BINARY TABLE_NAME NOT IN (BINARY 'Achats', BINARY 'BonsPreparation', BINARY 'Caisses', BINARY 'CaissesDepots', BINARY 'Categories', BINARY 'Clients', BINARY 'ComboChoix', BINARY 'Combos', BINARY 'CommandesAttente', BINARY 'CommandesOuvertes', BINARY 'CommandesPos', BINARY 'ComptagesCloture', BINARY 'Depots', BINARY 'DepotsLinge', BINARY 'Factures', BINARY 'ImprimantesPreparation', BINARY 'ImprimantesPreparationCategories', BINARY 'JourneesCaisses', BINARY 'LignesAchats', BINARY 'LignesBonPreparation', BINARY 'LignesCommandePos', BINARY 'LignesCommandePosTaxes', BINARY 'LignesFactures', BINARY 'Livreurs', BINARY 'MigrationsAppliquees', BINARY 'ModesPaiement', BINARY 'Motifs', BINARY 'MouvementsStock', BINARY 'OperationsCaisses', BINARY 'PaiementsPos', BINARY 'PostesHorsLigne', BINARY 'ProduitAttributValeurs', BINARY 'ProduitAttributs', BINARY 'ProduitCombos', BINARY 'ProduitImages', BINARY 'ProduitTaxes', BINARY 'Produits', BINARY 'Profils', BINARY 'ReglementsAchats', BINARY 'Salles', BINARY 'StocksDepots', BINARY 'TablesRestaurant', BINARY 'Taxes', BINARY 'TenantLogos', BINARY 'Tenants', BINARY 'TentativesConnexion', BINARY 'Unites', BINARY 'Utilisateurs', BINARY 'VarianteValeurs');
