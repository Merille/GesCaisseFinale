// Bascule « Liste / Cartes » des pages de liste, mémorisée dans le navigateur.
// Boutons : <div data-vues="produits"><button data-vue="liste">…</button><button data-vue="cartes">…</button></div>
// Contenus : <div data-vue-de="produits" data-vue="liste">…</div> et <div data-vue-de="produits" data-vue="cartes">…</div>
(function () {
    document.querySelectorAll('[data-vues]').forEach(function (groupe) {
        const nom = groupe.dataset.vues;
        const cle = 'gescaisse-vue-' + nom;
        function appliquer(vue) {
            groupe.querySelectorAll('[data-vue]').forEach(function (b) {
                const actif = b.dataset.vue === vue;
                b.classList.toggle('active', actif);
                b.setAttribute('aria-pressed', actif ? 'true' : 'false');
            });
            document.querySelectorAll('[data-vue-de="' + nom + '"]').forEach(function (c) {
                c.classList.toggle('d-none', c.dataset.vue !== vue);
            });
        }
        let vue = 'liste';
        try { vue = localStorage.getItem(cle) || 'liste'; } catch (e) { }
        appliquer(vue);
        groupe.addEventListener('click', function (e) {
            const b = e.target.closest('[data-vue]');
            if (!b) return;
            appliquer(b.dataset.vue);
            try { localStorage.setItem(cle, b.dataset.vue); } catch (err) { }
        });
    });
})();

// Fiche caisse : le dépôt de la caisse (principal) ne peut pas être aussi un dépôt secondaire ;
// les options restaurant ne s'affichent que pour une caisse Restaurant ou Bar.
(function () {
    function majSecondaires(form) {
        const liste = form && form.querySelector('.depots-secondaires');
        const principal = form && form.querySelector('[name="DepotId"]');
        if (!liste || !principal) return;
        liste.querySelectorAll('[data-depot]').forEach(function (ligne) {
            // Sans dépôt choisi, la caisse utilise le dépôt par défaut de la société (data-depot de l'option vide).
            const choisi = principal.value || (principal.selectedOptions[0] && principal.selectedOptions[0].dataset.depot) || '';
            const estPrincipal = ligne.dataset.depot === String(choisi);
            ligne.querySelectorAll('input').forEach(function (c) { c.disabled = estPrincipal; });
            if (estPrincipal) ligne.querySelector('[type="checkbox"]').checked = false;
            ligne.classList.toggle('text-muted', estPrincipal);
        });
    }
    // Options propres au restaurant (bons de préparation) : visibles seulement pour un type Restaurant ou Bar.
    function majType(form) {
        const type = form && form.querySelector('[name="TypePointVente"]');
        if (!type || type.type === 'hidden') return;
        form.querySelectorAll('.caisse-restaurant').forEach(function (b) {
            b.classList.toggle('d-none', type.value !== 'Restaurant' && type.value !== 'Bar');
        });
    }
    document.querySelectorAll('.depots-secondaires').forEach(function (l) { majSecondaires(l.closest('form')); });
    document.querySelectorAll('.caisse-restaurant').forEach(function (b) { majType(b.closest('form')); });
    document.addEventListener('change', function (e) {
        if (e.target.name === 'DepotId') majSecondaires(e.target.closest('form'));
        if (e.target.name === 'TypePointVente') majType(e.target.closest('form'));
    });
    document.addEventListener('show.bs.modal', function (e) {
        e.target.querySelectorAll('.depots-secondaires').forEach(function (l) { majSecondaires(l.closest('form')); });
        e.target.querySelectorAll('.caisse-restaurant').forEach(function (b) { majType(b.closest('form')); });
    });
})();
