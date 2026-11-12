// Manuel utilisateur GesCaisse (Word) — généré avec docx-js (npm install docx).
// Usage : node docs/generer_manuel_utilisateur.js docs/Manuel_utilisateur_GesCaisse.docx
// Captures d'écran : docs/manuel_images/*.jpg (1366 × 820, données de démonstration).
// Le module Facturation n'est pas décrit dans ce manuel.
const fs = require('fs');
const path = require('path');
const {
    Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, AlignmentType, HeadingLevel, ImageRun,
    BorderStyle, WidthType, ShadingType, LevelFormat, Header, Footer, PageNumber, TabStopType
} = require('docx');
const sectionGarde = require('./page_de_garde');

const BLEU = '195D84', BLEU_CLAIR = 'E6F0F7', GRIS = '5A6B78', ORANGE = 'B45309', ORANGE_CLAIR = 'FDF2E3';
const LARGEUR = 9638;   // A4 (11906) moins 2 × 1134 de marge
const POLICE = 'Arial';
const IMAGES = path.join(__dirname, 'manuel_images');

const t = (texte, o = {}) => new TextRun({ text: texte, font: POLICE, ...o });
// Texte avec **gras** : « Cliquez sur **Enregistrer** ».
const riche = (texte, o = {}) => texte.split(/(\*\*[^*]+\*\*)/).filter(Boolean)
    .map(m => m.startsWith('**') ? t(m.slice(2, -2), { ...o, bold: true }) : t(m, o));
const p = (texte, o = {}) => new Paragraph({ spacing: { after: 120, line: 300 }, ...o, children: Array.isArray(texte) ? texte : riche(texte) });
const h1 = texte => new Paragraph({ heading: HeadingLevel.HEADING_1, pageBreakBefore: true, children: [t(texte)] });
const h2 = texte => new Paragraph({ heading: HeadingLevel.HEADING_2, children: [t(texte)] });
const h3 = texte => new Paragraph({ heading: HeadingLevel.HEADING_3, children: [t(texte)] });
const puce = (texte, niveau = 0) => new Paragraph({
    numbering: { reference: 'puces', level: niveau }, spacing: { after: 60, line: 280 },
    children: Array.isArray(texte) ? texte : riche(texte)
});
// « Libellé : texte » avec le libellé en gras.
const pt = (libelle, texte, niveau = 0) => puce([t(libelle + ' : ', { bold: true }), ...riche(texte)], niveau);
// Étapes numérotées : une nouvelle liste repart à 1.
let numListe = 0;
const etapes = liste => {
    const instance = ++numListe;
    return liste.map(e => new Paragraph({
        numbering: { reference: 'etapes', level: 0, instance }, spacing: { after: 70, line: 280 }, children: riche(e)
    }));
};

const bord = { style: BorderStyle.SINGLE, size: 4, color: 'C9D5DE' };
const bords = { top: bord, bottom: bord, left: bord, right: bord };
function tableau(entetes, lignes, largeurs) {
    const total = largeurs.reduce((a, b) => a + b, 0);
    const cell = (texte, l, entete, pair) => new TableCell({
        borders: bords, width: { size: l, type: WidthType.DXA },
        shading: { fill: entete ? BLEU : (pair ? 'F5F8FA' : 'FFFFFF'), type: ShadingType.CLEAR, color: 'auto' },
        margins: { top: 70, bottom: 70, left: 110, right: 110 },
        children: [new Paragraph({ spacing: { after: 0, line: 260 },
            children: entete ? [t(texte, { bold: true, color: 'FFFFFF', size: 19 })] : riche(texte, { size: 19 }) })]
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

// Encadrés : astuce (bleu) et attention (orange).
const encadre = (titre, texte, couleur = BLEU, fond = BLEU_CLAIR) => new Paragraph({
    spacing: { before: 120, after: 160, line: 290 },
    shading: { fill: fond, type: ShadingType.CLEAR, color: 'auto' },
    border: { left: { style: BorderStyle.SINGLE, size: 24, color: couleur, space: 8 } },
    indent: { left: 200, right: 200 },
    children: [t(titre + ' ', { bold: true, color: couleur }), ...riche(texte)]
});
const astuce = texte => encadre('Astuce.', texte);
const attention = texte => encadre('Attention.', texte, ORANGE, ORANGE_CLAIR);

// Figure : capture d'écran centrée, bordée, avec sa légende numérotée.
let numFigure = 0;
const figure = (fichier, legende) => {
    const n = ++numFigure;
    return [
        new Paragraph({
            alignment: AlignmentType.CENTER, spacing: { before: 120, after: 60 }, keepNext: true,
            children: [new ImageRun({
                type: 'jpg', data: fs.readFileSync(path.join(IMAGES, fichier + '.jpg')),
                transformation: { width: 600, height: 360 },
                altText: { title: legende, description: legende, name: fichier }
            })]
        }),
        new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 200 },
            children: [t('Figure ' + n + ' — ', { bold: true, size: 18, color: GRIS }), t(legende, { italics: true, size: 18, color: GRIS })] })
    ];
};

// ---------------------------------------------------------------------------
// Page de garde : image pleine page (pages_de_garde/), voir page_de_garde.js
// ---------------------------------------------------------------------------
// Fiche du document (la page de garde est une image : voir generer_pages_de_garde.js)
const fiche = [
    new Paragraph({ spacing: { before: 480, after: 160 }, children: [t('Informations du document', { bold: true, color: BLEU, size: 24 })] }),
    tableau(['Rubrique', 'Information'], [
        ['Application', 'GesCaisse — gestion de caisse et point de vente (POS)'],
        ['Éditeur', 'M-ITECH AFRICA'],
        ['Public', 'Administrateurs, caissiers, vendeurs et serveurs des sociétés clientes'],
        ['Version du document', '3.3'],
        ['Date', 'Novembre 2026']
    ], [3000, 6638])
];

