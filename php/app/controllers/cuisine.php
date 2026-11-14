<?php
// Écran cuisine / bar : bons de préparation des caisses restaurant / bar, actualisés en continu.
// Ouvert à tous les profils connectés (cuisiniers, barmans, serveurs).

require_once __DIR__ . '/../restaurant.php';

function cuisine_index(): void
{
    $caisses = q("SELECT ID, ChkCode, ChkDescription, TypePointVente FROM Caisses WHERE TypePointVente IN ('Restaurant', 'Bar') AND " . tf() . ' ORDER BY ChkCode');
    $caisse = null;
    foreach ($caisses as $c) {
        if ((int) $c['ID'] === (int) get('caisse') || count($caisses) === 1) {
            $caisse = $c;
        }
    }
    if (!$caisse) {
        render('cuisine/choix', ['caisses' => $caisses], false);
        return;
    }
    $poste = in_array(get('poste'), ['Cuisine', 'Bar'], true) ? get('poste') : '';
    render('cuisine/index', ['donnees' => [
        'caisse' => $caisse['ChkCode'],
        'poste' => $poste,
        'urlBons' => url('cuisine/bons', ['caisse' => $caisse['ID']]),
        'urlStatut' => url('cuisine/statut'),
        // Impression des bons sur l'imprimante de ce poste (impression automatique ou « Imprimer »).
        'urlImpression' => url('cuisine/bon') . '&ids=',
        'urlRetour' => url('accueil'),
        'jeton' => ['nom' => '_csrf', 'valeur' => csrf_token()],
    ]], false);
}

/** Bons à préparer (et prêts depuis moins de 2 heures) d'une caisse, en JSON. */
function cuisine_bons(): void
{
    $caisse = q1('SELECT ID FROM Caisses WHERE ID = ? AND ' . tf(), [(int) get('caisse')]);
    if (!$caisse) {
        pos_json_cuisine(['erreur' => 'Caisse introuvable.'], 404);
    }
    $filtre = in_array(get('poste'), ['Cuisine', 'Bar'], true) ? ' AND Poste = ' . db()->quote(get('poste')) : '';
    $lire = function (array $bons): array {
        if (!$bons) {
            return [];
        }
        $ids = array_column($bons, 'Id');
        $marques = implode(',', array_fill(0, count($ids), '?'));
        $lignes = [];
        foreach (q("SELECT * FROM LignesBonPreparation WHERE BonPreparationId IN ($marques) ORDER BY Id", $ids) as $l) {
            $lignes[(int) $l['BonPreparationId']][] = ['libelle' => $l['Libelle'], 'qte' => (float) $l['Quantite'], 'note' => $l['Note']];
        }
        return array_map(fn($b) => [
            'id' => (int) $b['Id'], 'numero' => (int) $b['Numero'], 'poste' => $b['Poste'], 'table' => $b['TableNom'],
            'couverts' => $b['Couverts'] === null ? null : (int) $b['Couverts'], 'serveur' => $b['Serveur'], 'date' => $b['DateEnvoi'],
            'lignes' => $lignes[(int) $b['Id']] ?? [],
        ], $bons);
    };
    pos_json_cuisine([
        'bons' => $lire(q("SELECT * FROM BonsPreparation WHERE CaisseId = ? AND Statut = 'À préparer'$filtre ORDER BY DateEnvoi, Id LIMIT 60", [$caisse['ID']])),
        'prets' => $lire(q("SELECT * FROM BonsPreparation WHERE CaisseId = ? AND Statut = 'Prêt' AND DatePret >= NOW() - INTERVAL 2 HOUR$filtre ORDER BY DatePret DESC LIMIT 8", [$caisse['ID']])),
    ]);
}

/** « Prêt » (retiré de l'écran) ou « À préparer » (rappelé). */
function cuisine_statut(): void
{
    if (is_post()) {
        $statut = post('statut') === 'Prêt' ? 'Prêt' : 'À préparer';
        run('UPDATE BonsPreparation SET Statut = ?, DatePret = ' . ($statut === 'Prêt' ? 'NOW()' : 'NULL') . ' WHERE Id = ? AND ' . tf(), [$statut, (int) post('id')]);
    }
    pos_json_cuisine(['ok' => true]);
}

function pos_json_cuisine(array $r, int $code = 200): never
{
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($r, JSON_UNESCAPED_UNICODE);
    exit;
}

/** Bons de préparation à imprimer depuis l'écran cuisine / bar (page qui s'imprime d'elle-même). */
function cuisine_bon(): void
{
    $ids = array_values(array_filter(array_map('intval', explode(',', (string) get('ids'))))) ?: [0];
    $marques = implode(',', array_fill(0, count($ids), '?'));
    $bons = q("SELECT * FROM BonsPreparation WHERE Id IN ($marques) AND " . tf() . ' ORDER BY Id', $ids);
    foreach ($bons as &$b) {
        $b['lignes'] = q('SELECT * FROM LignesBonPreparation WHERE BonPreparationId = ? ORDER BY Id', [$b['Id']]);
    }
    unset($b);
    render('pos/bon', ['bons' => $bons], false);
}
