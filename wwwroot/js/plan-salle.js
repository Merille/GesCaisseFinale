// Éditeur du plan de salle d'une caisse restaurant / bar (commun aux versions .NET et PHP).
// Données dans <script id="plan-donnees" type="application/json"> : { caisseId, salles, urlEnregistrer, jeton }.
// Les tables se placent sur un plan de 1000 × 600 points (glisser pour déplacer, poignée pour
// agrandir) ; « Enregistrer le plan » envoie toutes les salles en une fois.
(function () {
    'use strict';

    const D = JSON.parse(document.getElementById('plan-donnees').textContent);
    const racine = document.getElementById('plan-salle');
    const L = 1000, H = 600, PAS = 10;
    const echap = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const borne = (v, min, max) => Math.max(min, Math.min(max, v));
    const arrondi = v => Math.round(v / PAS) * PAS;

    let salles = D.salles.map(s => ({ id: s.id, nom: s.nom, tables: s.tables.map(t => Object.assign({}, t)) }));
    let active = 0;
    let choisie = null;    // table sélectionnée
    let modifie = false;
    let provisoire = -1;   // identifiants négatifs : éléments pas encore enregistrés

    const salle = () => salles[active];

    function marquer() {
        modifie = true;
        const b = racine.querySelector('[data-action="enregistrer"]');
        if (b) b.classList.add('btn-pulse');
    }

    function nomLibre() {
        const noms = new Set(salles.flatMap(s => s.tables.map(t => t.nom.toLowerCase())));
        for (let n = 1; ; n++) if (!noms.has(('Table ' + n).toLowerCase())) return 'Table ' + n;
    }

    function ajouterSalle() {
        const nom = prompt('Nom de la salle (ex : Salle principale, Terrasse) :', salles.length ? 'Salle ' + (salles.length + 1) : 'Salle principale');
        if (!nom || !nom.trim()) return;
        salles.push({ id: provisoire--, nom: nom.trim().slice(0, 50), tables: [] });
        active = salles.length - 1;
        choisie = null;
        marquer();
        afficher();
    }

    function renommerSalle() {
        if (!salle()) return;
        const nom = prompt('Nouveau nom de la salle :', salle().nom);
        if (!nom || !nom.trim()) return;
        salle().nom = nom.trim().slice(0, 50);
        marquer();
        afficher();
    }

    function supprimerSalle() {
        if (!salle()) return;
        if (!confirm('Supprimer la salle « ' + salle().nom + ' » et ses ' + salle().tables.length + ' table(s) ?')) return;
        salles.splice(active, 1);
        active = Math.max(0, active - 1);
        choisie = null;
        marquer();
        afficher();
    }

    function ajouterTable(forme) {
        if (!salle()) { ajouterSalle(); if (!salle()) return; }
        // Première place libre en partant du coin haut gauche.
        const occupe = (x, y) => salle().tables.some(t => x < t.x + t.l + 10 && x + 100 > t.x - 10 && y < t.y + t.h + 10 && y + 100 > t.y - 10);
        let x = 20, y = 20;
        outer: for (y = 20; y <= H - 120; y += 120) for (x = 20; x <= L - 120; x += 120) if (!occupe(x, y)) break outer;
        const t = { id: provisoire--, nom: nomLibre(), places: forme === 'ronde' ? 2 : 4, forme: forme, x: borne(x, 0, L - 100), y: borne(y, 0, H - 100), l: 100, h: 100 };
        salle().tables.push(t);
        choisie = t;
        marquer();
        afficher();
    }

    function supprimerTable() {
        if (!choisie) return;
        salle().tables = salle().tables.filter(t => t !== choisie);
        choisie = null;
        marquer();
        afficher();
    }

    async function enregistrer() {
        const corps = new FormData();
        corps.append(D.jeton.nom, D.jeton.valeur);
        corps.append('plan', JSON.stringify({
            caisseId: D.caisseId,
            salles: salles.map((s, i) => ({ id: s.id, nom: s.nom, ordre: i, tables: s.tables.map(t => ({ id: t.id, nom: t.nom, places: t.places, forme: t.forme, x: t.x, y: t.y, l: t.l, h: t.h })) }))
        }));
        const bouton = racine.querySelector('[data-action="enregistrer"]');
        bouton.disabled = true;
        try {
            const res = await fetch(D.urlEnregistrer, { method: 'POST', body: corps, credentials: 'same-origin' });
            const r = await res.json().catch(() => null);
            if (!res.ok || !r || r.erreur) throw new Error(r && r.erreur ? r.erreur : 'Réponse inattendue du serveur (' + res.status + ').');
            const nomActive = salle() ? salle().nom : null;
            salles = r.salles.map(s => ({ id: s.id, nom: s.nom, tables: s.tables.map(t => Object.assign({}, t)) }));
            active = Math.max(0, salles.findIndex(s => s.nom === nomActive));
            choisie = null;
            modifie = false;
            afficher();
            message('Plan enregistré.');
        } catch (err) {
            bouton.disabled = false;
            message(err.message || 'Enregistrement impossible.', true);
        }
    }

    function message(texte, erreur) {
        const el = racine.querySelector('.plan-message');
        el.className = 'plan-message alert ' + (erreur ? 'alert-danger' : 'alert-success');
        el.textContent = texte;
        clearTimeout(message.t);
        message.t = setTimeout(() => { el.className = 'plan-message d-none'; }, erreur ? 8000 : 3000);
    }

    // ------------------------------------------------------------------
    // Affichage
    // ------------------------------------------------------------------
    function htmlTable(t) {
        return '<div class="plan-table ' + (t.forme === 'ronde' ? 'ronde' : '') + (t === choisie ? ' sel' : '') + '" data-table="' + t.id + '"'
            + ' style="left:' + (t.x / L * 100) + '%;top:' + (t.y / H * 100) + '%;width:' + (t.l / L * 100) + '%;height:' + (t.h / H * 100) + '%">'
            + '<span class="nom">' + echap(t.nom) + '</span><span class="places"><i class="fas fa-user"></i> ' + t.places + '</span>'
            + (t === choisie ? '<span class="poignee" data-poignee title="Agrandir"></span>' : '') + '</div>';
    }

    function htmlProprietes() {
        if (!choisie) {
            return '<div class="text-muted small">Cliquez sur une table pour modifier son nom, ses places et sa forme. '
                + 'Faites-la glisser pour la déplacer ; la poignée en bas à droite l\'agrandit.</div>';
        }
        const t = choisie;
        return '<div class="row g-2 align-items-end">'
            + '<div class="col-sm-4"><label class="form-label small mb-1" for="tNom">Nom</label><input class="form-control form-control-sm" id="tNom" data-prop="nom" maxlength="30" value="' + echap(t.nom) + '"></div>'
            + '<div class="col-sm-2"><label class="form-label small mb-1" for="tPlaces">Places</label><input class="form-control form-control-sm" id="tPlaces" type="number" min="1" max="50" data-prop="places" value="' + t.places + '"></div>'
            + '<div class="col-sm-3"><label class="form-label small mb-1" for="tForme">Forme</label><select class="form-select form-select-sm" id="tForme" data-prop="forme">'
            + '<option value="carree"' + (t.forme !== 'ronde' ? ' selected' : '') + '>Carrée / rectangle</option><option value="ronde"' + (t.forme === 'ronde' ? ' selected' : '') + '>Ronde</option></select></div>'
            + '<div class="col-sm-3 text-sm-end"><button type="button" class="btn btn-outline-danger btn-sm" data-action="suppr-table"><i class="fas fa-trash-can"></i> Supprimer la table</button></div>'
            + '</div>';
    }

    function afficher() {
        const s = salle();
        racine.innerHTML = '<div class="plan-message d-none"></div>'
            + '<div class="d-flex flex-wrap gap-2 align-items-center mb-3">'
            + '<ul class="nav nav-tabs flex-grow-1">'
            + salles.map((x, i) => '<li class="nav-item"><button type="button" class="nav-link' + (i === active ? ' active' : '') + '" data-salle="' + i + '">'
                + echap(x.nom) + ' <span class="badge bg-light text-dark">' + x.tables.length + '</span></button></li>').join('')
            + '<li class="nav-item"><button type="button" class="nav-link text-primary" data-action="ajout-salle"><i class="fas fa-plus"></i> Salle</button></li>'
            + '</ul></div>'
            + (s
                ? '<div class="d-flex flex-wrap gap-2 mb-2">'
                    + '<button type="button" class="btn btn-outline-primary btn-sm" data-action="table-carree"><i class="fas fa-square"></i> Table carrée</button>'
                    + '<button type="button" class="btn btn-outline-primary btn-sm" data-action="table-ronde"><i class="fas fa-circle"></i> Table ronde</button>'
                    + '<span class="flex-grow-1"></span>'
                    + '<button type="button" class="btn btn-outline-secondary btn-sm" data-action="renommer-salle"><i class="fas fa-pen"></i> Renommer la salle</button>'
                    + '<button type="button" class="btn btn-outline-danger btn-sm" data-action="suppr-salle"><i class="fas fa-trash-can"></i> Supprimer la salle</button>'
                    + '</div>'
                    + '<div class="plan-zone" data-zone>' + s.tables.map(htmlTable).join('')
                    + (s.tables.length ? '' : '<div class="plan-vide">Ajoutez des tables avec les boutons ci-dessus.</div>') + '</div>'
                    + '<div class="card border-0 bg-light mt-3"><div class="card-body py-2" data-proprietes>' + htmlProprietes() + '</div></div>'
                : '<div class="plan-zone plan-zone-vide"><div class="plan-vide">Aucune salle. <button type="button" class="btn btn-primary btn-sm ms-2" data-action="ajout-salle"><i class="fas fa-plus"></i> Créer une salle</button></div></div>')
            + '<div class="d-flex flex-wrap gap-2 align-items-center mt-3">'
            + '<button type="button" class="btn btn-success' + (modifie ? ' btn-pulse' : '') + '" data-action="enregistrer"><i class="fas fa-floppy-disk"></i> Enregistrer le plan</button>'
            + '<span class="small text-muted">' + salles.reduce((n, x) => n + x.tables.length, 0) + ' table(s) dans ' + salles.length + ' salle(s).</span>'
            + '</div>';
    }

    function majTable(t) {
        const el = racine.querySelector('[data-table="' + t.id + '"]');
        if (!el) return;
        el.style.left = (t.x / L * 100) + '%';
        el.style.top = (t.y / H * 100) + '%';
        el.style.width = (t.l / L * 100) + '%';
        el.style.height = (t.h / H * 100) + '%';
        el.querySelector('.nom').textContent = t.nom;
        el.querySelector('.places').innerHTML = '<i class="fas fa-user"></i> ' + t.places;
        el.classList.toggle('ronde', t.forme === 'ronde');
    }

    // ------------------------------------------------------------------
    // Glisser-déposer (souris, doigt, stylet)
    // ------------------------------------------------------------------
    let glisse = null;   // { t, mode: 'deplacer' | 'agrandir', x0, y0, t0 }
    racine.addEventListener('pointerdown', e => {
        const el = e.target.closest('[data-table]');
        if (!el) return;
        const t = salle().tables.find(x => String(x.id) === el.dataset.table);
        if (!t) return;
        if (choisie !== t) {
            choisie = t;
            afficher();
        }
        const zone = racine.querySelector('[data-zone]');
        const r = zone.getBoundingClientRect();
        glisse = { t: t, mode: e.target.closest('[data-poignee]') ? 'agrandir' : 'deplacer', x0: e.clientX, y0: e.clientY, t0: Object.assign({}, t), echelle: L / r.width, deplace: false };
        e.preventDefault();
    });
    document.addEventListener('pointermove', e => {
        if (!glisse) return;
        const dx = (e.clientX - glisse.x0) * glisse.echelle, dy = (e.clientY - glisse.y0) * glisse.echelle;
        if (Math.abs(dx) + Math.abs(dy) > 3) glisse.deplace = true;
        const t = glisse.t, t0 = glisse.t0;
        if (glisse.mode === 'deplacer') {
            t.x = borne(arrondi(t0.x + dx), 0, L - t.l);
            t.y = borne(arrondi(t0.y + dy), 0, H - t.h);
        } else {
            t.l = borne(arrondi(t0.l + dx), 40, Math.min(400, L - t.x));
            t.h = borne(arrondi(t0.h + dy), 40, Math.min(400, H - t.y));
        }
        majTable(t);
    });
    document.addEventListener('pointerup', () => {
        if (glisse && glisse.deplace) marquer();
        glisse = null;
    });

    racine.addEventListener('click', e => {
        const b = e.target.closest('[data-action], [data-salle]');
        if (!b) {
            if (e.target.closest('[data-zone]') && !e.target.closest('[data-table]') && choisie) { choisie = null; afficher(); }
            return;
        }
        if (b.dataset.salle !== undefined) { active = Number(b.dataset.salle); choisie = null; afficher(); return; }
        const a = b.dataset.action;
        if (a === 'ajout-salle') ajouterSalle();
        else if (a === 'renommer-salle') renommerSalle();
        else if (a === 'suppr-salle') supprimerSalle();
        else if (a === 'table-carree') ajouterTable('carree');
        else if (a === 'table-ronde') ajouterTable('ronde');
        else if (a === 'suppr-table') supprimerTable();
        else if (a === 'enregistrer') enregistrer();
    });

    racine.addEventListener('input', e => {
        const p = e.target.dataset.prop;
        if (!p || !choisie) return;
        if (p === 'places') choisie.places = borne(parseInt(e.target.value, 10) || 1, 1, 50);
        else if (p === 'nom') choisie.nom = e.target.value.slice(0, 30);
        else if (p === 'forme') choisie.forme = e.target.value === 'ronde' ? 'ronde' : 'carree';
        majTable(choisie);
        marquer();
    });

    window.addEventListener('beforeunload', e => { if (modifie) { e.preventDefault(); e.returnValue = ''; } });

    afficher();
})();
