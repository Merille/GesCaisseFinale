<?php
// Rapports du point de vente : tableau de bord, ventes par produit, catégorie, vendeur,
// heure et mode de paiement, meilleures ventes et panier moyen ; export Excel et PDF.
// Chiffre d'affaires net TTC = ventes - retours ; les ventes annulées sont exclues.

require_once __DIR__ . '/../xlsx.php';

/** Filtres : période (défaut : mois en cours) et caisse facultative. */
function posrapport_filtres(): array
{
    $d = fn($v) => ($v && DateTime::createFromFormat('!Y-m-d', $v)) ? $v : null;
    $debut = $d(get('dateDebut')) ?? date('Y-m-01');
    $fin = $d(get('dateFin')) ?? date('Y-m-d');
    if ($fin < $debut) {
        [$debut, $fin] = [$fin, $debut];
    }
    return ['dateDebut' => $debut, 'dateFin' => $fin, 'caisseId' => int_or_null(get('caisseId'))];
}

function posrapport_donnees(array $f): array
{
    $w = tf('cmd') . ' AND cmd.DateCommande >= :dd AND cmd.DateCommande < DATE_ADD(:df, INTERVAL 1 DAY)';
    $p = ['dd' => $f['dateDebut'], 'df' => $f['dateFin']];
    if ($f['caisseId']) {
        $w .= ' AND j.CaisseId = :cid';
        $p['cid'] = $f['caisseId'];
    }
    $from = ' FROM CommandesPos cmd JOIN JourneesCaisses j ON j.Id = cmd.JourneeCaisseId ';
    $net = $w . " AND cmd.Statut <> 'Annulée'";
    $estVente = "cmd.Statut NOT IN ('Retour', 'Annulée')";

    $k = q1(
        "SELECT COALESCE(SUM(CASE WHEN $estVente THEN cmd.TotalTTC END), 0) AS ventes,
                COALESCE(SUM(CASE WHEN $estVente THEN 1 END), 0) AS tickets,
                COALESCE(-SUM(CASE WHEN cmd.Statut = 'Retour' THEN cmd.TotalTTC END), 0) AS retours,
                COALESCE(SUM(CASE WHEN cmd.Statut = 'Retour' THEN 1 END), 0) AS nbRetours,
                COALESCE(SUM(CASE WHEN cmd.Statut = 'Annulée' THEN 1 END), 0) AS annulees,
                COALESCE(SUM(CASE WHEN cmd.Statut <> 'Annulée' THEN cmd.TotalHT END), 0) AS ht
         $from WHERE $w",
        $p
    );
    $ventes = (float) $k['ventes'];
    $tickets = (int) $k['tickets'];
    $articles = (float) qv("SELECT COALESCE(SUM(l.Quantite), 0) $from JOIN LignesCommandePos l ON l.CommandePosId = cmd.Id WHERE $net", $p);

    $parJour = q("SELECT DATE(cmd.DateCommande) AS d, SUM(cmd.TotalTTC) AS ca, SUM(CASE WHEN $estVente THEN 1 ELSE 0 END) AS tickets
                  $from WHERE $net GROUP BY DATE(cmd.DateCommande) ORDER BY d", $p);
    $parHeure = q("SELECT HOUR(cmd.DateCommande) AS h, SUM(cmd.TotalTTC) AS ca, SUM(CASE WHEN $estVente THEN 1 ELSE 0 END) AS tickets
                   $from WHERE $net GROUP BY HOUR(cmd.DateCommande) ORDER BY h", $p);

    $produits = q(
        "SELECT COALESCE(pr.Nom, l.Libelle) AS nom, pr.Code AS code, COALESCE(cat.Nom, 'Sans catégorie') AS categorie,
                SUM(l.Quantite) AS qte, SUM(l.TotalTTC) AS ca
         $from JOIN LignesCommandePos l ON l.CommandePosId = cmd.Id
         LEFT JOIN Produits pr ON pr.Id = l.ProduitId
         LEFT JOIN Categories cat ON cat.Id = pr.CategorieId
         WHERE $net
         GROUP BY COALESCE(CAST(l.ProduitId AS CHAR), CONCAT('#', l.Libelle)), COALESCE(pr.Nom, l.Libelle), pr.Code, COALESCE(cat.Nom, 'Sans catégorie')
         ORDER BY ca DESC, qte DESC, nom",
        $p
    );
    $categories = q(
        "SELECT COALESCE(cat.Nom, 'Sans catégorie') AS nom, MAX(cat.Couleur) AS couleur, SUM(l.Quantite) AS qte, SUM(l.TotalTTC) AS ca
         $from JOIN LignesCommandePos l ON l.CommandePosId = cmd.Id
         LEFT JOIN Produits pr ON pr.Id = l.ProduitId
         LEFT JOIN Categories cat ON cat.Id = pr.CategorieId
         WHERE $net GROUP BY cat.Id, COALESCE(cat.Nom, 'Sans catégorie') ORDER BY ca DESC, nom",
        $p
    );
    $vendeurs = q(
        "SELECT COALESCE(NULLIF(u.NomComplet, ''), u.NomUtilisateur, '?') AS nom,
                SUM(CASE WHEN $estVente THEN 1 ELSE 0 END) AS tickets,
                COALESCE(SUM(CASE WHEN $estVente THEN cmd.TotalTTC END), 0) AS ventes,
                COALESCE(-SUM(CASE WHEN cmd.Statut = 'Retour' THEN cmd.TotalTTC END), 0) AS retours,
                SUM(cmd.TotalTTC) AS ca
         $from LEFT JOIN Utilisateurs u ON u.Id = cmd.UtilisateurId
         WHERE $net GROUP BY cmd.UtilisateurId, COALESCE(NULLIF(u.NomComplet, ''), u.NomUtilisateur, '?') ORDER BY ca DESC, nom",
        $p
    );
    $modes = q(
        "SELECT pp.Libelle AS nom, COUNT(DISTINCT CASE WHEN $estVente THEN cmd.Id END) AS tickets, SUM(pp.Montant) AS montant
         $from JOIN PaiementsPos pp ON pp.CommandePosId = cmd.Id
         WHERE $net GROUP BY pp.Libelle ORDER BY montant DESC, nom",
        $p
    );

    // Taxes collectées : détail figé à la vente ; lignes plus anciennes comptées en TVA à leur taux total.
    $taxes = [];
    $detail = q("SELECT x.Code, x.Taux, SUM(x.Montant) AS montant $from JOIN LignesCommandePos l ON l.CommandePosId = cmd.Id
                 JOIN LignesCommandePosTaxes x ON x.LigneCommandePosId = l.Id WHERE $net GROUP BY x.Code, x.Taux", $p);
    $anciennes = q("SELECT 'TVA' AS Code, l.TauxTVA AS Taux, SUM(l.TotalTTC - l.TotalTTC / (1 + l.TauxTVA / 100)) AS montant
                    $from JOIN LignesCommandePos l ON l.CommandePosId = cmd.Id
                    WHERE $net AND l.TauxTVA > 0 AND NOT EXISTS (SELECT 1 FROM LignesCommandePosTaxes x WHERE x.LigneCommandePosId = l.Id)
                    GROUP BY l.TauxTVA", $p);
    foreach (array_merge($detail, $anciennes) as $t) {
        $nom = $t['Code'] . ' ' . quantite_fr($t['Taux']) . ' %';
        $taxes[$nom] = ($taxes[$nom] ?? 0) + (float) $t['montant'];
    }
    arsort($taxes);

    return [
        'taxes' => array_map(fn($nom, $montant) => ['nom' => $nom, 'montant' => round($montant, 2)], array_keys($taxes), $taxes),
        'kpi' => [
            'ca' => $ventes - (float) $k['retours'],
            'ht' => (float) $k['ht'],
            'ventes' => $ventes,
            'tickets' => $tickets,
            'panier' => $tickets > 0 ? $ventes / $tickets : 0.0,
            'articles' => $articles,
            'retours' => (float) $k['retours'],
            'nbRetours' => (int) $k['nbRetours'],
            'annulees' => (int) $k['annulees'],
        ],
        'parJour' => $parJour,
        'parHeure' => $parHeure,
        'produits' => $produits,
        'categories' => $categories,
        'vendeurs' => $vendeurs,
        'modes' => $modes,
    ];
}

function posrapport_caisse(array $f): ?array
{
    return $f['caisseId'] ? q1('SELECT ChkCode, ChkDescription FROM Caisses WHERE ID = ? AND ' . tf(), [$f['caisseId']]) : null;
}

function posrapport_index(): void
{
    $f = posrapport_filtres();
    render('posrapport/index', posrapport_donnees($f) + [
        'f' => $f,
        'caisses' => q('SELECT ID, ChkCode, ChkDescription FROM Caisses WHERE ' . tf() . ' ORDER BY ChkDescription'),
    ]);
}

function posrapport_preview(): void
{
    $f = posrapport_filtres();
    render('posrapport/preview', posrapport_donnees($f) + ['f' => $f, 'caisse' => posrapport_caisse($f)], false);
}

function posrapport_excel(): void
{
    $f = posrapport_filtres();
    $d = posrapport_donnees($f);
    $k = $d['kpi'];
    $caisse = posrapport_caisse($f);
    $n = fn($v) => round((float) $v, 2);

    $synthese = [
        ['Indicateur', 'Valeur'],
        ['Période', date_fr($f['dateDebut']) . ' au ' . date_fr($f['dateFin'])],
        ['Caisse', $caisse ? $caisse['ChkCode'] . ' - ' . $caisse['ChkDescription'] : 'Toutes'],
        ["Chiffre d'affaires net TTC", $n($k['ca'])],
        ["Chiffre d'affaires net HT", $n($k['ht'])],
        ['Ventes TTC', $n($k['ventes'])],
        ['Retours TTC', $n($k['retours'])],
        ['Tickets de vente', $k['tickets']],
        ['Panier moyen TTC', $n($k['panier'])],
        ['Articles vendus (net)', $n($k['articles'])],
        ['Retours', $k['nbRetours']],
        ['Ventes annulées', $k['annulees']],
    ];
    $feuille = fn(array $entetes, array $lignes, callable $ligne) => array_merge([$entetes], array_map($ligne, $lignes));
    $part = fn($v) => $k['ca'] != 0 ? round((float) $v * 100 / $k['ca'], 1) : 0.0;

    xlsx_envoyer('Rapport_POS_' . str_replace('-', '', $f['dateDebut']) . '_' . str_replace('-', '', $f['dateFin']) . '.xlsx', [
        'Synthèse' => $synthese,
        'Par produit' => $feuille(['Rang', 'Code', 'Produit', 'Catégorie', 'Quantité', 'CA TTC', 'Part %'], array_keys($d['produits']),
            fn($i) => [$i + 1, (string) $d['produits'][$i]['code'], $d['produits'][$i]['nom'], $d['produits'][$i]['categorie'],
                       $n($d['produits'][$i]['qte']), $n($d['produits'][$i]['ca']), $part($d['produits'][$i]['ca'])]),
        'Par catégorie' => $feuille(['Catégorie', 'Quantité', 'CA TTC', 'Part %'], $d['categories'],
            fn($c) => [$c['nom'], $n($c['qte']), $n($c['ca']), $part($c['ca'])]),
        'Par vendeur' => $feuille(['Vendeur', 'Tickets', 'Ventes TTC', 'Retours TTC', 'CA net TTC', 'Panier moyen'], $d['vendeurs'],
            fn($v) => [$v['nom'], (int) $v['tickets'], $n($v['ventes']), $n($v['retours']), $n($v['ca']),
                       (int) $v['tickets'] > 0 ? $n($v['ventes'] / $v['tickets']) : 0]),
        'Par heure' => $feuille(['Heure', 'Tickets', 'CA net TTC'], $d['parHeure'],
            fn($h) => [sprintf('%02dh - %02dh', $h['h'], ($h['h'] + 1) % 24), (int) $h['tickets'], $n($h['ca'])]),
        'Par jour' => $feuille(['Date', 'Tickets', 'CA net TTC'], $d['parJour'],
            fn($j) => [date_fr($j['d']), (int) $j['tickets'], $n($j['ca'])]),
        'Par mode de paiement' => $feuille(['Mode de paiement', 'Tickets', 'Encaissé net'], $d['modes'],
            fn($m) => [$m['nom'], (int) $m['tickets'], $n($m['montant'])]),
        'Taxes' => $feuille(['Taxe', 'Montant collecté'], $d['taxes'], fn($t) => [$t['nom'], $n($t['montant'])]),
    ]);
}
