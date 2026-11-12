// Écran de vente du point de vente (commun aux versions .NET et PHP).
// Les données (produits, catégories, clients, journée) sont fournies par la page
// dans <script id="pos-donnees" type="application/json">. Les tickets en cours
// sont gardés dans le navigateur (localStorage) jusqu'au paiement ; « Mettre en attente »
// les enregistre sur le serveur (liste « Commandes en attente », partagée entre les postes).
// Livraison : livreur et destinataire sur le ticket, payée maintenant ou à la livraison.
// Restaurant / bar (D.restaurant) : l'écran s'ouvre sur le plan de salle ; la commande de
// chaque table est gardée sur le serveur (partagée entre serveurs et appareils), envoyée en
// cuisine / au bar par bons de préparation, puis encaissée (en une fois ou partagée).
// Laverie (D.laverie) : dépôt de linge payé au retrait (ticket « NON PAYÉ », acompte facultatif),
// liste des dépôts (en cours, prêts, retirés) et encaissement au retrait, acompte déduit.
(function () {
    'use strict';

    const D = JSON.parse(document.getElementById('pos-donnees').textContent);
    const racine = document.getElementById('pos');
    const nf = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 2 });
    const fcfa = n => nf.format(Math.round(n));
    const qte = n => nf.format(n);
    const echap = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

    const produits = new Map(D.produits.map(p => [p.id, p]));
    // Variantes rangées sous leur modèle (une tuile par modèle, choix de la variante au clic).
    const variantesDe = new Map();
    D.produits.filter(p => p.parentId).forEach(v => {
        if (!variantesDe.has(v.parentId)) variantesDe.set(v.parentId, []);
        variantesDe.get(v.parentId).push(v);
    });
    variantesDe.forEach(liste => liste.sort((a, b) => a.id - b.id));   // ordre de création : S, M, L…
    const categories = new Map(D.categories.map(c => [c.id, c]));
    const clients = new Map(D.clients.map(c => [c.id, c]));

    // ------------------------------------------------------------------
    // État : tickets en cours, gardés dans le navigateur
    // ------------------------------------------------------------------
    let etat = charger();
    let categorieChoisie = 0;
    let recherche = '';
    let mode = 'qte';        // qte | remise | prix
    let saisie = null;       // chiffres tapés sur le pavé pour la ligne choisie
    let vue = 'vente';       // vente | paiement | fin
    let pay = null;          // paiement en cours : { lignes: [{ modeId, montant, auto }], choisie, saisie, envoi }
    let fin = null;          // vente enregistrée : { id, numero, rendu }
    const modes = new Map((D.modes || []).map(m => [m.id, m]));

    // Restaurant / bar : plan de salle et commande de la table ouverte (gardée sur le serveur).
    const R = D.restaurant || null;
    let salles = R ? R.salles : [];
    let salleActive = 0;
    let cmd = null;          // { id, version, tableId, table, couverts, addition, lignes, clientId, remise, choisie, retire }
    const sync = { minuterie: null, enCours: false, encore: false };
    if (R) vue = 'plan';

    // Laverie : dépôts de linge (liste partagée entre les postes et les journées).
    const L = D.laverie || null;
    let depots = [];

    // Hors ligne (hors-ligne.js) : vente ou dépôt gardé sur le poste, envoyé au retour de la connexion
    // avec un numéro provisoire (H-poste-n°) ; le ticket provisoire est imprimé depuis le poste.
    const F = window.gcFile || null;
    const horsLigne = () => !!F && !!window.gcConnexion && !window.gcConnexion.enLigne;
    // Restaurant / bar hors ligne : plan de salle gardé sur le poste (avec le détail des commandes), et
    // commandes de table prises hors ligne (file du poste, une par table) affichées par-dessus.
    const CLE_PLAN = 'gc-plan:' + D.cle;
    const dateServeur = d => d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0')
        + ' ' + String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0') + ':' + String(d.getSeconds()).padStart(2, '0');
    // (Commande d'une table encaissée hors ligne : elle reste dans la file avant sa vente, mais la table est libre.)
    const tablesHorsLigne = () => F ? F.elements().filter(x => x.type === 'table' && x.donnees.journeeId === D.journee.id && !x.payee) : [];
    function resumeLocal(d, avant) {
        const lignes = d.lignes || [];
        if (!lignes.length) return null;
        return {
            id: d.id, version: d.version, couverts: d.couverts, total: totaux({ lignes: lignes, remise: d.remise }).ttc, articles: lignes.length,
            addition: !!(avant && avant.addition), aEnvoyer: lignes.some(l => Math.abs(l.qte - (l.envoye || 0)) >= 0.01),
            serveur: (avant && avant.serveur) || D.utilisateur.nom, depuis: (avant && avant.depuis) || dateServeur(new Date()),
            lignes: lignes, clientId: d.clientId || null, remise: d.remise || null, horsLigne: true
        };
    }
    function superposer() {
        if (!R) return;
        tablesHorsLigne().forEach(x => { const t = tableDe(x.donnees.tableId); if (t) t.commande = resumeLocal(x.donnees, t.commande); });
    }
    function garderPlan() {
        if (!R) return;
        try { localStorage.setItem(CLE_PLAN, JSON.stringify({ quand: Date.now(), salles: salles })); } catch (err) { /* stockage plein */ }
    }

    // Feuille de style du ticket gardée par le service worker, pour imprimer sans connexion.
    if (D.ticket && D.ticket.css && navigator.onLine) fetch(D.ticket.css, { credentials: 'same-origin' }).catch(() => {});

    function charger() {
        try {
            const e = JSON.parse(localStorage.getItem(D.cle) || 'null');
            if (e && Array.isArray(e.tickets) && e.tickets.length) {
                // Produits retirés du catalogue depuis : lignes ignorées.
                e.tickets.forEach(t => { t.lignes = t.lignes.filter(l => produits.has(l.produitId)); });
                return e;
            }
        } catch (err) { /* stockage indisponible ou illisible */ }
        return { compteur: 1, actif: 0, tickets: [nouveauTicket(1)] };
    }

    function enregistrer() {
        if (cmd) { planifierSync(); return; }
        try { localStorage.setItem(D.cle, JSON.stringify(etat)); } catch (err) { /* navigation privée… */ }
    }

    function nouveauTicket(numero) {
        return { numero: numero, lignes: [], clientId: null, choisie: -1 };
    }

    const ticket = () => cmd || etat.tickets[etat.actif];

    // ------------------------------------------------------------------
    // Calculs (prix TTC ; les taxes sont comprises, l.tva = taux total du produit)
    // ------------------------------------------------------------------
    const totalLigne = l => Math.round(l.qte * l.prix * (1 - (l.remise || 0) / 100));
    // Remise globale du ticket (en % ou en montant), répartie sur les lignes par le serveur.
    function montantRemise(t, brut) {
        const r = t.remise;
        if (!r || !(r.valeur > 0) || brut <= 0) return 0;
        return r.type === 'pct' ? Math.round(brut * Math.min(100, r.valeur) / 100) : Math.min(brut, Math.round(r.valeur));
    }
    function totaux(t) {
        let brut = 0, tva = 0, unites = 0;
        t.lignes.forEach(l => {
            const tl = totalLigne(l);
            brut += tl;
            tva += tl - tl / (1 + (l.tva || 0) / 100);
            unites += l.qte;
        });
        const remise = montantRemise(t, brut);
        const ttc = brut - remise;
        return { brut: brut, remise: remise, ttc: ttc, tva: Math.round(brut > 0 ? tva * ttc / brut : 0), unites: unites };
    }
    // Frais de livraison du ticket (commande à livrer) : en plus du total, hors taxes.
    function fraisLivraison(t) {
        return !cmd && t && t.livraison ? Math.max(0, Math.round(t.livraison.frais || 0)) : 0;
    }
    function quantiteAuTicket(produitId) {
        return ticket().lignes.filter(l => l.produitId === produitId).reduce((s, l) => s + l.qte, 0);
    }
    const variantes = p => variantesDe.get(p.id) || [];

    // ------------------------------------------------------------------
    // Actions
    // ------------------------------------------------------------------
    // Vente sans stock interdite (option de la société) pour un produit suivi.
    const stockBloque = (p, qteVoulue) => D.venteSansStock === false && p.suivi && qteVoulue > p.stock;

    function ajouterProduit(p) {
        if (p.modele) { choisirVariante(p); return; }
        if (p.combo && p.combo.length) { choisirCombo(p); return; }
        const t = ticket();
        if (stockBloque(p, quantiteAuTicket(p.id) + 1)) {
            message('Stock épuisé pour « ' + p.nom + ' » : ' + qte(Math.max(0, p.stock)) + ' disponible(s).', true);
            return;
        }
        let i = t.lignes.findIndex(l => l.produitId === p.id && l.prix === p.prix && !l.remise && !l.note);
        if (i >= 0) {
            t.lignes[i].qte += 1;
        } else {
            t.lignes.push({ uid: identifiant(), produitId: p.id, nom: p.nom, qte: 1, prix: p.prix, remise: 0, tva: p.tva, unite: p.unite, note: '', envoye: 0 });
            i = t.lignes.length - 1;
        }
        t.choisie = i;
        mode = 'qte';
        saisie = null;
        if (p.suivi && quantiteAuTicket(p.id) > p.stock && D.venteSansStock !== false) {
            message('Stock insuffisant pour « ' + p.nom + ' » : ' + qte(p.stock) + ' en stock.', true);
        }
        enregistrer();
        afficher();
    }

    function trouverParCode(code) {
        const c = code.trim().toLowerCase();
        if (!c) return null;
        return D.produits.find(p => (p.codeBarres || '').toLowerCase() === c)
            || D.produits.find(p => p.code.toLowerCase() === c) || null;   // un modèle ouvre le choix de la variante
    }

    function scanner(code) {
        const p = trouverParCode(code);
        if (p) ajouterProduit(p);
        else message('Code inconnu : ' + code, true);
    }

    // Pavé numérique : la première touche remplace la valeur, les suivantes s'ajoutent.
    function touche(k) {
        const t = ticket();
        const l = t.lignes[t.choisie];
        if (!l) { message('Choisissez d\'abord une ligne du ticket.'); return; }
        if (k === 'suppr') { supprimerLigne(); return; }
        if (k === 'raz') {
            saisie = '';
        } else if (k === 'efface') {
            if (saisie === null || saisie === '') {
                if (mode === 'qte') { supprimerLigne(); return; }
                saisie = '';
            } else {
                saisie = saisie.slice(0, -1);
            }
        } else {
            saisie = (saisie === null ? '' : saisie) + k;
            if (k === ',' && (saisie.match(/,/g) || []).length > 1) saisie = saisie.slice(0, -1);
        }
        const v = parseFloat((saisie || '0').replace(',', '.')) || 0;
        const p = produits.get(l.produitId);
        if (mode === 'qte' && p && stockBloque(p, quantiteAuTicket(p.id) - l.qte + v)) {
            message('Stock insuffisant pour « ' + p.nom + ' » : ' + qte(Math.max(0, p.stock)) + ' disponible(s).', true);
            saisie = saisie.slice(0, -1);
            return;
        }
        if (mode === 'qte') l.qte = v;
        else if (mode === 'remise') l.remise = Math.min(100, v);
        else if (mode === 'prix') l.prix = v;
        enregistrer();
        afficher();
    }

    function choisirMode(m) {
        if (m === 'prix' && !D.peutModifierPrix) {
            message('Seul un administrateur peut modifier le prix.', true);
            return;
        }
        mode = m;
        saisie = null;
        afficher();
    }

    function supprimerLigne() {
        const t = ticket();
        if (t.choisie < 0) return;
        if (cmd && t.lignes[t.choisie] && t.lignes[t.choisie].envoye > 0) cmd.retire = true;   // annulation à envoyer
        t.lignes.splice(t.choisie, 1);
        t.choisie = Math.min(t.choisie, t.lignes.length - 1);
        saisie = null;
        enregistrer();
        afficher();
    }

    function nouveauTicketActif() {
        etat.compteur += 1;
        etat.tickets.push(nouveauTicket(etat.compteur));
        etat.actif = etat.tickets.length - 1;
        mode = 'qte';
        saisie = null;
        enregistrer();
        afficher();
    }

    function fermerTicket(i) {
        const t = etat.tickets[i];
        if (t.lignes.length && !confirm('Abandonner le ticket ' + t.numero + ' (' + t.lignes.length + ' article(s)) ?')) return;
        etat.tickets.splice(i, 1);
        if (!etat.tickets.length) {
            etat.compteur += 1;
            etat.tickets.push(nouveauTicket(etat.compteur));
        }
        etat.actif = Math.min(etat.actif, etat.tickets.length - 1);
        enregistrer();
        afficher();
    }

    // partage : { uid: quantité payée maintenant } pour une addition partagée (restaurant).
    async function payer(partage) {
        if (!ticket().lignes.length) { message('Le ticket est vide.'); return; }
        if (ticket().lignes.some(l => l.qte <= 0)) { message('Une ligne a une quantité nulle : corrigez-la ou supprimez-la.', true); return; }
        if (cmd) {
            // Articles pas encore envoyés : envoyés en préparation avant l'encaissement.
            if (aEnvoyer() && !(await envoyer(true))) return;
            if (!(await vider()) || !cmd || (!cmd.id && !cmd.cleFile)) { message('La commande de la table n\'est pas enregistrée : vérifiez la connexion.', true); return; }
        }
        pay = { lignes: [], choisie: -1, saisie: null, envoi: false, pourboire: 0, partage: partage || null };
        vue = 'paiement';
        afficher();
    }

    // Lignes encaissées : toutes, ou la part choisie pour une addition partagée.
    function lignesAPayer() {
        const t = ticket();
        if (!pay || !pay.partage) return t.lignes;
        return t.lignes.filter(l => (pay.partage[l.uid] || 0) > 0).map(l => Object.assign({}, l, { qte: pay.partage[l.uid] }));
    }

    // Articles qui restent sur la table après une addition partagée.
    function resteApresPaiement() {
        if (!pay || !pay.partage) return [];
        return ticket().lignes.map(l => Object.assign({}, l, { qte: Math.round((l.qte - (pay.partage[l.uid] || 0)) * 100) / 100 }))
            .filter(l => l.qte > 0)
            .map(l => ({ uid: l.uid, produitId: l.produitId, nom: l.nom, qte: l.qte, prix: l.prix, remise: l.remise || 0, tva: l.tva, unite: l.unite, note: l.note || '', composants: l.composants || [] }));
    }

    // ------------------------------------------------------------------
    // Restaurant / bar : commande de la table, gardée sur le serveur
    // ------------------------------------------------------------------
    function donneesCommande() {
        return {
            journeeId: D.journee.id, tableId: cmd.tableId, id: cmd.id, version: cmd.version, couverts: cmd.couverts,
            lignes: cmd.lignes.map(l => ({ uid: l.uid, produitId: l.produitId, nom: l.nom, qte: l.qte, prix: l.prix, remise: l.remise || 0, tva: l.tva, unite: l.unite, note: l.note || '', composants: l.composants || [], envoye: l.envoye || 0 })),
            clientId: cmd.clientId, remise: cmd.remise || null
        };
    }

    // Commande de table sans connexion : gardée dans la file du poste (un élément par table, remplacé à
    // chaque modification), envoyée au retour de la connexion ; le plan de salle du poste est mis à jour.
    function garderTable() {
        if (!cmd || !F) return false;
        if (!cmd.cleFile) {
            const deja = tablesHorsLigne().find(x => x.donnees.tableId === cmd.tableId);
            cmd.cleFile = deja ? deja.cle : 'table:' + D.journee.id + ':' + cmd.tableId + ':' + Date.now().toString(36);
        }
        const existant = F.trouver(cmd.cleFile);
        const d = donneesCommande();
        const t = tableDe(cmd.tableId);
        if (!d.lignes.length && !d.id) {
            // Commande vidée qui n'a jamais été envoyée : rien à envoyer.
            if (existant) F.retirer(existant.numero);
            cmd.cleFile = null;
            if (t) t.commande = null;
            garderPlan();
            return true;
        }
        const numero = existant ? existant.numero : F.numeroProvisoire();
        d.horsLigne = { date: new Date().toISOString(), numero: numero, vendeur: D.utilisateur.nom };
        const ok = F.mettre({
            type: 'table', cle: cmd.cleFile, numero: numero, libelle: cmd.table + ' · commande', montant: totaux(cmd).ttc,
            journeeId: D.journee.id, url: R.urlEnregistrer, urlJeton: D.urlJeton, champ: 'commande', donnees: d, base: cmd.base || {}
        });
        if (!ok) { message('Stockage du navigateur indisponible : la commande de la table ne peut pas être gardée hors ligne.', true); return false; }
        if (t) t.commande = resumeLocal(d, t.commande);
        garderPlan();
        return true;
    }

    // POST d'un objet JSON (champ « champ ») ; renvoie { ok, status, r }.
    async function appel(url, champ, donnees) {
        const corps = new FormData();
        corps.append(D.jeton.nom, D.jeton.valeur);
        corps.append(champ, JSON.stringify(donnees));
        try {
            const res = await fetch(url, { method: 'POST', body: corps, credentials: 'same-origin' });
            const r = await res.json().catch(() => null);
            return { ok: res.ok && !!r && !r.erreur, status: res.status, r: r };
        } catch (err) {
            return { ok: false, status: 0, r: null };
        }
    }

    function commandeDepuis(s, table) {
        const t = table || tableDe(s.tableId) || {};
        return {
            id: s.id, version: s.version, tableId: s.tableId || t.id, table: t.nom || 'Table', couverts: s.couverts, addition: !!s.addition,
            lignes: (s.lignes || []).map(l => Object.assign({}, l)), clientId: s.clientId || null, remise: s.remise || null, choisie: -1, retire: false,
            // Articles connus du serveur (fusion si la table est modifiée ailleurs pendant une coupure).
            base: Object.fromEntries((s.lignes || []).map(l => [l.uid, l.qte])), cleFile: null
        };
    }

    // Réponse du serveur appliquée à la commande affichée (identifiant, version, quantités envoyées).
    function appliquerServeur(s) {
        if (!cmd) return;
        if (!s) { cmd.id = 0; cmd.version = 0; cmd.addition = false; cmd.lignes.forEach(l => { l.envoye = 0; }); return; }
        cmd.id = s.id; cmd.version = s.version; cmd.addition = !!s.addition;
        cmd.base = Object.fromEntries((s.lignes || []).map(l => [l.uid, l.qte]));
        const envoye = new Map((s.lignes || []).map(l => [l.uid, l.envoye]));
        cmd.lignes.forEach(l => { l.envoye = envoye.get(l.uid) || 0; });
    }

    // Modification sur un autre appareil (409) : la commande du serveur remplace celle affichée.
    function traiterEchec(res) {
        if (res.status === 409 && res.r && cmd) {
            const tbl = { id: cmd.tableId, nom: cmd.table };
            cmd = res.r.commande ? commandeDepuis(res.r.commande, tbl)
                : { id: 0, version: 0, tableId: tbl.id, table: tbl.nom, couverts: cmd.couverts, addition: false, lignes: [], clientId: null, remise: null, choisie: -1, retire: false };
            message(res.r.erreur, true);
            afficher();
            return;
        }
        message(res.r && res.r.erreur ? res.r.erreur : 'Connexion impossible : la commande de la table n\'est pas enregistrée (nouvel essai à la prochaine modification).', true);
    }

    function planifierSync() {
        clearTimeout(sync.minuterie);
        sync.minuterie = setTimeout(synchroniser, 400);
    }

    async function synchroniser() {
        if (!cmd) return true;
        // Hors ligne, ou commande déjà dans la file du poste (l'ordre des envois est gardé).
        if (cmd.cleFile || horsLigne()) { clearTimeout(sync.minuterie); return garderTable(); }
        if (sync.enCours) { sync.encore = true; return true; }
        clearTimeout(sync.minuterie);
        sync.enCours = true;
        const c = cmd;
        const res = await appel(R.urlEnregistrer, 'commande', donneesCommande());
        sync.enCours = false;
        if (res.status === 0 && F && cmd === c) { window.gcConnexion.verifier(); return garderTable(); }
        if (cmd !== c) return res.ok;
        if (!res.ok) { traiterEchec(res); return false; }
        appliquerServeur(res.r.commande);
        if (sync.encore) { sync.encore = false; return synchroniser(); }
        if (vue === 'vente' && document.activeElement?.id !== 'posRecherche') afficher();
        return true;
    }

    // Attend la fin de l'enregistrement en cours puis enregistre la dernière version.
    async function vider() {
        while (sync.enCours) await new Promise(r => setTimeout(r, 80));
        return synchroniser();
    }

    const aEnvoyer = () => !!cmd && (cmd.retire || cmd.lignes.some(l => Math.abs(l.qte - (l.envoye || 0)) >= 0.01));
    const nbAEnvoyer = () => cmd ? cmd.lignes.reduce((n, l) => n + Math.max(0, l.qte - (l.envoye || 0)), 0) : 0;

    // Iframe cachée : bons de préparation et addition s'impriment sans quitter l'écran.
    function cadreImpression() {
        let f = document.getElementById('posImpression');
        if (!f) {
            f = document.createElement('iframe');
            f.id = 'posImpression';
            f.name = 'posImpression';
            f.title = 'Impression';
            f.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0';
            document.body.appendChild(f);
        }
        return f;
    }
    function imprimerDans(url) { const f = cadreImpression(); f.removeAttribute('srcdoc'); f.src = url; }
    // Ticket fabriqué sur le poste (hors ligne) : imprimé dès son chargement.
    function imprimerHtml(html) {
        const f = cadreImpression();
        f.removeAttribute('src');
        f.srcdoc = html.replace('</body>', '<script>window.addEventListener("load", function () { window.print(); });<\/script></body>');
    }

    // Addition (note provisoire « NON PAYÉ ») d'un ticket hors table : le ticket est envoyé au serveur,
    // qui reprend les prix du catalogue et imprime l'addition dans le cadre caché.
    function additionTicket() {
        const t = ticket();
        if (!t.lignes.length) { message('Le ticket est vide.'); return; }
        cadreImpression();
        const form = document.createElement('form');
        form.method = 'post';
        form.action = D.urlAdditionTicket;
        form.target = 'posImpression';
        form.style.display = 'none';
        const champ = (nom, valeur) => { const i = document.createElement('input'); i.type = 'hidden'; i.name = nom; i.value = valeur; form.appendChild(i); };
        champ(D.jeton.nom, D.jeton.valeur);
        champ('ticket', JSON.stringify({
            journeeId: D.journee.id, numero: t.numero, clientId: t.clientId, remise: t.remise || null,
            livraison: t.livraison ? { frais: fraisLivraison(t) } : null,
            lignes: t.lignes.map(l => ({ uid: l.uid, produitId: l.produitId, nom: l.nom, qte: l.qte, prix: l.prix, remise: l.remise || 0, composants: l.composants || [] }))
        }));
        document.body.appendChild(form);
        form.submit();
        form.remove();
        message('Addition imprimée (NON PAYÉ).');
    }

    // Envoie en cuisine / au bar les articles pas encore envoyés (et les annulations).
    async function envoyer(silencieux) {
        if (!cmd) return true;
        if (!aEnvoyer()) { if (!silencieux) message('Tous les articles sont déjà envoyés.'); return true; }
        if (cmd.cleFile || horsLigne()) { envoyerHorsLigne(); return true; }
        while (sync.enCours) await new Promise(r => setTimeout(r, 80));
        clearTimeout(sync.minuterie);
        sync.enCours = true;
        const res = await appel(R.urlEnvoyer, 'commande', donneesCommande());
        sync.enCours = false;
        if (!res.ok) { traiterEchec(res); return false; }
        appliquerServeur(res.r.commande);
        cmd.retire = false;
        const bons = res.r.bons || [];
        if (bons.length) {
            if (R.imprimerBons) imprimerDans(R.urlBons + bons.join(','));
            message(bons.length > 1 ? 'Commande envoyée en cuisine et au bar.' : 'Commande envoyée en préparation.');
        } else if (!silencieux) {
            message('Rien à préparer : ces articles n\'ont pas de poste de préparation.');
        }
        afficher();
        return true;
    }

    // Sans connexion, l'écran cuisine ne reçoit rien : bon imprimé sur le poste (si la caisse imprime
    // ses bons) et articles notés « envoyés » ; à annoncer en cuisine ou au bar.
    function envoyerHorsLigne() {
        const nouveaux = cmd.lignes.map(l => ({ l: l, delta: Math.round((l.qte - (l.envoye || 0)) * 100) / 100 })).filter(x => Math.abs(x.delta) >= 0.01);
        if (R.imprimerBons && nouveaux.length) {
            imprimerHtml(enteteTicket('Bon ' + cmd.table) + '<div class="ticket"><div class="c b grand">BON DE PRÉPARATION</div>'
                + '<div class="c b">' + echap(cmd.table) + ' · ' + cmd.couverts + ' couvert(s)</div><div class="c petit">Hors ligne · ' + dateFr(new Date()) + ' · ' + echap(D.utilisateur.nom) + '</div><hr>'
                + nouveaux.map(x => '<div class="b">' + (x.delta < 0 ? 'ANNULÉ ' : '') + qte(Math.abs(x.delta)) + ' x ' + echap(x.l.nom) + '</div>'
                    + (x.l.composants || []).map(c => '<div class="ind petit">· ' + qte(c.qte) + ' x ' + echap(c.nom) + '</div>').join('')
                    + (x.l.note ? '<div class="ind note">» ' + echap(x.l.note) + '</div>' : '')).join('')
                + '</div></body></html>');
        }
        cmd.lignes.forEach(l => { l.envoye = l.qte; });
        cmd.retire = false;
        garderTable();
        message('Hors ligne : ' + (R.imprimerBons ? 'bon imprimé sur ce poste, ' : '') + 'annoncez la commande en cuisine ou au bar (l\'écran cuisine ne la reçoit pas).', true);
        afficher();
    }

    function tableDe(id) {
        for (const s of salles) for (const t of s.tables) if (t.id === id) return t;
        return null;
    }

    async function rafraichirPlan() {
        if (!R) return;
        try {
            const res = await fetch(R.urlPlan, { credentials: 'same-origin', cache: 'no-store' });
            const r = await res.json();
            if (res.ok && r.salles) { salles = r.salles; superposer(); garderPlan(); if (vue === 'plan') afficher(); }
        } catch (err) { /* nouvel essai à la prochaine actualisation */ }
    }

    async function ouvrirTable(t) {
        let s = null;
        // Commande de cette table prise hors ligne sur ce poste, pas encore envoyée : elle continue ici.
        const locale = tablesHorsLigne().find(x => x.donnees.tableId === t.id);
        if (locale) {
            cmd = commandeDepuis(Object.assign({}, locale.donnees, { addition: t.commande && t.commande.addition }), t);
            cmd.cleFile = locale.cle;
            cmd.base = locale.base || {};
            vue = 'vente'; mode = 'qte'; saisie = null;
            afficher();
            return;
        }
        let horsReseau = horsLigne();
        if (!horsReseau) {
            try {
                const res = await fetch(R.urlCommande + '&table=' + t.id, { credentials: 'same-origin', cache: 'no-store' });
                const r = await res.json();
                if (!res.ok || r.erreur) throw new Error(r.erreur || 'Erreur ' + res.status);
                s = r.commande;
            } catch (err) {
                if (!(F && err instanceof TypeError)) {
                    message(err.message && !/fetch|network|JSON/i.test(err.message) ? err.message : 'Connexion impossible : réessayez.', true);
                    return;
                }
                horsReseau = true;
                window.gcConnexion.verifier();
            }
        }
        if (horsReseau) {
            // Sans connexion : la commande telle que le plan du poste la connaît.
            if (t.commande && !t.commande.lignes) { message('Commande de ' + t.nom + ' inconnue sur ce poste : attendez la connexion.', true); return; }
            s = t.commande ? Object.assign({ tableId: t.id }, t.commande) : null;
        }
        if (s) {
            cmd = commandeDepuis(s, t);
        } else {
            const n = await demanderCouverts(t.nom, Math.min(2, t.places));
            if (!n) return;
            cmd = { id: 0, version: 0, tableId: t.id, table: t.nom, couverts: n, addition: false, lignes: [], clientId: null, remise: null, choisie: -1, retire: false };
        }
        vue = 'vente';
        mode = 'qte';
        saisie = null;
        afficher();
    }

    async function retourPlan() {
        if (cmd) {
            if (aEnvoyer() && cmd.lignes.length && confirm('Des articles ne sont pas encore envoyés en préparation. Les envoyer maintenant ?')) {
                await envoyer(true);
            }
            await vider();
        }
        cmd = null;
        vue = 'plan';
        afficher();
        rafraichirPlan();
    }

    // Fenêtre : nombre de couverts (boutons rapides ou saisie).
    function demanderCouverts(titre, defaut) {
        return new Promise(resoudre => {
            const fond = document.createElement('div');
            fond.className = 'pos-modal-fond';
            fond.innerHTML = '<div class="pos-modal pos-modal-remise" role="dialog" aria-modal="true" aria-label="Couverts">'
                + '<div class="pos-modal-tete">' + echap(titre) + ' · couverts<button type="button" data-close aria-label="Fermer">×</button></div>'
                + '<div class="pos-remise-corps"><div class="pos-couverts">'
                + [1, 2, 3, 4, 5, 6, 7, 8].map(n => '<button type="button" data-n="' + n + '">' + n + '</button>').join('') + '</div>'
                + '<input inputmode="numeric" autocomplete="off" aria-label="Nombre de couverts" value="' + defaut + '">'
                + '<div class="pos-remise-boutons"><button type="button" class="pos-big" data-ok>Valider</button></div></div></div>';
            document.body.appendChild(fond);
            const champ = fond.querySelector('input');
            const fermer = v => { fond.remove(); resoudre(v); };
            const valeur = () => Math.max(1, Math.min(99, parseInt(champ.value, 10) || 0));
            fond.addEventListener('click', e => {
                if (e.target === fond || e.target.closest('[data-close]')) fermer(null);
                else if (e.target.closest('[data-n]')) fermer(Number(e.target.closest('[data-n]').dataset.n));
                else if (e.target.closest('[data-ok]')) fermer(valeur());
            });
            fond.addEventListener('keydown', e => {
                if (e.key === 'Escape') fermer(null);
                else if (e.key === 'Enter') { e.preventDefault(); fermer(valeur()); }
            });
            champ.focus();
            champ.select();
        });
    }

    async function changerCouverts() {
        const n = await demanderCouverts(cmd.table, cmd.couverts);
        if (!n) return;
        cmd.couverts = n;
        enregistrer();
        afficher();
    }

    async function addition() {
        if (!cmd.lignes.length) { message('La commande est vide.'); return; }
        if (cmd.cleFile || horsLigne()) {
            // Addition imprimée sur le poste (NON PAYÉ).
            await vider();
            const tot = totaux(cmd);
            imprimerHtml(enteteTicket('Addition ' + cmd.table) + '<div class="ticket">' + societeTicket() + '<hr>'
                + '<div class="c b grand">ADDITION</div><div class="non-paye">NON PAYÉ</div>'
                + '<div>Table  : ' + echap(cmd.table) + ' · ' + cmd.couverts + ' couvert(s)</div><div>Date   : ' + dateFr(new Date()) + '</div><hr>'
                + cmd.lignes.map(ligneTicket).join('') + '<hr>'
                + (tot.remise ? ligneR('Sous-total', fcfa(tot.brut)) + ligneR('Remise globale', '-' + fcfa(tot.remise)) : '')
                + ligneR('TOTAL TTC', fcfa(tot.ttc) + ' FCFA', 'b grand') + '<hr><div class="c petit">Addition provisoire (hors ligne)</div></div></body></html>');
            cmd.addition = true;
            const t = tableDe(cmd.tableId);
            if (t && t.commande) { t.commande.addition = true; garderPlan(); }
            message('Addition imprimée sur ce poste (hors ligne).');
            afficher();
            return;
        }
        if (!(await vider()) || !cmd.id) return;
        imprimerDans(R.urlAddition + cmd.id);
        cmd.addition = true;
        message('Addition imprimée : la table passe en « addition demandée ».');
        afficher();
    }

    // Fenêtre : table de destination (une table occupée reçoit les articles en plus des siens).
    async function transferer() {
        if (!cmd.lignes.length) { message('La commande est vide.'); return; }
        if (cmd.cleFile || horsLigne()) { message('Le transfert de table demande la connexion (la commande prise hors ligne doit d\'abord être envoyée).', true); return; }
        if (!(await vider()) || !cmd.id) return;
        await rafraichirPlan();
        const fond = document.createElement('div');
        fond.className = 'pos-modal-fond';
        fond.innerHTML = '<div class="pos-modal" role="dialog" aria-modal="true" aria-label="Transférer la commande">'
            + '<div class="pos-modal-tete">Transférer ' + echap(cmd.table) + ' vers…<button type="button" data-close aria-label="Fermer">×</button></div>'
            + '<div class="pos-modal-liste">' + salles.map(s => '<div class="pos-transfert-salle">' + echap(s.nom) + '</div>'
                + s.tables.filter(t => t.id !== cmd.tableId).map(t => '<button type="button" class="pos-client" data-cible="' + t.id + '">'
                    + echap(t.nom) + '<small>' + (t.commande ? 'occupée · ' + fcfa(t.commande.total) + ' FCFA (les commandes seront regroupées)' : 'libre') + '</small></button>').join('')).join('')
            + '</div></div>';
        document.body.appendChild(fond);
        const fermer = () => fond.remove();
        fond.addEventListener('click', async e => {
            if (e.target === fond || e.target.closest('[data-close]')) { fermer(); return; }
            const b = e.target.closest('[data-cible]');
            if (!b) return;
            fermer();
            const cible = tableDe(Number(b.dataset.cible));
            const res = await appel(R.urlTransferer, 'commande', { journeeId: D.journee.id, id: cmd.id, version: cmd.version, cibleId: cible.id });
            if (!res.ok) { traiterEchec(res); return; }
            const depuis = cmd.table;
            cmd = commandeDepuis(res.r.commande, cible);
            message('Commande de ' + depuis + ' transférée vers ' + cible.nom + '.');
            afficher();
            rafraichirPlan();
        });
        fond.addEventListener('keydown', e => { if (e.key === 'Escape') fermer(); });
    }

    // Fenêtre : note de l'article choisi (« sans oignon »…), imprimée sur le bon.
    function noteLigne() {
        const t = ticket();
        const l = t.lignes[t.choisie];
        if (!l) { message('Choisissez d\'abord un article du ticket.'); return; }
        const suggestions = ['Sans oignon', 'Sans piment', 'Bien cuit', 'À point', 'Saignant', 'Sans sel', 'Sans glace', 'À emporter'];
        const fond = document.createElement('div');
        fond.className = 'pos-modal-fond';
        fond.innerHTML = '<div class="pos-modal pos-modal-remise" role="dialog" aria-modal="true" aria-label="Note">'
            + '<div class="pos-modal-tete">Note · ' + echap(l.nom) + '<button type="button" data-close aria-label="Fermer">×</button></div>'
            + '<div class="pos-remise-corps"><div class="pos-notes">' + suggestions.map(n => '<button type="button" data-note="' + echap(n) + '">' + echap(n) + '</button>').join('') + '</div>'
            + '<input maxlength="200" autocomplete="off" aria-label="Note de l\'article" value="' + echap(l.note || '') + '" placeholder="Ex : sans oignon, bien cuit">'
            + '<div class="pos-remise-boutons">' + (l.note ? '<button type="button" class="pos-sec" data-retirer>Retirer</button>' : '')
            + '<button type="button" class="pos-big" data-ok>Enregistrer</button></div></div></div>';
        document.body.appendChild(fond);
        const champ = fond.querySelector('input');
        const fermer = () => fond.remove();
        const valider = v => { l.note = v.trim().slice(0, 200); enregistrer(); fermer(); afficher(); };
        fond.addEventListener('click', e => {
            if (e.target === fond || e.target.closest('[data-close]')) { fermer(); return; }
            const b = e.target.closest('[data-note]');
            if (b) { champ.value = champ.value.trim() ? champ.value.trim() + ', ' + b.dataset.note.toLowerCase() : b.dataset.note; champ.focus(); return; }
            if (e.target.closest('[data-retirer]')) valider('');
            else if (e.target.closest('[data-ok]')) valider(champ.value);
        });
        fond.addEventListener('keydown', e => {
            if (e.key === 'Escape') fermer();
            else if (e.key === 'Enter') { e.preventDefault(); valider(champ.value); }
        });
        champ.focus();
    }

    // Fenêtre : addition partagée (quantité de chaque article payée maintenant).
    function partager() {
        const t = ticket();
        if (!t.lignes.length) { message('La commande est vide.'); return; }
        if (cmd && (cmd.cleFile || horsLigne())) { message('Hors ligne, l\'addition s\'encaisse en une fois : le partage demande la connexion.', true); return; }
        if (t.remise) { message('Retirez la remise globale pour partager l\'addition.', true); return; }
        const choix = {};
        const fond = document.createElement('div');
        fond.className = 'pos-modal-fond';
        const total = () => t.lignes.reduce((s, l) => s + Math.round((choix[l.uid] || 0) * l.prix * (1 - (l.remise || 0) / 100)), 0);
        const remplir = () => {
            fond.querySelector('.pos-modal-liste').innerHTML = t.lignes.map(l => '<div class="pos-partage">'
                + '<div class="n">' + echap(l.nom) + '<small>' + qte(l.qte) + ' × ' + fcfa(l.prix) + '</small></div>'
                + '<button type="button" data-moins="' + l.uid + '" aria-label="Moins">−</button><b>' + qte(choix[l.uid] || 0) + '</b>'
                + '<button type="button" data-plus="' + l.uid + '" aria-label="Plus">+</button>'
                + '<button type="button" class="tout" data-tout="' + l.uid + '">Tout</button></div>').join('');
            fond.querySelector('[data-payer]').innerHTML = '<i class="fas fa-money-bill-wave"></i> Payer ' + fcfa(total()) + ' FCFA';
        };
        fond.innerHTML = '<div class="pos-modal" role="dialog" aria-modal="true" aria-label="Partager l\'addition">'
            + '<div class="pos-modal-tete">Partager l\'addition · ' + echap(cmd.table) + '<button type="button" data-close aria-label="Fermer">×</button></div>'
            + '<div class="pos-aide" style="margin:10px 18px 0">Choisissez les articles payés maintenant ; les autres restent sur la table.</div>'
            + '<div class="pos-modal-liste"></div>'
            + '<div class="pos-remise-boutons" style="padding:0 18px 16px"><button type="button" class="pos-big" data-payer></button></div></div>';
        document.body.appendChild(fond);
        remplir();
        const fermer = () => fond.remove();
        fond.addEventListener('click', e => {
            if (e.target === fond || e.target.closest('[data-close]')) { fermer(); return; }
            const b = e.target.closest('button');
            if (!b) return;
            const l = t.lignes.find(x => x.uid === (b.dataset.plus || b.dataset.moins || b.dataset.tout));
            if (l) {
                const v = choix[l.uid] || 0;
                choix[l.uid] = b.dataset.tout ? (v === l.qte ? 0 : l.qte) : Math.max(0, Math.min(l.qte, v + (b.dataset.plus ? 1 : -1)));
                remplir();
            } else if (b.dataset.payer !== undefined) {
                if (total() <= 0 && !Object.values(choix).some(v => v > 0)) { message('Choisissez au moins un article.'); return; }
                const toutPaye = t.lignes.every(x => (choix[x.uid] || 0) >= x.qte);
                fermer();
                payer(toutPaye ? null : choix);
            }
        });
        fond.addEventListener('keydown', e => { if (e.key === 'Escape') fermer(); });
    }

    // Fenêtre : pourboire (montant ou pourcentage du total).
    function pourboire() {
        const base = etatPaiement().ttc;
        const fond = document.createElement('div');
        fond.className = 'pos-modal-fond';
        fond.innerHTML = '<div class="pos-modal pos-modal-remise" role="dialog" aria-modal="true" aria-label="Pourboire">'
            + '<div class="pos-modal-tete">Pourboire<button type="button" data-close aria-label="Fermer">×</button></div>'
            + '<div class="pos-remise-corps"><div class="pos-remise-types">' + [5, 10, 15].map(p => '<button type="button" data-pct="' + p + '">' + p + ' %</button>').join('') + '</div>'
            + '<input inputmode="numeric" autocomplete="off" aria-label="Montant du pourboire" value="' + (pay.pourboire || '') + '" placeholder="Montant en FCFA">'
            + '<div class="pos-remise-apercu">Total de la commande : <b>' + fcfa(base) + ' FCFA</b></div>'
            + '<div class="pos-remise-boutons">' + (pay.pourboire ? '<button type="button" class="pos-sec" data-retirer>Retirer</button>' : '')
            + '<button type="button" class="pos-big" data-ok>Appliquer</button></div></div></div>';
        document.body.appendChild(fond);
        const champ = fond.querySelector('input');
        const fermer = () => fond.remove();
        const appliquer = v => { pay.pourboire = Math.max(0, Math.round(v || 0)); fermer(); afficher(); };
        fond.addEventListener('click', e => {
            if (e.target === fond || e.target.closest('[data-close]')) { fermer(); return; }
            const b = e.target.closest('[data-pct]');
            if (b) { champ.value = Math.round(base * Number(b.dataset.pct) / 100); champ.focus(); return; }
            if (e.target.closest('[data-retirer]')) appliquer(0);
            else if (e.target.closest('[data-ok]')) appliquer(parseInt(champ.value.replace(/\s/g, ''), 10));
        });
        fond.addEventListener('keydown', e => {
            if (e.key === 'Escape') fermer();
            else if (e.key === 'Enter') { e.preventDefault(); appliquer(parseInt(champ.value.replace(/\s/g, ''), 10)); }
        });
        champ.focus();
    }

    // Plan de salle : tables placées comme dans le restaurant, couleur selon l'état.
    function afficherPlan() {
        if (salleActive >= salles.length) salleActive = 0;
        const s = salles[salleActive];
        const L = 1000, H = 600;
        const occupees = salles.reduce((n, x) => n + x.tables.filter(t => t.commande).length, 0);
        racine.innerHTML = '<div class="pos-top">'
            + '<span class="pos-logo">GC</span>'
            + '<div class="pos-titre"><strong>' + (R.type === 'Bar' ? 'Bar' : 'Restaurant') + ' · ' + echap(D.journee.caisse) + '</strong>'
            + '<small>' + echap(D.journee.libelle) + '</small></div>'
            + '<div class="pos-tabs">' + salles.map((x, i) => '<button type="button" class="pos-tab' + (i === salleActive ? ' on' : '') + '" data-salle="' + i + '">'
                + echap(x.nom) + '</button>').join('') + '</div>'
            + '<div class="pos-droite">' + connexion()
            + '<button type="button" class="pos-btn-top" data-action="directe"><i class="fas fa-bag-shopping"></i> Vente directe</button>'
            + boutonAttentes()
            + '<a class="pos-btn-top" href="' + echap(R.urlCuisine) + '" target="_blank" rel="noopener"><i class="fas fa-fire-burner"></i> Écran cuisine</a>'
            + (D.urlVentes ? '<a class="pos-btn-top" href="' + echap(D.urlVentes) + '"><i class="fas fa-receipt"></i> Ventes</a>' : '')
            + '<a class="pos-btn-top rouge" href="' + echap(D.urlFermer) + '"><i class="fas fa-power-off"></i> Fermer</a>'
            + '</div></div>'
            + '<div class="pos-plan-zone">'
            + (s
                ? '<div class="pos-plan">' + s.tables.map(t => {
                    const c = t.commande;
                    const etat = !c ? 'libre' : c.addition ? 'addition' : 'occupee';
                    const depuis = c ? Math.max(0, Math.floor((Date.now() - new Date(String(c.depuis).replace(' ', 'T')).getTime()) / 60000)) : 0;
                    return '<button type="button" class="pos-tablepl ' + etat + (t.forme === 'ronde' ? ' ronde' : '') + '" data-table="' + t.id + '"'
                        + ' style="left:' + (t.x / L * 100) + '%;top:' + (t.y / H * 100) + '%;width:' + (t.l / L * 100) + '%;height:' + (t.h / H * 100) + '%">'
                        + (c && c.aEnvoyer ? '<span class="pastille" title="Articles pas encore envoyés en préparation"></span>' : '')
                        + '<span class="n">' + echap(t.nom) + '</span>'
                        + (c ? '<span class="t">' + fcfa(c.total) + '</span><span class="d"><i class="fas fa-user"></i> ' + c.couverts + ' · ' + depuis + ' min</span>'
                            : '<span class="d"><i class="fas fa-user"></i> ' + t.places + '</span>')
                        + '</button>';
                }).join('') + (s.tables.length ? '' : '<div class="pos-plan-vide">Aucune table dans cette salle.</div>') + '</div>'
                : '<div class="pos-plan-vide seul"><i class="fas fa-chair"></i>Aucune salle n\'est configurée pour cette caisse.<br>'
                    + 'Un administrateur crée les salles et les tables dans Caisses › Plan de salle.<br>'
                    + '<button type="button" class="pos-sec" data-action="directe"><i class="fas fa-bag-shopping"></i> Vente directe</button></div>')
            + '<div class="pos-plan-legende"><span class="libre"></span> Libre <span class="occupee"></span> Occupée <span class="addition"></span> Addition demandée'
            + ' <span class="pastille"></span> À envoyer en préparation · ' + occupees + ' table(s) occupée(s)</div>'
            + '</div>';
    }

    // ------------------------------------------------------------------
    // Paiement
    // ------------------------------------------------------------------
    function etatPaiement() {
        const ttc = totaux({ lignes: lignesAPayer(), remise: pay.partage ? null : ticket().remise }).ttc;
        const frais = pay.partage ? 0 : fraisLivraison(ticket());
        // Retrait d'un dépôt de linge : l'acompte versé au dépôt est déduit.
        const acompte = acompteDepot(ticket());
        const avant = ttc + (pay.pourboire || 0) + frais;
        const total = Math.max(0, avant - acompte);
        let recu = 0, especes = 0;
        pay.lignes.forEach(r => {
            recu += r.montant;
            if (modes.get(r.modeId)?.especes) especes += r.montant;
        });
        const rendu = Math.max(0, recu - total);
        return {
            ttc: ttc, total: total, frais: frais, recu: recu, especes: especes, rendu: rendu, acompte: acompte, acompteTrop: acompte > avant,
            reste: Math.max(0, total - recu),
            ok: (pay.lignes.length > 0 || total === 0) && acompte <= avant && recu >= total && rendu <= especes && !pay.lignes.some(r => r.montant <= 0)
        };
    }

    // Client en compte du ticket : crédit encore possible avant le plafond (Infinity = sans plafond).
    function creditDisponible(c) {
        return c.plafond == null || D.peutDepasserPlafond ? Infinity : Math.max(0, c.plafond - c.du);
    }

    function ajouterReglement(modeId) {
        // Montant proposé : le reste à payer (comme sur Odoo) ; la première frappe le remplace.
        let montant = etatPaiement().reste;
        // Paiement par compte (vente à crédit) : client en compte, dans la limite de son plafond.
        if (modes.get(modeId)?.compte) {
            const c = clients.get(ticket().clientId);
            if (!c) { message('Le paiement par compte demande un client : revenez au ticket et touchez « Choisir un client ».', true); return; }
            if (!c.compte) { message('« ' + c.nom + ' » n\'est pas un client en compte : cochez « Client en compte » sur sa fiche (Tiers).', true); return; }
            const dispo = creditDisponible(c) - pay.lignes.filter(r => modes.get(r.modeId)?.compte).reduce((s, r) => s + r.montant, 0);
            if (dispo <= 0) { message('Plafond de crédit atteint pour « ' + c.nom + ' » : solde dû ' + fcfa(c.du) + ' FCFA, plafond ' + fcfa(c.plafond) + ' FCFA.', true); return; }
            if (montant > dispo) {
                montant = dispo;
                message('Plafond de crédit : ' + fcfa(dispo) + ' FCFA possibles par compte ; le reste est à régler autrement.');
            }
        }
        pay.lignes.push({ modeId: modeId, montant: montant, auto: true });
        pay.choisie = pay.lignes.length - 1;
        pay.saisie = null;
        afficher();
    }

    function toucheReglement(k) {
        const r = pay.lignes[pay.choisie];
        if (!r) { message('Choisissez d\'abord un mode de paiement à gauche.'); return; }
        if (k === 'efface') {
            if (pay.saisie === null || pay.saisie === '') {
                pay.saisie = '';
            } else {
                pay.saisie = pay.saisie.slice(0, -1);
            }
        } else {
            pay.saisie = (pay.saisie === null ? '' : pay.saisie) + k;
        }
        r.montant = parseInt(pay.saisie || '0', 10) || 0;
        r.auto = false;
        afficher();
    }

    function billet(valeur) {
        let r = pay.lignes[pay.choisie];
        if (!r || !modes.get(r.modeId)?.especes) {
            const especes = (D.modes || []).find(m => m.especes);
            if (!especes) { message('Aucun mode « Espèces » actif.', true); return; }
            r = pay.lignes.find(x => x.modeId === especes.id);
            if (!r) { pay.lignes.push(r = { modeId: especes.id, montant: 0, auto: true }); }
            pay.choisie = pay.lignes.indexOf(r);
        }
        if (valeur === 'exact') {
            r.montant = Math.max(0, r.montant + etatPaiement().total - etatPaiement().recu);
        } else {
            r.montant = (r.auto ? 0 : r.montant) + Number(valeur);
        }
        r.auto = false;
        pay.saisie = null;
        afficher();
    }

    function supprimerReglement(i) {
        pay.lignes.splice(i, 1);
        pay.choisie = Math.min(pay.choisie, pay.lignes.length - 1);
        pay.saisie = null;
        afficher();
    }

    function identifiant() {
        return Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10) + '-' + Math.random().toString(36).slice(2, 10);
    }

    async function valider() {
        const e = etatPaiement();
        if (pay.envoi) return;
        if (!e.ok) {
            message(e.acompteTrop ? 'L\'acompte versé (' + fcfa(e.acompte) + ' FCFA) dépasse le total : remettez les articles du dépôt sur le ticket.'
                : e.recu < e.total ? 'Il reste ' + fcfa(e.reste) + ' FCFA à payer.'
                : e.rendu > e.especes ? 'Seule la monnaie sur les espèces peut être rendue.'
                : 'Ajoutez un règlement.', true);
            return;
        }
        const t = ticket();
        if (!t.cle) { t.cle = identifiant(); if (!cmd) enregistrer(); }   // même clé si l'envoi est refait
        const vente = {
            cle: t.cle,
            journeeId: D.journee.id,
            clientId: t.clientId,
            lignes: lignesAPayer().map(l => ({ produitId: l.produitId, qte: l.qte, prix: l.prix, remise: l.remise || 0, note: l.note || '', composants: l.composants || null })),
            remiseGlobale: pay.partage ? null : (t.remise || null),
            pourboire: pay.pourboire || 0,
            commandeOuverte: cmd ? { id: cmd.id, version: cmd.version, reste: resteApresPaiement() } : null,
            livraison: cmd ? null : (t.livraison || null),
            depotId: !cmd && t.depot ? t.depot.id : null,
            paiements: pay.lignes.map(r => ({ modeId: r.modeId, montant: r.montant }))
        };
        const corps = new FormData();
        corps.append(D.jeton.nom, D.jeton.valeur);
        corps.append('vente', JSON.stringify(vente));
        pay.envoi = true;
        afficher();
        // Hors ligne, ou table dont la commande attend son envoi : la vente passe par la file du poste.
        if (horsLigne() || (cmd && cmd.cleFile)) { garderVente(vente, e, t); return; }
        let reponse = null;
        try {
            const res = await fetch(D.urlVendre, { method: 'POST', body: corps, credentials: 'same-origin' });
            reponse = await res.json().catch(() => null);
            if (!res.ok || !reponse || reponse.erreur) throw new Error(reponse && reponse.erreur ? reponse.erreur : 'Réponse inattendue du serveur (' + res.status + ').');
        } catch (err) {
            // Coupure pendant l'envoi : la vente est gardée sur le poste (même clé : jamais enregistrée deux fois).
            if (F && err instanceof TypeError) { window.gcConnexion.verifier(); garderVente(vente, e, t); return; }
            pay.envoi = false;
            afficher();
            message((err && err.message && !/fetch|network/i.test(err.message) ? err.message : 'Connexion impossible : la vente n\'est pas enregistrée. Réessayez.'), true);
            return;
        }
        terminer(t, e, reponse, null);
    }

    // Vente sans connexion : gardée dans la file du poste, ticket provisoire imprimé sur le poste.
    function garderVente(vente, e, t) {
        const numero = F.numeroProvisoire();
        vente.horsLigne = { date: new Date().toISOString(), numero: numero, vendeur: D.utilisateur.nom };
        // Table : la vente suit l'envoi de sa commande (ref : clé dans la file) ; nom pour le contrôle.
        if (cmd) vente.commandeOuverte = Object.assign({}, vente.commandeOuverte, { ref: cmd.cleFile || null, table: cmd.table });
        const client = clients.get(t.clientId);
        const html = ticketLocal(vente, e, t, numero);
        const garde = F.ajouter({
            type: 'vente', numero: numero, libelle: 'Vente · ' + (cmd ? cmd.table : D.journee.caisse) + (client ? ' · ' + client.nom : ''), montant: e.total,
            journeeId: D.journee.id, url: D.urlVendre, urlJeton: D.urlJeton, champ: 'vente', donnees: vente
        });
        if (!garde) {
            pay.envoi = false;
            afficher();
            message('Stockage du navigateur indisponible : la vente ne peut pas être gardée hors ligne.', true);
            return;
        }
        terminer(t, e, { id: null, numero: numero, bons: [] }, html);
        message('Hors ligne : vente ' + numero + ' gardée sur ce poste, envoyée au retour de la connexion.');
    }

    // Vente enregistrée (sur le serveur, ou gardée hors ligne avec son ticket provisoire « html »).
    function terminer(t, e, reponse, html) {
        // Stock affiché mis à jour sans recharger la page.
        lignesAPayer().forEach(l => { const p = produits.get(l.produitId); if (p && p.suivi) p.stock -= l.qte; });
        // Solde dû du client en compte mis à jour (plafond des ventes suivantes).
        const client = clients.get(t.clientId);
        if (client) client.du += pay.lignes.filter(r => modes.get(r.modeId)?.compte).reduce((s, r) => s + r.montant, 0);
        fin = { id: reponse.id, numero: reponse.numero, rendu: e.rendu, direct: !cmd, resteTable: null, ticket: html };
        if (html && t.depot) depots = depots.filter(d => d.id !== t.depot.id);
        // Vente directe en restaurant / bar : les articles sont partis en préparation (bons créés par le serveur).
        const bonsDirects = !cmd && R ? (reponse.bons || []) : [];
        if (bonsDirects.length && R.imprimerBons) imprimerDans(R.urlBons + bonsDirects.join(','));
        if (cmd && html) {
            // Table encaissée hors ligne : libérée sur le plan du poste.
            const tbl = tableDe(cmd.tableId);
            if (tbl) tbl.commande = null;
            if (cmd.cleFile && F.trouver(cmd.cleFile)) F.mettre({ cle: cmd.cleFile, payee: true });
            garderPlan();
            cmd = null;
        } else if (cmd) {
            // Addition partagée : le reste des articles demeure sur la table.
            if (reponse.commande) fin.resteTable = { id: cmd.tableId, nom: cmd.table };
            cmd = null;
            rafraichirPlan();
        } else {
            etat.tickets.splice(etat.actif, 1);
            if (!etat.tickets.length) { etat.compteur += 1; etat.tickets.push(nouveauTicket(etat.compteur)); }
            etat.actif = Math.min(etat.actif, etat.tickets.length - 1);
            enregistrer();
        }
        const depotRetire = !cmd && t.depot;
        pay = null;
        vue = 'fin';
        afficher();
        if (depotRetire) { message('Dépôt n° ' + t.depot.numero + ' retiré et encaissé.'); rafraichirDepots(); }
        if (bonsDirects.length) message(bonsDirects.length > 1 ? 'Commande envoyée en cuisine et au bar.' : 'Commande envoyée en préparation.');
        if (html && R) message('Hors ligne : les bons de préparation ne sont pas envoyés, prévenez la cuisine ou le bar.', true);
        rafraichirAttentes();
    }

    // ------------------------------------------------------------------
    // Tickets provisoires (hors ligne), sur le modèle des tickets du serveur
    // ------------------------------------------------------------------
    const dateFr = d => d.toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }).replace(',', '');
    function enteteTicket(titre) {
        const T = D.ticket || {};
        return '<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><title>' + echap(titre) + '</title>'
            + '<meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="' + echap(T.css || '') + '"></head><body>';
    }
    const societeTicket = () => '<div class="c b grand">' + echap((D.ticket || {}).societe || 'GesCaisse') + '</div>'
        + ((D.ticket || {}).coordonnees || []).map(l => '<div class="c petit">' + echap(l) + '</div>').join('');
    const ligneR = (g, d, cls) => '<div class="r' + (cls ? ' ' + cls : '') + '"><span>' + g + '</span><span>' + d + '</span></div>';
    const ligneTicket = l => '<div class="b">' + echap(l.nom) + '</div>'
        + (l.composants || []).map(c => '<div class="ind petit">· ' + qte(c.qte) + ' x ' + echap(c.nom) + (c.supplement > 0 ? ' (+' + fcfa(c.supplement) + ')' : '') + '</div>').join('')
        + (l.note ? '<div class="ind note">» ' + echap(l.note) + '</div>' : '')
        + ligneR(qte(l.qte) + (l.unite && l.unite !== 'Unité' ? ' ' + echap(l.unite) : '') + ' x ' + fcfa(l.prix) + (l.remise > 0 ? ' -' + qte(l.remise) + '%' : ''), fcfa(totalLigne(l)), 'ind');

    function ticketLocal(vente, e, t, numero) {
        const client = clients.get(t.clientId);
        const lignes = lignesAPayer();
        const tot = totaux({ lignes: lignes, remise: vente.remiseGlobale });
        const total = tot.ttc + (vente.pourboire || 0) + e.frais;
        return enteteTicket('Ticket ' + numero) + '<div class="ticket">' + societeTicket()
            + '<div class="c">' + echap((D.ticket || {}).description || '') + '</div>'
            + '<div class="c b">TICKET PROVISOIRE · HORS LIGNE</div><hr>'
            + '<div>Ticket : ' + echap(numero) + '</div>'
            + '<div>Date   : ' + dateFr(new Date()) + '</div>'
            + '<div>Caisse : ' + echap(D.journee.caisse) + ' · Vendeur : ' + echap(D.utilisateur.nom) + '</div>'
            + (client ? '<div>Client : ' + echap(client.nom) + '</div>' : '')
            + (cmd ? '<div>Table  : ' + echap(cmd.table) + ' · ' + cmd.couverts + ' couvert(s)</div>' : '')
            + (t.livraison ? '<div>Livraison à : ' + echap(t.livraison.nom || (client ? client.nom : '')) + (t.livraison.telephone ? ' · ' + echap(t.livraison.telephone) : '') + '</div><div>' + echap(t.livraison.adresse || '') + '</div>' : '')
            + '<hr>' + lignes.map(ligneTicket).join('') + '<hr>'
            + (tot.remise ? ligneR('Sous-total', fcfa(tot.brut)) + ligneR('Remise globale', '-' + fcfa(tot.remise)) : '')
            + ligneR('TOTAL TTC', fcfa(tot.ttc) + ' FCFA', 'b grand')
            + ligneR('Total HT', fcfa(tot.ttc - tot.tva)) + (tot.tva ? ligneR('Taxes comprises', fcfa(tot.tva)) : '')
            + (e.frais ? ligneR('Frais de livraison', fcfa(e.frais)) : '')
            + (vente.pourboire ? ligneR('Pourboire', fcfa(vente.pourboire)) : '')
            + (vente.pourboire || e.frais ? ligneR('TOTAL PAYÉ', fcfa(total) + ' FCFA', 'b') : '')
            + '<hr>' + (e.acompte ? ligneR('Acompte (dépôt n° ' + echap(t.depot.numero) + ')', fcfa(e.acompte)) : '')
            + pay.lignes.map(r => ligneR(echap((modes.get(r.modeId) || {}).libelle || '?'), fcfa(r.montant))).join('')
            + (e.rendu > 0 ? ligneR('Monnaie rendue', fcfa(e.rendu), 'b') : '')
            + '<hr><div class="c">Merci de votre visite !</div>'
            + '<div class="c petit">' + echap(numero) + ' · numéro définitif attribué à l\'envoi</div>'
            + '</div></body></html>';
    }

    function ticketDepotLocal(dep, numero, total) {
        const brut = dep.lignes.reduce((s, l) => s + totalLigne(l), 0);
        const reste = Math.max(0, total - dep.acompte);
        const mode = dep.acompte > 0 ? (modes.get(dep.modeId) || {}).libelle : '';
        const retrait = dep.retrait ? dep.retrait.split('-').reverse().join('/') : '';
        const articles = dep.lignes.reduce((s, l) => s + l.qte, 0);
        return enteteTicket('Dépôt ' + numero)
            + '<div class="ticket saut">' + societeTicket() + '<hr>'
            + '<div class="c b tres-grand">DÉPÔT N° ' + echap(numero) + '</div><div class="non-paye">NON PAYÉ</div>'
            + '<div class="c petit">Exemplaire client · numéro provisoire (hors ligne)</div>'
            + '<div>Déposé le : ' + dateFr(new Date()) + '</div>'
            + (retrait ? '<div class="b">Retrait   : à partir du ' + retrait + '</div>' : '')
            + '<div>Client    : ' + echap(dep.nom) + '</div><div>Téléphone : ' + echap(dep.telephone) + '</div>'
            + '<div>Reçu par  : ' + echap(D.utilisateur.nom) + '</div><hr>'
            + dep.lignes.map(ligneTicket).join('') + '<hr>'
            + (brut !== total ? ligneR('Sous-total', fcfa(brut)) + ligneR('Remise globale', '-' + fcfa(brut - total)) : '')
            + ligneR('TOTAL TTC', fcfa(total) + ' FCFA', 'b grand')
            + (dep.acompte > 0 ? ligneR('Acompte versé' + (mode ? ' (' + echap(mode) + ')' : ''), '-' + fcfa(dep.acompte)) : '')
            + ligneR('RESTE À PAYER', fcfa(reste) + ' FCFA', 'b grand')
            + '<hr><div class="c">Présentez ce ticket pour retirer votre linge.<br>Le paiement se fait au retrait.</div></div>'
            + '<div class="ticket">' + '<div class="c b grand">' + echap((D.ticket || {}).societe || 'GesCaisse') + '</div>'
            + '<div class="c petit">Souche à joindre au linge</div><hr>'
            + '<div class="c b tres-grand">DÉPÔT N° ' + echap(numero) + '</div>'
            + '<div class="c b grand">' + echap(dep.nom) + '</div><div class="c b">' + echap(dep.telephone) + '</div><hr>'
            + '<div>Déposé le : ' + dateFr(new Date()) + '</div>' + (retrait ? '<div class="b">Retrait   : ' + retrait + '</div>' : '') + '<hr>'
            + dep.lignes.map(l => ligneR(echap(l.nom), 'x ' + qte(l.qte)) + (l.note ? '<div class="ind petit note">' + echap(l.note) + '</div>' : '')).join('')
            + '<hr>' + ligneR('Articles', qte(articles), 'b') + ligneR(reste > 0 ? 'Reste à payer' : 'Payé', reste > 0 ? fcfa(reste) + ' FCFA' : '', 'b')
            + '</div></body></html>';
    }

    function nouvelleVente() {
        const plan = R && !fin.direct;
        fin = null;
        vue = plan ? 'plan' : 'vente';
        mode = 'qte';
        saisie = null;
        afficher();
    }

    function iconeMode(m) {
        const t = (m.libelle || '').toLowerCase();
        if (m.especes) return 'fa-money-bill-wave';
        if (m.compte) return 'fa-address-book';
        if (/mobile|money|airtel|moov|momo/.test(t)) return 'fa-mobile-screen-button';
        if (/carte|cb|visa|bancaire/.test(t)) return 'fa-credit-card';
        if (/ch[eè]que/.test(t)) return 'fa-money-check';
        if (/virement/.test(t)) return 'fa-building-columns';
        return 'fa-wallet';
    }

    // Indicateur de connexion (hors-ligne.js) : mis à jour par lui-même à chaque changement.
    function connexion() {
        return window.gcConnexion ? window.gcConnexion.html() : '';
    }

    function enteteSimple(titre, sousTitre) {
        return '<div class="pos-top"><span class="pos-logo">GC</span>'
            + '<div class="pos-titre"><strong>' + echap(titre) + '</strong><small>' + echap(sousTitre) + '</small></div>'
            + '<div class="pos-droite">' + connexion() + '<span class="pos-user"><span class="pos-avatar">' + echap(initiales(D.utilisateur.nom || '?')) + '</span><span>'
            + echap(D.utilisateur.nom) + ' · ' + echap(D.utilisateur.profil) + '</span></span></div></div>';
    }

    function afficherPaiement() {
        const t = ticket();
        const e = etatPaiement();
        const client = clients.get(t.clientId);
        const pt = (v, html) => '<button type="button" class="pos-k" data-pt="' + v + '">' + (html || v) + '</button>';
        racine.innerHTML = enteteSimple('Paiement · ' + (cmd ? cmd.table + ' · ' + cmd.couverts + ' couvert(s)' + (pay.partage ? ' · addition partagée' : '') : 'Ticket ' + t.numero),
            D.journee.caisse + (client ? ' · Client : ' + client.nom : ''))
            + '<div class="pos-pay">'
            + '<div class="pos-modes"><h3>Modes de paiement</h3>'
            + ((D.modes || []).length
                ? D.modes.map(m => '<button type="button" class="pos-mode" data-mode-paiement="' + m.id + '"><i class="fas ' + iconeMode(m) + '"></i> ' + echap(m.libelle) + '</button>').join('')
                : '<div class="pos-aide">Aucun mode de paiement actif : ajoutez-en dans Paramètres › Modes de paiement.</div>')
            + (R ? '<button type="button" class="pos-mode pourboire" data-action="pourboire"><i class="fas fa-hand-holding-heart"></i> '
                + (pay.pourboire ? 'Pourboire : <b>' + fcfa(pay.pourboire) + '</b>' : 'Ajouter un pourboire') + '</button>' : '')
            + '</div>'
            + '<div class="pos-centre">'
            + '<div class="pos-blocs">'
            + '<div class="pos-bloc"><small>Total à payer</small><div class="v">' + fcfa(e.total) + '</div>'
            + (pay.pourboire ? '<small>dont pourboire ' + fcfa(pay.pourboire) + '</small>' : '')
            + (e.acompte ? '<small>acompte déjà versé ' + fcfa(e.acompte) + ' déduit</small>' : '')
            + (e.frais ? '<small>dont frais de livraison ' + fcfa(e.frais) + '</small>' : '') + '</div>'
            + '<div class="pos-bloc' + (e.reste > 0 ? ' reste' : '') + '"><small>Reste à payer</small><div class="v">' + fcfa(e.reste) + '</div></div>'
            + '<div class="pos-bloc rendre"><small>Monnaie à rendre</small><div class="v">' + fcfa(e.rendu) + '</div></div>'
            + '</div>'
            + '<h3>Règlements</h3>'
            + '<div class="pos-reglements">'
            + (pay.lignes.length
                ? pay.lignes.map((r, i) => {
                    const m = modes.get(r.modeId) || { libelle: '?' };
                    return '<div class="pos-reglement' + (i === pay.choisie ? ' sel' : '') + '" data-reglement="' + i + '">'
                        + '<i class="fas ' + iconeMode(m) + '"></i> ' + echap(m.libelle) + (m.especes ? ' <small>reçu</small>' : m.compte ? ' <small>à crédit</small>' : '')
                        + '<b>' + fcfa(r.montant) + '</b>'
                        + '<button type="button" class="x" data-suppr-reglement="' + i + '" aria-label="Supprimer ce règlement"><i class="fas fa-xmark"></i></button></div>';
                }).join('')
                : '<div class="pos-aide">Choisissez un mode de paiement à gauche.</div>')
            + '</div>'
            + '<h3>Billets rapides (espèces)</h3>'
            + '<div class="pos-billets">' + [500, 1000, 2000, 5000, 10000].map(b => '<button type="button" class="pos-billet" data-billet="' + b + '">+' + fcfa(b) + '</button>').join('')
            + '<button type="button" class="pos-billet" data-billet="exact">Montant exact</button></div>'
            + (client && client.compte
                ? '<div class="pos-aide compte"><i class="fas fa-address-book"></i> Client en compte · solde dû <b>' + fcfa(client.du) + ' FCFA</b>'
                    + (client.plafond != null ? ' · plafond ' + fcfa(client.plafond) + ' FCFA' + (D.peutDepasserPlafond ? '' : ' (encore ' + fcfa(creditDisponible(client)) + ' FCFA possibles)') : ' · sans plafond') + '</div>'
                : '')
            + '<div class="pos-aide"><i class="fas fa-circle-info"></i> À la validation, chaque règlement devient un encaissement validé de la journée de caisse (motif « Vente POS »), '
            + 'sauf le paiement par compte, ajouté au solde dû du client.</div>'
            + '</div>'
            + '<div class="pos-droite2">'
            + '<div class="pos-pave pos-pave3">' + ['1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0'].map(v => pt(v)).join('') + pt('efface', '<i class="fas fa-delete-left"></i>') + '</div>'
            + '<button type="button" class="pos-retour" data-action="retour"><i class="fas fa-arrow-left"></i> Retour au ticket</button>'
            + '<button type="button" class="pos-valider" data-action="valider"' + (e.ok && !pay.envoi ? '' : ' disabled') + '>'
            + (pay.envoi ? '<i class="fas fa-spinner fa-spin"></i> Enregistrement…' : '<i class="fas fa-check"></i> Valider le paiement') + '</button>'
            + '</div></div>';
    }

    function afficherFin() {
        racine.innerHTML = enteteSimple((fin.ticket ? 'Vente hors ligne · ' : 'Vente terminée · ') + fin.numero, D.journee.caisse + ' · ' + D.journee.libelle)
            + '<div class="pos-finzone">'
            + '<div class="pos-apercu"><iframe id="posTicket" title="Ticket de caisse" '
            + (fin.ticket ? 'srcdoc="' + echap(fin.ticket) + '"' : 'src="' + echap(D.urlTicket + fin.id) + '"') + '></iframe></div>'
            + '<div class="pos-fin">'
            + '<div class="pos-ok' + (fin.ticket ? ' hors-ligne' : '') + '"><i class="fas ' + (fin.ticket ? 'fa-cloud-arrow-up' : 'fa-check') + '"></i></div>'
            + (fin.ticket
                ? '<h2>Paiement gardé sur ce poste</h2><p>Pas de connexion : la vente (ticket provisoire ' + echap(fin.numero) + ') sera envoyée automatiquement au serveur dès le retour de la connexion.</p>'
                : '<h2>Paiement enregistré</h2><p>Les encaissements sont dans la journée de caisse ' + echap(D.journee.caisse) + '.</p>')
            + (fin.rendu > 0 ? '<p class="pos-rendu">Monnaie à rendre : <b>' + fcfa(fin.rendu) + ' FCFA</b></p>' : '')
            + '<button type="button" class="pos-sec" data-action="imprimer"><i class="fas fa-print"></i> Imprimer le ticket</button>'
            + (fin.resteTable ? '<button type="button" class="pos-sec" data-action="continuer-table"><i class="fas fa-utensils"></i> Continuer : ' + echap(fin.resteTable.nom) + ' (reste à payer)</button>' : '')
            + (R && !fin.direct
                ? '<button type="button" class="pos-big" data-action="nouvelle-vente"><i class="fas fa-chair"></i> Plan de salle</button>'
                : '<button type="button" class="pos-big" data-action="nouvelle-vente"><i class="fas fa-plus"></i> Nouvelle vente</button>')
            + '</div></div>';
    }

    // ------------------------------------------------------------------
    // Affichage
    // ------------------------------------------------------------------
    function initiales(nom) {
        return nom.split(/\s+/).filter(m => /^[\p{L}\p{N}]/u.test(m)).slice(0, 2).map(m => m[0]).join('').toUpperCase();
    }

    function produitsAffiches() {
        const r = recherche.trim().toLowerCase();
        const correspond = p => p.nom.toLowerCase().includes(r) || p.code.toLowerCase().includes(r) || (p.codeBarres || '').toLowerCase().includes(r);
        return D.produits.filter(p =>
            !p.parentId && (!p.modele || variantes(p).length)
            && (!categorieChoisie || p.categorieId === categorieChoisie)
            && (!r || correspond(p) || variantes(p).some(correspond)));
    }

    function htmlTuiles() {
        const liste = produitsAffiches();
        if (!liste.length) {
            return '<div class="pos-aucun">' + (D.produits.length
                ? 'Aucun produit ne correspond.'
                : 'Aucun produit actif. Ajoutez-en dans Point de vente › Produits.') + '</div>';
        }
        return liste.map(p => {
            const c = categories.get(p.categorieId);
            const couleur = c ? c.couleur : '#5a6b78';
            let stock = '<div class="stock">Service</div>';
            if (p.combo && p.combo.length) {
                stock = '<div class="stock combo"><i class="fas fa-utensils"></i> Combo · ' + p.combo.length + ' choix</div>';
            } else if (p.modele) {
                const vs = variantes(p);
                const reste = vs.reduce((s, v) => s + (v.suivi ? v.stock - quantiteAuTicket(v.id) : 0), 0);
                stock = '<div class="stock">' + vs.length + ' variante' + (vs.length > 1 ? 's' : '') + (p.suivi ? ' · stock ' + qte(reste) : '') + '</div>';
            } else if (p.suivi) {
                const reste = p.stock - quantiteAuTicket(p.id);
                const bas = p.seuil !== null ? reste <= p.seuil : reste <= 0;
                stock = '<div class="stock' + (bas ? ' bas' : '') + '">' + (bas ? 'Stock bas : ' : 'Stock : ') + qte(reste) + '</div>';
            }
            return '<button type="button" class="pos-tuile" data-produit="' + p.id + '">'
                + (p.image
                    ? '<div class="img"><img src="' + echap(p.image) + '" alt="" loading="lazy"></div>'
                    : '<div class="img" style="background:' + echap(couleur) + '">' + echap(initiales(p.nom)) + '</div>')
                + '<span class="p">' + fcfa(p.prix) + (p.unite && p.unite !== 'Unité' ? ' / ' + echap(p.unite) : '') + '</span>'
                + '<div class="info"><div class="n">' + echap(p.nom) + '</div>' + stock + '</div></button>';
        }).join('');
    }

    function htmlLignes(t) {
        if (!t.lignes.length) {
            return '<div class="pos-vide"><i class="fas fa-basket-shopping"></i>Touchez un produit ou scannez un code-barres pour commencer.</div>';
        }
        return t.lignes.map((l, i) =>
            '<div class="pos-ligne' + (i === t.choisie ? ' sel' : '') + '" data-ligne="' + i + '">'
            + '<div><div class="nom">' + echap(l.nom) + '</div>'
            + '<div class="detail">' + qte(l.qte) + (l.unite && l.unite !== 'Unité' ? ' ' + echap(l.unite) : '') + ' × ' + fcfa(l.prix)
            + (l.remise ? ' · <span class="remise">remise ' + qte(l.remise) + ' %</span>' : '')
            + (cmd && l.envoye > 0 ? ' · <span class="envoye"><i class="fas fa-fire-burner"></i> ' + (l.envoye >= l.qte ? 'envoyé' : qte(l.envoye) + ' envoyé(s)') + '</span>' : '')
            + '</div>' + (l.composants || []).map(c => '<div class="compo">· ' + qte(c.qte) + ' × ' + echap(c.nom) + (c.supplement > 0 ? ' (+' + fcfa(c.supplement) + ')' : '') + '</div>').join('')
            + (l.note ? '<div class="note">» ' + echap(l.note) + '</div>' : '') + '</div>'
            + '<div class="tot">' + fcfa(totalLigne(l)) + '</div></div>').join('');
    }

    function afficher() {
        if (vue === 'plan') { afficherPlan(); return; }
        if (vue === 'paiement') { afficherPaiement(); return; }
        if (vue === 'fin') { afficherFin(); return; }
        const t = ticket();
        const tot = totaux(t);
        const client = clients.get(t.clientId);
        const k = (val, html, cls) => '<button type="button" class="pos-k ' + (cls || '') + '" data-touche="' + val + '">' + (html || val) + '</button>';
        const m = (val, txt) => '<button type="button" class="pos-k mode' + (mode === val ? ' on' : '') + '" data-mode="' + val + '"'
            + (val === 'prix' && !D.peutModifierPrix ? ' disabled title="Réservé aux administrateurs"' : '') + '>' + txt + '</button>';

        racine.innerHTML =
            '<div class="pos-top">'
            + '<span class="pos-logo">GC</span>'
            + '<div class="pos-titre"><strong>' + (R ? (cmd ? echap(cmd.table) : 'Vente directe') : (D.journee.type === 'Laverie' ? 'Laverie' : 'Point de vente')) + ' · ' + echap(D.journee.caisse) + '</strong>'
            + '<small>' + echap(D.journee.libelle) + '</small></div>'
            + '<div class="pos-tabs">'
            + (R ? '<button type="button" class="pos-tab plan" data-action="plan" title="Plan de salle"><i class="fas fa-chair"></i> Plan</button>' : '')
            + (cmd
                ? '<button type="button" class="pos-tab on" data-action="couverts" title="Changer le nombre de couverts">' + echap(cmd.table)
                    + ' · <i class="fas fa-user"></i> ' + cmd.couverts + (cmd.addition ? ' · <i class="fas fa-file-invoice-dollar" title="Addition imprimée"></i>' : '') + '</button>'
                : etat.tickets.map((tk, i) => '<button type="button" class="pos-tab' + (i === etat.actif ? ' on' : '') + '" data-ticket="' + i + '">Ticket ' + tk.numero
                    + (tk.lignes.length ? ' · ' + tk.lignes.length : '') + '<span class="x" data-fermer="' + i + '" title="Abandonner ce ticket">×</span></button>').join('')
                    + '<button type="button" class="pos-tab ajout" data-action="nouveau" title="Nouveau ticket"><i class="fas fa-plus"></i></button>')
            + '</div>'
            + '<div class="pos-droite">' + connexion()
            + '<span class="pos-user"><span class="pos-avatar">' + echap(initiales(D.utilisateur.nom || '?')) + '</span><span>' + echap(D.utilisateur.nom) + ' · ' + echap(D.utilisateur.profil) + '</span></span>'
            + boutonDepots()
            + boutonAttentes()
            + (D.urlVentes ? '<a class="pos-btn-top" href="' + echap(D.urlVentes) + '"><i class="fas fa-receipt"></i> Ventes</a>' : '')
            + '<a class="pos-btn-top rouge" href="' + echap(D.urlFermer) + '"><i class="fas fa-power-off"></i> Fermer</a>'
            + '</div></div>'
            + '<div class="pos-main">'
            + '<div class="pos-ticket">'
            + '<div class="pos-lignes">' + htmlLignes(t) + '</div>'
            + '<div class="pos-totaux">'
            + (tot.remise ? '<div class="pos-tva">Sous-total ' + fcfa(tot.brut) + ' · <span class="remise">remise globale'
                + (t.remise.type === 'pct' ? ' ' + qte(t.remise.valeur) + ' %' : '') + ' −' + fcfa(tot.remise) + '</span></div>' : '')
            + '<div class="pos-grand">' + fcfa(tot.ttc + fraisLivraison(t)) + ' FCFA</div>'
            + (fraisLivraison(t) ? '<div class="pos-tva">dont frais de livraison : ' + fcfa(fraisLivraison(t)) + ' (hors taxes)</div>' : '')
            + '<div class="pos-tva">dont taxes : ' + fcfa(tot.tva) + ' · ' + t.lignes.length + ' article(s), ' + qte(tot.unites) + ' unité(s)</div>'
            + (!cmd && t.depot ? '<div class="pos-depot-info"><i class="fas fa-shirt"></i> Retrait du dépôt n° <b>' + t.depot.numero + '</b> · ' + echap(t.depot.nom)
                + (t.depot.acompte ? ' · acompte versé ' + fcfa(t.depot.acompte) + ' · reste à payer <b>' + fcfa(Math.max(0, tot.ttc + fraisLivraison(t) - t.depot.acompte)) + '</b>' : '') + '</div>' : '')
            + '</div>'
            + '<div class="pos-actions' + (cmd ? '' : L ? ' six' : ' cinq') + '">'
            + '<button type="button" class="pos-act" data-action="client"><i class="fas fa-user"></i> ' + (client ? 'Client : <b>' + echap(client.nom) + '</b>' : 'Choisir un client') + '</button>'
            + (cmd ? '<button type="button" class="pos-act" data-action="note"><i class="fas fa-comment-dots"></i> Note</button>'
                : '<button type="button" class="pos-act" data-action="attente"' + (t.depot ? ' disabled title="Retrait d\'un dépôt : encaissez-le"' : '') + '><i class="fas fa-pause"></i> Mettre en attente</button>')
            + '<button type="button" class="pos-act" data-action="remise"' + (D.peutRemiseGlobale ? '' : ' disabled title="Réservée aux administrateurs"') + '>'
            + '<i class="fas fa-percent"></i> ' + (t.remise ? 'Remise : <b>' + (t.remise.type === 'pct' ? qte(t.remise.valeur) + ' %' : fcfa(t.remise.valeur)) + '</b>' : 'Remise globale') + '</button>'
            + (cmd ? '' : '<button type="button" class="pos-act' + (t.livraison ? ' livraison' : '') + '" data-action="livraison"><i class="fas '
                + iconeMoyen(t.livraison ? (livreurs.get(t.livraison.livreurId) || {}).moyen : null) + '"></i> '
                + (t.livraison ? 'Livraison : <b>' + echap(nomLivreur(t.livraison.livreurId)) + '</b>' + (fraisLivraison(t) ? ' + ' + fcfa(fraisLivraison(t)) : '') + (t.livraison.paiement === 'livraison' ? ' (à encaisser)' : '')
                    : 'Livraison') + '</button>')
            + (cmd ? '' : '<button type="button" class="pos-act" data-action="additionticket" title="Imprimer l\'addition (NON PAYÉ)"><i class="fas fa-file-invoice-dollar"></i> Addition</button>')
            + (L && !cmd ? (t.depot
                ? '<button type="button" class="pos-act depot" disabled><i class="fas fa-shirt"></i> Dépôt n° <b>' + t.depot.numero + '</b></button>'
                : '<button type="button" class="pos-act depot" data-action="deposer" title="Enregistrer le dépôt du linge, payé au retrait"><i class="fas fa-shirt"></i> Dépôt de linge</button>') : '')
            + '</div>'
            + (cmd ? '<div class="pos-actions resto">'
                + '<button type="button" class="pos-act envoyer' + (aEnvoyer() ? ' actif' : '') + '" data-action="envoyer"><i class="fas fa-fire-burner"></i> Envoyer'
                + (nbAEnvoyer() > 0 ? ' <b>' + qte(nbAEnvoyer()) + '</b>' : '') + '</button>'
                + '<button type="button" class="pos-act" data-action="addition"><i class="fas fa-file-invoice-dollar"></i> Addition</button>'
                + '<button type="button" class="pos-act" data-action="partager"><i class="fas fa-divide"></i> Partager</button>'
                + '<button type="button" class="pos-act" data-action="transferer"><i class="fas fa-right-left"></i> Transférer</button>'
                + '</div>' : '')
            + '<div class="pos-pave">'
            + m('qte', 'Qté') + k('1') + k('2') + k('3') + m('remise', 'Remise %')
            + m('prix', 'Prix') + k('4') + k('5') + k('6') + k('efface', '<i class="fas fa-delete-left"></i>')
            + k('suppr', '<i class="fas fa-trash-can" style="color:#b8323a"></i>', 'mode') + k('7') + k('8') + k('9')
            + '<button type="button" class="pos-k payer" data-action="payer"><i class="fas fa-money-bill-wave"></i>Paiement</button>'
            + k('00', '00', 'mode') + k('0') + k(',') + k('raz', 'C', 'mode')
            + '</div></div>'
            + '<div class="pos-produits">'
            + '<label class="pos-recherche"><i class="fas fa-magnifying-glass"></i>'
            + '<input id="posRecherche" placeholder="Rechercher un produit (nom, code, code-barres)…" autocomplete="off" value="' + echap(recherche) + '">'
            + '<span class="pos-scan"><i class="fas fa-barcode"></i> Douchette prête</span></label>'
            + '<div class="pos-cats">'
            + '<button type="button" class="pos-cat' + (!categorieChoisie ? ' on' : '') + '" data-categorie="0">Tous</button>'
            + D.categories.map(c => '<button type="button" class="pos-cat' + (categorieChoisie === c.id ? ' on' : '') + '" data-categorie="' + c.id + '">'
                + '<span class="pt" style="background:' + echap(c.couleur) + '"></span>' + echap(c.nom) + '</button>').join('')
            + '</div>'
            + '<div class="pos-grille" id="posGrille">' + htmlTuiles() + '</div>'
            + '</div></div>';

        const ligneChoisie = racine.querySelector('.pos-ligne.sel');
        if (ligneChoisie) ligneChoisie.scrollIntoView({ block: 'nearest' });
    }

    // Seule la grille change pendant la frappe : le champ de recherche garde le curseur.
    function afficherGrille() {
        document.getElementById('posGrille').innerHTML = htmlTuiles();
    }

    // ------------------------------------------------------------------
    // Choix du client
    // ------------------------------------------------------------------
    function choisirClient() {
        const fond = document.createElement('div');
        fond.className = 'pos-modal-fond';
        fond.innerHTML = '<div class="pos-modal" role="dialog" aria-modal="true" aria-label="Choisir un client">'
            + '<div class="pos-modal-tete">Choisir un client<button type="button" data-close aria-label="Fermer">×</button></div>'
            + '<input placeholder="Rechercher un client…" autocomplete="off">'
            + '<div class="pos-modal-liste"></div></div>';
        document.body.appendChild(fond);
        const champ = fond.querySelector('input');
        const liste = fond.querySelector('.pos-modal-liste');
        const remplir = () => {
            const r = champ.value.trim().toLowerCase();
            const trouves = D.clients.filter(c => !r || c.nom.toLowerCase().includes(r) || (c.code || '').toLowerCase().includes(r)).slice(0, 100);
            liste.innerHTML = '<button type="button" class="pos-client" data-client="">Sans client</button>'
                + trouves.map(c => '<button type="button" class="pos-client' + (ticket().clientId === c.id ? ' sel' : '') + '" data-client="' + c.id + '">'
                    + echap(c.nom) + '<small>' + echap(c.code) + (c.compte ? ' · <i class="fas fa-address-book"></i> en compte, dû ' + fcfa(c.du) + ' FCFA' : '') + '</small></button>').join('');
        };
        const fermer = () => fond.remove();
        remplir();
        champ.addEventListener('input', remplir);
        fond.addEventListener('click', e => {
            if (e.target === fond || e.target.closest('[data-close]')) { fermer(); return; }
            const b = e.target.closest('[data-client]');
            if (!b) return;
            ticket().clientId = b.dataset.client ? Number(b.dataset.client) : null;
            enregistrer();
            fermer();
            afficher();
        });
        fond.addEventListener('keydown', e => { if (e.key === 'Escape') fermer(); });
        champ.focus();
    }

    // ------------------------------------------------------------------
    // Choix de la variante d'un modèle
    // ------------------------------------------------------------------
    function choisirVariante(m) {
        const vs = variantes(m);
        if (!vs.length) { message('Aucune variante active pour « ' + m.nom + ' ».', true); return; }
        const fond = document.createElement('div');
        fond.className = 'pos-modal-fond';
        fond.innerHTML = '<div class="pos-modal" role="dialog" aria-modal="true" aria-label="Choisir la variante">'
            + '<div class="pos-modal-tete">' + echap(m.nom) + '<button type="button" data-close aria-label="Fermer">×</button></div>'
            + '<div class="pos-variantes">' + vs.map(v => {
                const reste = v.stock - quantiteAuTicket(v.id);
                return '<button type="button" class="pos-variante" data-variante="' + v.id + '">'
                    + '<span class="n">' + echap(v.variante || v.nom) + '</span>'
                    + '<span class="p">' + fcfa(v.prix) + ' FCFA</span>'
                    + '<span class="s' + (v.suivi && reste <= 0 ? ' bas' : '') + '">' + (v.suivi ? 'Stock : ' + qte(reste) : 'Service') + '</span></button>';
            }).join('') + '</div></div>';
        document.body.appendChild(fond);
        const fermer = () => fond.remove();
        fond.addEventListener('click', e => {
            if (e.target === fond || e.target.closest('[data-close]')) { fermer(); return; }
            const b = e.target.closest('[data-variante]');
            if (!b) return;
            fermer();
            ajouterProduit(produits.get(Number(b.dataset.variante)));
        });
        fond.addEventListener('keydown', e => { if (e.key === 'Escape') fermer(); });
        fond.querySelector('.pos-variante').focus();
    }

    // ------------------------------------------------------------------
    // Combo (menu, formule) : un ou plusieurs articles à choisir par groupe
    // ------------------------------------------------------------------
    function choisirCombo(p) {
        const groupes = p.combo.map(g => ({ id: g.id, nom: g.nom, quantite: g.quantite, choix: g.choix.filter(c => produits.has(c.produitId)) }));
        const choix = {};   // groupeId -> { produitId: quantité }
        groupes.forEach(g => { choix[g.id] = {}; });
        const nb = g => Object.values(choix[g.id]).reduce((a, b) => a + b, 0);
        const supplements = () => groupes.reduce((s, g) => s + g.choix.reduce((t, c) => t + (choix[g.id][c.produitId] || 0) * c.supplement, 0), 0);
        const complet = () => groupes.every(g => nb(g) === g.quantite);
        const fond = document.createElement('div');
        fond.className = 'pos-modal-fond';
        fond.innerHTML = '<div class="pos-modal pos-modal-combo" role="dialog" aria-modal="true" aria-label="Composer le combo">'
            + '<div class="pos-modal-tete">' + echap(p.nom) + '<button type="button" data-close aria-label="Fermer">×</button></div>'
            + '<div class="pos-combo-corps"></div>'
            + '<div class="pos-combo-pied"><span class="total"></span><button type="button" class="pos-big" data-ajouter>Ajouter</button></div></div>';
        document.body.appendChild(fond);
        const corps = fond.querySelector('.pos-combo-corps');
        const remplir = () => {
            corps.innerHTML = groupes.map(g => '<div class="pos-combo-groupe"><h4>' + echap(g.nom)
                + ' <small class="' + (nb(g) === g.quantite ? 'ok' : '') + '">' + nb(g) + ' / ' + g.quantite + '</small></h4><div class="pos-combo-choix">'
                + (g.choix.length ? g.choix.map(c => {
                    const pr = produits.get(c.produitId);
                    const n = choix[g.id][c.produitId] || 0;
                    return '<button type="button" class="pos-combo-article' + (n ? ' sel' : '') + '" data-g="' + g.id + '" data-p="' + c.produitId + '">'
                        + '<span class="n">' + echap(pr.nom) + '</span>'
                        + (c.supplement > 0 ? '<span class="s">+' + fcfa(c.supplement) + '</span>' : '')
                        + (pr.suivi && pr.stock <= 0 ? '<span class="r">Rupture</span>' : '')
                        + (n > 1 ? '<span class="q">× ' + n + '</span>' : '')
                        + (n ? '<span class="x" data-moins title="Retirer">−</span>' : '') + '</button>';
                }).join('') : '<div class="pos-aide">Aucun article actif dans ce groupe.</div>')
                + '</div></div>').join('');
            fond.querySelector('.total').innerHTML = 'Total : <b>' + fcfa(p.prix + supplements()) + ' FCFA</b>';
            fond.querySelector('[data-ajouter]').disabled = !complet();
        };
        const fermer = () => fond.remove();
        remplir();
        fond.addEventListener('click', e => {
            if (e.target === fond || e.target.closest('[data-close]')) { fermer(); return; }
            const b = e.target.closest('[data-g]');
            if (b) {
                const g = groupes.find(x => x.id === Number(b.dataset.g));
                const pid = Number(b.dataset.p);
                const sel = choix[g.id];
                if (e.target.closest('[data-moins]')) { sel[pid] = (sel[pid] || 0) - 1; if (sel[pid] <= 0) delete sel[pid]; }
                else if (g.quantite === 1) { choix[g.id] = { [pid]: 1 }; }
                else if (nb(g) < g.quantite) { sel[pid] = (sel[pid] || 0) + 1; }
                else { message('Déjà ' + g.quantite + ' article(s) choisi(s) dans « ' + g.nom + ' » : retirez-en un d\'abord.'); return; }
                remplir();
                return;
            }
            if (e.target.closest('[data-ajouter]') && complet()) {
                const composants = [];
                groupes.forEach(g => g.choix.forEach(c => {
                    const n = choix[g.id][c.produitId];
                    if (n) composants.push({ produitId: c.produitId, groupeId: g.id, nom: produits.get(c.produitId).nom, qte: n, supplement: c.supplement });
                }));
                const t = ticket();
                t.lignes.push({ uid: identifiant(), produitId: p.id, nom: p.nom, qte: 1, prix: p.prix + supplements(), remise: 0, tva: p.tva, unite: p.unite, note: '', envoye: 0, composants: composants });
                t.choisie = t.lignes.length - 1;
                mode = 'qte';
                saisie = null;
                fermer();
                enregistrer();
                afficher();
            }
        });
        fond.addEventListener('keydown', e => { if (e.key === 'Escape') fermer(); });
        fond.querySelector('button').focus();
    }

    // ------------------------------------------------------------------
    // Remise globale du ticket (administrateurs et utilisateurs autorisés à valider)
    // ------------------------------------------------------------------
    function remiseGlobale() {
        if (!D.peutRemiseGlobale) { message('La remise globale est réservée aux administrateurs.', true); return; }
        const t = ticket();
        if (!t.lignes.length) { message('Le ticket est vide.'); return; }
        let type = t.remise ? t.remise.type : 'pct';
        const fond = document.createElement('div');
        fond.className = 'pos-modal-fond';
        fond.innerHTML = '<div class="pos-modal pos-modal-remise" role="dialog" aria-modal="true" aria-label="Remise globale">'
            + '<div class="pos-modal-tete">Remise globale du ticket<button type="button" data-close aria-label="Fermer">×</button></div>'
            + '<div class="pos-remise-corps">'
            + '<div class="pos-remise-types"><button type="button" data-type="pct">En %</button><button type="button" data-type="montant">En FCFA</button></div>'
            + '<input inputmode="decimal" autocomplete="off" aria-label="Valeur de la remise" value="' + (t.remise ? String(t.remise.valeur).replace('.', ',') : '') + '">'
            + '<div class="pos-remise-apercu"></div>'
            + '<div class="pos-remise-boutons">'
            + (t.remise ? '<button type="button" class="pos-sec" data-retirer>Retirer la remise</button>' : '')
            + '<button type="button" class="pos-big" data-appliquer>Appliquer</button></div>'
            + '</div></div>';
        document.body.appendChild(fond);
        const champ = fond.querySelector('input');
        const apercu = fond.querySelector('.pos-remise-apercu');
        const valeur = () => parseFloat(champ.value.replace(/\s/g, '').replace(',', '.')) || 0;
        const maj = () => {
            fond.querySelectorAll('[data-type]').forEach(b => b.classList.toggle('on', b.dataset.type === type));
            const brut = totaux({ lignes: t.lignes, remise: null }).brut;
            const r = montantRemise({ remise: { type: type, valeur: valeur() } }, brut);
            apercu.innerHTML = 'Sous-total ' + fcfa(brut) + ' · remise <b>−' + fcfa(r) + '</b> · total <b>' + fcfa(brut - r) + ' FCFA</b>';
        };
        const fermer = () => fond.remove();
        const appliquer = () => {
            const v = valeur();
            if (type === 'pct' && v > 100) { message('La remise ne peut pas dépasser 100 %.', true); return; }
            t.remise = v > 0 ? { type: type, valeur: v } : null;
            enregistrer();
            fermer();
            afficher();
        };
        maj();
        champ.addEventListener('input', maj);
        fond.addEventListener('click', e => {
            if (e.target === fond || e.target.closest('[data-close]')) { fermer(); return; }
            const b = e.target.closest('[data-type]');
            if (b) { type = b.dataset.type; maj(); champ.focus(); return; }
            if (e.target.closest('[data-retirer]')) { t.remise = null; enregistrer(); fermer(); afficher(); return; }
            if (e.target.closest('[data-appliquer]')) appliquer();
        });
        fond.addEventListener('keydown', e => {
            if (e.key === 'Escape') fermer();
            else if (e.key === 'Enter') { e.preventDefault(); appliquer(); }
        });
        champ.focus();
        champ.select();
    }

    // ------------------------------------------------------------------
    // Commandes en attente (gardées sur le serveur, partagées entre les postes) et livraisons
    // ------------------------------------------------------------------
    let attentes = { attentes: [], livraisons: [] };
    try { const a = JSON.parse(localStorage.getItem('gc-attentes:' + D.cle) || 'null'); if (a && Array.isArray(a.attentes)) attentes = a; } catch (err) { /* illisible */ }
    const livreurs = new Map((D.livreurs || []).map(l => [l.id, l]));
    const nomLivreur = id => (livreurs.get(id) || {}).nom || 'Livreur';
    // Pictogramme du moyen de livraison (Moto, Voiture, Vélo, Autre).
    const iconeMoyen = m => ({ Voiture: 'fa-car', 'Vélo': 'fa-bicycle', Autre: 'fa-truck-fast' })[m] || 'fa-motorcycle';

    function boutonAttentes() {
        if (!D.urlAttentes) return '';
        const n = attentes.attentes.length + attentes.livraisons.length + attentesLocales().length;
        return '<button type="button" class="pos-btn-top" data-action="attentes" title="Commandes en attente et livraisons à effectuer">'
            + '<i class="fas fa-clock"></i> Commandes en attente' + (n ? ' <b class="pos-compte">' + n + '</b>' : '') + '</button>';
    }

    async function rafraichirAttentes() {
        if (!D.urlAttentes) return;
        try {
            const res = await fetch(D.urlAttentes, { credentials: 'same-origin' });
            const r = await res.json();
            if (!res.ok || !r || r.erreur) return;
            attentes = { attentes: r.attentes || [], livraisons: r.livraisons || [] };
            try { localStorage.setItem('gc-attentes:' + D.cle, JSON.stringify(attentes)); } catch (err) { /* stockage plein */ }
            const liste = document.querySelector('.pos-modal-attentes');
            if (liste) remplirAttentes(liste);
            // Seul le bouton est redessiné : la saisie en cours (recherche…) n'est pas perdue.
            racine.querySelectorAll('[data-action="attentes"]').forEach(b => { b.outerHTML = boutonAttentes(); });
        } catch (err) { /* hors ligne : la liste sera actualisée plus tard */ }
    }

    // Ticket enregistré sur le serveur puis retiré de l'écran (repris depuis n'importe quel poste).
    async function mettreEnAttente() {
        const t = ticket();
        if (!t.lignes.length) { message('Le ticket est vide.'); return false; }
        if (!t.cleAttente) { t.cleAttente = identifiant(); enregistrer(); }   // même clé si l'envoi est refait
        const donnees = {
            cle: t.cleAttente, journeeId: D.journee.id,
            lignes: t.lignes.map(l => ({ uid: l.uid, produitId: l.produitId, nom: l.nom, qte: l.qte, prix: l.prix, remise: l.remise || 0, tva: l.tva, unite: l.unite, note: l.note || '', composants: l.composants || null })),
            clientId: t.clientId, remise: t.remise || null, livraison: t.livraison || null
        };
        let res = horsLigne() ? { ok: false, status: 0, r: null } : await appel(D.urlMettreEnAttente, 'commande', donnees);
        if (!res.ok && res.status === 0 && F) {
            // Sans connexion : la commande est gardée sur le poste et mise en attente au retour de la connexion.
            const numero = F.numeroProvisoire();
            donnees.horsLigne = { date: new Date().toISOString(), numero: numero, vendeur: D.utilisateur.nom };
            const total = totaux(t).ttc + fraisLivraison(t);
            if (!F.ajouter({ type: 'attente', numero: numero, libelle: (t.livraison ? 'Commande à livrer' : 'Commande en attente') + (clients.get(t.clientId) ? ' · ' + clients.get(t.clientId).nom : ''),
                montant: total, journeeId: D.journee.id, url: D.urlMettreEnAttente, urlJeton: D.urlJeton, champ: 'commande', donnees: donnees })) {
                message('Stockage du navigateur indisponible : la commande ne peut pas être gardée hors ligne.', true);
                return false;
            }
            res = { ok: true, r: { numero: numero }, horsLigne: true };
        }
        if (!res.ok) {
            message(res.r && res.r.erreur ? res.r.erreur : 'Connexion impossible : la commande n\'est pas mise en attente. Réessayez.', true);
            return false;
        }
        const l = t.livraison;
        etat.tickets.splice(etat.actif, 1);
        if (!etat.tickets.length) { etat.compteur += 1; etat.tickets.push(nouveauTicket(etat.compteur)); }
        etat.actif = Math.min(etat.actif, etat.tickets.length - 1);
        mode = 'qte';
        saisie = null;
        enregistrer();
        afficher();
        message((l ? 'Commande à livrer n° ' + res.r.numero + ' confiée à ' + nomLivreur(l.livreurId) + ' : à encaisser à son retour.'
            : 'Commande mise en attente : n° ' + res.r.numero + '.') + (res.horsLigne ? ' Hors ligne : gardée sur ce poste, envoyée au retour de la connexion.' : ''));
        rafraichirAttentes();
        return true;
    }

    function htmlLivraison(l) {
        return '<div class="pos-att-livraison"><i class="fas ' + iconeMoyen(l.moyen) + '"></i> ' + echap(l.livreur || 'Livreur') + (l.moyen ? ' (' + echap(l.moyen) + ')' : '')
            + (l.nom || l.telephone ? ' · ' + echap([l.nom, l.telephone].filter(Boolean).join(' · ')) : '')
            + (l.adresse ? '<br><span>' + echap(l.adresse) + '</span>' : '') + '</div>';
    }

    // Commandes mises en attente hors ligne sur ce poste, pas encore envoyées : reprises sur ce poste seulement.
    const attentesLocales = () => F ? F.elements().filter(x => x.type === 'attente' && x.donnees.journeeId === D.journee.id) : [];

    function remplirAttentes(fond) {
        const a = attentes.attentes, l = attentes.livraisons, loc = attentesLocales();
        fond.querySelector('.pos-att-corps').innerHTML =
            '<h6>En attente (' + (a.length + loc.length) + ')</h6>'
            + loc.map(x => '<div class="pos-att"><div class="pos-att-info"><b>' + echap(x.numero) + '</b> · ' + echap(new Date(x.cree).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }))
                + (clients.get(x.donnees.clientId) ? ' · ' + echap(clients.get(x.donnees.clientId).nom) : '') + ' · ' + x.donnees.lignes.length + ' article(s)'
                + '<span class="pos-att-badge annule">' + (x.erreur ? 'Refusée : ' + echap(x.erreur) : 'À envoyer') + '</span>'
                + (x.donnees.livraison ? '<div class="pos-att-livraison"><i class="fas fa-motorcycle"></i> ' + echap(nomLivreur(x.donnees.livraison.livreurId)) + (x.donnees.livraison.adresse ? ' · ' + echap(x.donnees.livraison.adresse) : '') + '</div>' : '')
                + '</div><div class="pos-att-total">' + fcfa(x.montant) + ' FCFA</div>'
                + '<div class="pos-att-btns"><button type="button" class="pos-sec" data-reprendre-local="' + echap(x.numero) + '">Reprendre</button></div></div>').join('')
            + (a.length ? a.map(c => '<div class="pos-att">'
                + '<div class="pos-att-info"><b>N° ' + c.numero + '</b> · ' + echap(c.heure) + (c.client ? ' · ' + echap(c.client) : '')
                + ' · ' + c.articles + ' article(s)' + (c.utilisateur ? ' · <small>' + echap(c.utilisateur) + '</small>' : '')
                + (c.livraison ? '<span class="pos-att-badge">À livrer · à encaisser</span>' + htmlLivraison(c.livraison) : '') + '</div>'
                + '<div class="pos-att-total">' + fcfa(c.total) + ' FCFA</div>'
                + '<div class="pos-att-btns"><button type="button" class="pos-sec" data-reprendre="' + c.id + '">Reprendre</button>'
                + '<button type="button" class="pos-sec rouge" data-supprimer="' + c.id + '" data-numero="' + c.numero + '" aria-label="Supprimer la commande n° ' + c.numero + '">'
                + '<i class="fas fa-trash-can"></i></button></div></div>').join('')
                : loc.length ? '' : '<div class="pos-att-vide">Aucune commande en attente.</div>')
            + '<h6>Livraisons payées à effectuer (' + l.length + ')</h6>'
            + (l.length ? l.map(c => '<div class="pos-att">'
                + '<div class="pos-att-info"><b>' + echap(c.numero) + '</b> · ' + echap(c.heure) + (c.client ? ' · ' + echap(c.client) : '')
                + '<span class="pos-att-badge paye">Payée · à livrer</span>' + htmlLivraison(c) + '</div>'
                + '<div class="pos-att-total">' + fcfa(c.total) + ' FCFA</div>'
                + '<div class="pos-att-btns"><button type="button" class="pos-sec vert" data-livree="' + c.id + '"><i class="fas fa-check"></i> Livrée</button>'
                + '<a class="pos-sec" href="' + echap(D.urlTicket + c.id) + '" target="_blank" rel="noopener" title="Ticket"><i class="fas fa-receipt"></i></a></div></div>').join('')
                : '<div class="pos-att-vide">Aucune livraison payée en cours.</div>');
    }

    function listeAttentes() {
        const fond = document.createElement('div');
        fond.className = 'pos-modal-fond attentes';
        fond.innerHTML = '<div class="pos-modal pos-modal-attentes" role="dialog" aria-modal="true" aria-label="Commandes en attente">'
            + '<div class="pos-modal-tete">Commandes en attente<button type="button" data-close aria-label="Fermer">×</button></div>'
            + '<div class="pos-att-corps"></div></div>';
        document.body.appendChild(fond);
        remplirAttentes(fond);
        rafraichirAttentes();
        const fermer = () => { fond.remove(); afficher(); };
        fond.addEventListener('click', async e => {
            if (e.target === fond || e.target.closest('[data-close]')) { fermer(); return; }
            const b = e.target.closest('button');
            if (!b || b.disabled) return;
            if (b.dataset.reprendreLocal) {
                const x = attentesLocales().find(y => y.numero === b.dataset.reprendreLocal);
                if (!x) { remplirAttentes(fond); return; }
                F.retirer(x.numero);
                reprendre({ numero: x.numero, contenu: { lignes: x.donnees.lignes, clientId: x.donnees.clientId, remise: x.donnees.remise, livraison: x.donnees.livraison } });
                fond.remove();
            } else if (b.dataset.reprendre) {
                if (horsLigne()) { message('Hors ligne : seules les commandes mises en attente sur ce poste peuvent être reprises.', true); return; }
                b.disabled = true;
                const res = await appel(D.urlReprendre, 'commande', { id: Number(b.dataset.reprendre) });
                if (!res.ok) { message(res.r && res.r.erreur ? res.r.erreur : 'Connexion impossible. Réessayez.', true); rafraichirAttentes(); return; }
                reprendre(res.r);
                fond.remove();
            } else if (b.dataset.supprimer) {
                if (!confirm('Supprimer la commande en attente n° ' + b.dataset.numero + ' ?')) return;
                b.disabled = true;
                const res = await appel(D.urlSupprimerAttente, 'commande', { id: Number(b.dataset.supprimer) });
                if (!res.ok) message(res.r && res.r.erreur ? res.r.erreur : 'Connexion impossible. Réessayez.', true);
                else message('Commande n° ' + b.dataset.numero + ' supprimée.');
                rafraichirAttentes();
            } else if (b.dataset.livree) {
                b.disabled = true;
                const res = await appel(D.urlLivree, 'commande', { id: Number(b.dataset.livree) });
                if (!res.ok) message(res.r && res.r.erreur ? res.r.erreur : 'Connexion impossible. Réessayez.', true);
                else message('Livraison marquée comme effectuée.');
                rafraichirAttentes();
            }
        });
        fond.addEventListener('keydown', e => { if (e.key === 'Escape') fermer(); });
    }

    // Commande reprise : elle devient un nouveau ticket de ce poste (vente directe).
    function reprendre(r) {
        const c = r.contenu || {};
        const lignes = (c.lignes || []).filter(l => produits.has(l.produitId))
            .map(l => Object.assign({ remise: 0, note: '', envoye: 0 }, l, { uid: l.uid || identifiant(), envoye: 0 }));
        etat.compteur += 1;
        etat.tickets.push({ numero: etat.compteur, lignes: lignes, clientId: c.clientId || null, remise: c.remise || null, livraison: c.livraison || null, choisie: -1 });
        etat.actif = etat.tickets.length - 1;
        cmd = null;
        vue = 'vente';
        mode = 'qte';
        saisie = null;
        enregistrer();
        afficher();
        message(lignes.length < (c.lignes || []).length
            ? 'Commande n° ' + r.numero + ' reprise : un article retiré du catalogue a été ignoré.'
            : 'Commande n° ' + r.numero + ' reprise' + (c.livraison && c.livraison.paiement === 'livraison' ? ' : encaissez-la au retour du livreur.' : '.'),
            lignes.length < (c.lignes || []).length);
        rafraichirAttentes();
    }

    // Livraison du ticket : livreur et destinataire ; payée maintenant (vente normale, livrée ensuite)
    // ou à la livraison (commande mise en attente jusqu'au retour du livreur).
    function livraison() {
        const t = ticket();
        if (!t.lignes.length) { message('Le ticket est vide.'); return; }
        if (!livreurs.size) { message('Aucun livreur actif : créez-en dans Paramètres › Livreurs.', true); return; }
        const client = clients.get(t.clientId) || {};
        const l = t.livraison || { livreurId: null, nom: client.nom || '', telephone: client.telephone || '', adresse: client.adresse || '', paiement: 'livraison',
            frais: Math.round(D.fraisLivraison || 0) };
        const fond = document.createElement('div');
        fond.className = 'pos-modal-fond';
        fond.innerHTML = '<div class="pos-modal pos-modal-livraison" role="dialog" aria-modal="true" aria-label="Livraison">'
            + '<div class="pos-modal-tete">Commande à livrer<button type="button" data-close aria-label="Fermer">×</button></div>'
            + '<div class="pos-form">'
            + '<label>Livreur<select name="livreurId"><option value="">-- Choisir un livreur --</option>'
            + (D.livreurs || []).map(x => '<option value="' + x.id + '"' + (x.id === l.livreurId ? ' selected' : '') + '>' + echap(x.nom) + (x.moyen ? ' · ' + echap(x.moyen) : '') + (x.telephone ? ' · ' + echap(x.telephone) : '') + '</option>').join('')
            + '</select></label>'
            + '<div class="pos-form-2"><label>Destinataire<input name="nom" maxlength="100" value="' + echap(l.nom) + '"></label>'
            + '<label>Téléphone<input name="telephone" maxlength="30" inputmode="tel" value="' + echap(l.telephone) + '"></label></div>'
            + '<label>Adresse de livraison<textarea name="adresse" rows="2" maxlength="200">' + echap(l.adresse) + '</textarea></label>'
            + '<label>Frais de livraison (FCFA, hors taxes)<input name="frais" inputmode="numeric" maxlength="9" value="' + (l.frais || 0) + '"></label>'
            + '<div class="pos-remise-types"><button type="button" data-paiement="maintenant">Payée maintenant</button><button type="button" data-paiement="livraison">À encaisser à la livraison</button></div>'
            + '<div class="pos-form-aide"></div>'
            + '<div class="pos-remise-boutons">'
            + (t.livraison ? '<button type="button" class="pos-sec" data-retirer>Retirer la livraison</button>' : '')
            + '<button type="button" class="pos-big" data-valider>Valider</button></div>'
            + '</div></div>';
        document.body.appendChild(fond);
        let paiement = l.paiement === 'maintenant' ? 'maintenant' : 'livraison';
        const champ = n => fond.querySelector('[name="' + n + '"]');
        const maj = () => {
            fond.querySelectorAll('[data-paiement]').forEach(b => b.classList.toggle('on', b.dataset.paiement === paiement));
            fond.querySelector('.pos-form-aide').textContent = paiement === 'maintenant'
                ? 'Le client paie maintenant : encaissez le ticket, puis marquez la livraison « Livrée » au retour du livreur.'
                : 'La commande est mise en attente et confiée au livreur : reprenez-la à son retour pour l\'encaisser.';
            fond.querySelector('[data-valider]').textContent = paiement === 'maintenant' ? 'Valider puis encaisser' : 'Confier au livreur';
        };
        const fermer = () => fond.remove();
        const valider = async () => {
            const livreurId = Number(champ('livreurId').value) || null;
            const adresse = champ('adresse').value.trim();
            if (!livreurId) { message('Choisissez un livreur.', true); champ('livreurId').focus(); return; }
            if (!adresse) { message('Indiquez l\'adresse de livraison.', true); champ('adresse').focus(); return; }
            const frais = Math.max(0, parseInt(String(champ('frais').value).replace(/[^0-9]/g, '') || '0', 10));
            t.livraison = { livreurId: livreurId, nom: champ('nom').value.trim(), telephone: champ('telephone').value.trim(), adresse: adresse, paiement: paiement, frais: frais };
            enregistrer();
            fermer();
            if (paiement === 'livraison') {
                if (!(await mettreEnAttente())) afficher();
            } else {
                afficher();
                payer();
            }
        };
        maj();
        fond.addEventListener('click', e => {
            if (e.target === fond || e.target.closest('[data-close]')) { fermer(); return; }
            const b = e.target.closest('[data-paiement]');
            if (b) { paiement = b.dataset.paiement; maj(); return; }
            if (e.target.closest('[data-retirer]')) { t.livraison = null; enregistrer(); fermer(); afficher(); return; }
            if (e.target.closest('[data-valider]')) valider();
        });
        fond.addEventListener('keydown', e => { if (e.key === 'Escape') fermer(); });
        champ('livreurId').focus();
    }

    // ------------------------------------------------------------------
    // Laverie : dépôts de linge payés au retrait
    // ------------------------------------------------------------------
    // Acompte déjà versé du dépôt repris sur le ticket (retrait).
    function acompteDepot(t) {
        return !cmd && t && t.depot ? Math.max(0, Math.round(t.depot.acompte || 0)) : 0;
    }

    function boutonDepots() {
        if (!L) return '';
        const n = depots.filter(d => d.statut === 'En cours' || d.statut === 'Prêt').length;
        const prets = depots.filter(d => d.statut === 'Prêt').length;
        return '<button type="button" class="pos-btn-top" data-action="depots" title="Dépôts de linge : en cours, prêts, retirés">'
            + '<i class="fas fa-shirt"></i> Dépôts' + (n ? ' <b class="pos-compte">' + n + '</b>' : '') + (prets ? ' <small>(' + prets + ' prêt' + (prets > 1 ? 's' : '') + ')</small>' : '') + '</button>';
    }

    async function rafraichirDepots() {
        if (!L) return;
        try {
            const res = await fetch(L.urlDepots, { credentials: 'same-origin' });
            const r = await res.json();
            if (!res.ok || !r || r.erreur) return;
            depots = r.depots || [];
            const liste = document.querySelector('.pos-modal-depots');
            if (liste) remplirDepots(liste);
            racine.querySelectorAll('[data-action="depots"]').forEach(b => { b.outerHTML = boutonDepots(); });
        } catch (err) { /* hors ligne : la liste sera actualisée plus tard */ }
    }

    function dateDans(jours) {
        const d = new Date();
        d.setDate(d.getDate() + jours);
        return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
    }

    // Fenêtre : dépôt du linge (client, téléphone, retrait prévu, acompte facultatif).
    function deposer() {
        const t = ticket();
        if (!t.lignes.length) { message('Le ticket est vide.'); return; }
        if (t.lignes.some(l => l.qte <= 0)) { message('Une ligne a une quantité nulle : corrigez-la ou supprimez-la.', true); return; }
        if (t.livraison) { message('Retirez la livraison du ticket avant d\'enregistrer le dépôt.', true); return; }
        const total = totaux(t).ttc;
        const client = clients.get(t.clientId) || {};
        const modesAcompte = (D.modes || []).filter(m => !m.compte);
        const especes = modesAcompte.find(m => m.especes) || modesAcompte[0];
        const fond = document.createElement('div');
        fond.className = 'pos-modal-fond';
        fond.innerHTML = '<div class="pos-modal pos-modal-depot" role="dialog" aria-modal="true" aria-label="Dépôt de linge">'
            + '<div class="pos-modal-tete">Dépôt de linge · ' + fcfa(total) + ' FCFA<button type="button" data-close aria-label="Fermer">×</button></div>'
            + '<div class="pos-form">'
            + '<div class="pos-form-2"><label>Nom du client<input name="nom" maxlength="100" value="' + echap(client.nom || '') + '"></label>'
            + '<label>Téléphone<input name="telephone" maxlength="30" inputmode="tel" value="' + echap(client.telephone || '') + '"></label></div>'
            + '<label>Retrait prévu le<input name="retrait" type="date" min="' + dateDans(0) + '" value="' + dateDans(2) + '"></label>'
            + '<div class="pos-form-2"><label>Acompte versé maintenant (FCFA, facultatif)<input name="acompte" inputmode="numeric" maxlength="9" value="0"></label>'
            + '<label>Mode de paiement de l\'acompte<select name="modeId">' + modesAcompte.map(m => '<option value="' + m.id + '"' + (m === especes ? ' selected' : '') + '>' + echap(m.libelle) + '</option>').join('') + '</select></label></div>'
            + '<div class="pos-form-aide">Le linge est payé au retrait : un ticket « NON PAYÉ » est imprimé en deux exemplaires (client et souche à joindre au linge). '
            + 'L\'acompte éventuel est encaissé dans la journée de caisse ; il sera déduit au retrait.</div>'
            + '<div class="pos-remise-boutons"><button type="button" class="pos-big" data-valider><i class="fas fa-shirt"></i> Enregistrer le dépôt</button></div>'
            + '</div></div>';
        document.body.appendChild(fond);
        const champ = n => fond.querySelector('[name="' + n + '"]');
        const fermer = () => fond.remove();
        const valider = async b => {
            const nom = champ('nom').value.trim(), telephone = champ('telephone').value.trim();
            if (!nom) { message('Indiquez le nom du client.', true); champ('nom').focus(); return; }
            if (!telephone) { message('Indiquez le téléphone du client.', true); champ('telephone').focus(); return; }
            const acompte = Math.max(0, parseInt(String(champ('acompte').value).replace(/[^0-9]/g, '') || '0', 10));
            if (acompte > total) { message('L\'acompte dépasse le total du dépôt (' + fcfa(total) + ' FCFA).', true); champ('acompte').focus(); return; }
            if (!t.cleDepot) { t.cleDepot = identifiant(); enregistrer(); }   // même clé si l'envoi est refait
            b.disabled = true;
            const donnees = {
                cle: t.cleDepot, journeeId: D.journee.id, clientId: t.clientId, remise: t.remise || null,
                nom: nom, telephone: telephone, retrait: champ('retrait').value || null,
                acompte: acompte, modeId: acompte > 0 ? Number(champ('modeId').value) : null,
                lignes: t.lignes.map(l => ({ uid: l.uid, produitId: l.produitId, nom: l.nom, qte: l.qte, prix: l.prix, remise: l.remise || 0, note: l.note || '', composants: l.composants || [] }))
            };
            const res = horsLigne() ? { ok: false, status: 0, r: null } : await appel(L.urlDeposer, 'commande', donnees);
            let numero = res.ok ? res.r.numero : null;
            if (!res.ok && res.status === 0 && F) {
                // Sans connexion : dépôt gardé sur le poste, souche imprimée avec un numéro provisoire.
                numero = F.numeroProvisoire();
                donnees.horsLigne = { date: new Date().toISOString(), numero: numero, vendeur: D.utilisateur.nom };
                if (!F.ajouter({ type: 'depot', numero: numero, libelle: 'Dépôt de linge · ' + nom, montant: total, journeeId: D.journee.id,
                    url: L.urlDeposer, urlJeton: D.urlJeton, champ: 'commande', donnees: donnees })) {
                    b.disabled = false; message('Stockage du navigateur indisponible : le dépôt ne peut pas être gardé hors ligne.', true); return;
                }
                imprimerHtml(ticketDepotLocal(donnees, numero, total));
            } else if (!res.ok) { b.disabled = false; message(res.r && res.r.erreur ? res.r.erreur : 'Connexion impossible : le dépôt n\'est pas enregistré. Réessayez.', true); return; }
            else imprimerDans(L.urlTicket + res.r.id);
            fermer();
            etat.tickets.splice(etat.actif, 1);
            if (!etat.tickets.length) { etat.compteur += 1; etat.tickets.push(nouveauTicket(etat.compteur)); }
            etat.actif = Math.min(etat.actif, etat.tickets.length - 1);
            mode = 'qte';
            saisie = null;
            enregistrer();
            afficher();
            message(res.ok ? 'Dépôt n° ' + numero + ' enregistré' + (acompte ? ' (acompte ' + fcfa(acompte) + ' FCFA encaissé)' : '') + ' : ticket imprimé.'
                : 'Hors ligne : dépôt ' + numero + ' gardé sur ce poste (ticket imprimé), envoyé au retour de la connexion.');
            rafraichirDepots();
        };
        fond.addEventListener('click', e => {
            if (e.target === fond || e.target.closest('[data-close]')) { fermer(); return; }
            const b = e.target.closest('[data-valider]');
            if (b && !b.disabled) valider(b);
        });
        fond.addEventListener('keydown', e => { if (e.key === 'Escape') fermer(); });
        champ(client.nom ? 'telephone' : 'nom').focus();
    }

    let filtreDepots = 'actifs', rechercheDepots = '';
    function remplirDepots(fond) {
        const q = rechercheDepots.trim().toLowerCase();
        const liste = depots.filter(d => (filtreDepots === 'actifs') === (d.statut === 'En cours' || d.statut === 'Prêt'))
            .filter(d => !q || String(d.numero) === q.replace(/^n°\s*/, '') || (d.horsLigne || '').toLowerCase() === q || (d.nom || '').toLowerCase().includes(q) || (d.telephone || '').replace(/\s/g, '').includes(q.replace(/\s/g, '')));
        // Dépôts faits hors ligne sur ce poste, pas encore envoyés : affichés, encaissables après l'envoi.
        const enAttente = filtreDepots !== 'actifs' || !F ? [] : F.elements().filter(x => x.type === 'depot')
            .filter(x => !q || x.numero.toLowerCase() === q || (x.donnees.nom || '').toLowerCase().includes(q) || (x.donnees.telephone || '').replace(/\s/g, '').includes(q.replace(/\s/g, '')));
        fond.querySelectorAll('[data-filtre]').forEach(b => b.classList.toggle('on', b.dataset.filtre === filtreDepots));
        const badge = d => d.statut === 'Prêt' ? '<span class="pos-att-badge paye">Prêt</span>'
            : d.statut === 'En cours' ? '<span class="pos-att-badge">En cours</span>'
            : d.statut === 'Retiré' ? '<span class="pos-att-badge paye">Retiré le ' + echap(d.retire || '') + '</span>'
            : '<span class="pos-att-badge annule">Annulé</span>';
        fond.querySelector('.pos-att-corps').innerHTML = enAttente.map(x => '<div class="pos-att"><div class="pos-att-info"><b>' + echap(x.numero) + '</b> · ' + echap(x.donnees.nom)
            + (x.donnees.telephone ? ' · ' + echap(x.donnees.telephone) : '') + '<span class="pos-att-badge annule">À envoyer</span>'
            + '<div class="pos-att-livraison">Fait hors ligne sur ce poste : encaissable une fois envoyé au serveur.</div></div>'
            + '<div class="pos-att-total">' + fcfa(x.montant - (x.donnees.acompte || 0)) + ' FCFA<small>reste à payer</small></div><div class="pos-att-btns"></div></div>').join('')
            + (liste.length ? liste.map(d => '<div class="pos-att">'
            + '<div class="pos-att-info"><b>N° ' + d.numero + '</b>' + (d.horsLigne ? ' <small>(provisoire ' + echap(d.horsLigne) + ')</small>' : '') + ' · ' + echap(d.nom) + (d.telephone ? ' · ' + echap(d.telephone) : '') + badge(d)
            + '<div class="pos-att-livraison">Déposé le ' + echap(d.depose) + ' · ' + qte(d.articles) + ' article(s)'
            + (d.retrait ? ' · retrait prévu le <span class="' + (d.enRetard ? 'pos-retard' : '') + '">' + echap(d.retrait) + (d.enRetard ? ' (en retard)' : '') + '</span>' : '')
            + (d.acompte ? ' · acompte ' + fcfa(d.acompte) : '') + '</div></div>'
            + '<div class="pos-att-total">' + fcfa(d.statut === 'Retiré' || d.statut === 'Annulé' ? d.total : d.reste) + ' FCFA'
            + (d.statut === 'En cours' || d.statut === 'Prêt' ? '<small>reste à payer</small>' : '') + '</div>'
            + '<div class="pos-att-btns">'
            + (d.statut === 'En cours' || d.statut === 'Prêt'
                ? '<button type="button" class="pos-sec vert" data-encaisser="' + d.id + '"><i class="fas fa-cash-register"></i> Encaisser</button>'
                  + '<button type="button" class="pos-sec" data-pret="' + d.id + '">' + (d.statut === 'Prêt' ? 'Remettre en cours' : '<i class="fas fa-check"></i> Prêt') + '</button>'
                : '')
            + '<button type="button" class="pos-sec" data-reimprimer="' + d.id + '" title="Réimprimer le ticket de dépôt" aria-label="Réimprimer le ticket du dépôt n° ' + d.numero + '"><i class="fas fa-print"></i></button>'
            + (d.venteId ? '<a class="pos-sec" href="' + echap(D.urlTicket + d.venteId) + '" target="_blank" rel="noopener" title="Ticket de caisse"><i class="fas fa-receipt"></i></a>' : '')
            + ((d.statut === 'En cours' || d.statut === 'Prêt') && L.peutAnnuler
                ? '<button type="button" class="pos-sec rouge" data-annuler="' + d.id + '" aria-label="Annuler le dépôt n° ' + d.numero + '"><i class="fas fa-ban"></i></button>' : '')
            + '</div></div>').join('')
            : enAttente.length ? '' : '<div class="pos-att-vide">' + (q ? 'Aucun dépôt ne correspond à « ' + echap(rechercheDepots) + ' ».' : filtreDepots === 'actifs' ? 'Aucun dépôt en cours.' : 'Aucun dépôt retiré ou annulé depuis 30 jours.') + '</div>');
    }

    function listeDepots() {
        const fond = document.createElement('div');
        fond.className = 'pos-modal-fond attentes';
        fond.innerHTML = '<div class="pos-modal pos-modal-attentes pos-modal-depots" role="dialog" aria-modal="true" aria-label="Dépôts de linge">'
            + '<div class="pos-modal-tete">Dépôts de linge<button type="button" data-close aria-label="Fermer">×</button></div>'
            + '<div class="pos-depots-outils"><input type="search" class="pos-depots-recherche" placeholder="N° de dépôt, nom ou téléphone" aria-label="Rechercher un dépôt" value="' + echap(rechercheDepots) + '">'
            + '<div class="pos-remise-types"><button type="button" data-filtre="actifs">À retirer</button><button type="button" data-filtre="termines">Retirés / annulés</button></div></div>'
            + '<div class="pos-att-corps"></div></div>';
        document.body.appendChild(fond);
        remplirDepots(fond);
        rafraichirDepots();
        const fermer = () => { fond.remove(); afficher(); };
        const depot = id => depots.find(d => d.id === Number(id));
        fond.querySelector('.pos-depots-recherche').addEventListener('input', e => { rechercheDepots = e.target.value; remplirDepots(fond); });
        fond.addEventListener('click', async e => {
            if (e.target === fond || e.target.closest('[data-close]')) { fermer(); return; }
            const b = e.target.closest('button');
            if (!b || b.disabled) return;
            if (b.dataset.filtre) { filtreDepots = b.dataset.filtre; remplirDepots(fond); }
            else if (b.dataset.reimprimer) imprimerDans(L.urlTicket + b.dataset.reimprimer);
            else if (b.dataset.pret) {
                b.disabled = true;
                const res = await appel(L.urlPret, 'commande', { id: Number(b.dataset.pret) });
                if (!res.ok) message(res.r && res.r.erreur ? res.r.erreur : 'Connexion impossible. Réessayez.', true);
                else message(res.r.statut === 'Prêt' ? 'Linge prêt : prévenez le client.' : 'Dépôt remis « En cours ».');
                rafraichirDepots();
            } else if (b.dataset.annuler) {
                const d = depot(b.dataset.annuler);
                if (!d || !confirm('Annuler le dépôt n° ' + d.numero + ' (' + d.nom + ') ?' + (d.acompte ? '\nL\'acompte de ' + fcfa(d.acompte) + ' FCFA sera remboursé (décaissement dans la journée).' : ''))) return;
                b.disabled = true;
                const res = await appel(L.urlAnnuler, 'commande', { id: d.id, journeeId: D.journee.id });
                if (!res.ok) message(res.r && res.r.erreur ? res.r.erreur : 'Connexion impossible. Réessayez.', true);
                else message('Dépôt n° ' + d.numero + ' annulé' + (res.r.rembourse ? ' : acompte de ' + fcfa(res.r.rembourse) + ' FCFA remboursé.' : '.'));
                rafraichirDepots();
            } else if (b.dataset.encaisser) {
                const d = depot(b.dataset.encaisser);
                if (d) { fond.remove(); encaisserDepot(d); }
            }
        });
        fond.addEventListener('keydown', e => { if (e.key === 'Escape') fermer(); });
        fond.querySelector('.pos-depots-recherche').focus();
    }

    // Retrait : le dépôt devient un ticket de ce poste, encaissé comme une vente (acompte déduit).
    function encaisserDepot(d) {
        const deja = etat.tickets.findIndex(x => x.depot && x.depot.id === d.id);
        if (deja < 0) {
            const c = d.contenu || {};
            const lignes = (c.lignes || []).filter(l => produits.has(l.produitId))
                .map(l => Object.assign({ remise: 0, note: '', envoye: 0 }, l, { uid: l.uid || identifiant(), envoye: 0 }));
            etat.compteur += 1;
            etat.tickets.push({ numero: etat.compteur, lignes: lignes, clientId: c.clientId || null, remise: c.remise || null, choisie: -1,
                depot: { id: d.id, numero: d.numero, nom: d.nom, acompte: d.acompte } });
            if (lignes.length < (c.lignes || []).length) message('Dépôt n° ' + d.numero + ' : un article retiré du catalogue a été ignoré.', true);
        }
        etat.actif = deja < 0 ? etat.tickets.length - 1 : deja;
        cmd = null;
        vue = 'vente';
        mode = 'qte';
        saisie = null;
        enregistrer();
        afficher();
        payer();
    }

    // ------------------------------------------------------------------
    // Messages
    // ------------------------------------------------------------------
    let minuterie = null;
    function message(texte, erreur) {
        let el = document.querySelector('.pos-toast');
        if (!el) { el = document.createElement('div'); el.setAttribute('role', 'status'); document.body.appendChild(el); }
        el.className = 'pos-toast' + (erreur ? ' erreur' : '');
        el.textContent = texte;
        clearTimeout(minuterie);
        minuterie = setTimeout(() => el.remove(), 3500);
    }

    // ------------------------------------------------------------------
    // Événements
    // ------------------------------------------------------------------
    racine.addEventListener('click', e => {
        const el = e.target.closest('button, .pos-ligne, .pos-reglement, [data-fermer]');
        if (!el) return;
        if (vue === 'plan') {
            const d = el.dataset;
            if (d.table) { const t = tableDe(Number(d.table)); if (t) ouvrirTable(t); }
            else if (d.salle !== undefined) { salleActive = Number(d.salle); afficher(); }
            else if (d.action === 'directe') { cmd = null; vue = 'vente'; mode = 'qte'; saisie = null; afficher(); }
            else if (d.action === 'attentes') listeAttentes();
            return;
        }
        if (vue !== 'vente') {
            const d = el.dataset;
            if (d.supprReglement !== undefined) supprimerReglement(Number(d.supprReglement));
            else if (d.modePaiement) ajouterReglement(Number(d.modePaiement));
            else if (d.reglement !== undefined) { pay.choisie = Number(d.reglement); pay.saisie = null; afficher(); }
            else if (d.billet) billet(d.billet);
            else if (d.pt) toucheReglement(d.pt);
            else if (d.action === 'retour') { if (!pay.envoi) { pay = null; vue = 'vente'; afficher(); } }
            else if (d.action === 'valider') valider();
            else if (d.action === 'imprimer') { const f = document.getElementById('posTicket'); if (f) f.contentWindow.print(); }
            else if (d.action === 'nouvelle-vente') nouvelleVente();
            else if (d.action === 'pourboire') pourboire();
            else if (d.action === 'continuer-table') { const t = tableDe(fin.resteTable.id) || fin.resteTable; fin = null; vue = 'plan'; ouvrirTable(t); }
            return;
        }
        if (e.target.closest('[data-fermer]')) { e.stopPropagation(); fermerTicket(Number(e.target.closest('[data-fermer]').dataset.fermer)); return; }
        const d = el.dataset;
        if (d.produit) ajouterProduit(produits.get(Number(d.produit)));
        else if (d.ligne !== undefined) { ticket().choisie = Number(d.ligne); saisie = null; afficher(); }
        else if (d.touche) touche(d.touche);
        else if (d.mode) choisirMode(d.mode);
        else if (d.categorie !== undefined) { categorieChoisie = Number(d.categorie); afficher(); }
        else if (d.ticket !== undefined) { etat.actif = Number(d.ticket); mode = 'qte'; saisie = null; enregistrer(); afficher(); }
        else if (d.action === 'nouveau') nouveauTicketActif();
        else if (d.action === 'attente') mettreEnAttente();
        else if (d.action === 'attentes') listeAttentes();
        else if (d.action === 'livraison') livraison();
        else if (d.action === 'additionticket') additionTicket();
        else if (d.action === 'deposer') deposer();
        else if (d.action === 'depots') listeDepots();
        else if (d.action === 'client') choisirClient();
        else if (d.action === 'remise') remiseGlobale();
        else if (d.action === 'payer') payer();
        else if (d.action === 'plan') retourPlan();
        else if (d.action === 'couverts') changerCouverts();
        else if (d.action === 'note') noteLigne();
        else if (d.action === 'envoyer') envoyer(false);
        else if (d.action === 'addition') addition();
        else if (d.action === 'partager') partager();
        else if (d.action === 'transferer') transferer();
    });

    racine.addEventListener('input', e => {
        if (e.target.id === 'posRecherche') { recherche = e.target.value; afficherGrille(); }
    });

    racine.addEventListener('keydown', e => {
        if (e.target.id !== 'posRecherche' || e.key !== 'Enter') return;
        e.preventDefault();
        const valeur = e.target.value;
        const p = trouverParCode(valeur);
        const liste = produitsAffiches();
        const choix = p || (liste.length === 1 ? liste[0] : null);
        if (choix) {
            recherche = '';
            ajouterProduit(choix);
            document.getElementById('posRecherche').focus();
        } else if (valeur.trim()) {
            message('Aucun produit pour « ' + valeur.trim() + ' ».', true);
        }
    });

    // Douchette hors du champ de recherche : caractères tapés très vite puis Entrée.
    // Clavier : chiffres et Retour arrière agissent sur le pavé.
    let tampon = '', dernier = 0;
    document.addEventListener('keydown', e => {
        if (document.querySelector('.pos-modal-fond')) return;
        if (vue === 'plan') return;
        if (vue === 'paiement') {
            if (/^[0-9]$/.test(e.key)) toucheReglement(e.key);
            else if (e.key === 'Backspace') { e.preventDefault(); toucheReglement('efface'); }
            else if (e.key === 'Enter') { e.preventDefault(); valider(); }
            else if (e.key === 'Escape' && !pay.envoi) { pay = null; vue = 'vente'; afficher(); }
            return;
        }
        if (vue === 'fin') {
            if (e.key === 'Enter') { e.preventDefault(); nouvelleVente(); }
            return;
        }
        const cible = e.target;
        if (cible.tagName === 'INPUT' || cible.tagName === 'TEXTAREA') return;
        const maintenant = Date.now();
        if (maintenant - dernier > 60) tampon = '';
        dernier = maintenant;
        if (e.key === 'Enter') {
            if (tampon.length >= 3) { e.preventDefault(); scanner(tampon); }
            tampon = '';
            return;
        }
        if (e.key.length === 1) {
            tampon += e.key;
            if (/[0-9,]/.test(e.key) && tampon.length === 1) {
                // Frappe isolée : touche du pavé, annulée si c'était le début d'un scan.
                setTimeout(() => { if (tampon === e.key) touche(e.key); }, 70);
            }
        } else if (e.key === 'Backspace') {
            e.preventDefault();
            touche('efface');
        }
    });

    // Plan de salle actualisé régulièrement (tables ouvertes ou encaissées sur d'autres appareils).
    if (R) {
        // Page rouverte sans connexion : le dernier plan connu du poste.
        try {
            const p = JSON.parse(localStorage.getItem(CLE_PLAN) || 'null');
            if (p && Array.isArray(p.salles) && !navigator.onLine) salles = p.salles;
        } catch (err) { /* plan illisible */ }
        superposer();
    }
    if (R) setInterval(() => { if (vue === 'plan' && !document.querySelector('.pos-modal-fond')) rafraichirPlan(); }, 8000);
    // Commandes en attente actualisées régulièrement (mises en attente ou reprises sur d'autres postes).
    setInterval(rafraichirAttentes, 15000);
    if (L) setInterval(rafraichirDepots, 30000);
    // Envoi d'une vente ou d'un dépôt fait hors ligne : numéro définitif annoncé, listes actualisées.
    window.addEventListener('gc-file', e => {
        const d = e.detail || {};
        if (d.envoye && d.reponse) {
            const libelles = { depot: 'Dépôt ' + d.envoye.numero + ' envoyé : dépôt n° ', attente: 'Commande ' + d.envoye.numero + ' mise en attente : n° ', vente: 'Vente ' + d.envoye.numero + ' envoyée : ticket ' };
            if (libelles[d.envoye.type]) message(libelles[d.envoye.type] + d.reponse.numero + '.');
            if (d.envoye.type === 'depot' || d.envoye.donnees.depotId) rafraichirDepots();
        }
        // Commande de la table ouverte envoyée : elle reprend l'identifiant du serveur (fusionnée au besoin).
        if (d.envoye && d.envoye.type === 'table' && cmd && cmd.cleFile === d.envoye.cle && !F.trouver(d.envoye.cle)) {
            const tbl = { id: cmd.tableId, nom: cmd.table };
            const choisie = cmd.choisie;
            cmd = d.reponse.commande ? commandeDepuis(d.reponse.commande, tbl)
                : { id: 0, version: 0, tableId: tbl.id, table: tbl.nom, couverts: cmd.couverts, addition: false, lignes: [], clientId: null, remise: null, choisie: -1, retire: false, base: {}, cleFile: null };
            cmd.choisie = Math.min(choisie, cmd.lignes.length - 1);
            if (vue === 'vente' && document.activeElement?.id !== 'posRecherche') afficher();
        }
        if (d.fin && d.envoyes) { rafraichirAttentes(); rafraichirPlan(); }
        if (d.ajoute || d.envoye || d.retire) racine.querySelectorAll('[data-action="attentes"]').forEach(b => { b.outerHTML = boutonAttentes(); });
        if (d.ajoute || d.envoye) { const liste = document.querySelector('.pos-modal-depots'); if (liste) remplirDepots(liste); }
    });

    afficher();
    rafraichirAttentes();
    rafraichirDepots();
})();