// ---------------------------------------------------------------------------
// Sommaire (statique : lisible à l'identique dans Word et dans le PDF)
// ---------------------------------------------------------------------------
const chapitres = [
    ['1', 'Présentation de GesCaisse'],
    ['2', 'Prise en main'],
    ['3', 'Caisses et journées de caisse'],
    ['4', 'Tiers'],
    ['5', 'Rapports et export comptable'],
    ['6', 'Point de vente : vendre au comptoir'],
    ['7', 'Ventes, retours et annulations'],
    ['8', 'Stock'],
    ['9', 'Rapports de ventes'],
    ['10', 'Restaurant et bar'],
    ['11', 'Catalogue : catégories, produits et combos'],
    ['12', 'Paramètres'],
    ['13', 'Questions fréquentes'],
    ['14', 'Glossaire']
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
    // 1 ------------------------------------------------------------------
    h1('1. Présentation de GesCaisse'),
    h2('1.1 À quoi sert GesCaisse'),
    p('GesCaisse est une application web qui permet de tenir les caisses d’une société et de vendre au comptoir. Elle s’utilise depuis un navigateur (ordinateur, tablette ou écran tactile), sans installation sur le poste. Les montants sont exprimés en francs CFA.'),
    p('Elle regroupe :'),
    pt('La gestion de caisse', 'journées de caisse, encaissements et décaissements, validation, clôture avec comptage, rapports et export vers Sage.'),
    pt('Le point de vente', 'écran de vente tactile, tickets de caisse, retours, gestion du stock et rapports de ventes.'),
    pt('La restauration', 'plan de salle, commandes par table, bons de préparation pour la cuisine et le bar, addition et partage.'),
    astuce('Le point de vente (et donc le stock, le catalogue et la restauration) est un module activé par votre fournisseur. S’il n’apparaît pas dans votre menu, votre société n’utilise que la gestion de caisse : les chapitres 3 à 5, 12 et 13 vous concernent.'),
    h2('1.2 Profils d’utilisateurs'),
    p('Chaque utilisateur reçoit un profil qui détermine les menus auxquels il a accès :'),
    tableau(['Profil', 'Pour qui', 'Ce qu’il peut faire'], [
        ['Admin', 'Responsable de la société', 'Tout ce qui concerne sa société : caisses, catalogue, stock, plan de salle, paramètres, utilisateurs, retours et annulations, modification des prix à la caisse'],
        ['Caissier', 'Tenue de caisse', 'Journées de caisse, opérations, point de vente, consultation des ventes'],
        ['Vendeur', 'Vente au comptoir ou service en salle', 'Point de vente, écran cuisine / bar, consultation des ventes'],
        ['Super-administrateur', 'Fournisseur de la solution', 'Création des sociétés, licences et modules ; peut consulter toutes les sociétés']
    ], [2000, 2600, 5038]),
    espace(),
    p('Le droit complémentaire **Peut valider / rejeter les opérations de caisse** peut être accordé à un caissier ou à un vendeur. Il autorise la validation des opérations de caisse, la remise globale sur un ticket, les retours et les annulations de ventes.'),
    h2('1.3 Conventions de ce manuel'),
    puce('Les noms de menus, de boutons et de champs sont écrits en **gras**, par exemple **Caisses** › **Journées**.'),
    puce('Le signe « › » indique un chemin dans les menus : **Configuration** › **Produits**.'),
    puce('Les encadrés bleus donnent des astuces ; les encadrés orange signalent un point d’attention.'),

    // 2 ------------------------------------------------------------------
    h1('2. Prise en main'),
    h2('2.1 Se connecter'),
    ...etapes([
        'Ouvrez l’adresse de GesCaisse communiquée par votre administrateur dans votre navigateur.',
        'Saisissez votre **Nom d’utilisateur** et votre **Mot de passe**.',
        'Cliquez sur **Se connecter** (ou appuyez sur Entrée).'
    ]),
    ...figure('01_connexion', 'Page de connexion'),
    attention('Si la licence de votre société a expiré, une page « compte suspendu » s’affiche après la connexion. Contactez votre fournisseur pour la renouveler.'),
    h2('2.2 L’écran principal'),
    p('Après la connexion, l’application s’ouvre sur le tableau de bord. L’écran comporte :'),
    pt('Le menu latéral (à gauche)', 'les rubriques Activité, Analyse, Point de vente, Configuration et Administration. Le bouton **Réduire le menu**, en bas, ne garde que les icônes pour libérer de la place ; il se souvient de votre choix.'),
    pt('La barre du haut', 'le chemin de la page (ex. « Activité › Tableau de bord »), son titre, les notifications, l’utilisateur connecté et le bouton de déconnexion.'),
    pt('Le bloc Société', 'le nom de votre société. Le super-administrateur y choisit la « société consultée ».'),
    h3('Les listes'),
    p('Toutes les listes (caisses, tiers, ventes, produits, utilisateurs…) fonctionnent de la même façon :'),
    pt('Rechercher', 'tapez quelques lettres dans la zone de recherche, en haut à droite : la liste se filtre aussitôt.'),
    pt('Trier', 'cliquez sur le titre d’une colonne ; un second clic inverse l’ordre.'),
    pt('Afficher … entrées', 'choisissez, en haut à gauche, le nombre de lignes par page ; les boutons **Précédent** et **Suivant**, en bas, changent de page.'),
    h3('Les impressions'),
    p('Les documents imprimés (liste des caisses, journées, journal des opérations, rapport des opérations) portent en en-tête le logo et les coordonnées de votre société, ainsi que la date, l’heure et le nom de la personne qui les a édités. La liste des caisses, les journées et le journal des opérations portent aussi la mention « République gabonaise — Union - Travail - Justice ». Les montants sont en francs CFA, au format 50 000.'),
    astuce('Selon la version installée, l’impression s’ouvre en PDF ou dans une page à imprimer. Dans ce cas, cliquez sur **Imprimer / enregistrer en PDF**, puis choisissez une imprimante ou « Enregistrer au format PDF ».'),
    h2('2.3 Le tableau de bord'),
    p('Le tableau de bord résume l’activité des caisses sur la période choisie.'),
    ...figure('02_tableau_de_bord', 'Tableau de bord'),
    pt('Filtres', 'période (**Aujourd’hui**, **7 jours**, **Ce mois**, **Personnalisé**), caisse et statut de journée, puis **Filtrer**.'),
    pt('Solde en caisse', 'fond initial des journées, plus les entrées, moins les sorties.'),
    pt('Entrées, Sorties, Résultat net', 'totaux de la période et nombre d’opérations.'),
    pt('À traiter', 'opérations en attente de validation, décaissements sans justificatif, journées ouvertes depuis plus de 24 heures. Cliquez sur une alerte pour ouvrir la liste correspondante.'),
    pt('Flux des 7 derniers jours et État des caisses', 'graphique des entrées et sorties, et situation de chaque caisse (ouverte ou clôturée, solde).'),
    p('Le bouton **Nouvelle opération** permet de saisir directement un encaissement ou un décaissement dans une journée ouverte.'),
    h2('2.4 Les notifications (cloche)'),
    p('La **cloche**, en haut à droite de chaque page, rassemble ce qui attend une action. Quand il y a quelque chose à traiter, elle s’allume et une pastille rouge indique le nombre total d’éléments ; cliquez dessus pour ouvrir la liste, puis sur une ligne pour aller directement à la bonne page.'),
    ...figure('02b_cloche', 'Notifications de la cloche'),
    pt('Pour tous les utilisateurs', 'opérations en attente de validation, décaissements sans justificatif et journées ouvertes depuis plus de 24 h, toutes caisses confondues (la ligne ouvre la plus ancienne journée concernée).'),
    pt('Livraisons à livrer', 'ventes payées confiées à un livreur dont la livraison n’est pas encore marquée **Livrée** (6.6), avec leur montant, frais de livraison compris. La ligne ouvre l’écran de vente de la journée de la plus ancienne, où **Commandes en attente** permet de la marquer livrée (ou la fiche de la vente si sa journée est clôturée) ; pour un administrateur, le rapport des livraisons filtré « À livrer » (9.1). Les ventes annulées ne sont pas comptées.'),
    pt('Livraisons à encaisser', 'commandes confiées à un livreur et pas encore encaissées (6.6), avec le montant attendu, frais de livraison compris. La ligne ouvre l’écran de vente de la journée de la plus ancienne commande, où vous l’encaissez au retour du livreur depuis **Commandes en attente** ; pour un administrateur, elle ouvre le rapport des livraisons filtré « À encaisser » (9.1).'),
    pt('Pour les administrateurs', 'produits en vente au niveau ou sous leur seuil d’alerte (page Stock) et, en laverie, produits d’entretien à racheter (dépôt des achats, 8.7) et dépôts de linge en retard (rapport des dépôts filtré « En retard », 9.2).'),
    p('Quand tout est traité, la cloche s’éteint et indique « Rien à traiter pour le moment ».'),
    h2('2.5 Installer l’application et travailler sans connexion'),
    p('GesCaisse peut s’installer comme une application sur le poste de caisse, la tablette ou le téléphone : cliquez sur l’icône **Installer l’application** (flèche vers le bas) dans la barre du haut quand elle apparaît, ou utilisez le menu du navigateur (« Installer GesCaisse » / « Ajouter à l’écran d’accueil »). L’application s’ouvre alors dans sa propre fenêtre, avec son icône.'),
    pt('Indicateur de connexion', 'en haut de chaque page et de l’écran de vente : **En ligne** (point vert) ou **Hors ligne** (badge orange). La connexion au serveur est vérifiée toutes les 30 secondes : un wifi branché mais sans internet est détecté.'),
    pt('Écran de vente sans connexion', 'chaque écran de vente ouvert avec la connexion est enregistré sur le poste, avec ses articles, ses images et ses icônes. Si la connexion tombe, l’écran reste utilisable et se rouvre même après un rechargement : le ticket en cours est conservé.'),
    pt('Autres pages', 'hors connexion, elles affichent une page « Pas de connexion au serveur » qui propose de revenir aux écrans de vente enregistrés sur le poste, et un bouton **Réessayer**.'),
    pt('Confidentialité', 'les écrans de vente enregistrés sont effacés du poste à la déconnexion.'),
    attention('Ouvrez la journée et l’écran de vente au moins une fois avec la connexion avant une coupure. Dans cette version, la validation d’une vente demande encore la connexion : l’enregistrement des ventes hors ligne et leur envoi automatique au retour de la connexion arrivent dans la prochaine mise à jour.'),
    h2('2.6 Se déconnecter'),
    p('Cliquez sur l’icône de sortie, à droite de votre nom dans la barre du haut. Pensez à vous déconnecter sur un poste partagé.'),

    // 3 ------------------------------------------------------------------
    h1('3. Caisses et journées de caisse'),
    p('Une **caisse** représente un tiroir-caisse ou un point d’encaissement. Une **journée de caisse** couvre une période de travail sur cette caisse : on l’ouvre avec un fond initial, on y enregistre les opérations, puis on la clôture en comptant l’argent.'),
    h2('3.1 Les caisses'),
    p('Menu **Caisses**. La liste affiche chaque caisse avec son code (et son StCode en dessous), sa description, son type, son caissier par défaut, son compte comptable et ses dépôts (dépôt de la caisse, « par défaut » s’il n’a pas été choisi, puis les dépôts secondaires).'),
    ...figure('10_caisses', 'Liste des caisses'),
    p('Pour créer une caisse (administrateur), cliquez sur **Nouvelle caisse** et renseignez :'),
    pt('Code et description', 'par exemple « CASH1 · Caisse principale ».'),
    pt('Caissier par défaut', 'utilisateur habituellement affecté à la caisse.'),
    pt('Compte comptable', 'compte de trésorerie utilisé comme contrepartie dans l’export Sage (ex. 571100).'),
    pt('Type de point de vente', '**Vente en détail** (comptoir classique), **Restaurant** ou **Bar** (plan de salle et commandes par table, voir chapitre 10), ou **Laverie** (vente au comptoir de prestations de lavage et de pressing, voir 6.10).'),
    pt('Imprimer les bons de préparation', 'impression automatique des bons envoyés en cuisine et au bar. Cette case n’apparaît que pour une caisse **Restaurant** ou **Bar**.'),
    pt('Dépôt de la caisse', 'dépôt principal de la caisse : ses ventes en sortent d’abord et ses retours y reviennent (voir 8 et 12.7). Si vous laissez « **Dépôt par défaut de la société** », la caisse utilise le dépôt par défaut choisi dans Paramètres › Dépôts, et le suit s’il change.'),
    pt('Dépôts secondaires', 'cochez les autres dépôts où la caisse peut compléter une vente quand le stock du dépôt principal ne suffit pas, et indiquez leur **ordre** d’utilisation (1 d’abord, puis 2…). Un même dépôt peut servir de complément à plusieurs caisses. Le dépôt de la caisse ne peut pas être coché comme secondaire.'),
    ...figure('10b_caisse_depots', 'Dépôt principal et dépôts secondaires d’une caisse'),
    p('Les boutons de chaque ligne permettent d’ouvrir les **Journées** de la caisse, de la **Modifier** ou de la **Supprimer** ; pour un restaurant ou un bar, l’icône en forme de chaise ouvre son **Plan de salle**. Une caisse qui a déjà des journées ne peut pas être supprimée. Le bouton **Imprimer**, en haut de la liste, édite la liste des caisses (code, description, StCode, caissier par défaut, compte comptable).'),
    h2('3.2 Ouvrir une journée'),
    ...etapes([
        'Dans **Caisses**, cliquez sur **Journées** sur la ligne de la caisse.',
        'Cliquez sur **Ouvrir une journée**.',
        'Vérifiez la **Date de la journée** et le **Solde initial** (fond de caisse). Le solde proposé est le montant compté à la dernière clôture.',
        'Cliquez sur **Ouvrir la journée**.'
    ]),
    ...figure('11_journees_caisse', 'Journées d’une caisse'),
    p('Dans la page des journées d’une caisse, le bouton **Imprimer les journées** édite la liste des journées avec, pour chacune, le solde initial, les encaissements, les décaissements, le solde et le statut, ainsi qu’une ligne de total. Les opérations rejetées ne sont pas comptées.'),
    ...figure('12_ouverture_journee', 'Ouverture d’une journée'),
    h2('3.3 Enregistrer un encaissement ou un décaissement'),
    p('Dans la page de la journée, cliquez sur **+ Encaissement** (entrée d’argent) ou sur **− Décaissement** (sortie d’argent). Renseignez :'),
    pt('Tiers', 'client ou fournisseur concerné (facultatif).'),
    pt('Montant', 'en francs CFA.'),
    pt('Motif', 'nature de l’opération (ex. « Règlement client », « Achat fournitures »), voir **Paramètres** › **Motifs**.'),
    pt('Description', 'libellé libre, repris dans les rapports.'),
    pt('Mode de paiement', 'espèces, mobile money, chèque…'),
    pt('Validation', 'case **justifié** si une pièce justificative existe ; statut de validation si vous en avez le droit.'),
    ...figure('13_encaissement', 'Saisie d’un encaissement'),
    p('Cliquez sur **Enregistrer**. L’opération apparaît dans l’historique de la journée avec le statut **En attente**, sauf si vous l’avez directement validée.'),
    astuce('Les ventes du point de vente arrivent automatiquement dans la journée, déjà validées, avec le motif « Vente POS ».'),
    h2('3.4 Valider ou rejeter les opérations'),
    p('Les utilisateurs habilités voient un bouton de validation sur chaque opération en attente. Ils choisissent **Validé** ou **Rejeté**, indiquent si le mouvement est justifié et peuvent ajouter une observation. Une opération rejetée n’est pas comptée dans le solde.'),
    ...figure('14_journee_details', 'Page d’une journée : soldes, totaux par mode de paiement et historique'),
    p('La page de la journée affiche le solde initial, les encaissements, les décaissements, le solde théorique, les totaux par mode de paiement et l’historique des opérations. Le bouton **Imprimer les opérations** produit le journal de la journée : soldes, totaux par mode de paiement et détail des opérations (une opération rejetée y apparaît barrée et n’est pas comptée).'),
    h2('3.5 Clôturer une journée'),
    ...etapes([
        'Dans la page de la journée, cliquez sur **Clôturer**.',
        'Pour chaque mode de paiement, saisissez le **montant compté** réellement présent.',
        'GesCaisse calcule l’**écart** avec le montant théorique. Ajoutez au besoin une **note de clôture** pour l’expliquer.',
        'Cliquez sur **Clôturer la journée** et confirmez.'
    ]),
    attention('La clôture est définitive : plus aucune opération ne peut être ajoutée à la journée. Elle est refusée tant qu’une commande est en attente au point de vente ou, dans un restaurant, tant qu’une table a une commande en cours.'),
    h2('3.6 Règlement d’un client en compte'),
    p('Quand un client en compte (4.2) vient régler ce qu’il doit, enregistrez son règlement dans la journée ouverte :'),
    ...etapes([
        'Dans la page de la journée, cliquez sur **Règlement client**.',
        'Choisissez le client : la liste indique son solde dû, proposé comme montant.',
        'Saisissez le montant réglé, le mode de paiement (espèces par défaut) et au besoin une observation (n° de chèque, reçu…).',
        'Cliquez sur **Enregistrer le règlement**.'
    ]),
    ...figure('14b_reglement_client', 'Règlement d’un client en compte'),
    p('Le règlement est un encaissement de la journée (motif « Règlement client ») : il entre dans la caisse et diminue le solde dû du client. Il ne peut pas dépasser ce solde. S’il est rejeté à la validation (3.4), le solde dû est rétabli.'),

    // 4 ------------------------------------------------------------------
    h1('4. Tiers'),
    p('Menu **Tiers**. Les tiers sont vos clients, fournisseurs, salariés ou autres partenaires. Ils peuvent être associés aux opérations de caisse et aux ventes.'),
    ...figure('15_tiers', 'Liste des tiers'),
    h2('4.1 Créer ou modifier un tiers'),
    p('Cliquez sur **Nouveau tiers** (ou **Modifier** sur une ligne) : la fiche s’ouvre dans une fenêtre.'),
    pt('Genre', '**Entreprise** (société, association, administration…) ou **Particulier** (personne physique). Le genre s’affiche dans la liste et sert de filtre dans le rapport des tiers (5.3).'),
    pt('Code, nom et type', 'le nom est la raison sociale d’une entreprise ou le nom et le prénom d’un particulier ; le type vaut Client, Fournisseur, Salarié ou Autre.'),
    pt('Coordonnées et contact', 'adresse, téléphone, e-mail, puis le contact (nom, fonction, téléphone, e-mail) pour une entreprise.'),
    pt('Compte général (Sage)', 'compte comptable du tiers (ex. 411000 pour un client).'),
    ...figure('15b_tiers_genre', 'Fiche d’un tiers : genre Entreprise ou Particulier'),
    h2('4.2 Clients en compte'),
    p('Un client en compte peut payer « par compte » au point de vente : la vente est faite à crédit et le client la règle plus tard. Sur la fiche du tiers, section **Compte client** :'),
    pt('Client en compte', 'cochez la case pour autoriser le paiement par compte.'),
    pt('Plafond de crédit', 'montant dû à ne pas dépasser (laissez vide pour ne fixer aucun plafond). Au-delà, la vente par compte est refusée, sauf pour un administrateur.'),
    ...figure('15c_tiers_compte', 'Fiche d’un tiers : client en compte et plafond de crédit'),
    p('La colonne **Solde dû** de la liste des tiers indique, pour chaque client en compte, ce qu’il doit encore et son plafond.'),
    ...figure('15_tiers', 'Liste des tiers avec le solde dû des clients en compte'),
    p('Le solde dû est la somme des ventes payées par compte, moins les règlements du client (3.6) et les retours crédités sur son compte (7.3). Une vente annulée ne compte plus.'),
    h2('4.3 Rechercher'),
    p('La zone de recherche filtre la liste par code, nom, contact ou téléphone. La liste est paginée.'),
    h2('4.4 Importer et exporter'),
    pt('Exporter Excel', 'télécharge la liste complète des tiers.'),
    pt('Importer Excel', 'ajoute ou met à jour des tiers depuis un fichier. La première ligne est un en-tête ; les colonnes sont dans l’ordre : Code, Société, Contact, Téléphone, EmailContact, Adresse, Email, Type, FonctionContact, TelephoneContact, CompteGeneral, Genre (Entreprise ou Particulier ; vide = Entreprise), EnCompte (Oui ou Non), PlafondCredit (vide = sans plafond).'),
    astuce('Le plus simple pour préparer un import est de partir d’un export : vous obtenez directement les bonnes colonnes.'),

    // 5 ------------------------------------------------------------------
    h1('5. Rapports et export comptable'),
    h2('5.1 Rapport des opérations'),
    p('Menu **Rapports**. Choisissez la période, la caisse, le type d’opération (encaissement ou décaissement) et le statut, puis cliquez sur **Filtrer**.'),
    ...figure('16_rapport_operations', 'Rapport des opérations'),
    p('Sous la liste, le rapport donne :'),
    pt('Total encaissements et Total décaissements', 'opérations de la période ; les opérations rejetées sont listées mais pas comptées.'),
    pt('Solde de la période', 'encaissements moins décaissements.'),
    pt('Montant initial des journées', 'fond de caisse de départ : le solde initial de la première journée de chaque caisse sur la période. Les journées suivantes repartent du solde de la veille, elles ne sont donc pas ajoutées une seconde fois.'),
    pt('Solde en caisse', 'montant initial plus solde de la période.'),
    p('Le bouton **Imprimer / PDF** ouvre un aperçu imprimable du rapport, avec les mêmes colonnes et les mêmes totaux.'),
    h2('5.2 Export vers Sage'),
    p('Le bouton **Export Sage** produit le fichier d’écritures à importer dans votre logiciel comptable, au format Excel (.xlsx), CSV (.csv) ou texte (.txt). Chaque ligne comporte le code caisse, la date, le compte général, le compte tiers, le libellé, le débit, le crédit et le numéro de pièce.'),
    attention('L’export signale les anomalies, par exemple une caisse sans compte comptable ou un tiers sans compte général. Complétez ces informations avant d’importer le fichier dans Sage.'),
    h2('5.3 Rapport des tiers'),
    p('Menu **Rapport des tiers** (rubrique Analyse). Le rapport résume l’activité de chaque tiers sur une période : choisissez les dates, le type (Client, Fournisseur…) et le genre (Entreprise ou Particulier), puis cliquez sur **Filtrer**. Cochez **Inclure les tiers sans mouvement** pour voir aussi les tiers inactifs sur la période.'),
    ...figure('16b_rapport_tiers', 'Rapport des tiers'),
    p('Les cartes du haut donnent le nombre de tiers et les totaux de la période. Pour chaque tiers, le tableau indique :'),
    pt('Ventes et Ventes nettes', 'nombre de tickets du point de vente au nom du tiers et leur montant, retours déduits ; les ventes annulées ne sont pas comptées.'),
    pt('Encaissements et Décaissements', 'opérations de caisse au nom du tiers ; les opérations rejetées ne sont pas comptées. Une vente payée apparaît aussi dans les encaissements (« Vente POS »).'),
    pt('Solde', 'encaissements moins décaissements : positif quand le tiers a versé de l’argent, négatif quand la société lui en a versé (un fournisseur réglé, par exemple).'),
    pt('Dû (compte)', 'pour un client en compte, ce qu’il doit à la fin de la période. Une vente par compte n’entre dans les encaissements qu’au moment de son règlement.'),
    pt('Dernier mouvement', 'date de la dernière vente ou opération (l’heure s’affiche au survol).'),
    p('Les boutons **Imprimer / PDF** et **Exporter Excel** reprennent le tableau et ses totaux. Le bouton de fin de ligne ouvre le **relevé du tiers** : le détail de ses opérations de caisse (journée, mode de paiement, statut) et de ses ventes sur la période, prêt à imprimer ou à enregistrer en PDF, par exemple pour le remettre au client.'),
    ...figure('16c_releve_tiers', 'Relevé d’un tiers'),
    astuce('Dans le relevé, les opérations rejetées et les ventes annulées restent visibles mais barrées, et ne comptent pas dans les totaux.'),
    p('Pour un client en compte, le relevé ajoute une section **Compte client** : le solde dû la veille du début de la période, les ventes par compte, les règlements et le solde dû à la fin de la période. La liste des ventes indique le mode de paiement de chacune.'),
    ...figure('16d_releve_compte', 'Relevé d’un client en compte'),

    // 6 ------------------------------------------------------------------
    h1('6. Point de vente : vendre au comptoir'),
    h2('6.1 Ouvrir le point de vente'),
    ...etapes([
        'Vérifiez qu’une journée est ouverte sur la caisse (voir 3.2).',
        'Cliquez sur **Vendre** dans le menu (ou sur **Ouvrir le POS** dans la page de la journée).',
        'Si plusieurs journées sont ouvertes, choisissez la caisse : l’écran de vente s’ouvre en plein écran.'
    ]),
    ...figure('20_pos_vente', 'Écran de vente'),
    p('L’écran se compose de trois zones :'),
    pt('Le ticket (à gauche)', 'les articles ajoutés, leur quantité et leur montant, puis le total et les taxes.'),
    pt('Le pavé (en bas à gauche)', 'quantité, prix, remise, suppression et le bouton **Paiement**.'),
    pt('Les produits (à droite)', 'la recherche, les catégories et les tuiles des produits, avec leur prix et leur stock.'),
    h2('6.2 Ajouter des articles'),
    puce('Touchez une tuile pour ajouter le produit ; touchez-la à nouveau pour augmenter la quantité.'),
    puce('Filtrez par catégorie, ou tapez un nom, un code ou un code-barres dans la zone de recherche.'),
    puce('Avec une douchette, scannez simplement le code-barres : l’indication **Douchette prête** confirme que la lecture est active.'),
    puce('Pour un produit à variantes (taille, couleur…), une fenêtre propose de choisir la variante.'),
    puce('Pour un produit combo (menu), une fenêtre propose de choisir les articles de chaque combo (voir 10.4).'),
    astuce('« Stock bas » s’affiche en rouge sur une tuile lorsque le stock atteint le seuil d’alerte du produit.'),
    h2('6.3 Modifier une ligne avec le pavé'),
    p('Touchez une ligne du ticket pour la sélectionner, puis choisissez le mode du pavé :'),
    pt('Qté', 'tapez la nouvelle quantité (deux décimales possibles, ex. 1,5 kg).'),
    pt('Remise %', 'tapez le pourcentage de remise de la ligne.'),
    pt('Prix', 'tapez un nouveau prix unitaire (réservé aux administrateurs).'),
    pt('Corbeille', 'supprime la ligne ; la touche d’effacement corrige la saisie en cours.'),
    h2('6.4 Client, remise globale, addition et mise en attente'),
    pt('Choisir un client', 'associe la vente à un tiers (il apparaît sur le ticket et dans les rapports).'),
    pt('Remise globale', 'remise en % ou en montant sur tout le ticket (administrateurs et utilisateurs habilités). Elle est répartie sur les lignes.'),
    pt('Addition', 'imprime une note provisoire du ticket, avec la mention **NON PAYÉ** en tête et en pied : articles, total à payer (frais de livraison compris), client et vendeur. Le ticket reste à l’écran, rien n’est encaissé ; le vrai ticket de caisse est imprimé au paiement.'),
    pt('Mettre en attente', 'met le ticket de côté pour servir un autre client : il est enregistré et quitte l’écran. Il apparaît dans la liste **Commandes en attente**, visible depuis tous les postes de la journée (voir 6.5).'),
    pt('Plusieurs tickets', 'les tickets en cours sur ce poste apparaissent en onglets en haut de l’écran ; le bouton **+** en crée un nouveau.'),
    astuce('Les tickets en cours sont gardés dans le navigateur : une coupure de réseau ou un rechargement de la page ne les fait pas perdre.'),
    h2('6.5 Commandes en attente'),
    p('Le bouton **Commandes en attente**, en haut de l’écran, indique le nombre de commandes à reprendre. Il ouvre la liste de la journée, partagée entre tous les postes de la caisse :'),
    pt('En attente', 'commandes mises en attente et commandes à livrer à encaisser au retour du livreur : numéro, heure, client, articles, total, livreur et adresse. **Reprendre** ramène la commande dans un nouveau ticket de ce poste (un seul poste peut la reprendre) ; la corbeille la supprime.'),
    pt('Livraisons payées à effectuer', 'ventes déjà encaissées qui restent à livrer. **Livrée** les retire de la liste au retour du livreur ; l’icône de ticket le réimprime.'),
    ...figure('21c_attentes', 'Commandes en attente et livraisons à effectuer'),
    attention('Une journée ne peut pas être clôturée tant qu’une commande est en attente : reprenez-la pour l’encaisser, ou supprimez-la.'),
    h2('6.6 Commandes à livrer'),
    p('Les livreurs sont créés dans **Paramètres** › **Livreurs** (voir 12.8). Pour une commande à livrer :'),
    ...etapes([
        'Ajoutez les articles, choisissez au besoin le client, puis touchez **Livraison**.',
        'Choisissez le **livreur** (son moyen de livraison est indiqué : moto, voiture, vélo…) ; vérifiez le **destinataire**, le **téléphone** et l’**adresse de livraison** (repris de la fiche du client s’il est choisi).',
        'Vérifiez les **frais de livraison** : le montant par défaut (12.8) est proposé ; modifiez-le ou mettez 0 pour une livraison gratuite.',
        'Choisissez **À encaisser à la livraison** : la commande est mise en attente et confiée au livreur. À son retour, ouvrez **Commandes en attente**, touchez **Reprendre** puis encaissez : la vente est enregistrée comme livrée.',
        'Ou choisissez **Payée maintenant** : l’écran de paiement s’ouvre et la vente est encaissée tout de suite. Elle apparaît dans **Livraisons payées à effectuer** jusqu’au retour du livreur (bouton **Livrée**).'
    ]),
    ...figure('21b_livraison', 'Commande à livrer : livreur, destinataire et paiement'),
    p('Le ticket et le détail de la vente indiquent le livreur, le destinataire, l’adresse et le statut de la livraison (**À livrer** ou **Livrée**).'),
    p('Les frais de livraison s’ajoutent au total à payer, hors taxes, comme un pourboire : le total du ticket à l’écran et l’écran de paiement indiquent « dont frais de livraison ». Ils sont encaissés avec la vente et reviennent à la société ; le ticket imprimé les détaille avant le **TOTAL PAYÉ**. Une commande à encaisser à la livraison garde ses frais jusqu’à sa reprise.'),
    ...figure('21e_paiement_frais', 'Paiement d’une commande à livrer, frais de livraison compris'),
    astuce('Les frais ne font pas partie du chiffre d’affaires des articles (ventes TTC) et ne sont pas remboursés par un retour d’articles.'),
    h2('6.7 Encaisser'),
    ...etapes([
        'Touchez **Paiement**.',
        'Choisissez le mode de paiement (**Espèces**, **Mobile Money**…).',
        'Saisissez le montant reçu au pavé, ou utilisez les billets rapides (+500, +1 000, +2 000, +5 000, +10 000) ou **Montant exact**.',
        'Pour un paiement mixte, ajoutez un deuxième règlement avec un autre mode.',
        'Touchez **Valider le paiement**.'
    ]),
    ...figure('21_pos_paiement', 'Paiement : modes, montant reçu et monnaie à rendre'),
    p('La monnaie à rendre est calculée sur les espèces uniquement. Chaque règlement devient un encaissement validé de la journée de caisse.'),
    h3('Paiement par compte (client en compte)'),
    ...etapes([
        'Sur le ticket, touchez **Choisir un client** et sélectionnez le client : la liste indique « en compte » et son solde dû.',
        'Touchez **Paiement**, puis **Compte client** : le montant proposé est le reste à payer, limité au crédit encore possible sous le plafond.',
        'Complétez au besoin avec un autre mode (espèces, Mobile Money…), puis touchez **Valider le paiement**.'
    ]),
    ...figure('21d_paiement_compte', 'Paiement par compte : solde dû et plafond du client'),
    p('Le paiement par compte n’est pas un encaissement : il n’entre pas dans la caisse et ne se compte pas à la clôture. Il s’ajoute au solde dû du client, rappelé en bas du ticket (« Solde dû du compte »).'),
    attention('Sans client, ou avec un client qui n’est pas en compte, le paiement par compte est refusé. Au-delà du plafond de crédit, seul un administrateur peut valider la vente.'),
    h2('6.8 Le ticket'),
    p('Après le paiement, le ticket s’affiche avec le logo et les coordonnées de la société, les articles, le total, les taxes, les règlements et la monnaie rendue. Touchez **Imprimer le ticket** (imprimante 80 mm), puis **Nouvelle vente**.'),
    ...figure('22_pos_ticket', 'Vente terminée et ticket de caisse'),
    h2('6.9 Quitter le point de vente'),
    p('Le bouton **Ventes** ouvre la liste des ventes ; le bouton **Fermer** revient à l’application. La journée reste ouverte : seule la clôture (3.5) la termine.'),
    attention('Si votre société interdit la vente sans stock (voir 8.6), un article épuisé dans les dépôts de la caisse (principal et secondaires) est refusé. Sinon, la vente est acceptée avec un avertissement.'),

    h2('6.10 Laverie et pressing'),
    p('Une caisse de type **Laverie** (3.1) fonctionne comme la vente en détail : l’écran de vente s’ouvre directement sur le ticket et les articles, et son titre indique « Laverie ». Le catalogue réunit en général :'),
    pt('Des prestations', 'lavage et repassage à la pièce, pressing (nettoyage à sec), linge de maison, lavage au kilo, options (express, détachage, livraison). Créez-les sans suivi de stock (11.2) : elles s’affichent « Service » sur la tuile.'),
    pt('Des produits', 'lessive, assouplissant, housses… avec suivi de stock, vendus comme en boutique.'),
    p('Pour le lavage au kilo, choisissez l’unité **Kg** sur le produit ; à la caisse, touchez la tuile puis tapez le poids sur le pavé en mode **Qté** (par exemple 2,5).'),
    ...figure('20b_pos_laverie', 'Écran de vente d’une laverie'),
    astuce('Associez le ticket au client (**Choisir un client**) : ses tickets et ses règlements apparaissent dans le rapport des tiers et son relevé (5.3).'),
    h2('6.11 Dépôt de linge payé au retrait'),
    p('En laverie, le client dépose son linge et le paie quand il vient le chercher, souvent deux ou trois jours plus tard. Le **dépôt de linge** enregistre la commande sans l’encaisser : il ne bloque pas la clôture de la journée et se retrouve depuis n’importe quel poste, les jours suivants.'),
    h3('Enregistrer le dépôt'),
    ...etapes([
        'Ajoutez les articles au ticket comme pour une vente (chemises, pressing, kilos…).',
        'Touchez **Dépôt de linge** (le bouton n’apparaît que sur une caisse de type Laverie).',
        'Saisissez le **nom** et le **téléphone** du client (repris de sa fiche si vous l’avez choisi), la date de **retrait prévue** (dans deux jours par défaut) et, si le client verse une avance, l’**acompte** et son mode de paiement.',
        'Touchez **Enregistrer le dépôt** : le dépôt reçoit un numéro et le ticket quitte l’écran.'
    ]),
    ...figure('20c_laverie_depot', 'Dépôt de linge : client, retrait prévu et acompte'),
    p('Le **ticket de dépôt** s’imprime en deux exemplaires : l’exemplaire client, marqué **NON PAYÉ**, avec les articles, le total, l’acompte et le reste à payer ; la **souche** à joindre au linge, avec le numéro, le nom et le téléphone du client.'),
    ...figure('20f_ticket_depot', 'Ticket de dépôt : exemplaire client et souche'),
    p('L’acompte est encaissé tout de suite dans la journée de caisse (motif « Acompte laverie »). Sans acompte, rien n’est encaissé au dépôt.'),
    h3('Suivre les dépôts'),
    p('Le bouton **Dépôts**, en haut de l’écran de vente, indique le nombre de dépôts à retirer et le nombre de dépôts prêts. Il ouvre la liste, partagée entre les postes et les journées :'),
    pt('Rechercher', 'par numéro de dépôt, nom ou téléphone du client.'),
    pt('À retirer / Retirés · annulés', 'les dépôts en cours et prêts, ou ceux retirés ou annulés depuis 30 jours.'),
    pt('Prêt', 'le linge est lavé : prévenez le client. **Remettre en cours** annule ce statut.'),
    pt('Retrait prévu', 'affiché en rouge « en retard » quand la date est passée.'),
    pt('Imprimante', 'réimprime le ticket de dépôt (client et souche).'),
    pt('Annuler', 'administrateurs et utilisateurs autorisés à valider : le dépôt est annulé et l’acompte éventuel remboursé par un décaissement dans la journée du poste.'),
    ...figure('20d_laverie_depots', 'Liste des dépôts de linge'),
    astuce('Pour faire le point sur le linge en attente, les acomptes et le reste à encaisser, utilisez le **Rapport des dépôts de linge** (9.2).'),
    h3('Remettre le linge et encaisser'),
    ...etapes([
        'Ouvrez **Dépôts**, retrouvez le dépôt (numéro de la souche, nom ou téléphone) et touchez **Encaisser**.',
        'Le dépôt revient en ticket et l’écran de paiement s’ouvre : l’acompte déjà versé est déduit du total à payer.',
        'Encaissez le reste comme une vente (espèces, Mobile Money…), puis remettez le linge : le dépôt passe à **Retiré** et le ticket de caisse est imprimé.'
    ]),
    ...figure('20e_laverie_retrait', 'Retrait : acompte déduit du total'),
    astuce('La vente compte le jour du retrait ; l’acompte, lui, figure dans la journée du dépôt. Sur le ticket de caisse, l’acompte apparaît parmi les règlements (« Acompte (dépôt n° …) »).'),
    attention('Une vente issue d’un dépôt avec acompte ne peut pas être annulée : faites un retour (7.3). Sans acompte, l’annulation remet le dépôt dans la liste des dépôts à retirer.'),

    // 7 ------------------------------------------------------------------
    h1('7. Ventes, retours et annulations'),
    h2('7.1 Liste des ventes'),
    p('Menu **Ventes**. Recherchez par numéro de ticket, client ou période. Chaque ligne indique la date, la caisse, le client, le vendeur, le total et le statut.'),
    ...figure('23_ventes', 'Liste des ventes'),
    h2('7.2 Détail d’une vente'),
    p('Cliquez sur **Ouvrir** : la page présente les articles, les remises, les taxes, les règlements et les éventuels retours. Le bouton **Réimprimer le ticket** permet d’en éditer une copie. Pour une vente livrée, elle indique le livreur, le destinataire, l’adresse et le statut ; **Marquer livrée** termine une livraison payée à la commande.'),
    ...figure('24_vente_details', 'Détail d’une vente'),
    h2('7.3 Retour et remboursement'),
    ...etapes([
        'Dans le détail de la vente, cliquez sur **Retour / remboursement**.',
        'Saisissez la **quantité retournée** de chaque article (le retour peut être partiel).',
        'Choisissez la **journée où rembourser**, le **mode de remboursement** et le **motif** (ex. « produit défectueux »).',
        'Validez : le client est remboursé au prix réellement payé (remises comprises) et les articles reviennent en stock.'
    ]),
    p('Pour la vente d’un client en compte, le mode **Compte client** est proposé : le montant est alors crédité sur son compte (son solde dû diminue) au lieu d’être rendu en caisse.'),
    h2('7.4 Annuler une vente'),
    p('Le bouton **Annuler la vente** annule entièrement une vente de la journée en cours : ses encaissements sont rejetés et le stock est rétabli. Une vente d’une journée clôturée ne peut plus être annulée : utilisez un retour.'),
    attention('Les retours et les annulations sont réservés aux administrateurs et aux utilisateurs ayant le droit de validation.'),

    // 8 ------------------------------------------------------------------
    h1('8. Stock'),
    p('Menu **Stock** (administrateurs). Le stock de chaque produit suivi est tenu **par dépôt** (magasin, entrepôt, réserve… voir 12.7). Il évolue à chaque entrée, vente, retour, annulation, inventaire ou transfert. Le stock d’un produit affiché dans les listes et sur sa fiche est le total de tous les dépôts.'),
    pt('Ventes', 'elles sortent d’abord du dépôt principal de la caisse ; si son stock ne suffit pas, le reste est pris dans ses dépôts secondaires, dans l’ordre choisi sur la caisse (voir 3.1). L’écran de vente affiche le stock total du principal et des secondaires. Ce qui manque encore (vente sans stock autorisée) sort du dépôt principal.'),
    pt('Retours et annulations', 'un retour revient dans le dépôt principal de la caisse ; une vente annulée remet chaque quantité dans le dépôt d’où elle était sortie.'),
    pt('Entrées, inventaires et transferts', 'ils se font dans le dépôt choisi sur la page.'),
    pt('Nouveaux produits', 'leur stock initial est placé dans le dépôt par défaut.'),
    h2('8.1 Mouvements et alertes'),
    p('La page affiche les produits au niveau ou sous leur seuil d’alerte (stock total), puis l’historique des mouvements, filtrable par produit, **dépôt**, type et période. La colonne **Stock après** donne le stock du produit dans le dépôt du mouvement.'),
    ...figure('25_stock', 'Stock : alertes et historique des mouvements'),
    h2('8.2 Entrée de marchandises'),
    ...etapes([
        'Cliquez sur **Entrée de marchandises**.',
        'Choisissez le **dépôt qui reçoit** les marchandises, puis indiquez la référence du bon de livraison ou de la facture fournisseur et un commentaire.',
        'Ajoutez une ligne par produit avec la **quantité reçue** (**+ Ajouter une ligne** pour en ajouter).',
        'Cliquez sur **Enregistrer l’entrée** : le stock de chaque produit augmente dans ce dépôt.'
    ]),
    ...figure('26_entree_stock', 'Entrée de marchandises'),
    h2('8.3 Stock par dépôt'),
    p('L’onglet **Stock par dépôt** présente, pour chaque produit suivi, la quantité dans chaque dépôt et le total. Le total est en rouge quand il atteint le seuil d’alerte.'),
    ...figure('29_stock_depots', 'Stock par dépôt'),
    h2('8.4 Transfert entre dépôts'),
    ...etapes([
        'Cliquez sur **Transfert**.',
        'Choisissez le **dépôt de départ** : la liste des produits indique leur quantité dans ce dépôt. Choisissez ensuite le **dépôt d’arrivée**.',
        'Indiquez au besoin une référence (sinon « TRF-date-heure ») et un commentaire.',
        'Ajoutez une ligne par produit avec la quantité transférée, puis cliquez sur **Enregistrer le transfert**.'
    ]),
    ...figure('29b_transfert', 'Transfert entre dépôts'),
    p('Chaque produit sort du dépôt de départ et entre dans le dépôt d’arrivée (deux mouvements « Transfert ») ; le stock total ne change pas. Un transfert supérieur à la quantité du dépôt de départ est refusé.'),
    h2('8.5 Inventaire'),
    p('Cliquez sur **Inventaire**, choisissez le **dépôt** compté, filtrez au besoin par catégorie, puis saisissez le **stock compté** de chaque produit. L’écart avec le stock théorique du dépôt est calculé. Vous pouvez changer de page ou rechercher sans perdre vos saisies. Cliquez sur **Enregistrer l’inventaire** : les écarts deviennent des mouvements d’inventaire.'),
    ...figure('27_inventaire', 'Inventaire'),
    h2('8.6 Vente sans stock'),
    p('L’option de la page Stock détermine ce qui se passe quand un article est épuisé dans le dépôt de la caisse : vente **autorisée, avec un avertissement**, ou **interdite** (le point de vente refuse l’article).'),
    h2('8.7 Achats de produits et consommations (laverie)'),
    p('Une laverie achète des produits qu’elle ne vend pas : lessive, eau de Javel, assouplissant, détachant, cintres, housses… Le menu **Achats** (administrateurs, rubrique Point de vente ; il n’apparaît que si la société a une caisse de type Laverie) enregistre ces achats chez les fournisseurs, leur règlement et l’utilisation des produits.'),
    p('Ces produits ont leur propre dépôt, le **dépôt des achats** (« Magasin des produits d’entretien », code ACH01, créé automatiquement à la première ouverture du menu) : tous les achats y entrent et toutes les consommations en sortent. Il ne sert à aucune caisse : la vente n’y puise jamais. Le stock initial d’un nouveau produit consommable y est aussi placé.'),
    h3('Préparer les produits et les fournisseurs'),
    pt('Produits', 'créez chaque produit dans **Configuration** › **Produits** (11.2) et cochez **Consommable (non vendu en caisse)** : son stock est suivi et il n’apparaît jamais sur l’écran de vente. Un produit vendu (lessive en bouteille, par exemple) peut aussi être acheté ici : laissez-le simplement non consommable.'),
    pt('Fournisseurs', 'ce sont les tiers de type **Fournisseur** (4).'),
    h3('Enregistrer un achat'),
    ...etapes([
        'Cliquez sur **Nouvel achat**.',
        'Choisissez le **fournisseur**, la **date d’achat** et la référence de sa facture ou de son bon de livraison. Le **dépôt qui reçoit** est toujours le dépôt des achats.',
        'Ajoutez une ligne par produit avec la **quantité** et le **prix d’achat unitaire** (proposé au coût actuel du produit) : le montant de chaque ligne et le total se calculent.',
        'Choisissez le **règlement** : **à crédit** (à régler plus tard), **payé par la caisse** (montant, mode de paiement et journée de caisse ouverte qui paie) ou **payé hors caisse** (virement, chèque…). Le montant réglé peut être partiel.',
        'Cliquez sur **Enregistrer l’achat** : les quantités entrent dans le dépôt des achats (mouvement « Achat ») et le détail de l’achat s’affiche.'
    ]),
    ...figure('26c_nouvel_achat', 'Nouvel achat chez un fournisseur'),
    p('Le **coût** de chaque produit est recalculé en coût moyen pondéré : par exemple, 10 bidons en stock à 2 500 FCFA et 10 bidons achetés à 3 000 FCFA donnent un coût de 2 750 FCFA. Un paiement par la caisse est un **décaissement** de la journée choisie (motif « Achat fournisseur ») : il compte dans la clôture comme toute sortie d’argent.'),
    h3('Suivre les achats et payer les fournisseurs'),
    p('L’onglet **Achats** liste les achats de la période (filtres fournisseur et statut **Validé**, **Non soldé** ou **Annulé**) avec le montant, le réglé et le reste à payer. Les cartes donnent le total de la période et le montant **dû aux fournisseurs**, tous achats confondus.'),
    ...figure('26b_achats', 'Liste des achats'),
    p('Le détail d’un achat présente ses produits, ses règlements et, tant qu’il reste un montant dû, le formulaire **Régler** : montant, mode de paiement, par la caisse (journée ouverte) ou hors caisse.'),
    ...figure('26d_achat_details', 'Détail d’un achat à crédit et règlement'),
    pt('Annuler l’achat', 'les quantités ressortent du stock et les paiements faits par une caisse sont remboursés par un encaissement dans la même journée. L’annulation est refusée si cette journée est clôturée, ou si les produits ont déjà été utilisés ou vendus : corrigez alors le stock par un inventaire (8.5).'),
    h3('Enregistrer les consommations'),
    p('L’onglet **Consommations** sort du dépôt des achats les produits utilisés pour le service (par exemple chaque soir ou chaque semaine) : ajoutez une ligne par produit avec la **quantité utilisée** et un commentaire, puis **Enregistrer la consommation** (mouvement « Consommation »). La liste des produits indique la quantité **en magasin** ; une quantité supérieure est refusée.'),
    p('Sous le formulaire, la période choisie présente les consommations **par produit**, avec leur valeur au coût, et leur détail. Comparez cette valeur au chiffre d’affaires de la laverie pour suivre le coût des produits par lavage.'),
    ...figure('26e_consommations', 'Consommations de produits d’entretien'),
    h3('Suivre le dépôt des achats'),
    p('L’onglet **Dépôt des achats** présente, pour la période choisie, chaque produit du dépôt avec ses **entrées** (achats, transferts reçus, écarts d’inventaire positifs), ses **sorties** (consommations, annulations d’achats, transferts, écarts négatifs), le **stock** actuel, le seuil d’alerte, le coût et la valeur. Une ligne rouge signale un produit au niveau ou sous son seuil d’alerte : pensez à le racheter. Les cartes donnent le nombre de produits en alerte et la valeur du stock au coût ; le détail des entrées et sorties suit.'),
    ...figure('26f_depot_achats', 'Dépôt des achats : entrées, sorties et stock'),
    pt('Inventaire', 'comptez régulièrement le magasin : le bouton **Inventaire** ouvre l’inventaire (8.5) sur le dépôt des achats.'),
    pt('Transfert', 'un produit acheté pour être revendu (lessive en bouteille, par exemple) se transfère vers le dépôt d’une caisse avec le bouton **Transfert** (8.4).'),
    h3('Alerte de stock bas'),
    p('Renseignez le **seuil d’alerte** de chaque produit d’entretien dans sa fiche (11.2), par exemple 1 sac de lessive. Dès que son stock dans le dépôt des achats atteint ce seuil ou passe en dessous, GesCaisse prévient les administrateurs :'),
    pt('Cloche', 'en haut de chaque page, la cloche s’allume et sa liste indique le nombre de produits à racheter ; un clic sur la ligne ouvre le dépôt des achats (voir 2.4).'),
    pt('Tableau de bord', 'la ligne « produits d’entretien à racheter » apparaît dans **À traiter**.'),
    pt('Module Achats', 'un bandeau sur chaque onglet liste les produits concernés, le plus urgent en premier, avec leur stock et leur seuil.'),
    ...figure('26g_alerte_entretien', 'Alerte de stock bas des produits d’entretien'),
    p('Le bouton **Racheter** du bandeau ouvre un nouvel achat déjà rempli : une ligne par produit en alerte, au prix d’achat actuel. Il reste à choisir le fournisseur et à saisir les quantités. Un produit sans seuil d’alerte, ou inactif, ne déclenche jamais d’alerte.'),

    // 9 ------------------------------------------------------------------
    h1('9. Rapports de ventes'),
    p('Les rapports du point de vente sont regroupés dans le menu **Rapports** de la rubrique Point de vente (administrateurs) : cliquez dessus pour l’ouvrir, puis choisissez **Ventes**, **Livraisons** et, en laverie, **Dépôts de linge** et **Achats**. Le sous-menu reste ouvert tant que vous consultez l’un de ces rapports.'),
    p('Menu **Rapports** › **Ventes**. Choisissez la période (**Aujourd’hui**, **7 jours**, **Ce mois**, **Mois dernier** ou des dates), la caisse, puis **Filtrer**.'),
    ...figure('28_rapport_ventes', 'Rapports de ventes'),
    p('Le rapport présente le chiffre d’affaires TTC, le nombre de tickets, le panier moyen, les taxes, les retours, le chiffre d’affaires par jour, les ventes par mode de paiement, par catégorie et par vendeur, et le classement des produits les plus vendus.'),
    pt('Imprimer / PDF', 'aperçu imprimable du rapport.'),
    pt('Excel', 'export du rapport pour vos analyses.'),
    h2('9.1 Rapport des livraisons'),
    p('Menu **Rapports** › **Livraisons** (administrateurs, rubrique Point de vente). Choisissez la période, au besoin un **livreur** et un **statut** (Livrée, À livrer, À encaisser), puis **Filtrer**.'),
    ...figure('28b_rapport_livraisons', 'Rapport des livraisons'),
    p('Les cartes donnent le nombre de livraisons, les livraisons effectuées, celles en cours, le montant des ventes livrées et le total des frais de livraison. Le rapport présente ensuite :'),
    pt('Par livreur', 'pour chaque livreur et son moyen de livraison : nombre de livraisons, livrées, à livrer, à encaisser, montant des ventes et frais de livraison, avec le total.'),
    pt('Détail des livraisons', 'date, numéro du ticket (lien vers la vente), livreur, destinataire et téléphone, adresse, montant des articles, frais, statut et date de livraison.'),
    p('Statuts : **Livrée** (livraison effectuée), **À livrer** (vente payée, livreur pas encore revenu), **À encaisser** (commande confiée au livreur, à encaisser à son retour depuis **Commandes en attente**). Les ventes annulées ne sont pas comptées.'),
    pt('Imprimer / PDF et Exporter Excel', 'reprennent la synthèse par livreur et le détail (deux feuilles dans le fichier Excel).'),
    h2('9.2 Rapport des dépôts de linge'),
    p('Menu **Rapports** › **Dépôts de linge** (administrateurs, rubrique Point de vente ; il n’apparaît que si la société a une caisse de type Laverie). Choisissez la période de dépôt et, au besoin, un **statut**, puis **Filtrer**.'),
    pt('À retirer / En retard', 'ces deux filtres prennent tous les dépôts non retirés, quelle que soit leur date de dépôt (la période est alors grisée) : pratique pour faire le point sur le linge en attente et relancer les clients en retard.'),
    pt('En cours, Prêt, Retiré, Annulé', 'les dépôts de la période ayant ce statut.'),
    ...figure('28c_rapport_linge', 'Rapport des dépôts de linge'),
    p('Les cartes donnent le nombre de dépôts, ceux à retirer, ceux en retard, le montant des dépôts, les acomptes versés et le **reste à encaisser** (montant moins acompte des dépôts en cours ou prêts). Le rapport présente ensuite :'),
    pt('Par statut', 'pour chaque statut : nombre de dépôts, articles, montant, acomptes, reste à encaisser et retards, avec le total hors dépôts annulés.'),
    pt('Détail des dépôts', 'numéro, date et caisse du dépôt, client et téléphone, articles, montant, acompte, reste, retrait prévu (en rouge s’il est passé), statut et sa date, avec un lien vers la vente du retrait.'),
    pt('Imprimer / PDF et Excel', 'comme les autres rapports ; le fichier Excel a deux feuilles, Synthèse et Dépôts.'),
    h2('9.3 Rapport des achats et consommations'),
    p('Menu **Rapports** › **Achats** (administrateurs, rubrique Point de vente ; il n’apparaît que si la société a une caisse de type Laverie). Choisissez la période (date d’achat, par défaut du 1er du mois à aujourd’hui) et, au besoin, un **fournisseur**, puis **Filtrer**.'),
    ...figure('28d_rapport_achats', 'Rapport des achats et consommations'),
    p('Les cartes donnent le nombre d’achats, leur montant, le montant réglé, le reste à payer aux fournisseurs et la valeur des produits consommés sur la période. Le rapport présente ensuite :'),
    pt('Par fournisseur', 'nombre d’achats, montant, réglé et reste à payer de chaque fournisseur, avec le total.'),
    pt('Par produit', 'quantité et montant achetés, prix d’achat moyen, quantité consommée et sa valeur au coût actuel, et stock restant dans le dépôt des achats. Comparez la valeur consommée au chiffre d’affaires de la laverie pour suivre le coût des produits.'),
    pt('Détail des achats', 'numéro (lien vers l’achat), date, fournisseur, référence, montant, réglé, reste et statut (Soldé, Non soldé, Annulé).'),
    p('Les achats annulés figurent dans le détail mais pas dans les totaux. Avec un fournisseur choisi, seuls ses achats et ses produits sont présentés.'),
    pt('Imprimer / PDF et Exporter Excel', 'reprennent les trois tableaux (feuilles Fournisseurs, Produits et Achats dans le fichier Excel).'),

    // 10 -----------------------------------------------------------------
    h1('10. Restaurant et bar'),
    encadre('Principe.', 'Une caisse de type **Restaurant** ou **Bar** ouvre l’écran de vente sur le plan de salle. La commande de chaque table est gardée sur le serveur : plusieurs serveurs et appareils peuvent la consulter et la compléter jusqu’à son encaissement.'),
    h2('10.1 Mise en place (administrateur)'),
    ...etapes([
        'Dans **Caisses**, choisissez le type **Restaurant** ou **Bar** pour la caisse (voir 3.1).',
        'Dans **Configuration** › **Catégories**, indiquez le **poste de préparation** de chaque catégorie : **Cuisine**, **Bar** ou **Aucun** (articles servis directement).',
        'Dessinez le plan de salle (10.8).'
    ]),
    h2('10.2 Le plan de salle'),
    p('À l’ouverture du point de vente, le plan de la salle s’affiche. Les onglets en haut permettent de passer d’une salle à l’autre (salle principale, terrasse…).'),
    ...figure('35_plan_salle_occupe', 'Plan de salle : tables libres et occupées'),
    tableau(['Couleur', 'Signification'], [
        ['Blanc', 'Table libre'],
        ['Bleu', 'Table occupée : total, nombre de couverts et temps écoulé'],
        ['Orange', 'Addition demandée'],
        ['Pastille rouge', 'Des articles restent à envoyer en préparation']
    ], [2400, 7238]),
    espace(),
    p('Le bouton **Vente directe** permet de vendre au comptoir sans table. À l’encaissement, ses articles partent en préparation comme ceux d’une table (voir 10.5).'),
    h2('10.3 Prendre une commande'),
    ...etapes([
        'Touchez une table libre et choisissez le **nombre de couverts**.',
        'Ajoutez les articles comme au comptoir (6.2).',
        'Pour une précision, sélectionnez la ligne puis touchez **Note** : choisissez une note rapide (« Bien cuit », « Sans oignon »…) ou saisissez la vôtre.',
        'Touchez **Plan** pour revenir au plan : la commande est enregistrée sur la table.'
    ]),
    ...figure('31_couverts', 'Ouverture d’une table : nombre de couverts'),
    ...figure('32_commande_table', 'Commande d’une table avec une note et un menu'),
    ...figure('33_note', 'Note sur un article'),
    h2('10.4 Commander un menu (combo)'),
    p('Un produit combo, par exemple « Menu Jardin », se compose de plusieurs choix : un plat, un accompagnement, une boisson… En touchant sa tuile, une fenêtre affiche chaque combo avec le nombre d’articles à choisir. Certains choix ajoutent un supplément (ex. « +500 »). Le total se met à jour ; touchez **Ajouter**.'),
    ...figure('34_combo', 'Choix des articles d’un menu'),
    p('Sur le ticket, le menu apparaît avec ses articles choisis. En cuisine et au bar, chaque article part vers son poste de préparation.'),
    h2('10.5 Envoyer en cuisine et au bar'),
    p('Touchez **Envoyer** : un bon de préparation est créé pour chaque poste (cuisine, bar) avec les nouveaux articles seulement, leurs notes, la table et le nombre de couverts. Un article retiré après l’envoi part comme une ligne « ANNULÉ ». Selon le réglage de la caisse, le bon est imprimé automatiquement.'),
    astuce('Avant l’encaissement, les articles qui n’ont pas encore été envoyés le sont automatiquement.'),
    p('**Vente directe** : il n’y a pas de bouton Envoyer ; les articles partent en préparation dès l’encaissement, un bon par poste, intitulé « Vente directe · ticket N » (N = numéro de la vente dans la journée, les 4 derniers chiffres du ticket). Le bon est imprimé si la caisse imprime les bons, et s’affiche sur l’écran cuisine / bar. Les articles dont la catégorie a le poste **Aucun** ne font pas de bon.'),
    h2('10.6 Addition, partage, transfert et pourboire'),
    pt('Addition', 'imprime une note provisoire marquée **NON PAYÉ** (table, couverts, total et montant par couvert) ; la table passe en « addition demandée ». En vente directe, le bouton **Addition** du ticket fait de même (voir 6.4).'),
    pt('Partager', 'choisissez les articles payés maintenant ; le reste demeure sur la table.'),
    pt('Transférer', 'déplace la commande vers une table libre, ou la regroupe avec celle d’une table occupée.'),
    pt('Couverts', 'le nombre de couverts reste modifiable depuis l’en-tête de la commande.'),
    pt('Pourboire', 'au paiement, ajoutez 5, 10 ou 15 % ou un montant libre ; il figure sur le ticket.'),
    ...figure('36_paiement_table', 'Paiement d’une table'),
    attention('Si un autre appareil a modifié la commande entre-temps, GesCaisse vous prévient et recharge la dernière version pour éviter d’écraser son travail.'),
    h2('10.7 L’écran cuisine / bar'),
    p('Menu **Écran cuisine / bar** (ou bouton **Écran cuisine** du point de vente). Les bons à préparer s’affichent par ordre d’arrivée, avec la table, le poste, les couverts, le serveur, le temps d’attente et les notes. L’écran s’actualise seul toutes les 5 secondes et émet un signal sonore à l’arrivée d’un bon.'),
    ...figure('37_ecran_cuisine', 'Écran cuisine / bar'),
    puce('Les filtres **Tous**, **Cuisine** et **Bar** limitent l’affichage à un poste.'),
    puce('La couleur du bon change après 10 puis 20 minutes d’attente.'),
    puce('Touchez **Prêt** lorsque la préparation est terminée ; les derniers bons prêts restent rappelés en bas de l’écran.'),
    h2('10.8 Dessiner le plan de salle (administrateur)'),
    p('Depuis **Caisses**, cliquez sur l’icône **Plan de salle** (chaise) d’une caisse Restaurant ou Bar.'),
    ...figure('38_editeur_plan', 'Éditeur du plan de salle'),
    puce('**+ Salle** crée une salle (ex. Terrasse) ; ses onglets permettent de la renommer ou de la supprimer.'),
    puce('**Table carrée** ou **Table ronde** ajoute une table ; faites-la glisser pour la placer et tirez son coin pour la redimensionner.'),
    puce('Sélectionnez une table pour changer son nom et son nombre de places, ou la retirer.'),
    puce('Cliquez sur **Enregistrer le plan** pour conserver toutes les salles.'),
    attention('Une table ne peut pas être retirée tant qu’une commande y est en cours.'),

    // 11 -----------------------------------------------------------------
    h1('11. Catalogue : catégories, produits et combos'),
    p('Menu **Configuration** (administrateurs).'),
    h2('11.1 Catégories'),
    p('Les catégories regroupent les produits sur l’écran de vente. Pour chacune : nom, **couleur** des tuiles, **ordre** d’affichage et **poste de préparation** (Cuisine, Bar ou Aucun). Le poste de préparation n’apparaît que si la société a au moins une caisse Restaurant ou Bar ; sinon il est masqué (et conservé). Il en va de même pour le menu **Écran cuisine / bar**. Le bouton d’affichage permet de passer de la liste aux cartes.'),
    ...figure('50_categories', 'Catégories de produits'),
    h2('11.2 Produits'),
    p('La liste des produits se filtre par nom, code, code-barres ou catégorie ; elle s’affiche en liste ou en cartes et indique les produits sous le seuil d’alerte.'),
    ...figure('51_produits', 'Liste des produits'),
    p('Cliquez sur **Nouveau produit** ou **Modifier** et renseignez :'),
    pt('Identification', 'code, nom, catégorie, code-barres, image.'),
    pt('Prix', 'prix de vente TTC, coût d’achat (la marge est calculée), taxes applicables (TVA, CSS…), unité de vente (pièce, kg, litre…).'),
    pt('Stock', 'suivi du stock oui ou non, stock initial, seuil d’alerte. **Consommable** : produit acheté et utilisé pour le service (lessive, javel…), jamais vendu en caisse (voir 8.7).'),
    pt('Actif', 'un produit inactif n’apparaît plus à la caisse.'),
    ...figure('52_fiche_produit', 'Fiche d’un produit'),
    h3('Variantes'),
    p('Pour un article décliné (ex. T-shirt en tailles S, M, L et plusieurs couleurs), ajoutez des attributs et leurs valeurs dans le bloc **Variantes**, puis générez les variantes. Chaque combinaison devient une variante avec son code, son code-barres, son prix et son stock ; elle reprend le nom, la catégorie, les taxes, l’unité et le coût du modèle.'),
    h3('Importer et exporter'),
    p('Les boutons **Exporter Excel** et **Importer Excel** permettent de mettre à jour le catalogue en masse.'),
    h2('11.3 Combos'),
    p('Un combo est une liste de produits proposés au choix, par exemple « Plat au choix » : Poulet braisé, Poisson braisé (+500), Brochettes. Il est réutilisable dans plusieurs menus.'),
    ...figure('53_combos', 'Liste des combos'),
    ...etapes([
        'Dans **Configuration** › **Combos**, cliquez sur **Nouveau combo** (ou **Modifier** sur une ligne) : une fenêtre s’ouvre.',
        'Saisissez le **Nom du combo** et le nombre d’**Articles à choisir**.',
        'Ajoutez les **produits proposés** avec, si besoin, un **supplément** en FCFA.',
        'Cliquez sur **Enregistrer**.'
    ]),
    ...figure('53b_combo_modale', 'Création ou modification d’un combo'),
    p('Pour créer le menu lui-même, ouvrez la fiche du produit (ex. « Menu Jardin », prix 4 500) et ajoutez ses combos dans l’ordre voulu dans le bloc **Combo (menu, formule)**. Le prix du menu est le prix du produit plus les suppléments des articles choisis. Les articles choisis sortent du stock ; le menu lui-même n’a pas de stock propre.'),
    ...figure('54_produit_combo', 'Combos d’un produit menu'),
    attention('Un combo utilisé par un menu ne peut pas être supprimé : retirez-le d’abord de la fiche du produit.'),

    // 12 -----------------------------------------------------------------
    h1('12. Paramètres'),
    p('Menu **Paramètres** (administrateurs).'),
    h2('12.1 Ma société'),
    p('Renseignez les coordonnées de votre société : adresse, ville, pays, e-mail, téléphone, NIF et logo. Elles figurent en en-tête des tickets et des impressions. Le nom, le code, la licence et les modules sont affichés à titre d’information : pour les modifier, contactez votre fournisseur.'),
    ...figure('40_ma_societe', 'Ma société'),
    h2('12.2 Utilisateurs'),
    p('Créez un compte pour chaque personne : **Nom d’utilisateur** (identifiant de connexion), **Nom complet**, **Mot de passe**, **Profil** et, si besoin, le droit **Peut valider / rejeter les opérations de caisse**. Pour changer le mot de passe d’un utilisateur, modifiez son compte et saisissez le nouveau mot de passe.'),
    ...figure('41_utilisateurs', 'Utilisateurs'),
    h2('12.3 Motifs'),
    p('Les motifs qualifient les encaissements et les décaissements (« Règlement client », « Achat fournitures »…) et précisent le type de tiers concerné et le compte comptable. Le motif « Vente POS » est créé automatiquement pour les ventes du point de vente.'),
    ...figure('42_motifs', 'Motifs'),
    h2('12.4 Modes de paiement'),
    p('Code, libellé et statut actif de chaque mode (Espèces, Mobile Money, Carte, Chèque…). Un mode déjà utilisé ne peut pas être supprimé ; désactivez-le plutôt. Le mode « Espèces » est reconnu pour le calcul de la monnaie. La case **Paiement par compte client** désigne le mode utilisé pour les ventes à crédit des clients en compte (« Compte client », créé pour chaque société) : il n’est pas proposé pour les opérations de caisse.'),
    ...figure('43_modes_paiement', 'Modes de paiement'),
    h2('12.5 Taxes'),
    p('Code, libellé, taux et case **Par défaut** (taxe cochée automatiquement sur les nouveaux produits). La TVA 18 % et la CSS 1 % sont créées pour chaque société. Les prix étant saisis TTC, le hors taxes est calculé : HT = TTC / (1 + somme des taux).'),
    ...figure('44_taxes', 'Taxes'),
    h2('12.6 Unités de vente'),
    p('Unités proposées sur les fiches produits (Unité, Kilogramme, Litre, Carton…). Vous pouvez en ajouter, les modifier, les activer ou les désactiver. Renommer une unité met à jour les produits qui l’utilisent ; une unité utilisée ne peut pas être supprimée.'),
    ...figure('45_unites', 'Unités de vente'),
    h2('12.7 Dépôts'),
    p('Menu **Paramètres** › **Dépôts**. Un dépôt est un lieu de stockage : magasin, entrepôt, réserve… Chaque société a au moins un dépôt, le **Dépôt principal**, créé automatiquement : il a reçu tout le stock existant lors de la mise à jour.'),
    ...figure('46_depots', 'Dépôts de stockage'),
    p('Cliquez sur **Nouveau dépôt** (ou **Modifier** sur une ligne) et renseignez le **code**, le **nom**, l’adresse et le responsable. La liste indique pour chaque dépôt le nombre de produits en stock et de caisses rattachées (comme dépôt principal ou secondaire).'),
    pt('Par défaut', 'le dépôt par défaut reçoit le stock initial des nouveaux produits et sert aux caisses sans dépôt choisi (elles passent automatiquement au nouveau dépôt par défaut si vous en changez). Il ne peut être ni désactivé ni supprimé : choisissez d’abord un autre dépôt par défaut.'),
    pt('Désactiver', 'un dépôt désactivé n’est plus proposé pour les caisses ni les mouvements de stock, et les caisses ne s’en servent plus comme dépôt secondaire. Un dépôt principal d’une caisse ne peut pas être désactivé.'),
    pt('Supprimer', 'seul un dépôt sans mouvement de stock ni caisse peut être supprimé ; sinon, désactivez-le.'),
    pt('Dépôt des achats', 'laverie : dépôt des produits d’entretien (voir 8.7), signalé par un badge. Il n’est pas proposé sur les caisses et ne peut être ni dépôt par défaut, ni désactivé, ni supprimé. Pour en changer, cliquez sur **Dépôt des achats** sur la ligne d’un autre dépôt actif qui ne sert à aucune caisse.'),
    h2('12.8 Livreurs'),
    p('Menu **Paramètres** › **Livreurs**. Les livreurs sont proposés au point de vente sur une commande à livrer ; ils n’ont pas de compte de connexion. Cliquez sur **Nouveau livreur** (ou **Modifier**) et renseignez le **nom**, le **téléphone** et le **moyen de livraison** : **Moto**, **Voiture**, **Vélo** ou **Autre**. La liste indique le moyen et le nombre de livraisons de chacun.'),
    pt('Moyen de livraison', 'il apparaît au point de vente dans le choix du livreur et dans la liste des commandes en attente, ainsi que sur le ticket et le détail de la vente (ex. « Jean Moussavou (Moto) »).'),
    ...figure('47_livreurs', 'Livreurs'),
    pt('Frais de livraison par défaut', 'en haut de la page : montant proposé dans la fenêtre « Livraison » du point de vente (0 = sans frais), modifiable à chaque vente. Cliquez sur **Enregistrer** après l’avoir changé.'),
    pt('Désactiver', 'un livreur désactivé n’est plus proposé au point de vente mais reste sur ses livraisons passées.'),
    pt('Supprimer', 'seul un livreur sans livraison peut être supprimé ; sinon, désactivez-le.'),
    h2('12.9 Sociétés (super-administrateur)'),
    p('Le super-administrateur crée les sociétés, choisit leurs modules (point de vente activé ou non), fixe leur mode d’accès (licence ou abonnement) et prolonge leur date d’expiration. Le bloc **Société** du menu lui permet de consulter les données d’une société en particulier.'),

    // 13 -----------------------------------------------------------------
    h1('13. Questions fréquentes'),
    tableau(['Question', 'Réponse'], [
        ['Le menu Vendre n’affiche aucune caisse.', 'Aucune journée n’est ouverte : ouvrez une journée sur la caisse (3.2).'],
        ['Je ne vois pas Configuration, Stock ou Paramètres.', 'Ces menus sont réservés aux administrateurs. Si personne ne les voit, le module Point de vente n’est pas activé pour votre société.'],
        ['Le bouton Prix du pavé est refusé.', 'La modification du prix à la caisse est réservée aux administrateurs.'],
        ['La remise globale, le retour ou l’annulation sont refusés.', 'Ces actions demandent le profil Admin ou le droit « Peut valider ».'],
        ['Je ne peux pas clôturer la journée.', 'Dans un restaurant, encaissez ou transférez d’abord les commandes des tables.'],
        ['Un article épuisé est refusé à la caisse.', 'La vente sans stock est interdite (8.6) et l’article est épuisé dans les dépôts de la caisse : enregistrez une entrée, un transfert ou un inventaire dans l’un d’eux, ou rattachez un dépôt secondaire à la caisse (3.1).'],
        ['Mon ticket a disparu après une coupure.', 'Rouvrez le point de vente sur le même poste et le même navigateur : les tickets en cours y sont conservés.'],
        ['Le ticket n’affiche pas notre logo ou notre adresse.', 'Complétez Paramètres › Ma société (12.1).'],
        ['La page indique « compte suspendu ».', 'La licence de la société a expiré : contactez votre fournisseur.'],
        ['L’export Sage signale des anomalies.', 'Renseignez le compte comptable de la caisse et le compte général des tiers concernés.']
    ], [3600, 6038]),

    // 14 -----------------------------------------------------------------
    h1('14. Glossaire'),
    tableau(['Terme', 'Définition'], [
        ['Caisse', 'Point d’encaissement (tiroir-caisse) de la société.'],
        ['Journée de caisse', 'Période de travail sur une caisse, de l’ouverture (fond initial) à la clôture (comptage).'],
        ['Fond initial', 'Montant présent dans la caisse à l’ouverture de la journée.'],
        ['Encaissement / décaissement', 'Entrée / sortie d’argent enregistrée dans une journée.'],
        ['Écart de clôture', 'Différence entre le montant compté et le montant théorique.'],
        ['Point de vente (POS)', 'Écran de vente tactile utilisé au comptoir ou en salle.'],
        ['Ticket', 'Vente encaissée au point de vente, et son justificatif imprimé.'],
        ['Couverts', 'Nombre de personnes servies à une table.'],
        ['Bon de préparation', 'Liste des articles à préparer, envoyée en cuisine ou au bar.'],
        ['Addition', 'Note provisoire marquée « NON PAYÉ », remise au client avant l’encaissement.'],
        ['Combo', 'Liste de produits proposés au choix (ex. « Plat au choix ») ; un menu en réunit plusieurs.'],
        ['Variante', 'Déclinaison d’un produit (taille, couleur…) avec son propre code, prix et stock.'],
        ['Seuil d’alerte', 'Stock en dessous duquel le produit est signalé « stock bas ».'],
        ['TTC / HT', 'Toutes taxes comprises / hors taxes.'],
        ['NIF', 'Numéro d’identification fiscale de la société.'],
        ['Genre du tiers', 'Entreprise (personne morale) ou Particulier (personne physique).'],
        ['Relevé du tiers', 'Détail imprimable des ventes et des opérations de caisse d’un tiers sur une période.'],
        ['Client en compte', 'Client autorisé à payer par compte (vente à crédit), dans la limite de son plafond.'],
        ['Solde dû', 'Ce que doit un client en compte : ventes par compte, moins ses règlements et les retours crédités.']
    ], [2800, 6838])
];

