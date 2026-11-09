// Cahier des charges GesCaisse (Word) — généré avec docx-js (npm install docx).
// Usage : node docs/generer_cahier_des_charges.js docs/Cahier_des_charges_GesCaisse.docx
const fs = require('fs');
const {
    Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, AlignmentType, HeadingLevel,
    BorderStyle, WidthType, ShadingType, LevelFormat, Header, Footer, PageNumber, PageBreak, TabStopType
} = require('docx');
const sectionGarde = require('./page_de_garde');

const BLEU = '195D84', BLEU_CLAIR = 'E6F0F7', GRIS = '5A6B78';
const LARGEUR = 9638;   // A4 (11906) moins 2 × 1134 de marge
const POLICE = 'Arial';

const t = (texte, o = {}) => new TextRun({ text: texte, font: POLICE, ...o });
const p = (texte, o = {}) => new Paragraph({ spacing: { after: 120, line: 300 }, ...o, children: Array.isArray(texte) ? texte : [t(texte)] });
const h1 = texte => new Paragraph({ heading: HeadingLevel.HEADING_1, pageBreakBefore: true, children: [t(texte)] });
const h2 = texte => new Paragraph({ heading: HeadingLevel.HEADING_2, children: [t(texte)] });
const h3 = texte => new Paragraph({ heading: HeadingLevel.HEADING_3, children: [t(texte)] });
const puce = (texte, niveau = 0) => new Paragraph({
    numbering: { reference: 'puces', level: niveau }, spacing: { after: 60, line: 280 },
    children: Array.isArray(texte) ? texte : [t(texte)]
});
// « Libellé : texte » avec le libellé en gras.
const pt = (libelle, texte, niveau = 0) => puce([t(libelle + ' : ', { bold: true }), t(texte)], niveau);

const bord = { style: BorderStyle.SINGLE, size: 4, color: 'C9D5DE' };
const bords = { top: bord, bottom: bord, left: bord, right: bord };
function tableau(entetes, lignes, largeurs) {
    const total = largeurs.reduce((a, b) => a + b, 0);
    const cell = (texte, l, entete, pair) => new TableCell({
        borders: bords, width: { size: l, type: WidthType.DXA },
        shading: { fill: entete ? BLEU : (pair ? 'F5F8FA' : 'FFFFFF'), type: ShadingType.CLEAR, color: 'auto' },
        margins: { top: 70, bottom: 70, left: 110, right: 110 },
        children: [new Paragraph({ spacing: { after: 0, line: 260 },
            children: [t(texte, entete ? { bold: true, color: 'FFFFFF', size: 19 } : { size: 19 })] })]
    });
    return new Table({
        width: { size: total, type: WidthType.DXA }, columnWidths: largeurs,
        rows: [
            new TableRow({ tableHeader: true, children: entetes.map((e, i) => cell(e, largeurs[i], true)) }),
            ...lignes.map((l, k) => new TableRow({ children: l.map((c, i) => cell(c, largeurs[i], false, k % 2 === 1)) }))
        ]
    });
}
const espace = () => new Paragraph({ spacing: { after: 60 }, children: [] });

// Encadré (paragraphe bordé à gauche, fond bleu clair).
const encadre = (titre, texte) => new Paragraph({
    spacing: { before: 120, after: 160, line: 290 },
    shading: { fill: BLEU_CLAIR, type: ShadingType.CLEAR, color: 'auto' },
    border: { left: { style: BorderStyle.SINGLE, size: 24, color: BLEU, space: 8 } },
    indent: { left: 200, right: 200 },
    children: [t(titre + ' ', { bold: true, color: BLEU }), t(texte)]
});

// ---------------------------------------------------------------------------
// Page de garde : image pleine page (pages_de_garde/), voir page_de_garde.js
// ---------------------------------------------------------------------------
// Fiche du document (la page de garde est une image : voir generer_pages_de_garde.js)
const fiche = [
    new Paragraph({ spacing: { before: 480, after: 160 }, children: [t('Informations du document', { bold: true, color: BLEU, size: 24 })] }),
    tableau(['Rubrique', 'Information'], [
        ['Projet', 'GesCaisse — gestion de caisse et point de vente (POS)'],
        ['Éditeur', 'M-ITECH AFRICA'],
        ['Versions', 'ASP.NET Core (.NET 10) / SQL Server — PHP 8 / MySQL'],
        ['Version du document', '1.7'],
        ['Date', 'Novembre 2026'],
        ['Statut', 'Document de référence (fonctionnalités réalisées)']
    ], [3000, 6638])
];

