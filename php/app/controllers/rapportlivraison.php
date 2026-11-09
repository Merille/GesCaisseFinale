<?php
// Rapport des livraisons : sur une période, synthèse par livreur (livraisons, livrées, en cours,
// montant des ventes, frais de livraison) et détail des livraisons — ventes livrées ou à livrer,
// et commandes confiées au livreur, à encaisser à son retour. Les ventes annulées sont exclues.
// Impression / PDF et export Excel.

require_once __DIR__ . '/../xlsx.php';
require_once __DIR__ . '/livreur.php';

const RAPPORT_LIVRAISON_STATUTS = ['Livrée', 'À livrer', 'À encaisser'];

/** Filtres lus dans l'URL (par défaut : du 1er du mois à aujourd'hui). */
function rapportlivraison_filtres(): array
{
    $d = fn($v) => ($v && DateTime::createFromFormat('!Y-m-d', (string) $v)) ? (string) $v : null;
    $statut = (string) get('statut', '');
    $f = [
        'du' => $d(get('du')) ?? date('Y-m-01'),
        'au' => $d(get('au')) ?? date('Y-m-d'),
        'livreur' => (int) get('livreur', 0),
        'statut' => in_array($statut, RAPPORT_LIVRAISON_STATUTS, true) ? $statut : '',
    ];
    if ($f['au'] < $f['du']) {
        [$f['du'], $f['au']] = [$f['au'], $f['du']];
    }
    return $f;
}

/** Paramètres d'URL des filtres (liens Imprimer et Excel). */
function rapportlivraison_params(array $f): array
{
    return array_filter(['du' => $f['du'], 'au' => $f['au'], 'livreur' => $f['livreur'] ?: '', 'statut' => $f['statut']], fn($v) => $v !== '');
}

/**
 * Livraisons de la période : ventes avec livreur (hors annulées et retours) et commandes en attente
 * confiées à un livreur (« À encaisser »). Montant = articles (TTC) ; frais en plus.
 */
function rapportlivraison_lignes(array $f): array
{
    $p = [$f['du'], $f['au']];
    $w = '';
    if ($f['livreur']) {
        $w = ' AND c.LivreurId = ?';
        $p[] = $f['livreur'];
    }
    $lignes = array_map(fn($c) => $c + ['Source' => 'vente'], q(
        "SELECT c.Id, c.Numero, c.DateCommande AS Date, c.TotalTTC AS Montant, c.FraisLivraison AS Frais, c.StatutLivraison AS Statut,
                c.DateLivraison, c.NomLivraison, c.TelephoneLivraison, c.AdresseLivraison, c.LivreurId,
                l.Nom AS Livreur, l.MoyenLivraison AS Moyen, cl.NomSociete AS Client
         FROM CommandesPos c LEFT JOIN Livreurs l ON l.Id = c.LivreurId LEFT JOIN Clients cl ON cl.Id = c.ClientId
         WHERE c.LivreurId IS NOT NULL AND c.Statut <> 'Annulée' AND c.CommandeOrigineId IS NULL
           AND c.DateCommande >= ? AND c.DateCommande < DATE_ADD(?, INTERVAL 1 DAY)$w AND " . tf('c'),
        $p
    ));
    foreach (q(
        "SELECT a.Id, a.Numero, a.DateCreation AS Date, a.Total, a.Contenu, a.NomLivraison, a.TelephoneLivraison, a.AdresseLivraison, a.LivreurId,
                l.Nom AS Livreur, l.MoyenLivraison AS Moyen, cl.NomSociete AS Client
         FROM CommandesAttente a LEFT JOIN Livreurs l ON l.Id = a.LivreurId LEFT JOIN Clients cl ON cl.Id = a.ClientId
         WHERE a.LivreurId IS NOT NULL AND a.DateCreation >= ? AND a.DateCreation < DATE_ADD(?, INTERVAL 1 DAY)" . str_replace('c.', 'a.', $w) . ' AND ' . tf('a'),
        $p
    ) as $a) {
        $frais = (float) (json_decode((string) $a['Contenu'], true)['livraison']['frais'] ?? 0);
        $lignes[] = [
            'Id' => (int) $a['Id'], 'Numero' => 'Attente n° ' . $a['Numero'], 'Date' => $a['Date'], 'Montant' => (float) $a['Total'] - $frais,
            'Frais' => $frais, 'Statut' => 'À encaisser', 'DateLivraison' => null, 'NomLivraison' => $a['NomLivraison'],
            'TelephoneLivraison' => $a['TelephoneLivraison'], 'AdresseLivraison' => $a['AdresseLivraison'], 'LivreurId' => $a['LivreurId'],
            'Livreur' => $a['Livreur'], 'Moyen' => $a['Moyen'], 'Client' => $a['Client'], 'Source' => 'attente',
        ];
    }
    if ($f['statut'] !== '') {
        $lignes = array_values(array_filter($lignes, fn($l) => $l['Statut'] === $f['statut']));
    }
    usort($lignes, fn($a, $b) => [$a['Date'], $a['Numero']] <=> [$b['Date'], $b['Numero']]);
    return $lignes;
}