// ---------------------------------------------------------------------------
// Document
// ---------------------------------------------------------------------------
const doc = new Document({
    creator: 'M-ITECH AFRICA',
    title: 'Manuel utilisateur GesCaisse',
    description: 'Manuel utilisateur de l\'application GesCaisse',
    styles: {
        default: { document: { run: { font: POLICE, size: 21 } } },
        paragraphStyles: [
            { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
                run: { size: 34, bold: true, font: POLICE, color: BLEU },
                paragraph: { spacing: { before: 120, after: 240 }, outlineLevel: 0,
                    border: { bottom: { style: BorderStyle.SINGLE, size: 8, color: BLEU, space: 4 } } } },
            { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true,
                run: { size: 26, bold: true, font: POLICE, color: BLEU },
                paragraph: { spacing: { before: 260, after: 120 }, outlineLevel: 1, keepNext: true } },
            { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true,
                run: { size: 22, bold: true, font: POLICE, color: '333333' },
                paragraph: { spacing: { before: 180, after: 80 }, outlineLevel: 2, keepNext: true } }
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
        }, {
            reference: 'etapes',
            levels: [
                { level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT,
                    style: { paragraph: { indent: { left: 540, hanging: 320 } }, run: { bold: true, color: BLEU } } }
            ]
        }]
    },
    sections: [
        sectionGarde('garde_manuel.jpg', 'Manuel utilisateur GesCaisse'),
        {
            properties: { page: { margin: { top: 1134, right: 1134, bottom: 1134, left: 1134 }, pageNumbers: { start: 2 } } },
            headers: { default: new Header({ children: [new Paragraph({
                border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: 'C9D5DE', space: 4 } },
                tabStops: [{ type: TabStopType.RIGHT, position: LARGEUR }],
                children: [t('GesCaisse — Manuel utilisateur', { size: 17, color: GRIS }), t('\tM-ITECH AFRICA', { size: 17, color: GRIS })]
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
    fs.writeFileSync(process.argv[2] || 'Manuel_utilisateur_GesCaisse.docx', b);
    console.log('ok');
});
