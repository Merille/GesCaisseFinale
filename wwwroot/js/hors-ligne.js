// GesCaisse — mode hors ligne (étape 1), commun aux versions PHP et .NET.
// - Inscrit le service worker (attribut data-sw du script : adresse de sw.js).
// - Sur l'écran de vente, fait enregistrer la page et tout ce qu'elle a chargé, pour qu'elle se rouvre
//   sans réseau.
// - Indicateur de connexion (éléments .gc-connexion) : « En ligne » / « Hors ligne », vérifié par un
//   petit appel au serveur toutes les 30 s (un wifi branché sans internet est détecté). Événement
//   « gc-connexion » à chaque changement ; window.gcConnexion.html() donne le badge à jour (pos.js).
// - Bouton « Installer l'application » (élément #gcInstaller) quand le navigateur le propose.
(function () {
    const script = document.currentScript;
    const sw = script && script.dataset.sw;
    let enLigne = navigator.onLine;
    let sondage = null;

    const html = () => '<span class="gc-connexion ' + (enLigne ? 'en-ligne' : 'hors-ligne') + '" role="status" title="'
        + (enLigne ? 'Connecté au serveur' : 'Pas de connexion au serveur : l\'écran de vente reste disponible') + '">'
        + '<span class="gc-point"></span>' + (enLigne ? 'En ligne' : 'Hors ligne') + '</span>';

    function majAffichage() {
        document.querySelectorAll('.gc-connexion').forEach(el => { el.outerHTML = html(); });
        document.documentElement.classList.toggle('gc-hors-ligne', !enLigne);
    }

    function changer(etat) {
        if (etat === enLigne) return;
        enLigne = etat;
        majAffichage();
        window.dispatchEvent(new CustomEvent('gc-connexion', { detail: { enLigne } }));
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
    sondage = setInterval(verifier, 30000);
    document.addEventListener('DOMContentLoaded', () => { majAffichage(); verifier(); });

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
