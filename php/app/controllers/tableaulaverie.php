<?php
// Tableau de bord de la laverie (société qui a une caisse de type Laverie) : une page à part, en
// tuiles, à côté du tableau de bord général (inchangé). Dépôts et retraits du jour et de la semaine,
// linge à retirer et en retard, clients servis, articles, produits d'entretien, caisse du jour ;
// graphique des 14 derniers jours ; linge prêt à remettre et en retard.

function tableaulaverie_index(): void
{
    if (!laverie_actif()) {
        redirect('dashboard/index');
    }
    $tf = tf('d');
    $aujourdhui = date('Y-m-d');
    $lundi = date('Y-m-d', strtotime('monday this week'));
    $mois = date('Y-m-01');
    $fin = date('Y-m-d', strtotime('+1 day'));
    $actifs = "d.Statut IN ('En cours', 'Prêt')";

    $depotsSemaine = (int) qv("SELECT COUNT(*) FROM DepotsLinge d WHERE d.Statut <> 'Annulé' AND d.DateDepot >= ? AND d.DateDepot < ? AND $tf", [$lundi, $fin]);
    $depotsJour = q1("SELECT COUNT(*) AS Nombre, COALESCE(SUM(NbArticles), 0) AS Articles, COALESCE(SUM(Total), 0) AS Montant
                      FROM DepotsLinge d WHERE d.Statut <> 'Annulé' AND d.DateDepot >= ? AND d.DateDepot < ? AND $tf", [$aujourdhui, $fin]);
    $retraits = q1("SELECT SUM(d.DateRetrait >= ?) AS Jour, COALESCE(SUM(CASE WHEN d.DateRetrait >= ? THEN d.Total ELSE 0 END), 0) AS MontantJour, COUNT(*) AS Semaine
                    FROM DepotsLinge d WHERE d.Statut = 'Retiré' AND d.DateRetrait >= ? AND d.DateRetrait < ? AND $tf", [$aujourdhui, $aujourdhui, $lundi, $fin]);
    $aRetirer = q1("SELECT COUNT(*) AS Nombre, SUM(d.Statut = 'Prêt') AS Prets, COALESCE(SUM(GREATEST(0, d.Total - d.Acompte)), 0) AS Reste,
                       SUM(d.DateRetraitPrevue < ?) AS Retard, MIN(CASE WHEN d.DateRetraitPrevue < ? THEN d.DateRetraitPrevue END) AS PlusAncien,
                       COALESCE(SUM(CASE WHEN d.DateRetraitPrevue < ? THEN GREATEST(0, d.Total - d.Acompte) ELSE 0 END), 0) AS ResteRetard
                    FROM DepotsLinge d WHERE $actifs AND $tf", [$aujourdhui, $aujourdhui, $aujourdhui]);

    // Clients servis ce mois (dépôts) : par fiche client, sinon par téléphone ou nom.
    $clientsMois = (int) qv("SELECT COUNT(DISTINCT COALESCE(CAST(d.ClientId AS CHAR), NULLIF(d.TelephoneClient, ''), d.NomClient))
                             FROM DepotsLinge d WHERE d.Statut <> 'Annulé' AND d.DateDepot >= ? AND $tf", [$mois]);
    $clientsTotal = (int) qv("SELECT COUNT(*) FROM Clients WHERE Type = 'Client' AND " . tf());
    $du = tenant_id() ? array_sum(array_filter(compte_soldes(tenant_id()), fn($v) => $v > 0)) : 0.0;

    // Articles : en vente, catégories ; les plus déposés ce mois (contenu des dépôts).
    $articles = (int) qv('SELECT COUNT(*) FROM Produits WHERE Actif = 1 AND Consommable = 0 AND EstModele = 0 AND ' . tf());
    $categories = (int) qv('SELECT COUNT(*) FROM Categories WHERE ' . tf());
    $parArticle = [];
    foreach (q("SELECT d.Contenu FROM DepotsLinge d WHERE d.Statut <> 'Annulé' AND d.DateDepot >= ? AND $tf", [$mois]) as $r) {
        foreach ((array) (json_decode((string) $r['Contenu'], true)['lignes'] ?? []) as $l) {
            if (is_array($l) && !empty($l['nom'])) {
                $parArticle[$l['nom']] = ($parArticle[$l['nom']] ?? 0) + (float) ($l['qte'] ?? 0);
            }
        }
    }
    arsort($parArticle);

    // Produits d'entretien : à racheter, valeur du stock du dépôt des achats, achats du mois.
    $entretien = q1('SELECT COALESCE(SUM(sd.Quantite * p.Cout), 0) AS Valeur, COUNT(DISTINCT p.Id) AS Produits
                     FROM Produits p JOIN Depots dp ON dp.TenantId = p.TenantId AND dp.DepotAchats = 1
                     LEFT JOIN StocksDepots sd ON sd.ProduitId = p.Id AND sd.DepotId = dp.Id
                     WHERE p.Consommable = 1 AND p.Actif = 1 AND ' . tf('p'));
    $achatsMois = (float) qv("SELECT COALESCE(SUM(Total), 0) FROM Achats WHERE Statut = 'Validé' AND DateAchat >= ? AND " . tf(), [$mois]);

    // Caisse : journées ouvertes des caisses Laverie, encaissements du jour (hors rejetés).
    $journees = q("SELECT j.Id, c.ChkCode FROM JourneesCaisses j JOIN Caisses c ON c.ID = j.CaisseId
                   WHERE j.Statut = 'Ouverte' AND c.TypePointVente = 'Laverie' AND " . tf('j') . ' ORDER BY c.ChkCode');
    $encaissements = (float) qv("SELECT COALESCE(SUM(o.Montant), 0) FROM OperationsCaisses o JOIN JourneesCaisses j ON j.Id = o.JourneeCaisseId
                                 JOIN Caisses c ON c.ID = j.CaisseId
                                 WHERE c.TypePointVente = 'Laverie' AND o.TypeOperation = 'Encaissement' AND o.StatutValidation <> 'Rejeté'
                                   AND o.DateOperation >= ? AND o.DateOperation < ? AND " . tf('o'), [$aujourdhui, $fin]);

    // 14 derniers jours : dépôts et retraits par jour.
    $debut = date('Y-m-d', strtotime('-13 days'));
    $jours = [];
    for ($i = 0; $i < 14; $i++) {
        $jours[date('Y-m-d', strtotime("$debut +$i days"))] = ['depots' => 0, 'retraits' => 0];
    }
    foreach (q("SELECT DATE(d.DateDepot) AS Jour, COUNT(*) AS N FROM DepotsLinge d WHERE d.Statut <> 'Annulé' AND d.DateDepot >= ? AND $tf GROUP BY DATE(d.DateDepot)", [$debut]) as $r) {
        if (isset($jours[$r['Jour']])) $jours[$r['Jour']]['depots'] = (int) $r['N'];
    }
    foreach (q("SELECT DATE(d.DateRetrait) AS Jour, COUNT(*) AS N FROM DepotsLinge d WHERE d.Statut = 'Retiré' AND d.DateRetrait >= ? AND $tf GROUP BY DATE(d.DateRetrait)", [$debut]) as $r) {
        if (isset($jours[$r['Jour']])) $jours[$r['Jour']]['retraits'] = (int) $r['N'];
    }

    render('tableaulaverie/index', [
        'depotsJour' => $depotsJour,
        'depotsSemaine' => $depotsSemaine,
        'retraits' => $retraits,
        'aRetirer' => $aRetirer,
        'clientsMois' => $clientsMois,
        'clientsTotal' => $clientsTotal,
        'du' => $du,
        'articles' => $articles,
        'categories' => $categories,
        'topArticles' => array_slice($parArticle, 0, 5, true),
        'entretien' => $entretien,
        'aRacheter' => count(entretien_en_alerte()),
        'achatsMois' => $achatsMois,
        'journees' => $journees,
        'encaissements' => $encaissements,
        'jours' => $jours,
        'prets' => q("SELECT d.* FROM DepotsLinge d WHERE d.Statut = 'Prêt' AND $tf ORDER BY d.DatePret, d.Numero LIMIT 8"),
        'retards' => q("SELECT d.* FROM DepotsLinge d WHERE $actifs AND d.DateRetraitPrevue < ? AND $tf ORDER BY d.DateRetraitPrevue, d.Numero LIMIT 8", [$aujourdhui]),
    ]);
}