// ---------------------------------------------------------------------------
// Sommaire (statique : lisible à l'identique dans Word et dans le PDF)
// ---------------------------------------------------------------------------
const chapitres = [
    ['1', 'Présentation du projet'],
    ['2', 'Acteurs, profils et droits'],
    ['3', 'Exigences fonctionnelles — gestion de caisse'],
    ['4', 'Exigences fonctionnelles — point de vente'],
    ['5', 'Exigences fonctionnelles — restaurant et bar'],
    ['6', 'Exigences fonctionnelles — paramétrage'],
    ['7', 'Règles de gestion'],
    ['8', 'Exigences non fonctionnelles'],
    ['9', 'Architecture technique et données'],
    ['10', 'Déploiement, livrables et maintenance'],
    ['11', 'Glossaire']
];
const sommaire = [
    new Paragraph({ heading: HeadingLevel.HEADING_1, children: [t('Sommaire')] }),
    ...chapitres.map(([n, titre]) => new Paragraph({
        spacing: { after: 140 }, tabStops: [{ type: TabStopType.LEFT, position: 700 }],
        border: { bottom: { style: BorderStyle.DOTTED, size: 4, color: 'C9D5DE', space: 4 } },
        children: [t(n + '.', { bold: true, color: BLEU }), t('\t' + titre, { size: 22 })]
    }))
];

