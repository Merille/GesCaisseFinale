-- GesCaisse (version PHP / MySQL) : structure complète de la base et données de départ.
-- Les noms de tables et de colonnes reprennent ceux de la version .NET
-- (SQL Server) pour faciliter une éventuelle reprise des données.
--
-- Base à jour : intègre toutes les migrations de sql/migrations (001 à 022),
-- notées comme appliquées dans MigrationsAppliquees.
--
-- Utilisation (NOUVELLE installation uniquement) : créer une base VIDE (ex. gescaisse),
-- puis importer ce fichier (phpMyAdmin > Importer, ou : mysql -u root -p gescaisse < schema.sql).
-- Une base déjà en service ne doit PAS recevoir ce fichier : l'application la met à jour
-- toute seule au premier chargement, en appliquant les migrations manquantes.
--
-- Comptes créés (mot de passe 123, à changer après la première connexion) :
-- superadmin (super-administrateur) et admin (administrateur de la société de démonstration).

SET NAMES utf8mb4;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Achats` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL,
  `Numero` int NOT NULL,
  `DateAchat` date NOT NULL,
  `FournisseurId` int DEFAULT NULL,
  `DepotId` int NOT NULL,
  `Reference` varchar(100) DEFAULT NULL,
  `Commentaire` varchar(300) DEFAULT NULL,
  `Total` decimal(18,2) NOT NULL DEFAULT '0.00',
  `Statut` varchar(20) NOT NULL DEFAULT 'Validé',
  `UtilisateurId` int DEFAULT NULL,
  `DateCreation` datetime NOT NULL,
  `DateAnnulation` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_Achats_TenantId_Numero` (`TenantId`,`Numero`),
  KEY `IX_Achats_TenantId_DateAchat` (`TenantId`,`DateAchat`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `BonsPreparation` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `CaisseId` int NOT NULL,
  `JourneeCaisseId` int NOT NULL,
  `CommandeOuverteId` int DEFAULT NULL,
  `Numero` int NOT NULL DEFAULT '0',
  `Poste` varchar(20) NOT NULL,
  `TableNom` varchar(60) DEFAULT NULL,
  `Couverts` int DEFAULT NULL,
  `Serveur` varchar(100) DEFAULT NULL,
  `DateEnvoi` datetime NOT NULL,
  `Statut` varchar(20) NOT NULL DEFAULT 'À préparer',
  `DatePret` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_BonsPreparation_Caisse` (`CaisseId`,`Statut`),
  KEY `FK_BonsPreparation_Journees` (`JourneeCaisseId`),
  CONSTRAINT `FK_BonsPreparation_Journees` FOREIGN KEY (`JourneeCaisseId`) REFERENCES `JourneesCaisses` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Caisses` (
  `ID` int NOT NULL AUTO_INCREMENT,
  `ChkCode` varchar(50) DEFAULT NULL,
  `ChkDescription` varchar(200) DEFAULT NULL,
  `StCode` varchar(50) DEFAULT NULL,
  `SalesPersonDefault` int DEFAULT NULL,
  `CashierDefault` int DEFAULT NULL,
  `CustomerDefaultCode` varchar(50) DEFAULT 'C0001',
  `JournalDefaultCode` varchar(50) DEFAULT 'J0001',
  `CompteComptable` varchar(50) DEFAULT NULL,
  `TenantId` int NOT NULL DEFAULT '0',
  `TypePointVente` varchar(20) NOT NULL DEFAULT 'Boutique',
  `ImprimerBons` tinyint(1) NOT NULL DEFAULT '1',
  `DepotId` int DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `IX_Caisses_Tenant` (`TenantId`),
  KEY `IX_Caisses_DepotId` (`DepotId`),
  CONSTRAINT `FK_Caisses_Depots` FOREIGN KEY (`DepotId`) REFERENCES `Depots` (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

INSERT INTO `Caisses` (`ID`, `ChkCode`, `ChkDescription`, `StCode`, `SalesPersonDefault`, `CashierDefault`, `CustomerDefaultCode`, `JournalDefaultCode`, `CompteComptable`, `TenantId`, `TypePointVente`, `ImprimerBons`, `DepotId`) VALUES (1,'CASH1','Caisse principale','ST01',NULL,NULL,'CUST001','JRN01',NULL,1,'Boutique',1,1);
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `CaissesDepots` (
  `CaisseId` int NOT NULL,
  `DepotId` int NOT NULL,
  `Ordre` int NOT NULL DEFAULT '1',
  PRIMARY KEY (`CaisseId`,`DepotId`),
  KEY `IX_CaissesDepots_DepotId` (`DepotId`),
  CONSTRAINT `FK_CaissesDepots_Caisses` FOREIGN KEY (`CaisseId`) REFERENCES `Caisses` (`ID`) ON DELETE CASCADE,
  CONSTRAINT `FK_CaissesDepots_Depots` FOREIGN KEY (`DepotId`) REFERENCES `Depots` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Categories` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `Nom` varchar(100) NOT NULL,
  `Couleur` varchar(7) NOT NULL DEFAULT '#195d84',
  `Ordre` int NOT NULL DEFAULT '0',
  `Preparation` varchar(20) NOT NULL DEFAULT 'Cuisine',
  PRIMARY KEY (`Id`),
  KEY `IX_Categories_Tenant` (`TenantId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Clients` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `CodeClient` varchar(50) NOT NULL,
  `NomSociete` varchar(200) NOT NULL,
  `Adresse` varchar(300) DEFAULT NULL,
  `Telephone` varchar(50) DEFAULT NULL,
  `Email` varchar(150) DEFAULT NULL,
  `Type` varchar(50) DEFAULT NULL,
  `CompteGeneral` varchar(50) DEFAULT NULL,
  `NomContact` varchar(150) DEFAULT NULL,
  `FonctionContact` varchar(150) DEFAULT NULL,
  `TelephoneContact` varchar(50) DEFAULT NULL,
  `EmailContact` varchar(150) DEFAULT NULL,
  `Genre` varchar(20) NOT NULL DEFAULT 'Entreprise',
  `EnCompte` tinyint(1) NOT NULL DEFAULT '0',
  `PlafondCredit` decimal(18,2) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_Clients_Tenant` (`TenantId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ComboChoix` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `ComboId` int NOT NULL,
  `ProduitId` int NOT NULL,
  `Supplement` decimal(18,2) NOT NULL DEFAULT '0.00',
  `Ordre` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `IX_ComboChoix_Groupe` (`ComboId`),
  KEY `IX_ComboChoix_Produit` (`ProduitId`),
  CONSTRAINT `FK_ComboChoix_Groupes` FOREIGN KEY (`ComboId`) REFERENCES `Combos` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Combos` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `Nom` varchar(50) NOT NULL,
  `Quantite` int NOT NULL DEFAULT '1',
  `Ordre` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `CommandesAttente` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL,
  `JourneeCaisseId` int NOT NULL,
  `Numero` int NOT NULL,
  `DateCreation` datetime NOT NULL,
  `UtilisateurId` int NOT NULL,
  `ClientId` int DEFAULT NULL,
  `Contenu` mediumtext NOT NULL,
  `Total` decimal(18,2) NOT NULL DEFAULT '0.00',
  `NbArticles` int NOT NULL DEFAULT '0',
  `LivreurId` int DEFAULT NULL,
  `NomLivraison` varchar(100) DEFAULT NULL,
  `TelephoneLivraison` varchar(30) DEFAULT NULL,
  `AdresseLivraison` varchar(200) DEFAULT NULL,
  `CleClient` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_CommandesAttente_JourneeCaisseId_Numero` (`JourneeCaisseId`,`Numero`),
  KEY `IX_CommandesAttente_LivreurId` (`LivreurId`),
  CONSTRAINT `FK_CommandesAttente_JourneesCaisses` FOREIGN KEY (`JourneeCaisseId`) REFERENCES `JourneesCaisses` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `FK_CommandesAttente_Livreurs` FOREIGN KEY (`LivreurId`) REFERENCES `Livreurs` (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `CommandesOuvertes` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `CaisseId` int NOT NULL,
  `JourneeCaisseId` int NOT NULL,
  `TableId` int DEFAULT NULL,
  `Couverts` int NOT NULL DEFAULT '1',
  `UtilisateurId` int DEFAULT NULL,
  `DateOuverture` datetime NOT NULL,
  `DateMaj` datetime NOT NULL,
  `Version` int NOT NULL DEFAULT '1',
  `AdditionImprimee` tinyint(1) NOT NULL DEFAULT '0',
  `Contenu` mediumtext NOT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `UX_CommandesOuvertes_Table` (`TableId`),
  KEY `IX_CommandesOuvertes_Journee` (`JourneeCaisseId`),
  CONSTRAINT `FK_CommandesOuvertes_Journees` FOREIGN KEY (`JourneeCaisseId`) REFERENCES `JourneesCaisses` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `CommandesPos` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `Numero` varchar(50) NOT NULL,
  `CleClient` varchar(64) NOT NULL,
  `JourneeCaisseId` int NOT NULL,
  `ClientId` int DEFAULT NULL,
  `UtilisateurId` int NOT NULL,
  `DateCommande` datetime NOT NULL,
  `TotalHT` decimal(18,2) NOT NULL DEFAULT '0.00',
  `TotalTVA` decimal(18,2) NOT NULL DEFAULT '0.00',
  `TotalTTC` decimal(18,2) NOT NULL DEFAULT '0.00',
  `MontantRecu` decimal(18,2) NOT NULL DEFAULT '0.00',
  `MonnaieRendue` decimal(18,2) NOT NULL DEFAULT '0.00',
  `Statut` varchar(20) NOT NULL DEFAULT 'Payée',
  `FactureId` int DEFAULT NULL,
  `CommandeOrigineId` int DEFAULT NULL,
  `Motif` varchar(300) DEFAULT NULL,
  `RemiseGlobale` decimal(18,2) NOT NULL DEFAULT '0.00',
  `RemiseGlobaleTaux` decimal(5,2) DEFAULT NULL,
  `TableNom` varchar(60) DEFAULT NULL,
  `Couverts` int DEFAULT NULL,
  `Pourboire` decimal(18,2) NOT NULL DEFAULT '0.00',
  `LivreurId` int DEFAULT NULL,
  `NomLivraison` varchar(100) DEFAULT NULL,
  `TelephoneLivraison` varchar(30) DEFAULT NULL,
  `AdresseLivraison` varchar(200) DEFAULT NULL,
  `StatutLivraison` varchar(20) DEFAULT NULL,
  `DateLivraison` datetime DEFAULT NULL,
  `FraisLivraison` decimal(18,2) NOT NULL DEFAULT '0.00',
  `NumeroHorsLigne` varchar(30) DEFAULT NULL,
  `AlerteHorsLigne` varchar(500) DEFAULT NULL,
  `AlerteHorsLigneVue` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `UX_CommandesPos_Numero` (`TenantId`,`Numero`),
  UNIQUE KEY `UX_CommandesPos_Cle` (`TenantId`,`CleClient`),
  KEY `IX_CommandesPos_Journee` (`JourneeCaisseId`),
  KEY `IX_CommandesPos_Origine` (`CommandeOrigineId`),
  KEY `IX_CommandesPos_LivreurId` (`LivreurId`),
  CONSTRAINT `FK_CommandesPos_Journees` FOREIGN KEY (`JourneeCaisseId`) REFERENCES `JourneesCaisses` (`Id`),
  CONSTRAINT `FK_CommandesPos_Livreurs` FOREIGN KEY (`LivreurId`) REFERENCES `Livreurs` (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ComptagesCloture` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `JourneeCaisseId` int NOT NULL,
  `ModePaiementId` int DEFAULT NULL,
  `MontantTheorique` decimal(18,2) NOT NULL DEFAULT '0.00',
  `MontantCompte` decimal(18,2) NOT NULL DEFAULT '0.00',
  `TenantId` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `IX_Comptages_Journee` (`JourneeCaisseId`),
  CONSTRAINT `FK_Comptages_Journees` FOREIGN KEY (`JourneeCaisseId`) REFERENCES `JourneesCaisses` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Depots` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL,
  `Code` varchar(20) NOT NULL,
  `Nom` varchar(100) NOT NULL,
  `Adresse` varchar(200) DEFAULT NULL,
  `Responsable` varchar(100) DEFAULT NULL,
  `Actif` tinyint(1) NOT NULL DEFAULT '1',
  `ParDefaut` tinyint(1) NOT NULL DEFAULT '0',
  `DepotAchats` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_Depots_TenantId_Code` (`TenantId`,`Code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

INSERT INTO `Depots` (`Id`, `TenantId`, `Code`, `Nom`, `Adresse`, `Responsable`, `Actif`, `ParDefaut`, `DepotAchats`) VALUES (1,1,'DEP01','Dépôt principal',NULL,NULL,1,1,0);
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `DepotsLinge` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL,
  `CaisseId` int NOT NULL,
  `JourneeCaisseId` int NOT NULL,
  `Numero` int NOT NULL,
  `CleClient` varchar(64) DEFAULT NULL,
  `DateDepot` datetime NOT NULL,
  `DateRetraitPrevue` date DEFAULT NULL,
  `NomClient` varchar(100) NOT NULL,
  `TelephoneClient` varchar(30) DEFAULT NULL,
  `ClientId` int DEFAULT NULL,
  `UtilisateurId` int DEFAULT NULL,
  `Contenu` longtext NOT NULL,
  `Total` decimal(18,2) NOT NULL DEFAULT '0.00',
  `NbArticles` decimal(18,2) NOT NULL DEFAULT '0.00',
  `Acompte` decimal(18,2) NOT NULL DEFAULT '0.00',
  `AcompteModePaiementId` int DEFAULT NULL,
  `AcompteOperationId` int DEFAULT NULL,
  `Statut` varchar(20) NOT NULL DEFAULT 'En cours',
  `DatePret` datetime DEFAULT NULL,
  `DateRetrait` datetime DEFAULT NULL,
  `DateAnnulation` datetime DEFAULT NULL,
  `CommandePosId` int DEFAULT NULL,
  `NumeroHorsLigne` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_DepotsLinge_TenantId_Numero` (`TenantId`,`Numero`),
  KEY `IX_DepotsLinge_TenantId_Statut` (`TenantId`,`Statut`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Factures` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `Numero` varchar(50) NOT NULL,
  `DateFacture` datetime NOT NULL,
  `ClientId` int NOT NULL,
  `MontantHT` decimal(18,2) NOT NULL DEFAULT '0.00',
  `TauxTVA` decimal(5,2) NOT NULL DEFAULT '0.00',
  `MontantTVA` decimal(18,2) NOT NULL DEFAULT '0.00',
  `MontantTTC` decimal(18,2) NOT NULL DEFAULT '0.00',
  `MontantPaye` decimal(18,2) NOT NULL DEFAULT '0.00',
  `Statut` varchar(20) NOT NULL DEFAULT 'Brouillon',
  PRIMARY KEY (`Id`),
  KEY `IX_Factures_Tenant` (`TenantId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `JourneesCaisses` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `CaisseId` int NOT NULL,
  `NumeroJournee` varchar(50) NOT NULL,
  `DateJournee` date NOT NULL,
  `DateOuverture` datetime NOT NULL,
  `DateFermeture` datetime DEFAULT NULL,
  `SoldeInitial` decimal(18,2) NOT NULL DEFAULT '0.00',
  `SoldeFinal` decimal(18,2) NOT NULL DEFAULT '0.00',
  `EcartCloture` decimal(18,2) DEFAULT NULL,
  `NoteCloture` varchar(500) DEFAULT NULL,
  `Statut` varchar(20) NOT NULL DEFAULT 'Ouverte',
  PRIMARY KEY (`Id`),
  KEY `IX_Journees_Tenant` (`TenantId`),
  KEY `IX_Journees_Caisse` (`CaisseId`),
  CONSTRAINT `FK_Journees_Caisses` FOREIGN KEY (`CaisseId`) REFERENCES `Caisses` (`ID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `LignesAchats` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `AchatId` int NOT NULL,
  `ProduitId` int NOT NULL,
  `Quantite` decimal(18,2) NOT NULL DEFAULT '0.00',
  `PrixUnitaire` decimal(18,2) NOT NULL DEFAULT '0.00',
  `Montant` decimal(18,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`Id`),
  KEY `IX_LignesAchats_AchatId` (`AchatId`),
  CONSTRAINT `FK_LignesAchats_Achats_AchatId` FOREIGN KEY (`AchatId`) REFERENCES `Achats` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `LignesBonPreparation` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `BonPreparationId` int NOT NULL,
  `Libelle` varchar(200) NOT NULL,
  `Quantite` decimal(18,2) NOT NULL DEFAULT '0.00',
  `Note` varchar(200) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_LignesBonPreparation_Bon` (`BonPreparationId`),
  CONSTRAINT `FK_LignesBonPreparation_Bons` FOREIGN KEY (`BonPreparationId`) REFERENCES `BonsPreparation` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `LignesCommandePos` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `CommandePosId` int NOT NULL,
  `ProduitId` int DEFAULT NULL,
  `Libelle` varchar(200) NOT NULL,
  `Quantite` decimal(18,2) NOT NULL DEFAULT '0.00',
  `PrixUnitaire` decimal(18,2) NOT NULL DEFAULT '0.00',
  `Remise` decimal(5,2) NOT NULL DEFAULT '0.00',
  `TauxTVA` decimal(5,2) NOT NULL DEFAULT '0.00',
  `TotalTTC` decimal(18,2) NOT NULL DEFAULT '0.00',
  `LigneOrigineId` int DEFAULT NULL,
  `RemiseGlobale` decimal(18,2) NOT NULL DEFAULT '0.00',
  `Note` varchar(200) DEFAULT NULL,
  `Composants` text,
  PRIMARY KEY (`Id`),
  KEY `IX_LignesCommandePos_Commande` (`CommandePosId`),
  KEY `FK_LignesCommandePos_Produits` (`ProduitId`),
  KEY `IX_LignesCommandePos_Origine` (`LigneOrigineId`),
  CONSTRAINT `FK_LignesCommandePos_Commandes` FOREIGN KEY (`CommandePosId`) REFERENCES `CommandesPos` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `FK_LignesCommandePos_Produits` FOREIGN KEY (`ProduitId`) REFERENCES `Produits` (`Id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `LignesCommandePosTaxes` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `LigneCommandePosId` int NOT NULL,
  `TaxeId` int DEFAULT NULL,
  `Code` varchar(20) NOT NULL,
  `Taux` decimal(5,2) NOT NULL DEFAULT '0.00',
  `Montant` decimal(18,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`Id`),
  KEY `IX_LignesCommandePosTaxes_Ligne` (`LigneCommandePosId`),
  CONSTRAINT `FK_LignesCommandePosTaxes_Lignes` FOREIGN KEY (`LigneCommandePosId`) REFERENCES `LignesCommandePos` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `LignesFactures` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `FactureId` int NOT NULL,
  `Designation` varchar(300) NOT NULL,
  `Quantite` decimal(18,2) NOT NULL DEFAULT '0.00',
  `PrixUnitaire` decimal(18,2) NOT NULL DEFAULT '0.00',
  `TotalLigne` decimal(18,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`Id`),
  KEY `IX_Lignes_Facture` (`FactureId`),
  CONSTRAINT `FK_Lignes_Factures` FOREIGN KEY (`FactureId`) REFERENCES `Factures` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Livreurs` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL,
  `Nom` varchar(100) NOT NULL,
  `Telephone` varchar(30) DEFAULT NULL,
  `Actif` tinyint(1) NOT NULL DEFAULT '1',
  `MoyenLivraison` varchar(20) NOT NULL DEFAULT 'Moto',
  PRIMARY KEY (`Id`),
  KEY `IX_Livreurs_TenantId` (`TenantId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `MigrationsAppliquees` (
  `Nom` varchar(100) NOT NULL,
  `DateApplication` datetime NOT NULL,
  PRIMARY KEY (`Nom`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('001_pos_catalogue.sql','2026-11-02 00:15:19');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('002_pos_ventes.sql','2026-11-02 00:15:19');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('003_pos_apres_vente.sql','2026-11-02 00:15:19');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('004_pos_stock.sql','2026-11-02 00:15:19');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('005_pos_taxes.sql','2026-11-02 00:15:19');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('006_societe_produits.sql','2026-11-02 00:15:19');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('007_variantes_remise.sql','2026-11-02 00:15:20');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('008_unites.sql','2026-11-02 00:15:20');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('009_restaurant.sql','2026-11-02 00:15:20');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('010_combos.sql','2026-11-02 00:15:20');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('011_combos_odoo.sql','2026-11-02 00:15:20');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('012_module_point_vente.sql','2026-11-02 00:15:20');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('013_depots.sql','2026-11-02 00:15:20');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('014_livraisons.sql','2026-11-02 00:15:20');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('015_moyen_livraison.sql','2026-11-02 00:15:20');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('016_genre_tiers.sql','2026-11-02 00:15:20');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('017_clients_en_compte.sql','2026-11-02 00:15:20');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('018_frais_livraison.sql','2026-11-02 00:15:20');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('019_depots_secondaires.sql','2026-11-02 00:15:20');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('020_depots_linge.sql','2026-11-02 00:15:20');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('021_achats.sql','2026-11-12 00:00:00');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('022_depot_achats.sql','2026-11-12 00:00:00');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('023_hors_ligne.sql','2026-11-12 00:00:00');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('024_attente_hors_ligne.sql','2026-11-12 00:00:00');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('025_postes_hors_ligne.sql','2026-11-13 00:00:00');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('026_droit_remise.sql','2026-11-13 00:00:00');
INSERT INTO `MigrationsAppliquees` (`Nom`, `DateApplication`) VALUES ('027_tentatives_connexion.sql','2026-11-14 00:00:00');
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ModesPaiement` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `Code` varchar(30) DEFAULT NULL,
  `Libelle` varchar(100) DEFAULT NULL,
  `Actif` tinyint(1) NOT NULL DEFAULT '1',
  `TenantId` int NOT NULL DEFAULT '0',
  `EstCompte` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `IX_ModesPaiement_Tenant` (`TenantId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Motifs` (
  `ID` int NOT NULL AUTO_INCREMENT,
  `LibelleMotif` varchar(200) DEFAULT NULL,
  `TypeModif` varchar(50) DEFAULT NULL,
  `CG_Num` varchar(50) DEFAULT NULL,
  `TenantId` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  KEY `IX_Motifs_Tenant` (`TenantId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `MouvementsStock` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `ProduitId` int NOT NULL,
  `DateMouvement` datetime NOT NULL,
  `TypeMouvement` varchar(20) NOT NULL,
  `Quantite` decimal(18,2) NOT NULL DEFAULT '0.00',
  `StockApres` decimal(18,2) NOT NULL DEFAULT '0.00',
  `Reference` varchar(100) DEFAULT NULL,
  `CommandePosId` int DEFAULT NULL,
  `UtilisateurId` int DEFAULT NULL,
  `Commentaire` varchar(300) DEFAULT NULL,
  `DepotId` int DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_MouvementsStock_Produit` (`ProduitId`,`DateMouvement`),
  KEY `IX_MouvementsStock_Tenant` (`TenantId`,`DateMouvement`),
  KEY `IX_MouvementsStock_DepotId` (`DepotId`),
  CONSTRAINT `FK_MouvementsStock_Depots` FOREIGN KEY (`DepotId`) REFERENCES `Depots` (`Id`),
  CONSTRAINT `FK_MouvementsStock_Produits` FOREIGN KEY (`ProduitId`) REFERENCES `Produits` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `OperationsCaisses` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `JourneeCaisseId` int NOT NULL,
  `DateOperation` datetime NOT NULL,
  `TypeOperation` varchar(20) NOT NULL,
  `Montant` decimal(18,2) NOT NULL DEFAULT '0.00',
  `Libelle` varchar(300) DEFAULT NULL,
  `ClientId` int DEFAULT NULL,
  `MotifId` int DEFAULT NULL,
  `ModePaiementId` int DEFAULT NULL,
  `UtilisateurId` int NOT NULL,
  `EstJustifie` tinyint(1) NOT NULL DEFAULT '0',
  `StatutValidation` varchar(20) NOT NULL DEFAULT 'En attente',
  `Valideur` varchar(200) DEFAULT NULL,
  `Observation` varchar(500) DEFAULT NULL,
  `ReglementCompte` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `IX_Operations_Tenant` (`TenantId`),
  KEY `IX_Operations_Journee` (`JourneeCaisseId`),
  KEY `IX_Operations_Date` (`DateOperation`),
  CONSTRAINT `FK_Operations_Journees` FOREIGN KEY (`JourneeCaisseId`) REFERENCES `JourneesCaisses` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `PaiementsPos` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `CommandePosId` int NOT NULL,
  `ModePaiementId` int DEFAULT NULL,
  `Libelle` varchar(100) NOT NULL,
  `MontantRecu` decimal(18,2) NOT NULL DEFAULT '0.00',
  `Montant` decimal(18,2) NOT NULL DEFAULT '0.00',
  `OperationCaisseId` int DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_PaiementsPos_Commande` (`CommandePosId`),
  CONSTRAINT `FK_PaiementsPos_Commandes` FOREIGN KEY (`CommandePosId`) REFERENCES `CommandesPos` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ProduitAttributValeurs` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `ProduitAttributId` int NOT NULL,
  `Valeur` varchar(50) NOT NULL,
  `Ordre` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `IX_ProduitAttributValeurs_Attribut` (`ProduitAttributId`),
  CONSTRAINT `FK_ProduitAttributValeurs_Attributs` FOREIGN KEY (`ProduitAttributId`) REFERENCES `ProduitAttributs` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ProduitAttributs` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `ProduitId` int NOT NULL,
  `Nom` varchar(50) NOT NULL,
  `Ordre` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `IX_ProduitAttributs_Produit` (`ProduitId`),
  CONSTRAINT `FK_ProduitAttributs_Produits` FOREIGN KEY (`ProduitId`) REFERENCES `Produits` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ProduitCombos` (
  `ProduitId` int NOT NULL,
  `ComboId` int NOT NULL,
  `Ordre` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ProduitId`,`ComboId`),
  KEY `IX_ProduitCombos_Combo` (`ComboId`),
  CONSTRAINT `FK_ProduitCombos_Combos` FOREIGN KEY (`ComboId`) REFERENCES `Combos` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `FK_ProduitCombos_Produits` FOREIGN KEY (`ProduitId`) REFERENCES `Produits` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ProduitImages` (
  `ProduitId` int NOT NULL,
  `TypeContenu` varchar(30) NOT NULL,
  `Donnees` mediumblob NOT NULL,
  PRIMARY KEY (`ProduitId`),
  CONSTRAINT `FK_ProduitImages_Produits` FOREIGN KEY (`ProduitId`) REFERENCES `Produits` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ProduitTaxes` (
  `ProduitId` int NOT NULL,
  `TaxeId` int NOT NULL,
  PRIMARY KEY (`ProduitId`,`TaxeId`),
  KEY `IX_ProduitTaxes_Taxe` (`TaxeId`),
  CONSTRAINT `FK_ProduitTaxes_Produits` FOREIGN KEY (`ProduitId`) REFERENCES `Produits` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `FK_ProduitTaxes_Taxes` FOREIGN KEY (`TaxeId`) REFERENCES `Taxes` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `PostesHorsLigne` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL,
  `Code` varchar(10) NOT NULL,
  `UtilisateurId` int DEFAULT NULL,
  `Navigateur` varchar(150) DEFAULT NULL,
  `EnAttente` int NOT NULL DEFAULT '0',
  `Refusees` int NOT NULL DEFAULT '0',
  `MontantEnAttente` decimal(18,2) NOT NULL DEFAULT '0.00',
  `PlusAncien` datetime DEFAULT NULL,
  `DernierEnvoi` datetime DEFAULT NULL,
  `DernierRapport` datetime NOT NULL,
  `Detail` text,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_PostesHorsLigne_TenantId_Code` (`TenantId`,`Code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Produits` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `Code` varchar(50) NOT NULL,
  `CodeBarres` varchar(50) DEFAULT NULL,
  `Nom` varchar(200) NOT NULL,
  `CategorieId` int DEFAULT NULL,
  `PrixVente` decimal(18,2) NOT NULL DEFAULT '0.00',
  `TauxTVA` decimal(5,2) NOT NULL DEFAULT '18.00',
  `SuiviStock` tinyint(1) NOT NULL DEFAULT '1',
  `StockActuel` decimal(18,2) NOT NULL DEFAULT '0.00',
  `SeuilAlerte` decimal(18,2) DEFAULT NULL,
  `Actif` tinyint(1) NOT NULL DEFAULT '1',
  `Cout` decimal(18,2) DEFAULT NULL,
  `Unite` varchar(20) NOT NULL DEFAULT 'Unité',
  `ImageMaj` datetime DEFAULT NULL,
  `ParentId` int DEFAULT NULL,
  `EstModele` tinyint(1) NOT NULL DEFAULT '0',
  `Supplement` decimal(18,2) NOT NULL DEFAULT '0.00',
  `LibelleVariante` varchar(150) DEFAULT NULL,
  `EstCombo` tinyint(1) NOT NULL DEFAULT '0',
  `Consommable` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`),
  UNIQUE KEY `UX_Produits_Code` (`TenantId`,`Code`),
  KEY `IX_Produits_CodeBarres` (`CodeBarres`),
  KEY `IX_Produits_Categorie` (`CategorieId`),
  KEY `IX_Produits_Parent` (`ParentId`),
  CONSTRAINT `FK_Produits_Categories` FOREIGN KEY (`CategorieId`) REFERENCES `Categories` (`Id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ReglementsAchats` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `AchatId` int NOT NULL,
  `DateReglement` datetime NOT NULL,
  `Montant` decimal(18,2) NOT NULL DEFAULT '0.00',
  `ModePaiementId` int DEFAULT NULL,
  `OperationCaisseId` int DEFAULT NULL,
  `UtilisateurId` int DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_ReglementsAchats_AchatId` (`AchatId`),
  CONSTRAINT `FK_ReglementsAchats_Achats_AchatId` FOREIGN KEY (`AchatId`) REFERENCES `Achats` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Salles` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `CaisseId` int NOT NULL,
  `Nom` varchar(50) NOT NULL,
  `Ordre` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `IX_Salles_Caisse` (`CaisseId`),
  CONSTRAINT `FK_Salles_Caisses` FOREIGN KEY (`CaisseId`) REFERENCES `Caisses` (`ID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `StocksDepots` (
  `DepotId` int NOT NULL,
  `ProduitId` int NOT NULL,
  `Quantite` decimal(18,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`DepotId`,`ProduitId`),
  KEY `IX_StocksDepots_ProduitId` (`ProduitId`),
  CONSTRAINT `FK_StocksDepots_Depots` FOREIGN KEY (`DepotId`) REFERENCES `Depots` (`Id`),
  CONSTRAINT `FK_StocksDepots_Produits` FOREIGN KEY (`ProduitId`) REFERENCES `Produits` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `TablesRestaurant` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `SalleId` int NOT NULL,
  `Nom` varchar(30) NOT NULL,
  `Places` int NOT NULL DEFAULT '4',
  `Forme` varchar(10) NOT NULL DEFAULT 'carree',
  `PosX` int NOT NULL DEFAULT '20',
  `PosY` int NOT NULL DEFAULT '20',
  `Largeur` int NOT NULL DEFAULT '100',
  `Hauteur` int NOT NULL DEFAULT '100',
  `Actif` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`Id`),
  KEY `IX_TablesRestaurant_Salle` (`SalleId`),
  CONSTRAINT `FK_TablesRestaurant_Salles` FOREIGN KEY (`SalleId`) REFERENCES `Salles` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Taxes` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `Code` varchar(20) NOT NULL,
  `Libelle` varchar(100) NOT NULL,
  `Taux` decimal(5,2) NOT NULL DEFAULT '0.00',
  `ParDefaut` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`Id`),
  KEY `IX_Taxes_Tenant` (`TenantId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

INSERT INTO `Taxes` (`Id`, `TenantId`, `Code`, `Libelle`, `Taux`, `ParDefaut`) VALUES (1,1,'TVA','Taxe sur la valeur ajoutée',18.00,1);
INSERT INTO `Taxes` (`Id`, `TenantId`, `Code`, `Libelle`, `Taux`, `ParDefaut`) VALUES (2,1,'CSS','Contribution spéciale de solidarité',1.00,0);
CREATE TABLE `TentativesConnexion` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `NomUtilisateur` varchar(100) NOT NULL,
  `AdresseIp` varchar(45) NOT NULL,
  `DateTentative` datetime NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_TentativesConnexion_Adresse` (`AdresseIp`,`DateTentative`),
  KEY `IX_TentativesConnexion_Nom` (`NomUtilisateur`,`DateTentative`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `TenantLogos` (
  `TenantId` int NOT NULL,
  `TypeContenu` varchar(30) NOT NULL,
  `Donnees` mediumblob NOT NULL,
  PRIMARY KEY (`TenantId`),
  CONSTRAINT `FK_TenantLogos_Tenants` FOREIGN KEY (`TenantId`) REFERENCES `Tenants` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Tenants` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `Nom` varchar(200) NOT NULL,
  `Code` varchar(50) NOT NULL,
  `Actif` tinyint(1) NOT NULL DEFAULT '1',
  `ModeAcces` varchar(20) NOT NULL DEFAULT 'Licence',
  `DateExpiration` date DEFAULT NULL,
  `DateCreation` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `PosVenteSansStock` tinyint(1) NOT NULL DEFAULT '1',
  `Adresse` varchar(250) DEFAULT NULL,
  `Ville` varchar(100) DEFAULT NULL,
  `Pays` varchar(100) DEFAULT NULL,
  `Email` varchar(150) DEFAULT NULL,
  `Telephone` varchar(50) DEFAULT NULL,
  `NIF` varchar(50) DEFAULT NULL,
  `LogoMaj` datetime DEFAULT NULL,
  `ModulePointVente` tinyint(1) NOT NULL DEFAULT '1',
  `FraisLivraisonDefaut` decimal(18,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

INSERT INTO `Tenants` (`Id`, `Nom`, `Code`, `Actif`, `ModeAcces`, `DateExpiration`, `DateCreation`, `PosVenteSansStock`, `Adresse`, `Ville`, `Pays`, `Email`, `Telephone`, `NIF`, `LogoMaj`, `ModulePointVente`) VALUES (1,'Société de démonstration','DEMO',1,'Licence',NULL,'2026-11-02 00:14:59',1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1);
INSERT INTO `ModesPaiement` (`Id`, `Code`, `Libelle`, `Actif`, `TenantId`, `EstCompte`) VALUES (1,'CPT','Compte client',1,1,1);
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Unites` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `TenantId` int NOT NULL DEFAULT '0',
  `Nom` varchar(20) NOT NULL,
  `Libelle` varchar(100) DEFAULT NULL,
  `Actif` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`Id`),
  UNIQUE KEY `UX_Unites_Tenant_Nom` (`TenantId`,`Nom`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

INSERT INTO `Unites` (`Id`, `TenantId`, `Nom`, `Libelle`, `Actif`) VALUES (1,1,'Unité','Article vendu à l\'unité',1);
INSERT INTO `Unites` (`Id`, `TenantId`, `Nom`, `Libelle`, `Actif`) VALUES (2,1,'Pièce','Pièce',1);
INSERT INTO `Unites` (`Id`, `TenantId`, `Nom`, `Libelle`, `Actif`) VALUES (3,1,'Kg','Kilogramme',1);
INSERT INTO `Unites` (`Id`, `TenantId`, `Nom`, `Libelle`, `Actif`) VALUES (4,1,'g','Gramme',1);
INSERT INTO `Unites` (`Id`, `TenantId`, `Nom`, `Libelle`, `Actif`) VALUES (5,1,'Litre','Litre',1);
INSERT INTO `Unites` (`Id`, `TenantId`, `Nom`, `Libelle`, `Actif`) VALUES (6,1,'cl','Centilitre',1);
INSERT INTO `Unites` (`Id`, `TenantId`, `Nom`, `Libelle`, `Actif`) VALUES (7,1,'Mètre','Mètre',1);
INSERT INTO `Unites` (`Id`, `TenantId`, `Nom`, `Libelle`, `Actif`) VALUES (8,1,'Carton','Carton',1);
INSERT INTO `Unites` (`Id`, `TenantId`, `Nom`, `Libelle`, `Actif`) VALUES (9,1,'Paquet','Paquet',1);
INSERT INTO `Unites` (`Id`, `TenantId`, `Nom`, `Libelle`, `Actif`) VALUES (10,1,'Boîte','Boîte',1);
INSERT INTO `Unites` (`Id`, `TenantId`, `Nom`, `Libelle`, `Actif`) VALUES (11,1,'Sac','Sac',1);
INSERT INTO `Unites` (`Id`, `TenantId`, `Nom`, `Libelle`, `Actif`) VALUES (12,1,'Bouteille','Bouteille',1);
INSERT INTO `Unites` (`Id`, `TenantId`, `Nom`, `Libelle`, `Actif`) VALUES (13,1,'Page','Page (impression, photocopie)',1);
INSERT INTO `Unites` (`Id`, `TenantId`, `Nom`, `Libelle`, `Actif`) VALUES (14,1,'Heure','Heure (service)',1);
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Utilisateurs` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `NomUtilisateur` varchar(100) NOT NULL,
  `MotPasse` varchar(255) NOT NULL,
  `NomComplet` varchar(200) NOT NULL,
  `Profil` varchar(30) NOT NULL,
  `PeutValiderOperations` tinyint(1) NOT NULL DEFAULT '0',
  `TenantId` int DEFAULT NULL,
  `PeutRemise` tinyint(1) NOT NULL DEFAULT '0',
  `RemiseMax` decimal(5,2) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `UX_Utilisateurs_Nom` (`NomUtilisateur`),
  KEY `FK_Utilisateurs_Tenants` (`TenantId`),
  CONSTRAINT `FK_Utilisateurs_Tenants` FOREIGN KEY (`TenantId`) REFERENCES `Tenants` (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

INSERT INTO `Utilisateurs` (`Id`, `NomUtilisateur`, `MotPasse`, `NomComplet`, `Profil`, `PeutValiderOperations`, `TenantId`, `PeutRemise`, `RemiseMax`) VALUES (1,'superadmin','pmWkWSBCL51Bfkhn79xPuKBKHz//H6B+mY6G9/eieuM=','Super Administrateur','SuperAdmin',1,NULL,1,NULL);
INSERT INTO `Utilisateurs` (`Id`, `NomUtilisateur`, `MotPasse`, `NomComplet`, `Profil`, `PeutValiderOperations`, `TenantId`, `PeutRemise`, `RemiseMax`) VALUES (2,'admin','pmWkWSBCL51Bfkhn79xPuKBKHz//H6B+mY6G9/eieuM=','Administrateur','Admin',1,1,1,NULL);
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `VarianteValeurs` (
  `VarianteId` int NOT NULL,
  `ValeurId` int NOT NULL,
  PRIMARY KEY (`VarianteId`,`ValeurId`),
  KEY `IX_VarianteValeurs_Valeur` (`ValeurId`),
  CONSTRAINT `FK_VarianteValeurs_Produits` FOREIGN KEY (`VarianteId`) REFERENCES `Produits` (`Id`) ON DELETE CASCADE,
  CONSTRAINT `FK_VarianteValeurs_Valeurs` FOREIGN KEY (`ValeurId`) REFERENCES `ProduitAttributValeurs` (`Id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;


/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

