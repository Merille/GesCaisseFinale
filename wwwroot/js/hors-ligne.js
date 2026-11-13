// GesCaisse — mode hors ligne (étapes 1 et 2), commun aux versions PHP et .NET.
// - Inscrit le service worker (attribut data-sw du script : adresse de sw.js).
// - Sur l'écran de vente, fait enregistrer la page et tout ce qu'elle a chargé, pour qu'elle se rouvre
//   sans réseau.
// - Indicateur de connexion (éléments .gc-connexion) : « En ligne » / « Hors ligne », vérifié par un
//   petit appel au serveur toutes les 30 s (un wifi branché sans internet est détecté). Événement
//   « gc-connexion » à chaque changement ; window.gcConnexion.html() donne le badge à jour (pos.js).
// - « Installer l'application » : entrée du menu de l'utilisateur et bouton #gcInstaller (raccourci sur le
//   bureau, fenêtre propre), avec une aide quand le navigateur ne propose pas l'installation directe.
// - File d'attente du poste (window.gcFile) : ventes et dépôts de linge faits sans connexion, gardés
//   dans le navigateur et envoyés dans l'ordre dès le retour de la connexion (sur n'importe quelle page
//   de l'application), avec un jeton frais. Le serveur reconnaît un envoi déjà reçu (clé de la vente) :
//   rien n'est enregistré deux fois. Événement « gc-file » à chaque changement.
//   Étape 3 : commande de table prise hors ligne (un élément par table, remplacé à chaque modification),
//   mise en attente, et vente qui paie une table (elle reprend l'identifiant que le serveur a donné à
//   la commande de la table). Commande de table modifiée entre-temps sur un autre poste : les articles
//   ajoutés hors ligne sont ajoutés à la commande du serveur. Après l'envoi : message sur la page,
//   journal des derniers envois dans le panneau.
// - Rapport du poste (attributs data-rapport et data-jeton du script) : quand le poste est connecté, il
//   indique au serveur ce qu'il lui reste à envoyer (page Synchronisation des administrateurs).
// - Clôture protégée : un formulaire [data-gc-cloture="id de la journée"] n'est pas envoyé tant que
//   ce poste a des ventes de cette journée à envoyer.
(function () {
    const script = document.currentScript;
    const sw = script && script.dataset.sw;
    const urlRapport = script && script.dataset.rapport;
    const urlJetonRapport = script && script.dataset.jeton;
    let enLigne = navigator.onLine;
    let sondage = null;

    // ------------------------------------------------------------------
    // File d'attente du poste
    // ------------------------------------------------------------------
    const CLE_FILE = 'gc-hors-ligne-file';
    const CLE_POSTE = 'gc-hors-ligne-poste';
    const CLE_REFS = 'gc-hors-ligne-refs';
    const CLE_JOURNAL = 'gc-hors-ligne-journal';
    const lire = (cle, defaut) => { try { return JSON.parse(localStorage.getItem(cle) || 'null') ?? defaut; } catch (e) { return defaut; } };
    const ecrire = (cle, v) => { try { localStorage.setItem(cle, JSON.stringify(v)); return true; } catch (e) { return false; } };
    let envoi = { enCours: false, probleme: '' };

    const elements = () => { const f = lire(CLE_FILE, []); return Array.isArray(f) ? f : []; };
    const nombre = journeeId => elements().filter(x => !journeeId || x.journeeId === journeeId).length;

    function signaler(detail) {
        majAffichage();
        window.dispatchEvent(new CustomEvent('gc-file', { detail: detail || {} }));
        clearTimeout(signaler.rapport);
        signaler.rapport = setTimeout(() => rapporter(false), 2000);
    }

    // Rapport du poste au serveur : envoyé quand l'état de la file change, et au moins toutes les 5 min.
    const CLE_RAPPORT = 'gc-hors-ligne-rapport';
    async function rapporter(force) {
        if (!urlRapport || !urlJetonRapport || !enLigne) return;
        const f = elements();
        const etat = {
            poste: poste().code, enAttente: f.length, refusees: f.filter(x => x.erreur).length,
            montant: f.filter(x => x.type === 'vente' || x.type === 'depot' || x.type === 'attente').reduce((n, x) => n + (Number(x.montant) || 0), 0),
            plusAncien: f.reduce((m, x) => !m || x.cree < m ? x.cree : m, null),
            dernierEnvoi: (journal()[0] || {}).quand || null,
            elements: f.slice(0, 50).map(x => ({ numero: x.numero, type: x.type, libelle: x.libelle, montant: x.montant, cree: x.cree, erreur: x.erreur || '' }))
        };
        const signature = JSON.stringify(etat);
        const avant = lire(CLE_RAPPORT, {}) || {};
        if (!force && avant.signature === signature && Date.now() - (avant.quand || 0) < 300000) return;
        try {
            const jeton = await (await fetch(urlJetonRapport, { credentials: 'same-origin', cache: 'no-store' })).json().catch(() => null);
            if (!jeton || !jeton.nom) return;
            const corps = new FormData();
            corps.append(jeton.nom, jeton.valeur);
            corps.append('rapport', signature);
            const r = await fetch(urlRapport, { method: 'POST', body: corps, credentials: 'same-origin' });
            const reponse = await r.json().catch(() => null);   // réponse lue : la requête se termine
            if (r.ok && reponse && reponse.ok) ecrire(CLE_RAPPORT, { signature: signature, quand: Date.now() });
        } catch (e) { /* nouvel essai plus tard */ }
    }

    // Identifiant court du poste (navigateur) et compteur : numéros provisoires H-K7Q2-0001…
    function poste() {
        let p = lire(CLE_POSTE, null);
        if (!p || !p.code) {
            const lettres = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
            p = { code: Array.from({ length: 4 }, () => lettres[Math.floor(Math.random() * lettres.length)]).join(''), n: 0 };
            ecrire(CLE_POSTE, p);
        }
        return p;
    }
    function numeroProvisoire() {
        const p = poste();
        p.n += 1;
        ecrire(CLE_POSTE, p);
        return 'H-' + p.code + '-' + String(p.n).padStart(4, '0');
    }

    // Élément : { type: 'vente' | 'depot', numero, libelle, montant, journeeId, url, urlJeton, champ, donnees }.
    function ajouter(el) {
        const f = elements();
        f.push(Object.assign({ cree: new Date().toISOString(), essais: 0, erreur: '' }, el));
        if (!ecrire(CLE_FILE, f)) return false;
        signaler({ ajoute: el });
        if (enLigne) setTimeout(envoyer, 200);
        return true;
    }

    // Élément identifié par sa clé « cle » (commande d'une table) : remplacé sur place, à la même
    // position dans la file ; ajouté sinon. rev : numéro de version, pour ne pas retirer une commande
    // modifiée pendant son envoi.
    function mettre(el) {
        const f = elements();
        const i = f.findIndex(x => x.cle && x.cle === el.cle);
        if (i >= 0) f[i] = Object.assign({}, f[i], el, { rev: (f[i].rev || 0) + 1, erreur: '' });
        else f.push(Object.assign({ cree: new Date().toISOString(), essais: 0, erreur: '', rev: 1 }, el));
        if (!ecrire(CLE_FILE, f)) return false;
        signaler({ ajoute: el });
        if (enLigne) setTimeout(envoyer, 200);
        return true;
    }
    const trouver = cle => elements().find(x => x.cle === cle) || null;

    function retirer(numero) {
        ecrire(CLE_FILE, elements().filter(x => x.numero !== numero));
    }

    // Identifiant et version donnés par le serveur à une commande de table envoyée (clé de la file).
    const refs = () => lire(CLE_REFS, {}) || {};
    function noterRef(cle, commande) {
        const r = refs();
        r[cle] = commande ? { id: commande.id, version: commande.version, quand: Date.now() } : null;
        // On ne garde que les références des dernières 24 h.
        Object.keys(r).forEach(k => { if (r[k] && Date.now() - r[k].quand > 86400000) delete r[k]; });
        ecrire(CLE_REFS, r);
    }

    // Journal des 30 derniers envois (numéro provisoire, numéro définitif, remarque).
    const journal = () => { const j = lire(CLE_JOURNAL, []); return Array.isArray(j) ? j : []; };
    function journaliser(el, r, note) {
        const j = journal();
        j.unshift({ numero: el.numero, type: el.type, libelle: el.libelle, definitif: r && r.numero != null ? String(r.numero) : '', note: note || '', quand: new Date().toISOString() });
        ecrire(CLE_JOURNAL, j.slice(0, 30));
    }

    // Commande de table modifiée sur un autre poste pendant la coupure : celle du serveur est gardée et
    // les articles ajoutés hors ligne sur ce poste y sont ajoutés.
    function fusionnerTable(d, base, serveur) {
        // base : quantités connues du serveur au moment de la coupure ({ uid: quantité }).
        const deBase = Array.isArray(base) ? Object.fromEntries(base.map(u => [u, 0])) : (base || {});
        const lignes = serveur ? serveur.lignes.map(l => Object.assign({}, l)) : [];
        (d.lignes || []).forEach(l => {
            const ajout = l.uid in deBase ? Math.round((l.qte - deBase[l.uid]) * 100) / 100 : l.qte;
            if (ajout <= 0) return;
            const s = lignes.find(x => x.uid === l.uid);
            if (s) s.qte = Math.round((s.qte + ajout) * 100) / 100;
            else lignes.push(Object.assign({}, l, { qte: ajout, envoye: Math.min(ajout, l.envoye || 0) }));
        });
        if (!serveur) return Object.assign({}, d, { id: 0, version: 0, lignes: lignes });
        return Object.assign({}, d, {
            id: serveur.id, version: serveur.version, couverts: Math.max(serveur.couverts || 1, d.couverts || 1),
            clientId: serveur.clientId ?? d.clientId, remise: serveur.remise ?? d.remise, lignes: lignes
        });
    }

    function modifier(numero, champs) {
        ecrire(CLE_FILE, elements().map(x => x.numero === numero ? Object.assign(x, champs) : x));
    }

    const baseDe = c => c ? Object.fromEntries(c.lignes.map(l => [l.uid, l.qte])) : {};

    async function envoyer() {
        if (envoi.enCours || !enLigne || !elements().length) return;
        envoi = { enCours: true, probleme: '' };
        majAffichage();
        let envoyes = 0, refuses = 0;
        const notes = [];
        const vus = new Set();
        try {
            for (let tour = 0; tour < 500; tour++) {
                // Toujours le premier élément pas encore traité, relu (il a pu changer entre-temps).
                const el = elements().find(x => !vus.has(x.numero));
                if (!el) break;
                let donnees = el.donnees;
                // Vente qui paie une table prise hors ligne : identifiant donné par le serveur.
                const co = donnees.commandeOuverte;
                if (co && co.ref) {
                    const ref = refs()[co.ref];
                    if (trouver(co.ref) && !ref) { vus.add(el.numero); continue; }   // commande de la table pas encore envoyée
                    donnees = Object.assign({}, donnees, { commandeOuverte: Object.assign({}, co, ref ? { id: ref.id, version: ref.version } : { id: 0, version: 0 }) });
                }
                let jeton;
                try {
                    const rj = await fetch(el.urlJeton, { credentials: 'same-origin', cache: 'no-store' });
                    jeton = await rj.json().catch(() => null);
                    if (!jeton || !jeton.nom) { envoi.probleme = 'Session expirée : reconnectez-vous pour envoyer les ventes faites hors ligne.'; break; }
                } catch (e) { changer(false); break; }
                const corps = new FormData();
                corps.append(jeton.nom, jeton.valeur);
                corps.append(el.champ, JSON.stringify(donnees));
                let res, r;
                try {
                    res = await fetch(el.url, { method: 'POST', body: corps, credentials: 'same-origin' });
                    r = await res.json().catch(() => null);
                } catch (e) { changer(false); break; }
                if (el.type === 'table' && res.status === 409 && r && 'commande' in r && !el.fusionnee) {
                    // Modifiée ou encaissée sur un autre poste : fusion, puis nouvel envoi.
                    const fusion = fusionnerTable(el.donnees, el.base, r.commande);
                    modifier(el.numero, { donnees: fusion, base: baseDe(r.commande), fusionnee: true });
                    notes.push((el.libelle || 'Table') + ' : modifiée sur un autre poste, les articles ajoutés hors ligne y ont été ajoutés.');
                    continue;
                }
                if (res.ok && r && !r.erreur) {
                    const actuel = elements().find(x => x.numero === el.numero);
                    if (el.type === 'table') noterRef(el.cle, r.commande);
                    if (el.type === 'table' && actuel && (actuel.rev || 0) !== (el.rev || 0)) {
                        // Modifiée pendant l'envoi : la nouvelle version repart avec l'identifiant du serveur.
                        modifier(el.numero, { donnees: Object.assign({}, actuel.donnees, { id: r.commande ? r.commande.id : 0, version: r.commande ? r.commande.version : 0 }),
                            base: baseDe(r.commande) });
                    } else {
                        retirer(el.numero);
                        vus.add(el.numero);
                    }
                    if (el.type !== 'table') { envoyes += 1; journaliser(el, r, el.fusionnee ? 'fusionnée' : ''); }
                    else if (!actuel || (actuel.rev || 0) === (el.rev || 0)) { envoyes += 1; journaliser(el, null, el.fusionnee ? 'fusionnée avec la commande du serveur' : ''); }
                    signaler({ envoye: el, reponse: r });
                } else if (!r) {
                    envoi.probleme = 'Réponse inattendue du serveur (' + res.status + ') : nouvel essai plus tard.';
                    break;
                } else {
                    vus.add(el.numero);
                    // Seul un nouveau refus est annoncé (pas chaque nouvel essai).
                    if (!el.erreur) refuses += 1;
                    modifier(el.numero, { essais: (el.essais || 0) + 1, erreur: r.erreur || ('Erreur ' + res.status) });
                }
            }
        } finally {
            envoi.enCours = false;
            signaler({ fin: true, envoyes: envoyes, refuses: refuses, notes: notes });
            rapporter(true);
            if (envoyes || refuses || notes.length) {
                notifier((envoyes ? envoyes + ' opération' + (envoyes > 1 ? 's' : '') + ' faite' + (envoyes > 1 ? 's' : '') + ' hors ligne envoyée' + (envoyes > 1 ? 's' : '') + ' au serveur.' : '')
                    + (refuses ? ' ' + refuses + ' refusée' + (refuses > 1 ? 's' : '') + ' : touchez l\'indicateur pour le détail.' : '')
                    + (notes.length ? ' ' + notes.join(' ') : ''), refuses > 0);
            }
        }
    }

    // Message en bas de page, sur toutes les pages de l'application.
    function notifier(texte, erreur) {
        if (!document.body || !texte.trim()) return;
        let el = document.querySelector('.gc-toast');
        if (!el) { el = document.createElement('div'); el.setAttribute('role', 'status'); document.body.appendChild(el); }
        el.className = 'gc-toast' + (erreur ? ' erreur' : '');
        el.textContent = texte.trim();
        clearTimeout(notifier.minuterie);
        notifier.minuterie = setTimeout(() => el.remove(), 6000);
    }

    // Panneau : ce qui attend d'être envoyé (ouvert en touchant l'indicateur).
    function panneau() {
        document.querySelector('.gc-file-fond')?.remove();
        const f = elements();
        const j = journal();
        const echap = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
        const nf = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 });
        const fond = document.createElement('div');
        fond.className = 'gc-file-fond';
        fond.innerHTML = '<div class="gc-file" role="dialog" aria-modal="true" aria-label="Envois en attente">'
            + '<div class="gc-file-tete">Envois en attente (' + f.length + ')<button type="button" data-gc-fermer aria-label="Fermer">×</button></div>'
            + '<div class="gc-file-aide">' + (enLigne
                ? (envoi.enCours ? 'Envoi en cours…' : envoi.probleme || 'Connexion rétablie : l\'envoi se fait automatiquement.')
                : 'Pas de connexion : ces opérations faites sur ce poste seront envoyées automatiquement au retour de la connexion. Ne videz pas les données du navigateur.') + '</div>'
            + '<div class="gc-file-liste">' + (f.length ? f.map(x => '<div class="gc-file-el"><div><b>' + echap(x.numero) + '</b> · ' + echap(x.libelle || x.type)
                + '<small>' + echap(new Date(x.cree).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' })) + (x.erreur ? ' · <span class="gc-file-erreur">' + echap(x.erreur) + '</span>' : '') + '</small></div>'
                + '<span>' + (x.montant != null ? nf.format(x.montant) + ' FCFA' : '')
                // Commande de table ou mise en attente refusée (journée clôturée…) : elle peut être retirée ; une vente, jamais.
                + (x.erreur && x.type !== 'vente' && x.type !== 'depot' ? ' <button type="button" class="gc-file-retirer" data-gc-retirer="' + echap(x.numero) + '">Retirer</button>' : '')
                + '</span></div>').join('')
                : '<div class="gc-file-vide">Tout est envoyé.</div>') + '</div>'
            + (f.length && enLigne ? '<button type="button" class="gc-file-envoyer" data-gc-envoyer' + (envoi.enCours ? ' disabled' : '') + '>Envoyer maintenant</button>' : '')
            + (j.length ? '<div class="gc-file-journal"><div class="gc-file-sous-titre">Derniers envois</div>' + j.slice(0, 10).map(x => '<div class="gc-file-el"><div><b>' + echap(x.numero) + '</b> · ' + echap(x.libelle || x.type)
                + '<small>' + echap(new Date(x.quand).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' })) + (x.note ? ' · ' + echap(x.note) : '') + '</small></div>'
                + '<span>' + (x.definitif ? (x.type === 'depot' ? 'n° ' : '') + echap(x.definitif) : 'envoyée') + '</span></div>').join('') + '</div>' : '')
            + '</div>';
        document.body.appendChild(fond);
        fond.addEventListener('click', e => {
            const r = e.target.closest('[data-gc-retirer]');
            if (e.target === fond || e.target.closest('[data-gc-fermer]')) fond.remove();
            else if (e.target.closest('[data-gc-envoyer]')) { verifier().then(envoyer); fond.remove(); }
            else if (r && confirm('Retirer « ' + r.dataset.gcRetirer + ' » de la file ? Elle ne sera pas envoyée au serveur.')) {
                retirer(r.dataset.gcRetirer);
                signaler({ retire: r.dataset.gcRetirer });
                panneau();
            }
        });
    }

    window.gcFile = { rapporter, poste,
        ajouter, mettre, trouver, retirer, elements, nombre, envoyer, numeroProvisoire, panneau, refs, notifier };

    // ------------------------------------------------------------------
    // Indicateur
    // ------------------------------------------------------------------
    const html = () => {
        const n = elements().length;
        const refusees = elements().filter(x => x.erreur).length;
        const texte = (enLigne ? 'En ligne' : 'Hors ligne') + (n ? ' · ' + (envoi.enCours ? 'envoi de ' + n + '…' : n + ' à envoyer') : '')
            + (refusees && !envoi.enCours ? ' (' + refusees + ' refusée' + (refusees > 1 ? 's' : '') + ')' : '');
        const titre = n ? n + ' opération(s) faite(s) hors ligne sur ce poste, pas encore envoyée(s) : touchez pour le détail'
            : enLigne ? 'Connecté au serveur' : 'Pas de connexion au serveur : l\'écran de vente reste disponible, les ventes seront envoyées au retour de la connexion';
        return '<span class="gc-connexion ' + (enLigne ? 'en-ligne' : 'hors-ligne') + (n ? ' gc-attente' : '') + (refusees ? ' gc-refus' : '') + '" role="status" title="' + titre + '"'
            + (n ? ' data-gc-file tabindex="0"' : '') + '>'
            + '<span class="gc-point"></span>' + texte + '</span>';
    };

    function majAffichage() {
        document.querySelectorAll('.gc-connexion').forEach(el => { el.outerHTML = html(); });
        document.documentElement.classList.toggle('gc-hors-ligne', !enLigne);
    }

    function changer(etat) {
        if (etat === enLigne) return;
        enLigne = etat;
        majAffichage();
        window.dispatchEvent(new CustomEvent('gc-connexion', { detail: { enLigne } }));
        if (enLigne) envoyer();
    }

    // Vérifie la connexion par un petit appel au serveur (jamais servi par le cache).
    async function verifier() {
        if (!navigator.onLine) { changer(false); return; }
        try {
            const u = new URL(sw || 'sw.js', location.href);
            u.searchParams.set('gc-ping', Date.now());
            const r = await fetch(u, { method: 'HEAD', cache: 'no-store' });
            changer(r.ok || r.status < 500);
        } catch (e) {
            changer(false);
        }
    }

    window.gcConnexion = { get enLigne() { return enLigne; }, html, verifier };
    window.addEventListener('online', verifier);
    window.addEventListener('offline', () => changer(false));
    sondage = setInterval(() => verifier().then(envoyer).then(() => rapporter(false)), 30000);
    document.addEventListener('DOMContentLoaded', () => { majAffichage(); verifier().then(envoyer).then(() => rapporter(false)); });
    // Autre onglet du même poste : file modifiée.
    window.addEventListener('storage', e => { if (e.key === CLE_FILE) majAffichage(); });
    document.addEventListener('click', e => { if (e.target.closest('[data-gc-file]')) panneau(); });
    document.addEventListener('keydown', e => { if ((e.key === 'Enter' || e.key === ' ') && e.target.closest?.('[data-gc-file]')) { e.preventDefault(); panneau(); } });

    // Clôture d'une journée : impossible tant que ce poste a des ventes de cette journée à envoyer.
    document.addEventListener('submit', e => {
        const f = e.target.closest && e.target.closest('form[data-gc-cloture]');
        if (!f) return;
        const n = nombre(Number(f.dataset.gcCloture));
        if (!n) return;
        e.preventDefault();
        e.stopImmediatePropagation();
        alert(n + ' vente(s) ou dépôt(s) de cette journée, faits hors ligne sur ce poste, ne sont pas encore envoyés au serveur.\n'
            + (enLigne ? 'L\'envoi est lancé : attendez qu\'il se termine puis clôturez.' : 'Rétablissez la connexion : ils seront envoyés automatiquement, puis vous pourrez clôturer.'));
        verifier().then(envoyer);
    }, true);

    // Service worker : mise en cache de l'écran de vente ouvert (page, scripts, styles, polices, images).
    if (sw && 'serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost' || location.hostname === '127.0.0.1')) {
        navigator.serviceWorker.register(sw).then(() => navigator.serviceWorker.ready).then(reg => {
            if (!document.getElementById('pos-donnees') || !reg.active) return;
            const envoyer = () => reg.active.postMessage({
                type: 'garder-caisse',
                page: location.href,
                ressources: performance.getEntriesByType('resource').map(r => r.name).filter(n => /^https?:/.test(n))
            });
            if (document.readyState === 'complete') setTimeout(envoyer, 500);
            else window.addEventListener('load', () => setTimeout(envoyer, 500));
        }).catch(() => { /* navigateur sans service worker : pas de mode hors ligne */ });
    }

    // Installation de l'application, comme dans Odoo : entrée « Installer l'application » du menu de
    // l'utilisateur ([data-gc-installer]) et bouton #gcInstaller (affiché quand le navigateur la propose).
    // GesCaisse s'ouvre alors dans sa propre fenêtre, avec un raccourci sur le bureau et dans le menu
    // Démarrer (Windows) ou le Launchpad (Mac). Si le navigateur ne propose pas l'installation directe,
    // une fenêtre explique comment faire avec ce navigateur.
    let proposition = null;
    const installee = () => window.matchMedia('(display-mode: standalone)').matches || window.matchMedia('(display-mode: window-controls-overlay)').matches || navigator.standalone === true;
    function majInstallation() {
        document.querySelectorAll('[data-gc-installer]').forEach(b => {
            const fait = installee();
            b.disabled = fait;
            const texte = b.querySelector('span');
            if (texte) texte.textContent = fait ? 'Application installée sur ce poste' : 'Installer l\'application';
        });
        const bouton = document.getElementById('gcInstaller');
        if (bouton) bouton.classList.toggle('d-none', !proposition || installee());
    }
    function aideInstallation() {
        document.querySelector('.gc-file-fond')?.remove();
        const ua = navigator.userAgent;
        const ios = /iPhone|iPad|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
        const navigateur = /Edg\//.test(ua) ? 'edge' : /SamsungBrowser/.test(ua) ? 'samsung' : /Firefox|FxiOS/.test(ua) ? 'firefox'
            : ios ? 'ios' : /Chrome|CriOS|Chromium/.test(ua) ? 'chrome' : /Safari/.test(ua) ? 'safari' : 'autre';
        const etapes = {
            chrome: ['Cliquez sur l\'icône <b>Installer</b> (un écran avec une flèche) à droite de la barre d\'adresse,',
                     'ou ouvrez le menu <b>⋮</b> › <b>Caster, enregistrer et partager</b> › <b>Installer la page en tant qu\'application</b>,',
                     'confirmez avec <b>Installer</b>.'],
            edge: ['Cliquez sur l\'icône <b>Application disponible</b> à droite de la barre d\'adresse,',
                   'ou ouvrez le menu <b>…</b> › <b>Applications</b> › <b>Installer ce site en tant qu\'application</b>,',
                   'confirmez avec <b>Installer</b>.'],
            samsung: ['Ouvrez le menu <b>≡</b> › <b>Ajouter la page à</b> › <b>Écran d\'accueil</b>.'],
            ios: ['Touchez le bouton <b>Partager</b> (carré avec une flèche vers le haut),', 'choisissez <b>Sur l\'écran d\'accueil</b>, puis <b>Ajouter</b>.'],
            safari: ['Menu <b>Fichier</b> › <b>Ajouter au Dock</b> (macOS Sonoma ou plus récent).'],
            firefox: ['Firefox ne sait pas installer les applications web sur ordinateur : ouvrez GesCaisse avec <b>Google Chrome</b> ou <b>Microsoft Edge</b>, puis utilisez « Installer l\'application ».'],
            autre: ['Ouvrez GesCaisse avec <b>Google Chrome</b> ou <b>Microsoft Edge</b>, puis utilisez « Installer l\'application ».']
        }[navigateur];
        const fond = document.createElement('div');
        fond.className = 'gc-file-fond';
        fond.innerHTML = '<div class="gc-file gc-install" role="dialog" aria-modal="true" aria-label="Installer l\'application">'
            + '<div class="gc-file-tete">Installer GesCaisse sur ce poste<button type="button" data-gc-fermer aria-label="Fermer">×</button></div>'
            + '<div class="gc-file-liste" style="padding:14px 16px">'
            + '<p>Installée, GesCaisse s\'ouvre dans sa propre fenêtre, comme un logiciel, avec un raccourci sur le bureau et dans le menu Démarrer. '
            + 'Elle reste disponible sans connexion pour vendre.</p>'
            + (window.isSecureContext ? '' : '<div class="gc-install-actuel">L\'installation demande une adresse sécurisée (https://). Ouvrez GesCaisse par son adresse en https.</div>')
            + '<div class="gc-install-actuel">Votre navigateur ne propose pas l\'installation directe pour le moment. Avec '
            + ({ chrome: 'Google Chrome', edge: 'Microsoft Edge', samsung: 'Samsung Internet', ios: 'Safari (iPhone, iPad)', safari: 'Safari (Mac)', firefox: 'Firefox', autre: 'ce navigateur' }[navigateur]) + ' :</div>'
            + '<ol>' + etapes.map(e => '<li>' + e + '</li>').join('') + '</ol>'
            + '<p class="text-muted small" style="color:#64748b;font-size:13px">Sous Windows, l\'application installée peut ensuite être épinglée à la barre des tâches (clic droit sur son icône › Épingler). '
            + 'Si GesCaisse est déjà installée, ouvrez-la depuis son raccourci.</p>'
            + '</div></div>';
        document.body.appendChild(fond);
        fond.addEventListener('click', e => { if (e.target === fond || e.target.closest('[data-gc-fermer]')) fond.remove(); });
    }
    function installer() {
        if (installee()) { notifier('GesCaisse est déjà installée : vous l\'utilisez dans sa fenêtre d\'application.'); return; }
        if (!proposition) { aideInstallation(); return; }
        proposition.prompt();
        proposition.userChoice.then(choix => {
            if (choix && choix.outcome === 'accepted') notifier('GesCaisse est installée : un raccourci a été ajouté sur ce poste.');
        }).finally(() => { proposition = null; majInstallation(); });
    }
    window.addEventListener('beforeinstallprompt', e => {
        e.preventDefault();
        proposition = e;
        majInstallation();
    });
    document.addEventListener('click', e => {
        if (e.target.closest('#gcInstaller, [data-gc-installer]')) installer();
    });
    window.addEventListener('appinstalled', () => { proposition = null; majInstallation(); });
    document.addEventListener('DOMContentLoaded', majInstallation);
    window.gcInstaller = { installer, aideInstallation };
})();