// ---------------------------------------------------------------------------
// Contenu
// ---------------------------------------------------------------------------
const contenu = [
    // 1
    h1('1. Présentation du projet'),
    h2('1.1 Contexte'),
    p("GesCaisse est une application web de gestion de caisse destinée aux entreprises d'Afrique centrale (montants en francs CFA). Elle couvre la tenue des journées de caisse (encaissements, décaissements, validation, clôture), la vente au comptoir par écran tactile (point de vente), la gestion du stock et, depuis la dernière évolution, la restauration (salles, tables, cuisine et bar)."),
    p("L'application est multi-sociétés : un même déploiement héberge plusieurs sociétés clientes, dont les données sont strictement cloisonnées. Un super-administrateur gère les sociétés et leurs licences."),
    h2('1.2 Objectifs'),
    puce('Fiabiliser la tenue de caisse : chaque mouvement est tracé, justifié, validé et rapproché à la clôture.'),
    puce('Accélérer la vente au comptoir : écran tactile, douchette, tickets en attente, plusieurs modes de paiement.'),
    puce('Maîtriser le stock, dépôt par dépôt : chaque entrée, inventaire, transfert, vente ou retour devient un mouvement historisé.'),
    puce('Servir les restaurants et bars comme un point de vente Odoo : plan de salle, commandes par table, bons de préparation.'),
    puce('Produire les états de gestion : rapports d\'opérations, rapports de ventes, export comptable vers Sage.'),
    h2('1.3 Périmètre'),
    p('Le périmètre fonctionnel comprend les modules suivants :'),
    tableau(['Domaine', 'Modules'], [
        ['Activité', 'Tableau de bord, caisses et journées, tiers (clients)'],
        ['Analyse', "Rapports d'opérations, export Sage, rapport des tiers"],
        ['Point de vente', 'Vente, ventes (retours, annulations), écran cuisine / bar, rapports de ventes, stock'],
        ['Configuration', 'Catégories, produits (variantes, combos), combos'],
        ['Paramètres', 'Ma société, utilisateurs, motifs, modes de paiement, taxes, unités de vente, dépôts, livreurs'],
        ['Administration', 'Sociétés et licences (super-administrateur)']
    ], [2600, 7038]),
    espace(),
    h2('1.4 Deux versions'),
    p("L'application existe en deux versions fonctionnellement identiques, maintenues en parallèle :"),
    pt('Version .NET', 'ASP.NET Core MVC (.NET 10), Entity Framework Core, SQL Server — pour un hébergement Windows / IIS ou un serveur dédié.'),
    pt('Version PHP', 'PHP 8 sans framework, MySQL / MariaDB — pour un hébergement mutualisé (Hostinger).'),
    p("Les écrans du point de vente, de l'éditeur de plan de salle, de l'écran cuisine et de l'éditeur de combos partagent les mêmes fichiers JavaScript et CSS dans les deux versions."),
    p("Les deux versions présentent les mêmes pages (titres, colonnes, boutons, messages), les mêmes listes, les mêmes impressions et les mêmes fichiers d'export (Sage, tiers, produits, ventes) : un utilisateur passe de l'une à l'autre sans différence visible."),

    // 2
    h1('2. Acteurs, profils et droits'),
    p('Chaque utilisateur appartient à une société (sauf le super-administrateur) et possède un profil :'),
    tableau(['Profil', 'Rôle', 'Accès principaux'], [
        ['SuperAdmin', 'Administrateur de la plateforme', 'Toutes les sociétés (choix de la « société consultée »), création des sociétés, prolongation des licences, toutes les fonctions'],
        ['Admin', 'Responsable de la société', 'Coordonnées et logo de sa société, catalogue, stock, paramètres, utilisateurs, plan de salle, rapports de ventes, retours et annulations, modification des prix au point de vente'],
        ['Caissier', 'Tenue de caisse', 'Journées de caisse, opérations, point de vente, ventes ; validation des opérations si le droit lui est accordé'],
        ['Vendeur', 'Vente au comptoir ou en salle', 'Point de vente, écran cuisine / bar, consultation des ventes']
    ], [1700, 2500, 5438]),
    espace(),
    h3('Droit complémentaire « Peut valider les opérations »'),
    p('Attribuable à un caissier ou un vendeur, il autorise la validation des opérations de caisse, la remise globale sur un ticket, les retours et les annulations de ventes.'),
    h3('Licence de la société'),
    p("Chaque société a une date d'expiration de licence, prolongée par le super-administrateur (de 1 à 120 mois). À l'expiration, les utilisateurs de la société sont redirigés vers une page « compte suspendu »."),
    h3('Ma société (Paramètres)'),
    p("L'administrateur modifie lui-même les coordonnées de sa société (adresse, ville, pays, e-mail, téléphone, NIF) et son logo, repris en en-tête des tickets et des impressions. Le nom, le code, la licence et les modules sont affichés en lecture seule : ils restent gérés par le super-administrateur."),
    h3('Module Point de vente optionnel'),
    p("À la création (ou en modification) d'une société, le super-administrateur choisit si elle dispose du module Point de vente. Sans ce module, la société n'a que la gestion de caisse (journées, opérations, tiers, rapports) : les menus Point de vente, Configuration, Taxes et Unités de vente sont masqués et leurs pages refusées, même par leur adresse."),

    // 3
    h1('3. Exigences fonctionnelles — gestion de caisse'),
    h2('3.1 Tableau de bord'),
    puce("Filtres : période (aujourd'hui, 7 jours, ce mois, personnalisée), caisse, statut de journée."),
    puce('Indicateurs : solde en caisse (fond initial, entrées, sorties), entrées, sorties, résultat net.'),
    puce('Bloc « À traiter » : opérations en attente de validation, décaissements sans justificatif, journées ouvertes depuis plus de 24 h.'),
    puce('Graphique des flux des 7 derniers jours et état de chaque caisse (ouverte, clôturée, solde).'),
    h2('3.2 Caisses'),
    puce('Création, modification, suppression (refusée si la caisse a des journées), impression de la liste.'),
    puce('Informations : code, description, caissier par défaut, compte comptable (contrepartie Sage).'),
    puce('Type de point de vente : Vente en détail, Restaurant, Bar ou Laverie ; option d\'impression des bons de préparation. Une laverie vend au comptoir comme la vente en détail (prestations sans suivi de stock et produits en stock) ; seuls le titre de l\'écran de vente et l\'icône du type changent.'),
    puce('Dépôt de stock : dépôt d\'où sortent les ventes de la caisse et où reviennent ses retours (dépôt par défaut de la société pour une nouvelle caisse).'),
    h2('3.3 Journées de caisse'),
    pt('Ouverture', 'numéro de journée, date de gestion, fond initial (suggestion : solde de la dernière clôture).'),
    pt('Opérations', 'encaissements et décaissements avec montant, libellé, client, motif, mode de paiement, justificatif.'),
    pt('Validation', 'les opérations saisies sont « En attente » puis validées ou rejetées par un utilisateur habilité ; les ventes du point de vente sont validées d\'office.'),
    pt('Clôture', 'comptage du montant réel par mode de paiement, calcul de l\'écart avec le théorique, note de clôture. Refusée tant qu\'une table de restaurant a une commande en cours.'),
    pt('Règlement client', 'bouton « Règlement client » de la journée ouverte : client en compte (solde dû affiché et proposé), montant, mode de paiement (espèces par défaut, hors mode compte), observation. Encaissement de la journée, motif « Règlement client », marqué règlement de compte ; montant limité au solde dû ; validé d\'office pour un utilisateur habilité, sinon « En attente ». Un règlement rejeté rétablit le solde dû.'),
    pt('Impressions', 'journal des opérations de la journée (totaux, totaux par mode de paiement, détail) et liste des journées de la caisse avec leur total ; les opérations rejetées sont exclues des montants.'),
    h2('3.4 Tiers (clients)'),
    puce('Fiche du tiers en fenêtre (création et modification) : genre (Entreprise ou Particulier, Entreprise par défaut), code, nom, type, coordonnées, contact et compte général ; recherche et pagination.'),
    puce('Le genre s\'affiche dans la liste (icône) ; il est repris dans l\'export et l\'import Excel (12e colonne, vide = Entreprise).'),
    puce('Import et export Excel.'),
    puce('Clients en compte : case « Client en compte » et plafond de crédit facultatif (section Compte client de la fiche, colonnes EnCompte et PlafondCredit de l\'Excel). La liste des tiers affiche le solde dû et le plafond de chaque client en compte.'),
    puce('Solde dû = ventes payées par compte (ventes annulées exclues) − retours crédités au compte − règlements non rejetés ; même calcul dans les deux versions (compte_soldes / SoldesComptesAsync).'),
    h2('3.5 Factures (module masqué)'),
    p("Le module de facturation n'apparaît plus dans le menu, dans les deux versions. Ses pages restent en place, accessibles par leur adresse ou depuis le détail d'une vente :"),
    puce('Création en brouillon, ajout et suppression de lignes, recalcul automatique HT / TVA / TTC.'),
    puce('Validation de la facture (refusée tant qu\'elle n\'a aucune ligne), puis impression ; une facture validée ne peut plus être modifiée.'),
    puce('Création d\'une facture à partir d\'une vente du point de vente.'),
    h2('3.6 Rapports et export comptable'),
    puce("Rapport des opérations filtré (période, caisse, type, statut), aperçu imprimable."),
    puce("Totaux du rapport : encaissements, décaissements, solde de la période, montant initial des journées et solde en caisse. Le montant initial est le fond de départ de la première journée de chaque caisse sur la période (les journées suivantes repartent du solde de la veille)."),
    puce('Export Sage (Excel, CSV ou texte) : code caisse, date, compte général, compte tiers, libellé, débit, crédit, numéro de pièce ; liste des anomalies (comptes manquants).'),
    puce("Rapport des tiers (menu Analyse) : filtres période (par défaut du 1er du mois à aujourd'hui), type, genre et option « tiers sans mouvement » ; une ligne par tiers avec le nombre de ventes, les ventes nettes (retours déduits, ventes annulées exclues), les encaissements et décaissements (opérations rejetées exclues), le solde (encaissements − décaissements), le dû des clients en compte à la fin de la période et la date du dernier mouvement ; cartes de totaux, impression / PDF et export Excel."),
    puce("Relevé d'un tiers sur la période, imprimable : synthèse, section Compte client pour un client en compte (solde dû au début et à la fin, ventes par compte, règlements), opérations de caisse (journée, mode de paiement, statut) et ventes du point de vente ; les opérations rejetées et les ventes annulées restent affichées, barrées, hors totaux."),
    h2('3.7 Impressions'),
    puce("Mise en page commune à toutes les impressions : logo et coordonnées de la société à gauche ; à droite, la date et l'heure d'édition et le nom de l'utilisateur (« Édité le … par … »)."),
    puce("En-tête officiel « RÉPUBLIQUE GABONAISE — Union - Travail - Justice » sur la liste des journées, le journal des opérations, la liste des caisses et la facture."),
    puce('Montants en francs CFA sans décimales, avec un espace comme séparateur de milliers (ex. 50 000).'),
    puce("Version .NET : documents PDF ; version PHP : pages imprimables, enregistrables en PDF depuis le navigateur. Le contenu est le même."),

    // 4
    h1('4. Exigences fonctionnelles — point de vente'),
    h2('4.1 Écran de vente'),
    puce('Choix de la journée de caisse ouverte, puis écran plein écran adapté au tactile.'),
    puce('Grille de produits par catégorie (couleurs), recherche par nom, code ou code-barres, lecture par douchette.'),
    puce('Plusieurs tickets en parallèle sur un poste (onglets), gardés dans le navigateur jusqu\'au paiement.'),
    puce('« Mettre en attente » : le ticket est enregistré sur le serveur et quitte l\'écran ; la liste « Commandes en attente » (journée de caisse) est partagée entre les postes, avec reprise (un seul poste à la fois) et suppression.'),
    puce('Commande à livrer : livreur (Paramètres › Livreurs : nom, téléphone, moyen de livraison Moto, Voiture, Vélo ou Autre), destinataire, téléphone, adresse ; payée maintenant (vente encaissée, statut « À livrer » puis « Livrée » au retour du livreur) ou à encaisser à la livraison (commande en attente reprise au retour du livreur, vente enregistrée « Livrée »). Livreur, destinataire et statut figurent sur le ticket et le détail de la vente.'),
    puce('Pavé numérique : quantité, remise par ligne (%), prix (administrateurs seulement), suppression.'),
    puce('Remise globale sur le ticket, en % ou en montant (administrateurs et utilisateurs habilités).'),
    puce('Choix du client ; affichage du stock restant dans le dépôt de la caisse et alerte de stock bas.'),
    h2('4.2 Paiement et ticket'),
    puce('Plusieurs règlements par ticket (espèces, mobile money, carte…), billets rapides, montant exact.'),
    puce('Monnaie rendue uniquement sur les espèces.'),
    puce('Chaque règlement devient un encaissement validé de la journée (motif « Vente POS »), sauf le paiement par compte.'),
    puce('Paiement par compte (mode « Compte client », case « Paiement par compte client » du mode) : client en compte obligatoire ; plafond de crédit contrôlé sur le serveur, sous verrou du client (solde dû + montant par compte ≤ plafond), dépassement réservé aux administrateurs ; montant proposé limité au crédit restant. Pas d\'encaissement en caisse ni de comptage à la clôture : le montant s\'ajoute au solde dû. L\'écran de paiement rappelle le solde dû et le plafond ; le ticket indique le « Solde dû du compte ».'),
    puce('Ticket 80 mm : logo et coordonnées de la société, lignes, remises, taxes, règlements, monnaie rendue.'),
    puce('Option de la société : interdire la vente quand le stock est épuisé.'),
    h2('4.3 Ventes'),
    puce('Liste filtrée, avec recherche et pagination, détail d\'une vente (lignes, taxes, règlements, retours).'),
    puce('Retour partiel ou total : remboursement au prix réellement payé, remise en stock. Pour un client en compte, remboursement possible « par compte » : montant crédité sur le compte (solde dû diminué), sans décaissement.'),
    puce("Annulation d'une vente de la journée en cours : encaissements rejetés, stock rétabli."),
    h2('4.4 Catalogue'),
    pt('Catégories', 'nom, couleur des tuiles, ordre d\'affichage, poste de préparation (Cuisine, Bar, Aucun) ; affichage en liste ou en cartes.'),
    pt('Produits', 'code, nom, catégorie, code-barres, prix de vente TTC, coût d\'achat (calcul de la marge), unité de vente, image, taxes multiples, suivi de stock, seuil d\'alerte, actif ; affichage en liste ou en cartes ; import et export Excel.'),
    pt('Variantes', 'attributs combinés (ex. Taille : S, M, L × Couleur) ; une variante par combinaison avec son code, son code-barres, son prix et son stock ; le modèle transmet nom, catégorie, taxes, unité et coût.'),
    pt('Combos', 'un produit combo (ex. « Menu midi ») se compose de combos réutilisables (ex. « Plats », « Boissons ») ; voir 4.5.'),
    h2('4.5 Combos (comme dans Odoo)'),
    puce('Configuration › Combos : nom, nombre d\'articles à choisir, produits proposés avec supplément éventuel.'),
    puce('Création et modification d\'un combo dans une fenêtre modale ouverte depuis la liste des combos (« Nouveau combo » ou « Modifier ») ; en cas de saisie refusée, le formulaire complet s\'affiche avec le message d\'erreur.'),
    puce('Fiche produit : liste ordonnée des combos qui composent le produit ; le produit combo n\'a pas de stock propre.'),
    puce('À la caisse : fenêtre de choix par combo, total suppléments compris ; le serveur recalcule le prix et contrôle les choix.'),
    puce('Les articles choisis sortent du stock, partent chacun vers leur poste de préparation et figurent sur le ticket.'),
    h2('4.6 Stock'),
    p("Le stock est tenu par dépôt de stockage (magasin, entrepôt, réserve…) ; le stock d'un produit affiché dans les listes est le total de tous ses dépôts."),
    puce('Dépôts (Paramètres) : code, nom, adresse, responsable, actif ; un dépôt par défaut par société, qui reçoit le stock initial des nouveaux produits et sert aux caisses sans dépôt choisi ; le dépôt par défaut ne peut être ni désactivé ni supprimé, un dépôt rattaché à une caisse ne peut pas être désactivé, un dépôt avec historique se désactive au lieu d\'être supprimé. À la mise à jour, un « Dépôt principal » reçoit le stock existant.'),
    puce('Historique des mouvements (stock initial, entrée, inventaire, vente, retour, annulation, transfert) avec filtres, dont le dépôt ; « stock après » = stock du dépôt.'),
    puce('Stock par dépôt : quantité de chaque produit dans chaque dépôt et total.'),
    puce('Entrée de marchandises (bon de livraison) sur plusieurs produits, dans le dépôt choisi.'),
    puce('Transfert entre deux dépôts : sortie du dépôt de départ et entrée dans le dépôt d\'arrivée, refusé au-delà du stock du dépôt de départ ; le stock total ne change pas.'),
    puce('Inventaire d\'un dépôt : saisie du stock compté, écarts calculés sur le stock du dépôt, pagination et recherche sans perte de saisie.'),
    puce('Alertes : produits au niveau ou sous le seuil d\'alerte (stock total).'),
    h2('4.7 Rapports de ventes'),
    puce('Chiffre d\'affaires, nombre de tickets, panier moyen, taxes, ventes par mode de paiement, par catégorie, par vendeur.'),
    puce('Classement des produits les plus vendus ; aperçu imprimable (PDF) et export Excel.'),

    // 5
    h1('5. Exigences fonctionnelles — restaurant et bar'),
    encadre('Principe.', "Une caisse de type Restaurant ou Bar ouvre l'écran de vente sur le plan de salle. La commande de chaque table est gardée sur le serveur, partagée entre serveurs et appareils, jusqu'à son encaissement."),
    h2('5.1 Plan de salle'),
    puce('Éditeur réservé aux administrateurs : salles (salle principale, terrasse…), tables carrées ou rondes.'),
    puce('Placement par glisser-déposer, redimensionnement, nom et nombre de places de chaque table.'),
    puce('Une table ne peut pas être retirée tant qu\'une commande y est en cours.'),
    h2('5.2 Service en salle'),
    puce('Plan coloré : table libre, occupée (total, couverts, temps écoulé), addition demandée ; pastille si des articles restent à envoyer.'),
    puce('Ouverture d\'une table avec le nombre de couverts (modifiable ensuite).'),
    puce('Notes par article (« sans oignon », « bien cuit »), imprimées sur le bon.'),
    puce('Protection contre les modifications simultanées : version de la commande contrôlée, rechargement si un autre appareil l\'a modifiée.'),
    puce('Vente directe au comptoir (sans table) toujours possible.'),
    h2('5.3 Cuisine et bar'),
    puce('Bouton « Envoyer » : bon de préparation des nouveaux articles seulement, un bon par poste (cuisine, bar) selon la catégorie.'),
    puce('Article retiré après l\'envoi : ligne « ANNULÉ » envoyée au poste.'),
    puce('Impression automatique du bon (option de la caisse) et affichage sur l\'écran cuisine / bar.'),
    puce('Écran cuisine / bar : actualisation toutes les 5 secondes, signal sonore, filtre par poste, couleur selon l\'attente (10 et 20 minutes), bouton « Prêt », rappel des bons prêts.'),
    h2('5.4 Addition et encaissement'),
    puce('Addition (note provisoire) imprimée ; la table passe en « addition demandée ».'),
    puce('Partage de l\'addition : choix des articles payés maintenant, le reste demeure sur la table.'),
    puce('Transfert vers une table libre, ou regroupement avec la commande d\'une table occupée.'),
    puce('Pourboire (5, 10, 15 % ou montant libre) ajouté au paiement et indiqué sur le ticket.'),
    puce('Articles non envoyés : envoyés automatiquement en préparation avant l\'encaissement.'),

    // 6
    h1('6. Exigences fonctionnelles — paramétrage'),
    tableau(['Paramètre', 'Contenu', 'Règles'], [
        ['Utilisateurs', 'Nom, identifiant, mot de passe, profil, droit de validation, société', 'Mot de passe haché ; un administrateur ne voit que sa société'],
        ['Motifs', "Motifs d'encaissement et de décaissement", 'Motif « Vente POS » créé automatiquement'],
        ['Modes de paiement', 'Code, libellé, actif, paiement par compte client', 'Suppression refusée s\'il est utilisé (opérations ou ventes) ; « Espèces » reconnu pour la monnaie ; mode « Compte client » créé pour chaque société (migration 017 / ClientsEnCompte, création d\'une société), exclu des opérations de caisse'],
        ['Taxes', 'Code, libellé, taux, cochée par défaut', 'TVA 18 % et CSS 1 % créées pour chaque société ; modifier un taux met à jour les produits'],
        ['Unités de vente', 'Nom court, libellé, active', '14 unités de départ ; renommer met à jour les produits ; suppression refusée si utilisée'],
        ['Sociétés', 'Nom, code, logo, adresse, ville, pays, e-mail, téléphone, NIF, licence, module Point de vente', 'Réservé au super-administrateur ; module Point de vente activé ou non par société']
    ], [1900, 3900, 3838]),

    // 7
    h1('7. Règles de gestion'),
    tableau(['N°', 'Règle'], [
        ['RG01', 'Les prix de vente sont saisis TTC. Les taxes d\'un produit s\'additionnent sur le HT : HT = TTC / (1 + somme des taux).'],
        ['RG02', 'Les montants sont arrondis au franc CFA (sans décimale) ; les quantités acceptent deux décimales.'],
        ['RG03', 'La remise globale est répartie sur les lignes au prorata de leur montant ; la dernière ligne reçoit le reste d\'arrondi. Les taxes portent sur le net.'],
        ['RG04', 'Le stock ne change que par des mouvements historisés (stock initial, entrée, inventaire, vente, retour, annulation, transfert), chacun dans un dépôt ; le stock total d\'un produit est toujours la somme de ses dépôts.'],
        ['RG04b', 'Une vente sort du dépôt de la caisse ; un retour ou une annulation y remet les articles. Le contrôle « vente sans stock interdite » porte sur le stock de ce dépôt.'],
        ['RG05', 'Numéro de ticket : POS-<code caisse>-<AAAAMMJJ>-<rang dans la journée sur 4 chiffres>, consécutif même avec plusieurs postes.'],
        ['RG06', 'Une vente envoyée deux fois (coupure réseau) n\'est enregistrée qu\'une fois (clé unique du ticket).'],
        ['RG07', 'Seuls les espèces peuvent dépasser le reste à payer (monnaie rendue).'],
        ['RG08', 'Un retour rembourse le prix réellement payé (remises comprises) et remet les articles en stock ; pour un combo, ce sont ses composants.'],
        ['RG09', 'Une variante de produit est vendue, stockée et suivie comme un produit ; le modèle n\'est ni vendu ni stocké.'],
        ['RG10', 'Le prix d\'un combo est le prix du produit combo plus les suppléments des articles choisis ; chaque combo doit avoir exactement le nombre d\'articles prévu.'],
        ['RG11', 'La quantité envoyée en préparation est fixée par le serveur ; seul l\'écart avec la dernière version donne lieu à un bon.'],
        ['RG12', 'Une journée de caisse ne peut être clôturée tant qu\'une table a une commande ouverte ou qu\'une commande est en attente.'],
        ['RG13', 'Les données de chaque société sont cloisonnées ; le super-administrateur peut consulter une société ou toutes.']
    ], [900, 8738]),

    // 8
    h1('8. Exigences non fonctionnelles'),
    h2('8.1 Ergonomie'),
    puce('Interface en français (montants au format 50 000), menu latéral repliable (Activité, Analyse, Point de vente, Configuration, Administration).'),
    puce('Barre du haut fixe avec le fil d\'Ariane, la société consultée, l\'utilisateur connecté et la déconnexion.'),
    puce('En-têtes de tableaux bleus, affichage en liste ou en cartes pour les produits et les catégories.'),
    puce('Listes identiques dans les deux versions : recherche instantanée, tri par colonne, choix du nombre de lignes affichées (« Afficher … entrées ») et pagination.'),
    puce('Saisies courtes (nouvel élément, combo) dans des fenêtres modales, sans quitter la liste.'),
    puce('Écrans du point de vente et de la cuisine conçus pour tablettes et écrans tactiles.'),
    h2('8.2 Sécurité'),
    puce('Authentification obligatoire ; mots de passe hachés ; profils et droits vérifiés côté serveur.'),
    puce('Protection CSRF sur tous les formulaires et appels du point de vente.'),
    puce('Cloisonnement des données par société dans toutes les requêtes.'),
    puce('Prix et remises recontrôlés par le serveur à chaque vente (aucune confiance accordée au navigateur).'),
    h2('8.3 Fiabilité et intégrité'),
    puce('Opérations sensibles en transaction (vente, retour, clôture, envoi en cuisine).'),
    puce('Verrous de base de données : numérotation des tickets, contrôle du stock, commandes de table.'),
    puce('Tickets en cours gardés dans le navigateur pour résister à une coupure réseau.'),
    h2('8.4 Compatibilité'),
    puce('Navigateurs récents (Chrome, Edge, Firefox, Safari) sur ordinateur, tablette et mobile.'),
    puce('Imprimante thermique 80 mm (tickets, bons, additions) ; douchette code-barres en émulation clavier.'),
    h2('8.5 Maintenabilité'),
    puce('Mises à jour de la base automatiques au démarrage (migrations), sans intervention manuelle.'),
    puce('Code commenté en français, scripts communs aux deux versions, tests automatisés par module.'),

    // 9
    h1('9. Architecture technique et données'),
    h2('9.1 Architecture'),
    tableau(['Élément', 'Version .NET', 'Version PHP'], [
        ['Langage / cadre', 'C#, ASP.NET Core MVC (.NET 10)', 'PHP 8, contrôleur frontal index.php?r=module/action'],
        ['Base de données', 'SQL Server, Entity Framework Core', 'MySQL 8 / MariaDB, PDO'],
        ['Migrations', 'Migrations EF Core appliquées au démarrage', 'Fichiers sql/migrations/*.sql appliqués une fois (table MigrationsAppliquees)'],
        ['PDF / Excel', 'Rotativa (wkhtmltopdf), ClosedXML', 'Pages imprimables, génération XLSX intégrée'],
        ['Interface', 'Bootstrap 5, Font Awesome, Chart.js, DataTables', 'Bootstrap 5, Font Awesome, Chart.js, DataTables'],
        ['Hébergement', 'Windows / IIS ou serveur Linux', 'Hébergement mutualisé (Hostinger)']
    ], [2100, 3769, 3769]),
    espace(),
    h2('9.2 Principales tables'),
    tableau(['Domaine', 'Tables'], [
        ['Sociétés et accès', 'Tenants, TenantLogos, Utilisateurs'],
        ['Caisse', 'Caisses, JourneesCaisses, OperationsCaisses, ComptagesCloture, Motifs, ModesPaiement (mode compte client), Clients (genre, client en compte, plafond de crédit)'],
        ['Facturation', 'Factures, LignesFactures'],
        ['Catalogue', 'Categories, Produits, ProduitImages, Taxes, ProduitTaxes, Unites, ProduitAttributs, ProduitAttributValeurs, VarianteValeurs'],
        ['Combos', 'Combos, ComboChoix, ProduitCombos'],
        ['Ventes', 'CommandesPos, LignesCommandePos, LignesCommandePosTaxes, PaiementsPos, CommandesAttente, Livreurs'],
        ['Stock', 'Depots, StocksDepots, MouvementsStock'],
        ['Restaurant', 'Salles, TablesRestaurant, CommandesOuvertes, BonsPreparation, LignesBonPreparation']
    ], [2400, 7238]),

    // 10
    h1('10. Déploiement, livrables et maintenance'),
    h2('10.1 Livrables'),
    puce('Code source des deux versions (dépôt Git), scripts de base de données et migrations.'),
    puce('Scripts de démonstration (catalogue, ventes, mouvements de stock) — à ne pas déployer en production. Le script demo_laverie crée une seconde société « Laverie Éclat Blanc » : caisse LAV1 de type Laverie, 6 catégories, 24 articles illustrés (prestations et produits en stock), 4 tiers et 20 ventes à ces tiers sur 5 journées clôturées ; il est intégré à la base de démonstration complète.'),
    puce('Bases de démonstration complètes, prêtes à importer dans une base vide, avec les mêmes données dans les deux versions : gescaisse_demo_complet_mysql.sql (PHP / MySQL) et gescaisse_demo_complet_sqlserver.sql (.NET / SQL Server, généré par Scripts/generer_demo_complet_sqlserver.py).'),
    puce('Le présent cahier des charges.'),
    h2('10.2 Procédure de mise à jour (version PHP sur Hostinger)'),
    puce('Sauvegarder la base MySQL (export phpMyAdmin).'),
    puce('Envoyer les fichiers modifiés en conservant le fichier config.php du serveur.'),
    puce('Ne pas envoyer le dossier sql/demo.'),
    puce('Ouvrir l\'application : les migrations en attente s\'appliquent automatiquement au premier chargement.'),
    h2('10.3 Maintenance'),
    puce('Corrections et évolutions développées sur une branche, testées sur les deux versions, puis fusionnées.'),
    puce('Tests automatisés de non-régression par module (point de vente, variantes, unités, restaurant, combos).'),

    // 11
    h1('11. Glossaire'),
    tableau(['Terme', 'Définition'], [
        ['Journée de caisse', 'Période de tenue d\'une caisse, de l\'ouverture (fond initial) à la clôture (comptage).'],
        ['Point de vente (POS)', 'Écran de vente au comptoir ou en salle, avec ticket et encaissement immédiat.'],
        ['Ticket', 'Vente en cours ou enregistrée au point de vente ; imprimé au format 80 mm.'],
        ['Variante', 'Déclinaison d\'un produit modèle selon des attributs (taille, couleur).'],
        ['Combo', 'Groupe de produits proposés au choix (ex. « Plats ») ; un produit combo (menu) en réunit plusieurs.'],
        ['Couverts', 'Nombre de personnes servies à une table.'],
        ['Bon de préparation', 'Liste des articles à préparer envoyée en cuisine ou au bar.'],
        ['Addition', 'Note provisoire remise au client avant le paiement.'],
        ['Société consultée', 'Société dont le super-administrateur affiche les données.'],
        ['NIF', "Numéro d'identification fiscale de la société."]
    ], [2600, 7038])
];

