// Listes paginées, triables et filtrables (DataTables), réglées comme dans la version .NET.
// Usage dans une vue : listeDataTable('#ventesTable', { pageLength: 20, lengthMenu: [20, 50, 100], order: [[1, 'desc']] });
window.listeDataTable = function (selecteur, options) {
    if (!window.jQuery || !jQuery.fn.DataTable || !document.querySelector(selecteur)) return null;
    return jQuery(selecteur).DataTable(Object.assign({
        language: { url: 'assets/vendor/datatables/fr-FR.json' },
        // Barre « Afficher N entrées » / « Rechercher » sur une ligne, comme dans la version .NET.
        dom: '<"d-flex justify-content-between align-items-center mb-3"lf>rtip'
    }, options));
};