/** Synthèse par livreur et totaux. */
function rapportlivraison_synthese(array $lignes): array
{
    $vide = ['Livraisons' => 0, 'Livrees' => 0, 'ALivrer' => 0, 'AEncaisser' => 0, 'Montant' => 0.0, 'Frais' => 0.0];
    $parLivreur = [];
    $total = $vide;
    $ajouter = function (array &$t, array $l): void {
        $t['Livraisons']++;
        $t[['Livrée' => 'Livrees', 'À livrer' => 'ALivrer', 'À encaisser' => 'AEncaisser'][$l['Statut']] ?? 'ALivrer']++;
        $t['Montant'] += (float) $l['Montant'];
        $t['Frais'] += (float) $l['Frais'];
    };
    foreach ($lignes as $l) {
        $k = (int) $l['LivreurId'];
        $parLivreur[$k] ??= $vide + ['Livreur' => $l['Livreur'], 'Moyen' => $l['Moyen']];
        $ajouter($parLivreur[$k], $l);
        $ajouter($total, $l);
    }
    uasort($parLivreur, fn($a, $b) => strcmp((string) $a['Livreur'], (string) $b['Livreur']));
    return [array_values($parLivreur), $total];
}

function rapportlivraison_donnees(): array
{
    $f = rapportlivraison_filtres();
    $lignes = rapportlivraison_lignes($f);
    [$livreurs, $total] = rapportlivraison_synthese($lignes);
    return ['f' => $f, 'lignes' => $lignes, 'parLivreur' => $livreurs, 'total' => $total,
            'livreurs' => q('SELECT Id, Nom FROM Livreurs WHERE ' . tf() . ' ORDER BY Nom')];
}

function rapportlivraison_index(): void
{
    render('rapportlivraison/index', rapportlivraison_donnees());
}

function rapportlivraison_imprimer(): void
{
    render('rapportlivraison/imprimer', rapportlivraison_donnees(), false);
}

function rapportlivraison_excel(): void
{
    $d = rapportlivraison_donnees();
    $f = $d['f'];
    $synthese = [['Livreur', 'Moyen', 'Livraisons', 'Livrées', 'À livrer', 'À encaisser', 'Montant des ventes', 'Frais de livraison']];
    foreach ($d['parLivreur'] as $l) {
        $synthese[] = [(string) $l['Livreur'], (string) $l['Moyen'], $l['Livraisons'], $l['Livrees'], $l['ALivrer'], $l['AEncaisser'], $l['Montant'], $l['Frais']];
    }
    $t = $d['total'];
    $synthese[] = ['Total', '', $t['Livraisons'], $t['Livrees'], $t['ALivrer'], $t['AEncaisser'], $t['Montant'], $t['Frais']];
    $detail = [['Date', 'N°', 'Livreur', 'Moyen', 'Client', 'Destinataire', 'Téléphone', 'Adresse', 'Montant des ventes', 'Frais de livraison', 'Statut', 'Livrée le']];
    foreach ($d['lignes'] as $l) {
        $detail[] = [date_fr($l['Date'], 'd/m/Y H:i'), (string) $l['Numero'], (string) $l['Livreur'], (string) $l['Moyen'], (string) $l['Client'],
            (string) $l['NomLivraison'], (string) $l['TelephoneLivraison'], (string) $l['AdresseLivraison'], (float) $l['Montant'], (float) $l['Frais'],
            (string) $l['Statut'], $l['DateLivraison'] ? date_fr($l['DateLivraison'], 'd/m/Y H:i') : ''];
    }
    xlsx_envoyer('Rapport_livraisons_' . str_replace('-', '', $f['du']) . '_' . str_replace('-', '', $f['au']) . '.xlsx',
        ['Livreurs' => $synthese, 'Livraisons' => $detail]);
}