const doc = new Document({
    creator: 'M-ITECH AFRICA',
    title: 'Cahier des charges GesCaisse',
    description: 'Cahier des charges de l\'application GesCaisse',
    styles: {
        default: { document: { run: { font: POLICE, size: 21 } } },
        paragraphStyles: [
            { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
                run: { size: 34, bold: true, font: POLICE, color: BLEU },
                paragraph: { spacing: { before: 120, after: 240 }, outlineLevel: 0,
                    border: { bottom: { style: BorderStyle.SINGLE, size: 8, color: BLEU, space: 4 } } } },
            { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true,
                run: { size: 26, bold: true, font: POLICE, color: BLEU },
                paragraph: { spacing: { before: 260, after: 120 }, outlineLevel: 1 } },
            { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true,
                run: { size: 22, bold: true, font: POLICE, color: '333333' },
                paragraph: { spacing: { before: 180, after: 80 }, outlineLevel: 2 } }
        ]
    },
    numbering: {
        config: [{
            reference: 'puces',
            levels: [
                { level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT,
                    style: { paragraph: { indent: { left: 540, hanging: 270 } }, run: { color: BLEU } } },
                { level: 1, format: LevelFormat.BULLET, text: '–', alignment: AlignmentType.LEFT,
                    style: { paragraph: { indent: { left: 1080, hanging: 270 } } } }
            ]
        }]
    },
    sections: [
        sectionGarde('garde_cahier.jpg', 'Cahier des charges GesCaisse'),
        {
            properties: { page: { margin: { top: 1134, right: 1134, bottom: 1134, left: 1134 }, pageNumbers: { start: 2 } } },
            headers: { default: new Header({ children: [new Paragraph({
                border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: 'C9D5DE', space: 4 } },
                tabStops: [{ type: TabStopType.RIGHT, position: LARGEUR }],
                children: [t('GesCaisse — Cahier des charges', { size: 17, color: GRIS }), t('\tM-ITECH AFRICA', { size: 17, color: GRIS })]
            })] }) },
            footers: { default: new Footer({ children: [new Paragraph({
                alignment: AlignmentType.CENTER,
                children: [t('Page ', { size: 17, color: GRIS }), new TextRun({ children: [PageNumber.CURRENT], font: POLICE, size: 17, color: GRIS }),
                    t(' / ', { size: 17, color: GRIS }), new TextRun({ children: [PageNumber.TOTAL_PAGES], font: POLICE, size: 17, color: GRIS })]
            })] }) },
            children: [...sommaire, ...fiche, ...contenu]
        }
    ]
});

Packer.toBuffer(doc).then(b => {
    fs.writeFileSync(process.argv[2] || 'Cahier_des_charges_GesCaisse.docx', b);
    console.log('ok');
});
