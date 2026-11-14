// Écran cuisine / bar (commun aux versions .NET et PHP) : bons de préparation à préparer,
// actualisés toutes les 5 secondes ; « Prêt » retire le bon, « Rappeler » le remet en préparation.
// Impression automatique (option du poste) : chaque nouveau bon s'imprime sur l'imprimante de ce poste
// (cuisine ou bar), une seule fois ; « Imprimer » réimprime un bon.
// Données dans <script id="cuisine-donnees" type="application/json"> : { caisse, poste, urlBons, urlStatut, urlImpression, jeton }.
(function () {
    'use strict';

    const D = JSON.parse(document.getElementById('cuisine-donnees').textContent);
    const racine = document.getElementById('cuisine');
    const echap = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const nf = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 2 });
    let poste = D.poste || '';
    let bons = [], prets = [], connus = null, erreur = null;

    // Impression automatique : choix du poste et bons déjà imprimés, gardés dans le navigateur.
    const cleAuto = 'gescaisse-cuisine-impression:' + D.caisse, cleImprimes = 'gescaisse-cuisine-imprimes:' + D.caisse;
    const lire = (cle, defaut) => { try { return JSON.parse(localStorage.getItem(cle)) ?? defaut; } catch (e) { return defaut; } };
    const ecrire = (cle, valeur) => { try { localStorage.setItem(cle, JSON.stringify(valeur)); } catch (e) { /* stockage indisponible */ } };
    let auto = !!D.urlImpression && lire(cleAuto, false) === true;
    let imprimes = new Set(lire(cleImprimes, []));
    function noterImprimes(ids) {
        ids.forEach(id => imprimes.add(id));
        ecrire(cleImprimes, [...imprimes].slice(-400));
    }

    // Cadre caché : la page des bons s'imprime d'elle-même à son chargement.
    function imprimer(ids) {
        if (!ids.length || !D.urlImpression) return;
        let f = document.getElementById('cuiImpression');
        if (!f) {
            f = document.createElement('iframe');
            f.id = 'cuiImpression'; f.title = 'Impression';
            f.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0';
            document.body.appendChild(f);
        }
        f.src = D.urlImpression + ids.join(',');
    }

    function minutes(date) {
        return Math.max(0, Math.floor((Date.now() - new Date(date.replace(' ', 'T')).getTime()) / 60000));
    }

    // Signal sonore discret à l'arrivée d'un nouveau bon.
    function bip() {
        try {
            const ctx = new (window.AudioContext || window.webkitAudioContext)();
            const o = ctx.createOscillator(), g = ctx.createGain();
            o.frequency.value = 880; g.gain.value = 0.15;
            o.connect(g); g.connect(ctx.destination);
            o.start(); o.stop(ctx.currentTime + 0.25);
        } catch (e) { /* son indisponible */ }
    }

    async function charger() {
        try {
            const res = await fetch(D.urlBons + '&poste=' + encodeURIComponent(poste), { credentials: 'same-origin', cache: 'no-store' });
            const r = await res.json();
            if (!res.ok || r.erreur) throw new Error(r.erreur || 'Erreur ' + res.status);
            const nouveaux = r.bons.filter(b => connus && !connus.has(b.id));
            if (nouveaux.length) bip();
            if (auto) {
                const aImprimer = r.bons.filter(b => !imprimes.has(b.id)).map(b => b.id);
                if (aImprimer.length) { noterImprimes(aImprimer); imprimer(aImprimer); }
            }
            connus = new Set(r.bons.map(b => b.id));
            bons = r.bons; prets = r.prets; erreur = null;
        } catch (e) {
            erreur = 'Connexion perdue : nouvel essai dans quelques secondes…';
        }
        afficher();
    }

    async function statut(id, valeur) {
        const corps = new FormData();
        corps.append(D.jeton.nom, D.jeton.valeur);
        corps.append('id', id);
        corps.append('statut', valeur);
        await fetch(D.urlStatut, { method: 'POST', body: corps, credentials: 'same-origin' }).catch(() => null);
        charger();
    }

    function carte(b) {
        const m = minutes(b.date);
        const etat = m >= 20 ? 'retard' : m >= 10 ? 'attente' : '';
        return '<article class="cui-bon ' + etat + '">'
            + '<header><strong>' + echap(b.table || 'Vente directe') + '</strong><span>N° ' + b.numero + '</span></header>'
            + '<div class="cui-info"><span><i class="fas ' + (b.poste === 'Bar' ? 'fa-martini-glass' : 'fa-utensils') + '"></i> ' + echap(b.poste) + '</span>'
            + (b.couverts ? '<span><i class="fas fa-user"></i> ' + b.couverts + '</span>' : '')
            + '<span><i class="fas fa-clock"></i> ' + m + ' min</span></div>'
            + '<div class="cui-serveur">' + echap(b.serveur || '') + '</div>'
            + '<ul>' + b.lignes.map(l => '<li class="' + (l.qte < 0 ? 'annule' : '') + '"><b>' + nf.format(Math.abs(l.qte)) + ' ×</b> ' + echap(l.libelle)
                + (l.qte < 0 ? ' <em>ANNULÉ</em>' : '') + (l.note ? '<div class="note">» ' + echap(l.note) + '</div>' : '') + '</li>').join('') + '</ul>'
            + (D.urlImpression ? '<button type="button" class="cui-reimprimer" data-imprimer="' + b.id + '" title="Imprimer ce bon"><i class="fas fa-print"></i> Imprimer</button>' : '')
            + '<button type="button" data-pret="' + b.id + '"><i class="fas fa-check"></i> Prêt</button>'
            + '</article>';
    }

    function afficher() {
        const heure = new Date().toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
        racine.innerHTML = '<div class="cui-top">'
            + '<span class="cui-logo"><i class="fas fa-fire-burner"></i></span>'
            + '<div class="cui-titre"><strong>Écran ' + (poste === 'Bar' ? 'bar' : poste === 'Cuisine' ? 'cuisine' : 'cuisine / bar') + ' · ' + echap(D.caisse) + '</strong>'
            + '<small>' + bons.length + ' bon(s) à préparer · ' + heure + '</small></div>'
            + '<div class="cui-postes">' + [['', 'Tous'], ['Cuisine', 'Cuisine'], ['Bar', 'Bar']].map(([v, t]) =>
                '<button type="button" data-poste="' + v + '" class="' + (poste === v ? 'on' : '') + '">' + t + '</button>').join('') + '</div>'
            + (D.urlImpression ? '<div class="cui-postes"><button type="button" data-auto="1" class="' + (auto ? 'on' : '') + '" aria-pressed="' + auto + '"'
                + ' title="Imprimer automatiquement chaque nouveau bon sur l\'imprimante de ce poste"><i class="fas fa-print"></i> Impression auto' + (auto ? ' : oui' : ' : non') + '</button></div>' : '')
            + (D.urlRetour ? '<a class="cui-retour" href="' + echap(D.urlRetour) + '"><i class="fas fa-arrow-left"></i> Retour</a>' : '')
            + '</div>'
            + (erreur ? '<div class="cui-erreur">' + echap(erreur) + '</div>' : '')
            + (auto ? '<div class="cui-auto"><i class="fas fa-print"></i> Impression automatique : chaque nouveau bon '
                + (poste === 'Bar' ? 'du bar' : poste === 'Cuisine' ? 'de la cuisine' : 'de la cuisine et du bar') + ' s\'imprime sur l\'imprimante de ce poste.</div>' : '')
            + '<div class="cui-grille">' + (bons.length ? bons.map(carte).join('')
                : '<div class="cui-vide"><i class="fas fa-mug-hot"></i>Aucune commande à préparer.</div>') + '</div>'
            + (prets.length ? '<div class="cui-prets"><span>Prêts récemment :</span>' + prets.map(b =>
                '<button type="button" data-rappel="' + b.id + '" title="Remettre en préparation">' + echap(b.table || 'Vente directe') + ' · N° ' + b.numero
                + ' <i class="fas fa-rotate-left"></i></button>').join('') + '</div>' : '');
    }

    racine.addEventListener('click', e => {
        const b = e.target.closest('button');
        if (!b) return;
        if (b.dataset.pret) { b.disabled = true; statut(b.dataset.pret, 'Prêt'); }
        else if (b.dataset.imprimer) imprimer([Number(b.dataset.imprimer)]);
        else if (b.dataset.auto) {
            auto = !auto;
            ecrire(cleAuto, auto);
            // Activation : seuls les bons qui arrivent ensuite s'impriment (ceux déjà affichés sont tenus pour imprimés).
            if (auto) noterImprimes(bons.map(x => x.id));
            afficher();
        }
        else if (b.dataset.rappel) statut(b.dataset.rappel, 'À préparer');
        else if (b.dataset.poste !== undefined) {
            poste = b.dataset.poste; connus = null;
            try { localStorage.setItem('gescaisse-cuisine-poste', poste); } catch (err) { /* stockage indisponible */ }
            charger();
        }
    });

    try { if (!D.poste) poste = localStorage.getItem('gescaisse-cuisine-poste') || ''; } catch (err) { /* stockage indisponible */ }
    afficher();
    charger();
    setInterval(charger, 5000);
})();
