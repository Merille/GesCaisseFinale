// Pagination dans la page d'un tableau de saisie (ex. inventaire) : les lignes des autres pages
// sont seulement masquées, leurs champs restent dans le formulaire et sont tous enregistrés.
// Usage : <table data-pagination="20" data-libelle="Produits">. Recherche sur le texte des lignes.
(function () {
    document.querySelectorAll('table[data-pagination]').forEach(function (table) {
        const parPage = parseInt(table.dataset.pagination, 10) || 20;
        const libelle = table.dataset.libelle || 'Lignes';
        const lignes = Array.from(table.tBodies[0].rows);
        let page = 1;
        let visibles = lignes;

        const recherche = document.createElement('input');
        recherche.type = 'search';
        recherche.className = 'form-control form-control-sm mb-3';
        recherche.style.maxWidth = '320px';
        recherche.placeholder = 'Rechercher (code, produit, catégorie)…';
        recherche.setAttribute('aria-label', 'Rechercher dans la liste');
        // Entrée dans la recherche : ne pas envoyer le formulaire.
        recherche.addEventListener('keydown', function (e) { if (e.key === 'Enter') e.preventDefault(); });
        table.parentNode.insertBefore(recherche, table);

        const pied = document.createElement('div');
        pied.className = 'd-flex flex-wrap justify-content-between align-items-center gap-2 mt-3';
        table.parentNode.insertBefore(pied, table.nextSibling);

        function texte(tr) {
            return Array.from(tr.cells).map(function (c) { return c.textContent; }).join(' ').toLowerCase();
        }
        const textes = lignes.map(texte);

        function lien(n, contenu, actif, desactive, aria) {
            const li = document.createElement('li');
            li.className = 'page-item' + (actif ? ' active' : '') + (desactive ? ' disabled' : '');
            const a = document.createElement(desactive && n === null ? 'span' : 'a');
            a.className = 'page-link';
            a.innerHTML = contenu;
            if (aria) a.setAttribute('aria-label', aria);
            if (actif) li.setAttribute('aria-current', 'page');
            if (a.tagName === 'A') {
                a.href = '#';
                a.addEventListener('click', function (e) { e.preventDefault(); if (!desactive) { page = n; afficher(); } });
            }
            li.appendChild(a);
            return li;
        }

        // Compteur seul : mis à jour à chaque saisie sans reconstruire la pagination
        // (sinon le clic sur une page, qui suit la saisie, serait perdu).
        let info = null;
        function majInfo() {
            const debut = (page - 1) * parPage;
            const comptes = table.querySelectorAll('input.compte');
            const saisis = Array.from(comptes).filter(function (c) { return c.value.trim() !== ''; }).length;
            info.textContent = visibles.length === 0
                ? 'Aucun résultat.'
                : libelle + ' ' + (debut + 1) + ' à ' + Math.min(debut + parPage, visibles.length) + ' sur ' + visibles.length
                    + (comptes.length ? ' · ' + saisis + ' saisi(s)' : '');
        }

        function afficher() {
            const pages = Math.max(1, Math.ceil(visibles.length / parPage));
            page = Math.min(Math.max(1, page), pages);
            const debut = (page - 1) * parPage;
            lignes.forEach(function (tr) { tr.style.display = 'none'; });
            visibles.slice(debut, debut + parPage).forEach(function (tr) { tr.style.display = ''; });

            pied.innerHTML = '';
            info = document.createElement('div');
            info.className = 'small text-muted';
            pied.appendChild(info);
            majInfo();
            if (pages > 1) {
                const nav = document.createElement('nav');
                nav.setAttribute('aria-label', 'Pagination');
                const ul = document.createElement('ul');
                ul.className = 'pagination pagination-sm mb-0';
                ul.appendChild(lien(page - 1, '&laquo;', false, page === 1, 'Page précédente'));
                // Première, dernière et deux pages autour de la page courante.
                let precedent = 0;
                for (let n = 1; n <= pages; n++) {
                    if (n !== 1 && n !== pages && Math.abs(n - page) > 2) continue;
                    if (n - precedent > 1) ul.appendChild(lien(null, '…', false, true));
                    ul.appendChild(lien(n, String(n), n === page, false));
                    precedent = n;
                }
                ul.appendChild(lien(page + 1, '&raquo;', false, page === pages, 'Page suivante'));
                nav.appendChild(ul);
                pied.appendChild(nav);
            }
        }

        recherche.addEventListener('input', function () {
            const q = recherche.value.trim().toLowerCase();
            visibles = q === '' ? lignes : lignes.filter(function (tr, i) { return textes[i].indexOf(q) !== -1; });
            page = 1;
            afficher();
        });
        table.addEventListener('input', function (e) { if (e.target.matches('input.compte')) majInfo(); });
        afficher();
    });
})();
