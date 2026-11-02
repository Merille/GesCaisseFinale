// Listes paginées, triables et filtrables (DataTables), réglées comme dans la version .NET.
// Usage dans une vue : listeDataTable('#ventesTable', { pageLength: 20, lengthMenu: [20, 50, 100], order: [[1, 'desc']] });
window.listeDataTable = function (selecteur, options) {
    if (!window.jQuery || !jQuery.fn.DataTable || !document.querySelector(selecteur)) return null;
    return jQuery(selecteur).DataTable(Object.assign({
        language: { url: '//cdn.datatables.net/plug-ins/1.13.6/i18n/fr-FR.json' }
    }, options));
};
