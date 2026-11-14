// Droits d'accès : masque les boutons et liens que le profil de l'utilisateur ne permet pas
// (créer, modifier, supprimer…). Le serveur refuse de toute façon ces actions ; ce script évite
// seulement de proposer des boutons inutiles. Données : window.GC_DROITS (carte des pages, mots des
// actions par opération, droits accordés), écrites par la mise en page. Commun aux versions PHP et .NET.
(function () {
    const D = window.GC_DROITS;
    if (!D || D.admin) return;
    const accordes = new Set(D.accordes);

    // Page visée par une adresse : [module, action], en PHP (?r=module/action) ou en .NET (/Module/Action/…).
    function page(adresse) {
        if (!adresse || /^(#|javascript:|mailto:|tel:)/i.test(adresse)) return null;
        let u;
        try { u = new URL(adresse, location.href); } catch (e) { return null; }
        if (u.origin !== location.origin) return null;
        const r = u.searchParams.get('r');
        const morceaux = (r || u.pathname.replace(/^\/+/, '')).toLowerCase().split('/').filter(Boolean);
        if (r === null && /\.php$/.test(morceaux[morceaux.length - 1] || '')) return null;
        return morceaux.length ? [morceaux[0], morceaux[1] || 'index', u.searchParams.get('id') || morceaux[2] || ''] : null;
    }

    function operation(action, id) {
        if (action === 'save' || action === 'edit') return Number(id) > 0 ? 'm' : 'a';
        for (const op of ['s', 'a', 'm']) if (D.mots[op].includes(action)) return op;
        return 'c';
    }

    // Permis ? (null : page inconnue, laissée telle quelle)
    function permis(module, action, id) {
        // .NET : ouvrir une journée et ajouter une opération depuis la page des caisses.
        const droit = module === 'caisse' && ['ouvrirjournee', 'ajouteroperation'].includes(action) ? 'journees' : D.carte[module];
        if (droit === undefined) return null;
        if (droit === '') return true;
        if (droit === 'admin') return false;
        let op = operation(action, id);
        if (!D.ops[droit] || !D.ops[droit].includes(op)) op = 'c';
        if (module === 'caisse' && op === 'c' && accordes.has('journees')) return true;
        if (module === 'synchro' && action === 'rapport') return true;
        return accordes.has(droit) && (op === 'c' || accordes.has(droit + '.' + op));
    }

    function masquer(el) { el.classList.add('d-none'); el.setAttribute('data-droit-masque', '1'); }

    function appliquer(racine) {
        racine.querySelectorAll('a[href]').forEach(a => {
            if (a.closest('.sb-nav')) return;
            const p = page(a.getAttribute('href'));
            if (p && permis(p[0], p[1], p[2]) === false) masquer(a);
        });
        racine.querySelectorAll('form[action]').forEach(f => {
            const p = page(f.getAttribute('action'));
            if (!p || f.closest('.modal')) return;
            const id = (f.querySelector('[name="id"],[name="Id"],[name="ID"]') || {}).value || p[2];
            if (permis(p[0], p[1], id) === false) masquer(f);
        });
        // Boutons qui ouvrent une fenêtre d'enregistrement (« Nouveau » : création ; bouton jaune ou avec
        // un identifiant : modification).
        racine.querySelectorAll('[data-bs-toggle="modal"][data-bs-target]').forEach(b => {
            const modale = document.querySelector(b.getAttribute('data-bs-target'));
            const form = modale && modale.querySelector('form[action]');
            const p = form && page(form.getAttribute('action'));
            if (!p || !['save', 'create', 'edit'].includes(p[1])) return;
            const modif = b.classList.contains('btn-warning') || Object.keys(b.dataset).some(k => k !== 'bsToggle' && k !== 'bsTarget' && b.dataset[k] !== '');
            if (permis(p[0], modif ? 'edit' : 'create', modif ? 1 : 0) === false) masquer(b);
        });
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', () => appliquer(document));
    else appliquer(document);
    // Contenus ajoutés plus tard (listes DataTables, fenêtres chargées) : même traitement.
    new MutationObserver(ms => ms.forEach(m => m.addedNodes.forEach(n => { if (n.nodeType === 1) appliquer(n); })))
        .observe(document.documentElement, { childList: true, subtree: true });
})();
