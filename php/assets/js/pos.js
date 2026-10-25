// Écran de vente du point de vente (commun aux versions .NET et PHP).
// Les données (produits, catégories, clients, journée) sont fournies par la page
// dans <script id="pos-donnees" type="application/json">. Les tickets en cours
// sont gardés dans le navigateur (localStorage) jusqu'au paiement.
(function () {
    'use strict';

    const D = JSON.parse(document.getElementById('pos-donnees').textContent);
    const racine = document.getElementById('pos');
    const nf = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 2 });
    const fcfa = n => nf.format(Math.round(n));
    const qte = n => nf.format(n);
    const echap = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

    const produits = new Map(D.produits.map(p => [p.id, p]));
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
        try { localStorage.setItem(D.cle, JSON.stringify(etat)); } catch (err) { /* navigation privée… */ }
    }

    function nouveauTicket(numero) {
        return { numero: numero, lignes: [], clientId: null, choisie: -1 };
    }

    const ticket = () => etat.tickets[etat.actif];

    // ------------------------------------------------------------------
    // Calculs (prix TTC ; la TVA est comprise)
    // ------------------------------------------------------------------
    const totalLigne = l => Math.round(l.qte * l.prix * (1 - (l.remise || 0) / 100));
    function totaux(t) {
        let ttc = 0, tva = 0, unites = 0;
        t.lignes.forEach(l => {
            const tl = totalLigne(l);
            ttc += tl;
            tva += tl - tl / (1 + (l.tva || 0) / 100);
            unites += l.qte;
        });
        return { ttc: ttc, tva: Math.round(tva), unites: unites };
    }
    function quantiteAuTicket(produitId) {
        return ticket().lignes.filter(l => l.produitId === produitId).reduce((s, l) => s + l.qte, 0);
    }

    // ------------------------------------------------------------------
    // Actions
    // ------------------------------------------------------------------
    function ajouterProduit(p) {
        const t = ticket();
        let i = t.lignes.findIndex(l => l.produitId === p.id && l.prix === p.prix && !l.remise);
        if (i >= 0) {
            t.lignes[i].qte += 1;
        } else {
            t.lignes.push({ produitId: p.id, nom: p.nom, qte: 1, prix: p.prix, remise: 0, tva: p.tva });
            i = t.lignes.length - 1;
        }
        t.choisie = i;
        mode = 'qte';
        saisie = null;
        if (p.suivi && quantiteAuTicket(p.id) > p.stock) {
            message('Stock insuffisant pour « ' + p.nom + ' » : ' + qte(p.stock) + ' en stock.', true);
        }
        enregistrer();
        afficher();
    }

    function trouverParCode(code) {
        const c = code.trim().toLowerCase();
        if (!c) return null;
        return D.produits.find(p => (p.codeBarres || '').toLowerCase() === c)
            || D.produits.find(p => p.code.toLowerCase() === c) || null;
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

    function payer() {
        if (!ticket().lignes.length) { message('Le ticket est vide.'); return; }
        if (ticket().lignes.some(l => l.qte <= 0)) { message('Une ligne a une quantité nulle : corrigez-la ou supprimez-la.', true); return; }
        message('Le paiement arrive à la prochaine étape du module. Le ticket reste en attente.');
    }

    // ------------------------------------------------------------------
    // Affichage
    // ------------------------------------------------------------------
    function initiales(nom) {
        return nom.split(/\s+/).filter(m => /^[\p{L}\p{N}]/u.test(m)).slice(0, 2).map(m => m[0]).join('').toUpperCase();
    }

    function produitsAffiches() {
        const r = recherche.trim().toLowerCase();
        return D.produits.filter(p =>
            (!categorieChoisie || p.categorieId === categorieChoisie)
            && (!r || p.nom.toLowerCase().includes(r) || p.code.toLowerCase().includes(r) || (p.codeBarres || '').toLowerCase().includes(r)));
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
            if (p.suivi) {
                const reste = p.stock - quantiteAuTicket(p.id);
                const bas = p.seuil !== null ? reste <= p.seuil : reste <= 0;
                stock = '<div class="stock' + (bas ? ' bas' : '') + '">' + (bas ? 'Stock bas : ' : 'Stock : ') + qte(reste) + '</div>';
            }
            return '<button type="button" class="pos-tuile" data-produit="' + p.id + '">'
                + '<div class="img" style="background:' + echap(couleur) + '">' + echap(initiales(p.nom)) + '</div>'
                + '<span class="p">' + fcfa(p.prix) + '</span>'
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
            + '<div class="detail">' + qte(l.qte) + ' × ' + fcfa(l.prix)
            + (l.remise ? ' · <span class="remise">remise ' + qte(l.remise) + ' %</span>' : '') + '</div></div>'
            + '<div class="tot">' + fcfa(totalLigne(l)) + '</div></div>').join('');
    }

    function afficher() {
        const t = ticket();
        const tot = totaux(t);
        const client = clients.get(t.clientId);
        const k = (val, html, cls) => '<button type="button" class="pos-k ' + (cls || '') + '" data-touche="' + val + '">' + (html || val) + '</button>';
        const m = (val, txt) => '<button type="button" class="pos-k mode' + (mode === val ? ' on' : '') + '" data-mode="' + val + '"'
            + (val === 'prix' && !D.peutModifierPrix ? ' disabled title="Réservé aux administrateurs"' : '') + '>' + txt + '</button>';

        racine.innerHTML =
            '<div class="pos-top">'
            + '<span class="pos-logo">GC</span>'
            + '<div class="pos-titre"><strong>Point de vente · ' + echap(D.journee.caisse) + '</strong>'
            + '<small>' + echap(D.journee.libelle) + '</small></div>'
            + '<div class="pos-tabs">'
            + etat.tickets.map((tk, i) => '<button type="button" class="pos-tab' + (i === etat.actif ? ' on' : '') + '" data-ticket="' + i + '">Ticket ' + tk.numero
                + (tk.lignes.length ? ' · ' + tk.lignes.length : '') + '<span class="x" data-fermer="' + i + '" title="Abandonner ce ticket">×</span></button>').join('')
            + '<button type="button" class="pos-tab ajout" data-action="nouveau" title="Nouveau ticket"><i class="fas fa-plus"></i></button>'
            + '</div>'
            + '<div class="pos-droite">'
            + '<span class="pos-user"><span class="pos-avatar">' + echap(initiales(D.utilisateur.nom || '?')) + '</span><span>' + echap(D.utilisateur.nom) + ' · ' + echap(D.utilisateur.profil) + '</span></span>'
            + '<a class="pos-btn-top rouge" href="' + echap(D.urlFermer) + '"><i class="fas fa-power-off"></i> Fermer</a>'
            + '</div></div>'
            + '<div class="pos-main">'
            + '<div class="pos-ticket">'
            + '<div class="pos-lignes">' + htmlLignes(t) + '</div>'
            + '<div class="pos-totaux"><div class="pos-grand">' + fcfa(tot.ttc) + ' FCFA</div>'
            + '<div class="pos-tva">dont TVA : ' + fcfa(tot.tva) + ' · ' + t.lignes.length + ' article(s), ' + qte(tot.unites) + ' unité(s)</div></div>'
            + '<div class="pos-actions">'
            + '<button type="button" class="pos-act" data-action="client"><i class="fas fa-user"></i> ' + (client ? 'Client : <b>' + echap(client.nom) + '</b>' : 'Choisir un client') + '</button>'
            + '<button type="button" class="pos-act" data-action="nouveau"><i class="fas fa-pause"></i> Mettre en attente</button>'
            + '</div>'
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
        const el = e.target.closest('button, .pos-ligne, [data-fermer]');
        if (!el) return;
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
        else if (d.action === 'payer') payer();
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

    afficher();
})();
