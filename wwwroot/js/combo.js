// Éditeur de combo de la fiche produit (commun aux versions .NET et PHP).
// Données dans <script id="combo-donnees" type="application/json"> : { produits: [{ id, nom, prix }], groupes: [...] }.
// Chaque groupe (Entrée, Plat, Boisson…) a un nombre d'articles à choisir et une liste de produits
// proposés, avec un supplément éventuel. Le tout est envoyé en JSON dans le champ caché « combo ».
(function () {
    'use strict';

    const zone = document.getElementById('combo-editeur');
    if (!zone) return;
    const D = JSON.parse(document.getElementById('combo-donnees').textContent);
    const champ = document.getElementById('combo-json');
    const echap = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const nf = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 2 });
    let groupes = (D.groupes || []).map(g => ({ nom: g.nom, quantite: g.quantite, choix: g.choix.map(c => ({ produitId: c.produitId, supplement: c.supplement })) }));

    function options(choisi) {
        return '<option value="">-- Produit --</option>' + D.produits.map(p =>
            '<option value="' + p.id + '"' + (p.id === choisi ? ' selected' : '') + '>' + echap(p.nom) + ' (' + nf.format(p.prix) + ')</option>').join('');
    }

    function serialiser() {
        champ.value = JSON.stringify({ groupes: groupes.map(g => ({ nom: g.nom, quantite: g.quantite, choix: g.choix.filter(c => c.produitId) })) });
    }

    function afficher() {
        zone.innerHTML = (groupes.length ? groupes.map((g, i) =>
            '<div class="combo-groupe" data-g="' + i + '">'
            + '<div class="d-flex flex-wrap gap-2 align-items-end mb-2">'
            + '<div class="flex-grow-1"><label class="form-label small mb-1">Groupe</label>'
            + '<input class="form-control form-control-sm" data-champ="nom" maxlength="50" placeholder="Ex : Entrée, Plat, Boisson" value="' + echap(g.nom) + '"></div>'
            + '<div style="width:110px"><label class="form-label small mb-1">À choisir</label>'
            + '<input class="form-control form-control-sm" type="number" min="1" max="10" data-champ="quantite" value="' + g.quantite + '"></div>'
            + '<button type="button" class="btn btn-outline-danger btn-sm" data-action="suppr-groupe" title="Retirer le groupe" aria-label="Retirer le groupe"><i class="fas fa-trash-can"></i></button>'
            + '</div>'
            + '<table class="table table-sm align-middle mb-1"><thead class="table-dark"><tr><th>Produit proposé</th><th class="text-end" style="width:130px">Supplément</th><th style="width:1%"></th></tr></thead><tbody>'
            + g.choix.map((c, k) => '<tr data-c="' + k + '">'
                + '<td><select class="form-select form-select-sm" data-champ="produit" aria-label="Produit proposé">' + options(c.produitId) + '</select></td>'
                + '<td><input class="form-control form-control-sm text-end" inputmode="decimal" data-champ="supplement" value="' + (c.supplement ? String(c.supplement).replace('.', ',') : '') + '" placeholder="0" aria-label="Supplément"></td>'
                + '<td><button type="button" class="btn btn-outline-danger btn-sm" data-action="suppr-choix" aria-label="Retirer ce produit"><i class="fas fa-xmark"></i></button></td></tr>').join('')
            + '</tbody></table>'
            + '<button type="button" class="btn btn-link btn-sm px-0" data-action="ajout-choix"><i class="fas fa-plus"></i> Ajouter un produit</button>'
            + '</div>').join('')
            : '<div class="text-muted small mb-2">Aucun groupe : ce produit n\'est pas un combo.</div>')
            + '<button type="button" class="btn btn-outline-primary btn-sm" data-action="ajout-groupe"><i class="fas fa-plus"></i> Ajouter un groupe</button>';
        serialiser();
    }

    zone.addEventListener('click', e => {
        const b = e.target.closest('[data-action]');
        if (!b) return;
        const gEl = b.closest('[data-g]');
        const g = gEl ? groupes[Number(gEl.dataset.g)] : null;
        const a = b.dataset.action;
        if (a === 'ajout-groupe') groupes.push({ nom: '', quantite: 1, choix: [{ produitId: null, supplement: 0 }] });
        else if (a === 'suppr-groupe') groupes.splice(Number(gEl.dataset.g), 1);
        else if (a === 'ajout-choix') g.choix.push({ produitId: null, supplement: 0 });
        else if (a === 'suppr-choix') g.choix.splice(Number(b.closest('[data-c]').dataset.c), 1);
        afficher();
        if (a === 'ajout-groupe') zone.querySelector('.combo-groupe:last-of-type [data-champ="nom"]')?.focus();
    });

    // Saisie : l'état est mis à jour sans redessiner (le curseur reste dans le champ).
    function saisir(e) {
        const el = e.target;
        const gEl = el.closest('[data-g]');
        if (!gEl || !el.dataset.champ) return;
        const g = groupes[Number(gEl.dataset.g)];
        if (el.dataset.champ === 'nom') g.nom = el.value;
        else if (el.dataset.champ === 'quantite') g.quantite = Math.max(1, Math.min(10, parseInt(el.value, 10) || 1));
        else {
            const c = g.choix[Number(el.closest('[data-c]').dataset.c)];
            if (el.dataset.champ === 'produit') c.produitId = el.value ? Number(el.value) : null;
            else c.supplement = parseFloat(el.value.replace(/\s/g, '').replace(',', '.')) || 0;
        }
        serialiser();
    }
    zone.addEventListener('input', saisir);
    zone.addEventListener('change', saisir);

    afficher();
})();
