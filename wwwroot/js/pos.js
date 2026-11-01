// Écran de vente du point de vente (commun aux versions .NET et PHP).
// Les données (produits, catégories, clients, journée) sont fournies par la page
// dans <script id="pos-donnees" type="application/json">. Les tickets en cours
// sont gardés dans le navigateur (localStorage) jusqu'au paiement.
// Restaurant / bar (D.restaurant) : l'écran s'ouvre sur le plan de salle ; la commande de
// chaque table est gardée sur le serveur (partagée entre serveurs et appareils), envoyée en
// cuisine / au bar par bons de préparation, puis encaissée (en une fois ou partagée).
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
            if (!(await vider()) || !cmd || !cmd.id) { message('La commande de la table n\'est pas enregistrée : vérifiez la connexion.', true); return; }
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
            lignes: cmd.lignes.map(l => ({ uid: l.uid, produitId: l.produitId, nom: l.nom, qte: l.qte, prix: l.prix, remise: l.remise || 0, tva: l.tva, unite: l.unite, note: l.note || '', composants: l.composants || [] })),
            clientId: cmd.clientId, remise: cmd.remise || null
        };
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
            id: s.id, version: s.version, tableId: s.tableId, table: t.nom || 'Table', couverts: s.couverts, addition: !!s.addition,
            lignes: (s.lignes || []).map(l => Object.assign({}, l)), clientId: s.clientId || null, remise: s.remise || null, choisie: -1, retire: false
        };
    }

    // Réponse du serveur appliquée à la commande affichée (identifiant, version, quantités envoyées).
    function appliquerServeur(s) {
        if (!cmd) return;
        if (!s) { cmd.id = 0; cmd.version = 0; cmd.addition = false; cmd.lignes.forEach(l => { l.envoye = 0; }); return; }
        cmd.id = s.id; cmd.version = s.version; cmd.addition = !!s.addition;
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
        if (sync.enCours) { sync.encore = true; return true; }
        clearTimeout(sync.minuterie);
        sync.enCours = true;
        const c = cmd;
        const res = await appel(R.urlEnregistrer, 'commande', donneesCommande());
        sync.enCours = false;
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
    function imprimerDans(url) {
        let f = document.getElementById('posImpression');
        if (!f) {
            f = document.createElement('iframe');
            f.id = 'posImpression';
            f.title = 'Impression';
            f.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0';
            document.body.appendChild(f);
        }
        f.src = url;
    }

    // Envoie en cuisine / au bar les articles pas encore envoyés (et les annulations).
    async function envoyer(silencieux) {
        if (!cmd) return true;
        if (!aEnvoyer()) { if (!silencieux) message('Tous les articles sont déjà envoyés.'); return true; }
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

    function tableDe(id) {
        for (const s of salles) for (const t of s.tables) if (t.id === id) return t;
        return null;
    }

    async function rafraichirPlan() {
        if (!R) return;
        try {
            const res = await fetch(R.urlPlan, { credentials: 'same-origin', cache: 'no-store' });
            const r = await res.json();
            if (res.ok && r.salles) { salles = r.salles; if (vue === 'plan') afficher(); }
        } catch (err) { /* nouvel essai à la prochaine actualisation */ }
    }

    async function ouvrirTable(t) {
        let s = null;
        try {
            const res = await fetch(R.urlCommande + '&table=' + t.id, { credentials: 'same-origin', cache: 'no-store' });
            const r = await res.json();
            if (!res.ok || r.erreur) throw new Error(r.erreur || 'Erreur ' + res.status);
            s = r.commande;
        } catch (err) {
            message(err.message && !/fetch|network|JSON/i.test(err.message) ? err.message : 'Connexion impossible : réessayez.', true);
            return;
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
        if (!(await vider()) || !cmd.id) return;
        imprimerDans(R.urlAddition + cmd.id);
        cmd.addition = true;
        message('Addition imprimée : la table passe en « addition demandée ».');
        afficher();
    }

    // Fenêtre : table de destination (une table occupée reçoit les articles en plus des siens).
    async function transferer() {
        if (!cmd.lignes.length) { message('La commande est vide.'); return; }
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
            + '<div class="pos-droite">'
            + '<button type="button" class="pos-btn-top" data-action="directe"><i class="fas fa-bag-shopping"></i> Vente directe</button>'
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
        const total = ttc + (pay.pourboire || 0);
        let recu = 0, especes = 0;
        pay.lignes.forEach(r => {
            recu += r.montant;
            if (modes.get(r.modeId)?.especes) especes += r.montant;
        });
        const rendu = Math.max(0, recu - total);
        return {
            ttc: ttc, total: total, recu: recu, especes: especes, rendu: rendu,
            reste: Math.max(0, total - recu),
            ok: pay.lignes.length > 0 && recu >= total && rendu <= especes && !pay.lignes.some(r => r.montant <= 0)
        };
    }

    function ajouterReglement(modeId) {
        // Montant proposé : le reste à payer (comme sur Odoo) ; la première frappe le remplace.
        pay.lignes.push({ modeId: modeId, montant: etatPaiement().reste, auto: true });
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
            message(e.recu < e.total ? 'Il reste ' + fcfa(e.reste) + ' FCFA à payer.'
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
            paiements: pay.lignes.map(r => ({ modeId: r.modeId, montant: r.montant }))
        };
        const corps = new FormData();
        corps.append(D.jeton.nom, D.jeton.valeur);
        corps.append('vente', JSON.stringify(vente));
        pay.envoi = true;
        afficher();
        let reponse = null;
        try {
            const res = await fetch(D.urlVendre, { method: 'POST', body: corps, credentials: 'same-origin' });
            reponse = await res.json().catch(() => null);
            if (!res.ok || !reponse || reponse.erreur) throw new Error(reponse && reponse.erreur ? reponse.erreur : 'Réponse inattendue du serveur (' + res.status + ').');
        } catch (err) {
            pay.envoi = false;
            afficher();
            message((err && err.message && !/fetch|network/i.test(err.message) ? err.message : 'Connexion impossible : la vente n\'est pas enregistrée. Réessayez.'), true);
            return;
        }
        // Stock affiché mis à jour sans recharger la page.
        lignesAPayer().forEach(l => { const p = produits.get(l.produitId); if (p && p.suivi) p.stock -= l.qte; });
        fin = { id: reponse.id, numero: reponse.numero, rendu: e.rendu, direct: !cmd, resteTable: null };
        if (cmd) {
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
        pay = null;
        vue = 'fin';
        afficher();
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
        if (/mobile|money|airtel|moov|momo/.test(t)) return 'fa-mobile-screen-button';
        if (/carte|cb|visa|bancaire/.test(t)) return 'fa-credit-card';
        if (/ch[eè]que/.test(t)) return 'fa-money-check';
        if (/virement/.test(t)) return 'fa-building-columns';
        return 'fa-wallet';
    }

    function enteteSimple(titre, sousTitre) {
        return '<div class="pos-top"><span class="pos-logo">GC</span>'
            + '<div class="pos-titre"><strong>' + echap(titre) + '</strong><small>' + echap(sousTitre) + '</small></div>'
            + '<div class="pos-droite"><span class="pos-user"><span class="pos-avatar">' + echap(initiales(D.utilisateur.nom || '?')) + '</span><span>'
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
            + (pay.pourboire ? '<small>dont pourboire ' + fcfa(pay.pourboire) + '</small>' : '') + '</div>'
            + '<div class="pos-bloc' + (e.reste > 0 ? ' reste' : '') + '"><small>Reste à payer</small><div class="v">' + fcfa(e.reste) + '</div></div>'
            + '<div class="pos-bloc rendre"><small>Monnaie à rendre</small><div class="v">' + fcfa(e.rendu) + '</div></div>'
            + '</div>'
            + '<h3>Règlements</h3>'
            + '<div class="pos-reglements">'
            + (pay.lignes.length
                ? pay.lignes.map((r, i) => {
                    const m = modes.get(r.modeId) || { libelle: '?' };
                    return '<div class="pos-reglement' + (i === pay.choisie ? ' sel' : '') + '" data-reglement="' + i + '">'
                        + '<i class="fas ' + iconeMode(m) + '"></i> ' + echap(m.libelle) + (m.especes ? ' <small>reçu</small>' : '')
                        + '<b>' + fcfa(r.montant) + '</b>'
                        + '<button type="button" class="x" data-suppr-reglement="' + i + '" aria-label="Supprimer ce règlement"><i class="fas fa-xmark"></i></button></div>';
                }).join('')
                : '<div class="pos-aide">Choisissez un mode de paiement à gauche.</div>')
            + '</div>'
            + '<h3>Billets rapides (espèces)</h3>'
            + '<div class="pos-billets">' + [500, 1000, 2000, 5000, 10000].map(b => '<button type="button" class="pos-billet" data-billet="' + b + '">+' + fcfa(b) + '</button>').join('')
            + '<button type="button" class="pos-billet" data-billet="exact">Montant exact</button></div>'
            + '<div class="pos-aide"><i class="fas fa-circle-info"></i> À la validation, chaque règlement devient un encaissement validé de la journée de caisse (motif « Vente POS »).</div>'
            + '</div>'
            + '<div class="pos-droite2">'
            + '<div class="pos-pave pos-pave3">' + ['1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0'].map(v => pt(v)).join('') + pt('efface', '<i class="fas fa-delete-left"></i>') + '</div>'
            + '<button type="button" class="pos-retour" data-action="retour"><i class="fas fa-arrow-left"></i> Retour au ticket</button>'
            + '<button type="button" class="pos-valider" data-action="valider"' + (e.ok && !pay.envoi ? '' : ' disabled') + '>'
            + (pay.envoi ? '<i class="fas fa-spinner fa-spin"></i> Enregistrement…' : '<i class="fas fa-check"></i> Valider le paiement') + '</button>'
            + '</div></div>';
    }

    function afficherFin() {
        racine.innerHTML = enteteSimple('Vente terminée · ' + fin.numero, D.journee.caisse + ' · ' + D.journee.libelle)
            + '<div class="pos-finzone">'
            + '<div class="pos-apercu"><iframe id="posTicket" title="Ticket de caisse" src="' + echap(D.urlTicket + fin.id) + '"></iframe></div>'
            + '<div class="pos-fin">'
            + '<div class="pos-ok"><i class="fas fa-check"></i></div>'
            + '<h2>Paiement enregistré</h2>'
            + '<p>Les encaissements sont dans la journée de caisse ' + echap(D.journee.caisse) + '.</p>'
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
            + '<div class="pos-titre"><strong>' + (R ? (cmd ? echap(cmd.table) : 'Vente directe') : 'Point de vente') + ' · ' + echap(D.journee.caisse) + '</strong>'
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
            + '<div class="pos-droite">'
            + '<span class="pos-user"><span class="pos-avatar">' + echap(initiales(D.utilisateur.nom || '?')) + '</span><span>' + echap(D.utilisateur.nom) + ' · ' + echap(D.utilisateur.profil) + '</span></span>'
            + (D.urlVentes ? '<a class="pos-btn-top" href="' + echap(D.urlVentes) + '"><i class="fas fa-receipt"></i> Ventes</a>' : '')
            + '<a class="pos-btn-top rouge" href="' + echap(D.urlFermer) + '"><i class="fas fa-power-off"></i> Fermer</a>'
            + '</div></div>'
            + '<div class="pos-main">'
            + '<div class="pos-ticket">'
            + '<div class="pos-lignes">' + htmlLignes(t) + '</div>'
            + '<div class="pos-totaux">'
            + (tot.remise ? '<div class="pos-tva">Sous-total ' + fcfa(tot.brut) + ' · <span class="remise">remise globale'
                + (t.remise.type === 'pct' ? ' ' + qte(t.remise.valeur) + ' %' : '') + ' −' + fcfa(tot.remise) + '</span></div>' : '')
            + '<div class="pos-grand">' + fcfa(tot.ttc) + ' FCFA</div>'
            + '<div class="pos-tva">dont taxes : ' + fcfa(tot.tva) + ' · ' + t.lignes.length + ' article(s), ' + qte(tot.unites) + ' unité(s)</div></div>'
            + '<div class="pos-actions">'
            + '<button type="button" class="pos-act" data-action="client"><i class="fas fa-user"></i> ' + (client ? 'Client : <b>' + echap(client.nom) + '</b>' : 'Choisir un client') + '</button>'
            + (cmd ? '<button type="button" class="pos-act" data-action="note"><i class="fas fa-comment-dots"></i> Note</button>'
                : '<button type="button" class="pos-act" data-action="nouveau"><i class="fas fa-pause"></i> Mettre en attente</button>')
            + '<button type="button" class="pos-act" data-action="remise"' + (D.peutRemiseGlobale ? '' : ' disabled title="Réservée aux administrateurs"') + '>'
            + '<i class="fas fa-percent"></i> ' + (t.remise ? 'Remise : <b>' + (t.remise.type === 'pct' ? qte(t.remise.valeur) + ' %' : fcfa(t.remise.valeur)) + '</b>' : 'Remise globale') + '</button>'
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
                    + echap(c.nom) + '<small>' + echap(c.code) + '</small></button>').join('');
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
    if (R) setInterval(() => { if (vue === 'plan' && !document.querySelector('.pos-modal-fond')) rafraichirPlan(); }, 8000);

    afficher();
})();
