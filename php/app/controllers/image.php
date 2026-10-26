<?php
// Images enregistrées dans la base : photos des produits et logos des sociétés.
// L'adresse porte la date de mise à jour (?v=…) : le navigateur peut les garder en cache.

function image_envoyer(?array $image): never
{
    if (!$image) {
        http_response_code(404);
        exit;
    }
    header('Content-Type: ' . $image['TypeContenu']);
    header('Cache-Control: private, max-age=31536000');
    header('X-Content-Type-Options: nosniff');
    echo $image['Donnees'];
    exit;
}

function image_produit(): void
{
    image_envoyer(q1(
        'SELECT i.TypeContenu, i.Donnees FROM ProduitImages i JOIN Produits p ON p.Id = i.ProduitId WHERE i.ProduitId = ? AND ' . tf('p'),
        [(int) get('id')]
    ));
}

function image_societe(): void
{
    $id = (int) get('id');
    // Son propre logo ; le SuperAdmin voit ceux de toutes les sociétés.
    if (!is_super_admin() && $id !== tenant_id()) {
        image_envoyer(null);
    }
    image_envoyer(q1('SELECT TypeContenu, Donnees FROM TenantLogos WHERE TenantId = ?', [$id]));
}
