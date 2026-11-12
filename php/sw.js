// GesCaisse — service worker (mode hors ligne, étape 1). Même fichier pour les versions PHP et .NET.
// - Écran de vente (Pos/Index?journee=… ou index.php?r=pos/index&journee=…) : réseau d'abord ; sans
//   réseau (ou après 5 s sans réponse), la dernière copie enregistrée est servie.
// - Ressources (CSS, JS, polices, bibliothèques des CDN) et images produits : servies depuis le cache et
//   rafraîchies en arrière-plan.
// - Autre page demandée hors ligne : page de secours « hors-ligne.html » (liste des caisses disponibles).
// - Déconnexion, ou passage par la page de connexion (session expirée) : les pages enregistrées sont effacées.
// Les envois (ventes, POST) ne passent pas par le cache : faits sans connexion, ils sont gardés dans la
// file du poste et envoyés au retour de la connexion (hors-ligne.js).
const VERSION = 'gc-1';
const STATIQUE = 'gc-statique-' + VERSION;
const IMAGES = 'gc-images';
const PAGES = 'gc-pages';
const SECOURS = new URL('hors-ligne.html', self.registration.scope).href;
// Heure du dernier effacement des pages (déconnexion) : un enregistrement commencé avant est abandonné,
// pour ne pas remettre en cache la caisse d'un utilisateur qui vient de se déconnecter.
let oubliLe = 0;
async function oublierPages() {
    oubliLe = Date.now();
    await caches.delete(PAGES);
}
async function garderPage(debut, url, reponse) {
    if (oubliLe < debut) await (await caches.open(PAGES)).put(url, reponse);
}

const estPos = url => /[?&]r=pos\/index(&|$)/i.test(url.search) && url.searchParams.has('journee')
    || /\/pos\/index$/i.test(url.pathname) && url.searchParams.has('journee');
const estDeconnexion = url => /[?&]r=auth\/logout/i.test(url.search) || /\/auth\/logout$/i.test(url.pathname);
const estConnexion = url => /[?&]r=auth\/login/i.test(url.search) || /\/auth\/login$/i.test(url.pathname);
const estImage = url => url.origin === self.location.origin && (/[?&]r=image\//i.test(url.search) || /\/image\/(produit|societe)/i.test(url.pathname));
const estStatique = url => url.origin === self.location.origin
    ? /\.(css|js|woff2?|ttf|png|jpe?g|svg|gif|ico|json)$/i.test(url.pathname) && !/\/sw\.js$/i.test(url.pathname)
    : /(cdn\.jsdelivr\.net|cdnjs\.cloudflare\.com|code\.jquery\.com|cdn\.datatables\.net|fonts\.(googleapis|gstatic)\.com)$/i.test(url.hostname);

self.addEventListener('install', e => {
    e.waitUntil(caches.open(STATIQUE).then(c => c.add(new Request(SECOURS, { cache: 'reload' }))).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
    e.waitUntil(caches.keys()
        .then(noms => Promise.all(noms.filter(n => n.startsWith('gc-statique-') && n !== STATIQUE).map(n => caches.delete(n))))
        .then(() => self.clients.claim()));
});

// Ressource sans son numéro de version (?v=) : sert à remplacer les anciennes versions en cache.
const cle = url => url.origin + url.pathname + (url.searchParams.has('r') ? '?r=' + url.searchParams.get('r') + '&id=' + url.searchParams.get('id') : '');

// Enregistre une réponse en remplaçant les anciennes versions de la même ressource.
async function garder(nom, requete, reponse) {
    const cache = await caches.open(nom);
    const url = new URL(requete.url);
    for (const k of await cache.keys()) {
        const u = new URL(k.url);
        if (u.href !== url.href && cle(u) === cle(url)) await cache.delete(k);
    }
    await cache.put(requete, reponse);
}

// Cache d'abord, rafraîchi en arrière-plan.
async function cacheEtReseau(e, nom) {
    const cache = await caches.open(nom);
    const enCache = await cache.match(e.request);
    const reseau = fetch(e.request).then(r => {
        if (r.ok || r.type === 'opaque') e.waitUntil(garder(nom, e.request, r.clone()));
        return r;
    }).catch(() => null);
    return enCache || (await reseau) || Response.error();
}

// Réseau d'abord (limité à 5 s), puis la copie enregistrée.
async function pageCaisse(e) {
    const cache = await caches.open(PAGES);
    const debut = Date.now();
    try {
        const r = await Promise.race([fetch(e.request), new Promise((_, rejet) => setTimeout(() => rejet(new Error('délai')), 5000))]);
        // Session expirée : le serveur renvoie la connexion ; on ne garde pas cette page à la place de la caisse.
        if (r.ok && !r.redirected) await garderPage(debut, e.request, r.clone());
        if (r.redirected && estConnexion(new URL(r.url))) await oublierPages();
        return r;
    } catch (err) {
        return (await cache.match(e.request)) || (await caches.match(SECOURS)) || Response.error();
    }
}

async function autrePage(e) {
    if (estDeconnexion(new URL(e.request.url))) await oublierPages();
    try {
        const r = await fetch(e.request);
        if (estConnexion(new URL(r.url))) await oublierPages();
        return r;
    } catch (err) {
        return (await caches.match(SECOURS)) || Response.error();
    }
}

self.addEventListener('fetch', e => {
    const req = e.request;
    if (req.method !== 'GET') return;
    const url = new URL(req.url);
    if (url.searchParams.has('gc-ping')) return;
    if (req.mode === 'navigate') {
        e.respondWith(estPos(url) ? pageCaisse(e) : autrePage(e));
    } else if (estImage(url)) {
        e.respondWith(cacheEtReseau(e, IMAGES));
    } else if (estStatique(url)) {
        e.respondWith(cacheEtReseau(e, STATIQUE));
    }
});

// Message de la page : enregistrer l'écran de vente ouvert et tout ce qu'il a chargé, pour qu'il se
// rouvre sans réseau dès la première visite.
self.addEventListener('message', e => {
    const d = e.data || {};
    if (d.type === 'garder-caisse') {
        e.waitUntil((async () => {
            const debut = Date.now();
            const page = await fetch(d.page, { credentials: 'same-origin' });
            if (page.ok && !page.redirected) await garderPage(debut, d.page, page);
            for (const u of d.ressources || []) {
                try {
                    const url = new URL(u);
                    const nom = estImage(url) ? IMAGES : estStatique(url) ? STATIQUE : null;
                    if (!nom || await (await caches.open(nom)).match(u)) continue;
                    const r = await fetch(u, url.origin === self.location.origin ? { credentials: 'same-origin' } : { mode: 'no-cors' });
                    if (r.ok || r.type === 'opaque') await garder(nom, new Request(u), r);
                } catch (err) { /* ressource indisponible : ignorée */ }
            }
        })());
    } else if (d.type === 'oublier-pages') {
        e.waitUntil(oublierPages());
    }
});
