// GesCaisse — mode hors ligne (étapes 1 et 2), commun aux versions PHP et .NET.
// - Inscrit le service worker (attribut data-sw du script : adresse de sw.js).
// - Sur l'écran de vente, fait enregistrer la page et tout ce qu'elle a chargé, pour qu'elle se rouvre
//   sans réseau.
// - Indicateur de connexion (éléments .gc-connexion) : « En ligne » / « Hors ligne », vérifié par un
//   petit appel au serveur toutes les 30 s (un wifi branché sans internet est détecté). Événement
//   « gc-connexion » à chaque changement ; window.gcConnexion.html() donne le badge à jour (pos.js).
// - Bouton « Installer l'application » (élément #gcInstaller) quand le navigateur le propose.
// - File d'attente du poste (window.gcFile) : ventes et dépôts de linge faits sans connexion, gardés
//   dans le navigateur et envoyés dans l'ordre dès le retour de la connexion (sur n'importe quelle page
//   de l'application), avec un jeton frais. Le serveur reconnaît un envoi déjà reçu (clé de la vente) :
//   rien n'est enregistré deux fois. Événement « gc-file » à chaque changement.
// - Clôture protégée : un formulaire [data-gc-cloture="id de la journée"] n'est pas envoyé tant que
//   ce poste a des ventes de cette journée à envoyer.
(function () {
    const script = document.currentScript;
    const sw = script && script.dataset.sw;
    let enLigne = navigator.onLine;
    let sondage = null;

    // ------------------------------------------------------------------
    // File d'attente du poste
    // ------------------------------------------------------------------
    const CLE_FILE = 'gc-hors-ligne-file';
    const CLE_POSTE = 'gc-hors-ligne-poste';
    const lire = (cle, defaut) => { try { return JSON.parse(localStorage.getItem(cle) || 'null') ?? defaut; } catch (e) { return defaut; } };
    const ecrire = (cle, v) => { try { localStorage.setItem(cle, JSON.stringify(v)); return true; } catch (e) { return false; } };
    let envoi = { enCours: false, probleme: '' };

    const elements = () => { const f = lire(CLE_FILE, []); return Array.isArray(f) ? f : []; };
    const nombre = journeeId => elements().filter(x => !journeeId || x.journeeId === journeeId).length;

    function signaler(detail) {
        majAffichage();
        window.dispatchEvent(new CustomEvent('gc-file', { detail: detail || {} }));
    }

    // Identifiant court du poste (navigateur) et compteur : numéros provisoires H-K7Q2-0001…
    function numeroProvisoire() {
        let p = lire(CLE_POSTE, null);
        if (!p || !p.code) {
            const lettres = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
            p = { code: Array.from({ length: 4 }, () => lettres[Math.floor(Math.random() * lettres.length)]).join(''), n: 0 };
        }
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

    function retirer(numero) {
        ecrire(CLE_FILE, elements().filter(x => x.numero !== numero));
    }

    function modifier(numero, champs) {
        ecrire(CLE_FILE, elements().map(x => x.numero === numero ? Object.assign(x, champs) : x));
    }

    // Envoi de la file, dans l'ordre. Arrêt à la première coupure ; une vente refusée par le serveur
    // reste dans la file (motif affiché) sans bloquer les suivantes.
    async function envoyer() {
        if (envoi.enCours || !enLigne || !elements().length) return;
        envoi = { enCours: true, probleme: '' };
        majAffichage();
        let envoyes = 0;
        try {
            for (const el of elements()) {
                let jeton;
                try {
                    const rj = await fetch(el.urlJeton, { credentials: 'same-origin', cache: 'no-store' });
                    jeton = await rj.json().catch(() => null);
                    if (!jeton || !jeton.nom) { envoi.probleme = 'Session expirée : reconnectez-vous pour envoyer les ventes faites hors ligne.'; break; }
                } catch (e) { changer(false); break; }
                const corps = new FormData();
                corps.append(jeton.nom, jeton.valeur);
                corps.append(el.champ, JSON.stringify(el.donnees));
                let res, r;
                try {
                    res = await fetch(el.url, { method: 'POST', body: corps, credentials: 'same-origin' });
                    r = await res.json().catch(() => null);
                } catch (e) { changer(false); break; }
                if (res.ok && r && !r.erreur) {
                    retirer(el.numero);
                    envoyes += 1;
                    signaler({ envoye: el, reponse: r });
                } else if (!r) {
                    envoi.probleme = 'Réponse inattendue du serveur (' + res.status + ') : nouvel essai plus tard.';
                    break;
                } else {
                    modifier(el.numero, { essais: (el.essais || 0) + 1, erreur: r.erreur || ('Erreur ' + res.status) });
                }
            }
        } finally {
            envoi.enCours = false;
            signaler({ fin: true, envoyes: envoyes });
        }
    }

    // Panneau : ce qui attend d'être envoyé (ouvert en touchant l'indicateur).
    function panneau() {
        document.querySelector('.gc-file-fond')?.remove();
        const f = elements();
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
                + '<span>' + (x.montant != null ? nf.format(x.montant) + ' FCFA' : '') + '</span></div>').join('')
                : '<div class="gc-file-vide">Tout est envoyé.</div>') + '</div>'
            + (f.length && enLigne ? '<button type="button" class="gc-file-envoyer" data-gc-envoyer' + (envoi.enCours ? ' disabled' : '') + '>Envoyer maintenant</button>' : '')
            + '</div>';
        document.body.appendChild(fond);
        fond.addEventListener('click', e => {
            if (e.target === fond || e.target.closest('[data-gc-fermer]')) fond.remove();
            else if (e.target.closest('[data-gc-envoyer]')) { verifier().then(envoyer); fond.remove(); }
        });
    }

    window.gcFile = { ajouter, elements, nombre, envoyer, numeroProvisoire, panneau };

    // ------------------------------------------------------------------
    // Indicateur
    // ------------------------------------------------------------------
    const html = () => {
        const n = elements().length;
        const texte = (enLigne ? 'En ligne' : 'Hors ligne') + (n ? ' · ' + (envoi.enCours ? 'envoi de ' + n + '…' : n + ' à envoyer') : '');
        const titre = n ? n + ' opération(s) faite(s) hors ligne sur ce poste, pas encore envoyée(s) : touchez pour le détail'
            : enLigne ? 'Connecté au serveur' : 'Pas de connexion au serveur : l\'écran de vente reste disponible, les ventes seront envoyées au retour de la connexion';
        return '<span class="gc-connexion ' + (enLigne ? 'en-ligne' : 'hors-ligne') + (n ? ' gc-attente' : '') + '" role="status" title="' + titre + '"'
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
    sondage = setInterval(() => verifier().then(envoyer), 30000);
    document.addEventListener('DOMContentLoaded', () => { majAffichage(); verifier().then(envoyer); });
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

    // Installation de l'application (bouton #gcInstaller affiché quand le navigateur la propose).
    let proposition = null;
    window.addEventListener('beforeinstallprompt', e => {
        e.preventDefault();
        proposition = e;
        const b = document.getElementById('gcInstaller');
        if (b) b.classList.remove('d-none');
    });
    document.addEventListener('click', e => {
        if (!e.target.closest('#gcInstaller') || !proposition) return;
        proposition.prompt();
        proposition.userChoice.finally(() => {
            proposition = null;
            document.getElementById('gcInstaller')?.classList.add('d-none');
        });
    });
    window.addEventListener('appinstalled', () => document.getElementById('gcInstaller')?.classList.add('d-none'));
})();
