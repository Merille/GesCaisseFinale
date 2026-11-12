<?php
// Rapport des achats et consommations (laverie) : sur une période (date d'achat) et, au besoin, un
// fournisseur : cartes (achats, montant, réglé, reste à payer, valeur consommée), synthèse par
// fournisseur, synthèse par produit (acheté : quantité, montant, prix moyen ; consommé : quantité et
// valeur au coût ; stock du dépôt des achats) et détail des achats. Les totaux ne comptent pas les
// achats annulés. Impression / PDF et export Excel.

require_once __DIR__ . '/../xlsx.php';

/** Filtres lus dans l'URL (par défaut : du 1er du mois à aujourd'hui, tous les fournisseurs). */
function rapportachat_filtres(): array
{
    $d = fn($v) => ($v && DateTime::createFromFormat('!Y-m-d', (string) $v)) ? (string) $v : null;
    $f = ['du' => $d(get('du')) ?? date('Y-m-01'), 'au' => $d(get('au')) ?? date('Y-m-d'), 'fournisseur' => (int) get('fournisseur', 0)];
    if ($f['au'] < $f['du']) {
        [$f['du'], $f['au']] = [$f['au'], $f['du']];
    }
    return $f;
}

/** Paramètres d'URL des filtres (liens Imprimer et Excel). */
function rapportachat_params(array $f): array
{
    return array_filter(['du' => $f['du'], 'au' => $f['au'], 'fournisseur' => $f['fournisseur'] ?: ''], fn($v) => $v !== '');
}

