// Formulaires de création en fenêtre modale.
// Un lien <a href="/Caisse/Create" data-modale> charge la page de création et
// affiche son formulaire dans une modale. Le formulaire est envoyé normalement :
// en cas d'erreur de saisie, le serveur affiche la page de création complète.
// Les éléments marqués « hors-modale » (ex. lien Annuler) sont masqués dans la modale.
(function () {
    let modale = null;

    function creerModale() {
        const div = document.createElement('div');
        div.className = 'modal fade';
        div.id = 'modalCreation';
        div.tabIndex = -1;
        div.setAttribute('aria-labelledby', 'modalCreationTitre');
        div.setAttribute('aria-hidden', 'true');
        div.innerHTML =
            '<div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">' +
            '  <div class="modal-content">' +
            '    <div class="modal-header bg-brand text-white">' +
            '      <h5 class="modal-title" id="modalCreationTitre"></h5>' +
            '      <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Fermer"></button>' +
            '    </div>' +
            '    <div class="modal-body"></div>' +
            '  </div>' +
            '</div>';
        document.body.appendChild(div);
        div.addEventListener('shown.bs.modal', function () {
            const champ = div.querySelector('.modal-body input:not([type=hidden]):not([type=checkbox]), .modal-body select, .modal-body textarea');
            if (champ) champ.focus();
        });
        return div;
    }

    async function ouvrir(lien) {
        const adresse = lien.getAttribute('href');
        const reponse = await fetch(adresse, { credentials: 'same-origin' });
        // Session expirée, droits insuffisants… : on laisse la navigation normale.
        if (!reponse.ok || reponse.redirected) throw new Error('page indisponible');

        const page = new DOMParser().parseFromString(await reponse.text(), 'text/html');
        const contenu = page.querySelector('.page-content') || page.body;
        const form = contenu.querySelector('form[method="post"], form[method="POST"]');
        if (!form) throw new Error('formulaire introuvable');

        // Sans attribut action, le formulaire doit être envoyé à la page de création.
        if (!form.getAttribute('action')) form.setAttribute('action', adresse);

        // Bouton Annuler qui ferme la modale, placé avant le bouton d'envoi.
        const envoi = form.querySelector('button[type=submit], button:not([type])');
        if (envoi) {
            const annuler = document.createElement('button');
            annuler.type = 'button';
            annuler.className = 'btn btn-outline-secondary me-2';
            annuler.setAttribute('data-bs-dismiss', 'modal');
            annuler.textContent = 'Annuler';
            envoi.parentNode.insertBefore(annuler, envoi);
        }

        const entete = contenu.querySelector('.card-header');
        modale = modale || creerModale();
        modale.querySelector('.modal-title').textContent =
            (entete ? entete.textContent : lien.textContent).replace(/\s+/g, ' ').trim();
        const corps = modale.querySelector('.modal-body');
        corps.replaceChildren(document.importNode(form, true));
        bootstrap.Modal.getOrCreateInstance(modale).show();
    }

    document.addEventListener('click', function (e) {
        const lien = e.target.closest('a[data-modale]');
        if (!lien || e.ctrlKey || e.metaKey || e.shiftKey || e.button !== 0) return;
        e.preventDefault();
        ouvrir(lien).catch(function () { window.location.href = lien.href; });
    });
})();
