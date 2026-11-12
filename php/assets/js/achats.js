// Saisie d'un achat (et d'une consommation) : lignes ajoutées / retirées, prix d'achat proposé
// au coût actuel du produit, montant de chaque ligne et total, champs du règlement.
(function () {
    const nombre = v => { const n = parseFloat(String(v || '').replace(/[\s  ]/g, '').replace(',', '.')); return isNaN(n) ? 0 : n; };
    const fcfa = n => Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + ' FCFA';
    const table = document.querySelector('#lignesAchat, #lignesConsommation');
    if (!table) return;
    const corps = table.tBodies[0];
    const modele = corps.rows[0].cloneNode(true);
    const montantRegle = document.getElementById('montantRegle');
    let regleSaisi = false;

    function total() {
        let t = 0;
        for (const ligne of corps.rows) {
            const prix = ligne.querySelector('[name^="prix"]');
            if (!prix) continue;
            const m = Math.round(nombre(ligne.querySelector('[name^="qte"]').value) * nombre(prix.value) * 100) / 100;
            ligne.querySelector('.montant').textContent = m > 0 ? fcfa(m) : '—';
            t += m;
        }
        const cellule = document.getElementById('totalAchat');
        if (cellule) cellule.textContent = fcfa(t);
        if (montantRegle && !regleSaisi) montantRegle.value = t > 0 ? Math.round(t * 100) / 100 : '';
    }

    document.getElementById('ajouterLigne').addEventListener('click', () => {
        const ligne = modele.cloneNode(true);
        ligne.querySelectorAll('input').forEach(i => i.value = '');
        ligne.querySelector('select').selectedIndex = 0;
        corps.appendChild(ligne);
        total();
    });
    corps.addEventListener('click', e => {
        const bouton = e.target.closest('.retirer');
        if (!bouton) return;
        if (corps.rows.length > 1) bouton.closest('tr').remove();
        else {
            bouton.closest('tr').querySelectorAll('input').forEach(c => c.value = '');
            bouton.closest('tr').querySelector('select').selectedIndex = 0;
        }
        total();
    });
    corps.addEventListener('change', e => {
        if (e.target.name.startsWith('produit')) {
            const prix = e.target.closest('tr').querySelector('[name^="prix"]');
            const cout = e.target.selectedOptions[0]?.dataset.cout;
            if (prix && !prix.value && cout) prix.value = cout;
        }
        total();
    });
    corps.addEventListener('input', total);
    if (montantRegle) montantRegle.addEventListener('input', () => regleSaisi = true);

    const paiement = document.getElementById('paiement');
    function majPaiement() {
        if (!paiement) return;
        document.querySelectorAll('.regle').forEach(el => el.classList.toggle('d-none', paiement.value === 'credit'));
        document.querySelectorAll('.regle-caisse').forEach(el => el.classList.toggle('d-none', paiement.value !== 'caisse'));
    }
    if (paiement) paiement.addEventListener('change', majPaiement);
    majPaiement();
    total();
})();
