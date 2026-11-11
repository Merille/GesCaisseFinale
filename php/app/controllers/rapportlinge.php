<?php
// Rapport des dépôts de linge (laverie) : sur une période (date de dépôt), synthèse par statut
// (nombre, articles, montant, acomptes, reste à encaisser) et détail des dépôts. Les filtres
// « À retirer » et « En retard » prennent tous les dépôts non retirés, quelle que soit leur date.
// Impression / PDF et export Excel.

require_once __DIR__ . '/../xlsx.php';

const RAPPORT_LINGE_STATUTS = ['En cours', 'Prêt', 'Retiré', 'Annulé'];
const RAPPORT_LINGE_FILTRES = ['À retirer', 'En retard', 'En cours', 'Prêt', 'Retiré', 'Annulé'];

/** Filtres lus dans l'URL (par défaut : du 1er du mois à aujourd'hui, tous les statuts). */
function rapportlinge_filtres(): array
{
    $d = fn($v) => ($v && DateTime::createFromFormat('!Y-m-d', (string) $v)) ? (string) $v : null;
    $statut = (string) get('statut', '');
    $f = [
        'du' => $d(get('du')) ?? date('Y-m-01'),
        'au' => $d(get('au')) ?? date('Y-m-d'),
        'statut' => in_array($statut, RAPPORT_LINGE_FILTRES, true) ? $statut : '',
    ];
    if ($f['au'] < $f['du']) {
        [$f['du'], $f['au']] = [$f['au'], $f['du']];
    }
    return $f;
}

/** Paramètres d'URL des filtres (liens Imprimer et Excel). */
function rapportlinge_params(array $f): array
{
    return array_filter(['du' => $f['du'], 'au' => $f['au'], 'statut' => $f['statut']], fn($v) => $v !== '');
}

/** Dépôts retenus, du plus ancien au plus récent. Reste : à encaisser pour un dépôt non retiré. */
function rapportlinge_lignes(array $f): array
{
    $sql = 'SELECT dl.*, c.ChkCode, u.NomComplet AS Utilisateur, cp.Numero AS NumeroVente
            FROM DepotsLinge dl LEFT JOIN Caisses c ON c.ID = dl.CaisseId LEFT JOIN Utilisateurs u ON u.Id = dl.UtilisateurId
            LEFT JOIN CommandesPos cp ON cp.Id = dl.CommandePosId WHERE ' . tf('dl');
    $p = [];
    if (in_array($f['statut'], ['À retirer', 'En retard'], true)) {
        $sql .= " AND dl.Statut IN ('En cours', 'Prêt')";
        if ($f['statut'] === 'En retard') {
            $sql .= ' AND dl.DateRetraitPrevue < CURDATE()';
        }
    } else {
        $sql .= ' AND dl.DateDepot >= ? AND dl.DateDepot < DATE_ADD(?, INTERVAL 1 DAY)';
        $p = [$f['du'], $f['au']];
        if ($f['statut'] !== '') {
            $sql .= ' AND dl.Statut = ?';
            $p[] = $f['statut'];
        }
    }
    $lignes = q($sql . ' ORDER BY dl.DateDepot, dl.Numero', $p);
    foreach ($lignes as &$l) {
        $actif = in_array($l['Statut'], ['En cours', 'Prêt'], true);
        $l['Reste'] = $actif ? max(0, (float) $l['Total'] - (float) $l['Acompte']) : 0.0;
        $l['EnRetard'] = $actif && $l['DateRetraitPrevue'] && $l['DateRetraitPrevue'] < date('Y-m-d');
    }
    return $lignes;
}