function rapportachat_donnees(): array
{
    $f = rapportachat_filtres();
    $fournisseur = $f['fournisseur'] ? (string) qv('SELECT NomSociete FROM Clients WHERE Id = ? AND ' . tf(), [$f['fournisseur']]) : '';
    $sql = 'SELECT a.*, f.NomSociete AS Fournisseur, u.NomComplet AS Utilisateur,
                (SELECT COALESCE(SUM(r.Montant), 0) FROM ReglementsAchats r WHERE r.AchatId = a.Id) AS Regle
            FROM Achats a LEFT JOIN Clients f ON f.Id = a.FournisseurId LEFT JOIN Utilisateurs u ON u.Id = a.UtilisateurId
            WHERE a.DateAchat BETWEEN ? AND ? AND ' . tf('a');
    $p = [$f['du'], $f['au']];
    if ($f['fournisseur']) {
        $sql .= ' AND a.FournisseurId = ?';
        $p[] = $f['fournisseur'];
    }
    $achats = q($sql . ' ORDER BY a.DateAchat, a.Numero', $p);
    $vide = ['Nombre' => 0, 'Montant' => 0.0, 'Regle' => 0.0, 'Reste' => 0.0];
    $total = $vide;
    $parFournisseur = [];
    $ids = [];
    $ajouter = function (array &$t, array $a, float $reste): void {
        $t['Nombre']++;
        $t['Montant'] += (float) $a['Total'];
        $t['Regle'] += (float) $a['Regle'];
        $t['Reste'] += $reste;
    };
    foreach ($achats as $i => $a) {
        $valide = $a['Statut'] === 'Validé';
        $achats[$i]['Reste'] = $reste = $valide ? max(0, round((float) $a['Total'] - (float) $a['Regle'], 2)) : 0.0;
        if (!$valide) {
            continue;
        }
        $ids[] = (int) $a['Id'];
        $nom = $a['Fournisseur'] ?? 'Sans fournisseur';
        $parFournisseur[$nom] ??= $vide;
        $ajouter($total, $a, $reste);
        $ajouter($parFournisseur[$nom], $a, $reste);
    }
    ksort($parFournisseur, SORT_NATURAL | SORT_FLAG_CASE);

    // Par produit : achats validés de la période et consommations de la période (tous fournisseurs).
    $depot = tenant_id() > 0 ? (int) depot_des_achats(tenant_id())['Id'] : 0;
    $produits = [];
    $ligne = function (array $p) use (&$produits, $depot): void {
        $produits[(int) $p['Id']] ??= ['Code' => $p['Code'], 'Nom' => $p['Nom'], 'Unite' => $p['Unite'], 'Cout' => (float) $p['Cout'],
            'QteAchetee' => 0.0, 'MontantAchete' => 0.0, 'QteConsommee' => 0.0, 'ValeurConsommee' => 0.0,
            'Stock' => (float) qv('SELECT COALESCE(SUM(Quantite), 0) FROM StocksDepots WHERE ProduitId = ? AND DepotId = ?', [$p['Id'], $depot])];
    };
    if ($ids) {
        foreach (q('SELECT p.Id, p.Code, p.Nom, p.Unite, p.Cout, SUM(l.Quantite) AS Qte, SUM(l.Montant) AS Montant
                    FROM LignesAchats l JOIN Produits p ON p.Id = l.ProduitId WHERE l.AchatId IN (' . implode(',', $ids) . ')
                    GROUP BY p.Id, p.Code, p.Nom, p.Unite, p.Cout') as $r) {
            $ligne($r);
            $produits[(int) $r['Id']]['QteAchetee'] = (float) $r['Qte'];
            $produits[(int) $r['Id']]['MontantAchete'] = (float) $r['Montant'];
        }
    }
    foreach (q("SELECT p.Id, p.Code, p.Nom, p.Unite, p.Cout, -SUM(m.Quantite) AS Qte FROM MouvementsStock m JOIN Produits p ON p.Id = m.ProduitId
                WHERE m.TypeMouvement = 'Consommation' AND m.DateMouvement >= ? AND m.DateMouvement < DATE_ADD(?, INTERVAL 1 DAY) AND " . tf('m') . '
                GROUP BY p.Id, p.Code, p.Nom, p.Unite, p.Cout', [$f['du'], $f['au']]) as $r) {
        if ($f['fournisseur'] && !isset($produits[(int) $r['Id']])) {
            continue;
        }
        $ligne($r);
        $produits[(int) $r['Id']]['QteConsommee'] = (float) $r['Qte'];
        $produits[(int) $r['Id']]['ValeurConsommee'] = (float) $r['Qte'] * (float) $r['Cout'];
    }
    usort($produits, fn($x, $y) => strcmp($x['Nom'], $y['Nom']));
    $totalProduits = ['MontantAchete' => array_sum(array_column($produits, 'MontantAchete')), 'ValeurConsommee' => array_sum(array_column($produits, 'ValeurConsommee'))];
    return ['f' => $f, 'nomFournisseur' => $fournisseur, 'periode' => rapportachat_periode($f, $fournisseur), 'achats' => $achats, 'total' => $total, 'parFournisseur' => $parFournisseur,
            'produits' => $produits, 'totalProduits' => $totalProduits,
            'fournisseurs' => q("SELECT Id, NomSociete FROM Clients WHERE Type = 'Fournisseur' AND " . tf() . ' ORDER BY NomSociete')];
}

/** Libellé de la période et du fournisseur. */
function rapportachat_periode(array $f, string $fournisseur): string
{
    return 'Achats du ' . date_fr($f['du']) . ' au ' . date_fr($f['au']) . ($fournisseur !== '' ? ' — Fournisseur : ' . $fournisseur : '');
}

function rapportachat_index(): void
{
    render('rapportachat/index', rapportachat_donnees());
}

function rapportachat_imprimer(): void
{
    render('rapportachat/imprimer', rapportachat_donnees(), false);
}

function rapportachat_excel(): void
{
    $d = rapportachat_donnees();
    $fournisseurs = [['Fournisseur', 'Achats', 'Montant', 'Réglé', 'Reste à payer']];
    foreach ($d['parFournisseur'] as $nom => $s) {
        $fournisseurs[] = [$nom, $s['Nombre'], $s['Montant'], $s['Regle'], $s['Reste']];
    }
    $t = $d['total'];
    $fournisseurs[] = ['Total (hors annulés)', $t['Nombre'], $t['Montant'], $t['Regle'], $t['Reste']];
    $produits = [['Code', 'Produit', 'Unité', 'Quantité achetée', 'Montant acheté', 'Prix moyen', 'Quantité consommée', 'Valeur consommée', 'Stock (dépôt des achats)']];
    foreach ($d['produits'] as $p) {
        $produits[] = [$p['Code'], $p['Nom'], $p['Unite'], $p['QteAchetee'], $p['MontantAchete'],
            $p['QteAchetee'] > 0 ? round($p['MontantAchete'] / $p['QteAchetee'], 2) : '', $p['QteConsommee'], round($p['ValeurConsommee'], 2), $p['Stock']];
    }
    $achats = [['N°', 'Date', 'Fournisseur', 'Référence', 'Montant', 'Réglé', 'Reste à payer', 'Statut', 'Saisi par']];
    foreach ($d['achats'] as $a) {
        $achats[] = [(int) $a['Numero'], date_fr($a['DateAchat']), (string) ($a['Fournisseur'] ?? ''), (string) $a['Reference'], (float) $a['Total'],
            (float) $a['Regle'], (float) $a['Reste'], rapportachat_statut($a), (string) $a['Utilisateur']];
    }
    xlsx_envoyer('Rapport_achats_' . str_replace('-', '', $d['f']['du']) . '_' . str_replace('-', '', $d['f']['au']) . '.xlsx',
        ['Fournisseurs' => $fournisseurs, 'Produits' => $produits, 'Achats' => $achats]);
}

/** Statut affiché : Annulé, Non soldé ou Soldé. */
function rapportachat_statut(array $a): string
{
    return $a['Statut'] !== 'Validé' ? 'Annulé' : ((float) $a['Reste'] > 0 ? 'Non soldé' : 'Soldé');
}
