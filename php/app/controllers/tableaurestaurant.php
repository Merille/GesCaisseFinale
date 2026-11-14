<?php
// Tableau de bord du restaurant-bar (société qui a une caisse de type Restaurant ou Bar) : une page à
// part, en tuiles, à côté du tableau de bord général (inchangé). Ventes, tables et couverts, bons en
// cuisine et au bar, livraisons, meilleures ventes, stock, caisse du jour ; chiffre d'affaires des
// 14 derniers jours ; tables occupées et bons en attente. Chiffres des caisses Restaurant et Bar.

require_once __DIR__ . '/../restaurant.php';

function tableaurestaurant_index(): void
{
    if (!restaurant_actif()) {
        redirect('dashboard/index');
    }
    $aujourdhui = date('Y-m-d');
    $lundi = date('Y-m-d', strtotime('monday this week'));
    $fin = date('Y-m-d', strtotime('+1 day'));
    $resto = "c.TypePointVente IN ('Restaurant', 'Bar')";
    $ventes = "FROM CommandesPos v JOIN JourneesCaisses j ON j.Id = v.JourneeCaisseId JOIN Caisses c ON c.ID = j.CaisseId
               WHERE $resto AND v.Statut <> 'Annulée' AND " . tf('v');
    $estVente = "v.Statut <> 'Retour'";

    // Ventes : chiffre d'affaires net (ventes - retours), tickets, panier moyen, couverts, pourboires.
    $jour = q1("SELECT COALESCE(SUM(v.TotalTTC), 0) AS CA, COALESCE(SUM(CASE WHEN $estVente THEN 1 END), 0) AS Tickets,
                       COALESCE(SUM(CASE WHEN $estVente THEN v.TotalTTC END), 0) AS Ventes,
                       COALESCE(SUM(CASE WHEN $estVente THEN v.Couverts END), 0) AS Couverts,
                       COALESCE(SUM(CASE WHEN $estVente AND v.Couverts > 0 THEN v.TotalTTC END), 0) AS VentesCouverts,
                       COALESCE(SUM(v.Pourboire), 0) AS Pourboires
                $ventes AND v.DateCommande >= ? AND v.DateCommande < ?", [$aujourdhui, $fin]);
    $semaine = q1("SELECT COALESCE(SUM(v.TotalTTC), 0) AS CA, COALESCE(SUM(CASE WHEN $estVente THEN v.Couverts END), 0) AS Couverts
                   $ventes AND v.DateCommande >= ? AND v.DateCommande < ?", [$lundi, $fin]);

    // Tables : occupées / actives, couverts en salle, montant des commandes en cours (toutes commandes ouvertes).
    $tables = (int) qv("SELECT COUNT(*) FROM TablesRestaurant t JOIN Salles s ON s.Id = t.SalleId JOIN Caisses c ON c.ID = s.CaisseId
                        WHERE t.Actif = 1 AND $resto AND " . tf('t'));
    $ouvertes = q("SELECT o.*, t.Nom AS TableNom, COALESCE(NULLIF(u.NomComplet, ''), u.NomUtilisateur) AS Serveur
                   FROM CommandesOuvertes o JOIN Caisses c ON c.ID = o.CaisseId
                   LEFT JOIN TablesRestaurant t ON t.Id = o.TableId LEFT JOIN Utilisateurs u ON u.Id = o.UtilisateurId
                   WHERE $resto AND " . tf('o') . ' ORDER BY o.DateOuverture, o.Id');
    $enCours = 0.0;
    $occupees = 0;
    $couvertsSalle = 0;
    foreach ($ouvertes as &$o) {
        $o['Total'] = restaurant_total(restaurant_contenu($o['Contenu']));
        $enCours += $o['Total'];
        if ($o['TableId'] !== null) {
            $occupees++;
            $couvertsSalle += (int) $o['Couverts'];
        }
    }
    unset($o);

    // Cuisine et bar : bons à préparer, par poste, le plus ancien.
    $bons = q("SELECT b.*, (SELECT COUNT(*) FROM LignesBonPreparation l WHERE l.BonPreparationId = b.Id) AS Lignes
               FROM BonsPreparation b JOIN Caisses c ON c.ID = b.CaisseId
               WHERE b.Statut = 'À préparer' AND $resto AND " . tf('b') . ' ORDER BY b.DateEnvoi, b.Id');
    $parPoste = ['Cuisine' => 0, 'Bar' => 0];
    foreach ($bons as $b) {
        $parPoste[$b['Poste']] = ($parPoste[$b['Poste']] ?? 0) + 1;
    }
    $attente = $bons ? max(0, (int) floor((time() - strtotime($bons[0]['DateEnvoi'])) / 60)) : 0;

    // Livraisons : à livrer (ventes payées confiées à un livreur), à encaisser (commandes en attente
    // confiées à un livreur, frais compris), livrées aujourd'hui.
    $aLivrer = q1("SELECT COUNT(*) AS Nombre, COALESCE(SUM(v.TotalTTC + v.FraisLivraison), 0) AS Montant $ventes AND v.StatutLivraison = 'À livrer'");
    $aEncaisser = ['Nombre' => 0, 'Montant' => 0.0];
    foreach (q("SELECT a.Total, a.Contenu FROM CommandesAttente a JOIN JourneesCaisses j ON j.Id = a.JourneeCaisseId JOIN Caisses c ON c.ID = j.CaisseId
                WHERE a.LivreurId IS NOT NULL AND $resto AND " . tf('a')) as $a) {
        $aEncaisser['Nombre']++;
        $aEncaisser['Montant'] += (float) $a['Total'] + (float) (json_decode((string) $a['Contenu'], true)['livraison']['frais'] ?? 0);
    }
    $livrees = (int) qv("SELECT COUNT(*) $ventes AND v.StatutLivraison = 'Livrée' AND v.DateLivraison >= ? AND v.DateLivraison < ?", [$aujourdhui, $fin]);

    // Meilleures ventes du jour : article le plus vendu (quantité), catégorie (chiffre d'affaires), articles vendus.
    $top = q1("SELECT COALESCE(p.Nom, l.Libelle) AS Nom, SUM(l.Quantite) AS Qte
               FROM LignesCommandePos l JOIN CommandesPos v ON v.Id = l.CommandePosId JOIN JourneesCaisses j ON j.Id = v.JourneeCaisseId
               JOIN Caisses c ON c.ID = j.CaisseId LEFT JOIN Produits p ON p.Id = l.ProduitId
               WHERE $resto AND v.Statut <> 'Annulée' AND " . tf('v') . ' AND v.DateCommande >= ? AND v.DateCommande < ?
               GROUP BY COALESCE(CAST(l.ProduitId AS CHAR), CONCAT(\'#\', l.Libelle)), COALESCE(p.Nom, l.Libelle)
               HAVING SUM(l.Quantite) > 0 ORDER BY Qte DESC, Nom LIMIT 1', [$aujourdhui, $fin]);
    $topCategorie = q1("SELECT COALESCE(cat.Nom, 'Sans catégorie') AS Nom, SUM(l.TotalTTC) AS CA
               FROM LignesCommandePos l JOIN CommandesPos v ON v.Id = l.CommandePosId JOIN JourneesCaisses j ON j.Id = v.JourneeCaisseId
               JOIN Caisses c ON c.ID = j.CaisseId LEFT JOIN Produits p ON p.Id = l.ProduitId LEFT JOIN Categories cat ON cat.Id = p.CategorieId
               WHERE $resto AND v.Statut <> 'Annulée' AND " . tf('v') . " AND v.DateCommande >= ? AND v.DateCommande < ?
               GROUP BY cat.Id, COALESCE(cat.Nom, 'Sans catégorie') HAVING SUM(l.TotalTTC) > 0 ORDER BY CA DESC, Nom LIMIT 1", [$aujourdhui, $fin]);
    $articlesVendus = (float) qv("SELECT COALESCE(SUM(l.Quantite), 0) FROM LignesCommandePos l JOIN CommandesPos v ON v.Id = l.CommandePosId
               JOIN JourneesCaisses j ON j.Id = v.JourneeCaisseId JOIN Caisses c ON c.ID = j.CaisseId
               WHERE $resto AND v.Statut <> 'Annulée' AND " . tf('v') . ' AND v.DateCommande >= ? AND v.DateCommande < ?', [$aujourdhui, $fin]);

    // Stock : produits sous le seuil d'alerte (hors produits d'entretien), produits suivis.
    $stockBas = (int) qv('SELECT COUNT(*) FROM Produits WHERE SuiviStock = 1 AND Actif = 1 AND EstModele = 0 AND Consommable = 0
                          AND SeuilAlerte IS NOT NULL AND StockActuel <= SeuilAlerte AND ' . tf());
    $suivis = (int) qv('SELECT COUNT(*) FROM Produits WHERE SuiviStock = 1 AND Actif = 1 AND EstModele = 0 AND Consommable = 0 AND ' . tf());
    $ruptures = (int) qv('SELECT COUNT(*) FROM Produits WHERE SuiviStock = 1 AND Actif = 1 AND EstModele = 0 AND Consommable = 0 AND StockActuel <= 0 AND ' . tf());

    // Caisse : journées ouvertes des caisses Restaurant / Bar, encaissements du jour (hors rejetés).
    $journees = q("SELECT j.Id, c.ChkCode FROM JourneesCaisses j JOIN Caisses c ON c.ID = j.CaisseId
                   WHERE j.Statut = 'Ouverte' AND $resto AND " . tf('j') . ' ORDER BY c.ChkCode');
    $encaissements = (float) qv("SELECT COALESCE(SUM(o.Montant), 0) FROM OperationsCaisses o JOIN JourneesCaisses j ON j.Id = o.JourneeCaisseId
                                 JOIN Caisses c ON c.ID = j.CaisseId
                                 WHERE $resto AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'
                                   AND o.DateOperation >= ? AND o.DateOperation < ? AND " . tf('o'), [$aujourdhui, $fin]);

    // 14 derniers jours : chiffre d'affaires net par jour.
    $debut = date('Y-m-d', strtotime('-13 days'));
    $jours = [];
    for ($i = 0; $i < 14; $i++) {
        $jours[date('Y-m-d', strtotime("$debut +$i days"))] = 0.0;
    }
    foreach (q("SELECT DATE(v.DateCommande) AS Jour, SUM(v.TotalTTC) AS CA $ventes AND v.DateCommande >= ? GROUP BY DATE(v.DateCommande)", [$debut]) as $r) {
        if (isset($jours[$r['Jour']])) $jours[$r['Jour']] = (float) $r['CA'];
    }

    render('tableaurestaurant/index', [
        'jour' => $jour,
        'semaine' => $semaine,
        'tables' => $tables,
        'occupees' => $occupees,
        'couvertsSalle' => $couvertsSalle,
        'enCours' => $enCours,
        'nbOuvertes' => count($ouvertes),
        'parPoste' => $parPoste,
        'nbBons' => count($bons),
        'attente' => $attente,
        'aLivrer' => $aLivrer,
        'aEncaisser' => $aEncaisser,
        'livrees' => $livrees,
        'top' => $top,
        'topCategorie' => $topCategorie,
        'articlesVendus' => $articlesVendus,
        'stockBas' => $stockBas,
        'suivis' => $suivis,
        'ruptures' => $ruptures,
        'journees' => $journees,
        'encaissements' => $encaissements,
        'jours' => $jours,
        'tablesOccupees' => array_slice(array_values(array_filter($ouvertes, fn($o) => $o['TableId'] !== null)), 0, 8),
        'bons' => array_slice($bons, 0, 8),
    ]);
}
