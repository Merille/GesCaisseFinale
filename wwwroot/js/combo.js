// Combos comme dans le point de vente Odoo (commun aux versions .NET et PHP).
// - Page ou fenêtre modale d'un combo (#combo-editeur) : produits proposés et suppléments, envoyés en JSON dans
//   le champ caché #combo-json. Données : <script id="combo-donnees"> { produits, choix }.
// - Fiche d'un produit (#produit-combos) : liste ordonnée des combos qui le composent, envoyée
//   dans #produit-combos-json. Données : <script id="produit-combos-donnees"> { combos, choisis }.
(function () {
    'use strict';

    const echap = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const nf = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 2 });

    // ------------------------------------------------------------------
    // Produits proposés dans un combo
    // ------------------------------------------------------------------
    const editeur = document.getElementById('combo-editeur');
    if (editeur) {
        const D = JSON.parse(document.getElementById('combo-donnees').textContent);
        const champ = document.getElementById('combo-json');
        let choix = (D.choix || []).map(c => ({ produitId: c.produitId, supplement: c.supplement }));
        if (!choix.length) choix.push({ produitId: null, supplement: 0 });
        const options = choisi => '<option value="">-- Produit --</option>' + D.produits.map(p =>
            '<option value="' + p.id + '"' + (p.id === choisi ? ' selected' : '') + '>' + echap(p.nom) + ' (' + nf.format(p.prix) + ')</option>').join('');
        const serialiser = () => { champ.value = JSON.stringify(choix.filter(c => c.produitId)); };
        const afficher = () => {
            editeur.innerHTML = '<table class="table align-middle mb-2"><thead class="table-dark"><tr><th>Produit proposé</th>'
                + '<th class="text-end" style="width:160px">Supplément (FCFA)</th><th style="width:1%"></th></tr></thead><tbody>'
                + choix.map((c, k) => '<tr data-c="' + k + '">'
                    + '<td><select class="form-select" data-champ="produit" aria-label="Produit proposé">' + options(c.produitId) + '</select></td>'
                    + '<td><input class="form-control text-end" inputmode="decimal" data-champ="supplement" value="' + (c.supplement ? String(c.supplement).replace('.', ',') : '') + '" placeholder="0" aria-label="Supplément"></td>'
                    + '<td><button type="button" class="btn btn-outline-danger btn-sm" data-action="suppr" aria-label="Retirer ce produit"><i class="fas fa-xmark"></i></button></td></tr>').join('')
                + '</tbody></table>'
                + '<button type="button" class="btn btn-outline-primary btn-sm" data-action="ajout"><i class="fas fa-plus"></i> Ajouter un produit</button>';
            serialiser();
        };
        editeur.addEventListener('click', e => {
            const b = e.target.closest('[data-action]');
            if (!b) return;
            if (b.dataset.action === 'ajout') choix.push({ produitId: null, supplement: 0 });
            else choix.splice(Number(b.closest('[data-c]').dataset.c), 1);
            afficher();
        });
        const saisir = e => {
            const el = e.target, tr = el.closest('[data-c]');
            if (!tr || !el.dataset.champ) return;
            const c = choix[Number(tr.dataset.c)];
            if (el.dataset.champ === 'produit') c.produitId = el.value ? Number(el.value) : null;
            else c.supplement = parseFloat(el.value.replace(/\s/g, '').replace(',', '.')) || 0;
            serialiser();
        };
        editeur.addEventListener('input', saisir);
        editeur.addEventListener('change', saisir);
        afficher();

        // Fenêtre modale (liste des combos) : la même fenêtre sert à la création et à la
        // modification. Le bouton « Modifier » porte le combo dans data-combo
        // { id, action, nom, quantite, choix } ; « Nouveau combo » n'en porte pas.
        const modale = editeur.closest('.modal');
        if (modale) {
            const form = modale.querySelector('form');
            const titre = modale.querySelector('.modal-title');
            const actionCreation = form.getAttribute('action');
            const titreCreation = titre.textContent;
            modale.addEventListener('show.bs.modal', e => {
                const b = e.relatedTarget;
                const d = b && b.dataset.combo ? JSON.parse(b.dataset.combo) : null;
                form.setAttribute('action', d ? d.action : actionCreation);
                titre.textContent = d ? 'Modifier le combo' : titreCreation;
                if (form.elements.id) form.elements.id.value = d ? d.id : 0;
                form.elements.Nom.value = d ? d.nom : '';
                form.elements.Quantite.value = d ? d.quantite : 1;
                choix = d ? d.choix.map(c => ({ produitId: c.produitId, supplement: c.supplement })) : [];
                if (!choix.length) choix.push({ produitId: null, supplement: 0 });
                afficher();
            });
            modale.addEventListener('shown.bs.modal', () => form.elements.Nom.focus());
        }
    }

    // ------------------------------------------------------------------
    // Combos qui composent un produit
    // ------------------------------------------------------------------
    const liste = document.getElementById('produit-combos');
    if (liste) {
        const D = JSON.parse(document.getElementById('produit-combos-donnees').textContent);
        const champ = document.getElementById('produit-combos-json');
        const combos = new Map(D.combos.map(c => [c.id, c]));
        let choisis = (D.choisis || []).filter(id => combos.has(id));
        const afficher = () => {
            const libres = D.combos.filter(c => !choisis.includes(c.id));
            liste.innerHTML = (choisis.length
                ? '<ol class="list-group list-group-numbered mb-2">' + choisis.map((id, i) => {
                    const c = combos.get(id);
                    return '<li class="list-group-item d-flex align-items-center gap-2">'
                        + '<div class="flex-grow-1"><strong>' + echap(c.nom) + '</strong> <span class="badge text-bg-light border">' + c.quantite + ' à choisir</span>'
                        + '<div class="small text-muted">' + echap(c.resume) + '</div></div>'
                        + '<button type="button" class="btn btn-outline-secondary btn-sm" data-monter="' + i + '"' + (i ? '' : ' disabled') + ' aria-label="Monter"><i class="fas fa-arrow-up"></i></button>'
                        + '<button type="button" class="btn btn-outline-danger btn-sm" data-retirer="' + i + '" aria-label="Retirer"><i class="fas fa-xmark"></i></button></li>';
                }).join('') + '</ol>'
                : '<div class="text-muted small mb-2">Aucun combo : ce produit n\'est pas un menu.</div>')
                + (libres.length
                    ? '<div class="input-group input-group-sm"><select class="form-select" data-ajout aria-label="Combo à ajouter"><option value="">-- Ajouter un combo --</option>'
                        + libres.map(c => '<option value="' + c.id + '">' + echap(c.nom) + '</option>').join('') + '</select></div>'
                    : (D.combos.length ? '' : '<div class="small text-muted">Créez d\'abord des combos dans Configuration › Combos.</div>'));
            champ.value = JSON.stringify(choisis);
        };
        liste.addEventListener('click', e => {
            const b = e.target.closest('button');
            if (!b) return;
            if (b.dataset.retirer !== undefined) choisis.splice(Number(b.dataset.retirer), 1);
            else if (b.dataset.monter !== undefined) {
                const i = Number(b.dataset.monter);
                [choisis[i - 1], choisis[i]] = [choisis[i], choisis[i - 1]];
            }
            afficher();
        });
        liste.addEventListener('change', e => {
            if (e.target.matches('[data-ajout]') && e.target.value) { choisis.push(Number(e.target.value)); afficher(); }
        });
        afficher();
    }
})();
