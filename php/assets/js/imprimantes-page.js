// Page Paramètres › Imprimantes de préparation (versions .NET et PHP) : fenêtre de saisie et bouton « Tester ».
(function () {
    'use strict';
    const modale = document.getElementById('modalImprimante');
    if (!modale) return;
    const $ = id => document.getElementById(id);

    function avis(texte, ok) {
        let el = document.getElementById('impAvis');
        if (!el) {
            el = document.createElement('div');
            el.id = 'impAvis';
            el.setAttribute('role', 'status');
            el.style.cssText = 'position:fixed;top:16px;left:50%;transform:translateX(-50%);z-index:2000;max-width:min(640px,92vw)';
            document.body.appendChild(el);
        }
        el.className = 'alert shadow ' + (ok ? 'alert-success' : 'alert-danger');
        el.textContent = texte;
        clearTimeout(avis.minuterie);
        avis.minuterie = setTimeout(() => el.remove(), ok ? 4000 : 9000);
    }

    async function tester(imp, bouton) {
        if (!imp.ip) { avis('Indiquez l\'adresse IP de l\'imprimante.', false); return; }
        const texte = bouton.innerHTML;
        bouton.disabled = true;
        bouton.innerHTML = '<i class="fa fa-spinner fa-spin"></i> Test…';
        const r = await window.GCImprimantes.tester(imp);
        bouton.disabled = false;
        bouton.innerHTML = texte;
        avis(r.ok ? 'Page d\'essai envoyée à « ' + imp.nom + ' ».' : 'Échec de l\'impression sur « ' + imp.nom + ' » : ' + r.erreur, r.ok);
    }

    // Imprimante décrite par la fenêtre (test avant d'enregistrer).
    function saisie() {
        const port = parseInt($('impPort').value, 10);
        return {
            nom: $('impNom').value.trim() || 'Imprimante', type: $('impTypeReseau').checked ? 'Reseau' : 'Epson',
            ip: $('impIp').value.trim(), port: port > 0 ? port : null, largeur: Number($('impLargeur').value),
            encodage: $('impEncodage').value, bip: $('impBip').checked, categories: []
        };
    }

    modale.addEventListener('show.bs.modal', e => {
        const brut = e.relatedTarget ? e.relatedTarget.getAttribute('data-imprimante') : '';
        const d = brut ? JSON.parse(brut) : null;
        $('imprimanteTitre').textContent = d ? 'Modifier l\'imprimante' : 'Nouvelle imprimante';
        $('impId').value = d ? d.id : '';
        $('impNom').value = d ? d.nom : '';
        $('impCaisse').value = d && d.caisseId ? String(d.caisseId) : '';
        $(d && d.type === 'Reseau' ? 'impTypeReseau' : 'impTypeEpson').checked = true;
        $('impIp').value = d ? d.ip : '';
        $('impPort').value = d && d.port ? d.port : '';
        $('impLargeur').value = d ? String(d.largeur) : '80';
        $('impEncodage').value = d ? d.encodage : 'PC850';
        $('impBip').checked = d ? !!d.bip : false;
        $('impActif').checked = d ? !!d.actif : true;
        const cats = new Set(d ? d.categories.map(Number) : []);
        modale.querySelectorAll('#impCategories input').forEach(c => { c.checked = cats.has(Number(c.value)); });
        indiquerPort();
    });
    modale.addEventListener('shown.bs.modal', () => $('impNom').focus());

    // Port par défaut selon le type.
    function indiquerPort() { $('impPort').placeholder = $('impTypeReseau').checked ? '9100' : 'Par défaut'; }
    modale.querySelectorAll('input[name="Type"]').forEach(r => r.addEventListener('change', indiquerPort));

    modale.addEventListener('click', e => {
        const b = e.target.closest('[data-cocher]');
        if (b) modale.querySelectorAll('#impCategories input').forEach(c => { c.checked = !!b.dataset.cocher && c.dataset.poste === b.dataset.cocher; });
    });
    $('impTester').addEventListener('click', e => tester(saisie(), e.currentTarget));
    document.addEventListener('click', e => {
        const b = e.target.closest('[data-tester]');
        if (b) tester(JSON.parse(b.getAttribute('data-tester')), b);
    });
})();