/** Synthèse par statut et totaux (hors annulés). */
function rapportlinge_synthese(array $lignes): array
{
    $vide = ['Nombre' => 0, 'Articles' => 0.0, 'Montant' => 0.0, 'Acomptes' => 0.0, 'Reste' => 0.0, 'EnRetard' => 0];
    $parStatut = array_fill_keys(RAPPORT_LINGE_STATUTS, $vide);
    $total = $vide;
    $ajouter = function (array &$t, array $l): void {
        $t['Nombre']++;
        $t['Articles'] += (float) $l['NbArticles'];
        $t['Montant'] += (float) $l['Total'];
        $t['Acomptes'] += (float) $l['Acompte'];
        $t['Reste'] += $l['Reste'];
        $t['EnRetard'] += $l['EnRetard'] ? 1 : 0;
    };
    foreach ($lignes as $l) {
        $ajouter($parStatut[$l['Statut']], $l);
        if ($l['Statut'] !== 'Annulé') {
            $ajouter($total, $l);
        }
    }
    return [$parStatut, $total];
}

function rapportlinge_donnees(): array
{
    $f = rapportlinge_filtres();
    $lignes = rapportlinge_lignes($f);
    [$parStatut, $total] = rapportlinge_synthese($lignes);
    return ['f' => $f, 'lignes' => $lignes, 'parStatut' => $parStatut, 'total' => $total];
}

function rapportlinge_index(): void
{
    render('rapportlinge/index', rapportlinge_donnees());
}

function rapportlinge_imprimer(): void
{
    render('rapportlinge/imprimer', rapportlinge_donnees(), false);
}

/** Libellé de la période ou du filtre sans période. */
function rapportlinge_periode(array $f): string
{
    return in_array($f['statut'], ['À retirer', 'En retard'], true)
        ? 'Tous les dépôts non retirés' . ($f['statut'] === 'En retard' ? ' dont la date de retrait est passée' : '')
        : 'Dépôts du ' . date_fr($f['du']) . ' au ' . date_fr($f['au']) . ($f['statut'] !== '' ? ' — Statut : ' . $f['statut'] : '');
}

function rapportlinge_excel(): void
{
    $d = rapportlinge_donnees();
    $f = $d['f'];
    $synthese = [['Statut', 'Dépôts', 'Articles', 'Montant', 'Acomptes', 'Reste à encaisser', 'En retard']];
    foreach ($d['parStatut'] as $statut => $s) {
        $synthese[] = [$statut, $s['Nombre'], $s['Articles'], $s['Montant'], $s['Acomptes'], $s['Reste'], $s['EnRetard']];
    }
    $t = $d['total'];
    $synthese[] = ['Total (hors annulés)', $t['Nombre'], $t['Articles'], $t['Montant'], $t['Acomptes'], $t['Reste'], $t['EnRetard']];
    $detail = [['N°', 'Déposé le', 'Caisse', 'Client', 'Téléphone', 'Articles', 'Montant', 'Acompte', 'Reste à encaisser', 'Retrait prévu', 'Statut', 'Retiré / annulé le', 'Vente', 'Reçu par']];
    foreach ($d['lignes'] as $l) {
        $fin = $l['DateRetrait'] ?: $l['DateAnnulation'];
        $detail[] = [(int) $l['Numero'], date_fr($l['DateDepot'], 'd/m/Y H:i'), (string) $l['ChkCode'], (string) $l['NomClient'], (string) $l['TelephoneClient'],
            (float) $l['NbArticles'], (float) $l['Total'], (float) $l['Acompte'], (float) $l['Reste'],
            $l['DateRetraitPrevue'] ? date_fr($l['DateRetraitPrevue']) : '', $l['Statut'] . ($l['EnRetard'] ? ' (en retard)' : ''),
            $fin ? date_fr($fin, 'd/m/Y H:i') : '', (string) $l['NumeroVente'], (string) $l['Utilisateur']];
    }
    xlsx_envoyer('Rapport_depots_linge_' . str_replace('-', '', $f['du']) . '_' . str_replace('-', '', $f['au']) . '.xlsx',
        ['Synthèse' => $synthese, 'Dépôts' => $detail]);
}
