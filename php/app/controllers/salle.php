<?php
// Plan de salle d'une caisse restaurant / bar : salles et tables placées sur un plan.
// Réservé aux profils Admin et SuperAdmin.

require_once __DIR__ . '/../restaurant.php';

function salle_caisse(int $id): array
{
    $caisse = q1('SELECT * FROM Caisses WHERE ID = ? AND ' . tf(), [$id]);
    if (!$caisse) {
        not_found('Caisse introuvable.');
    }
    return $caisse;
}

function salle_index(): void
{
    $caisse = salle_caisse((int) get('caisse'));
    if (!caisse_est_restaurant($caisse)) {
        flash('warning', "Le plan de salle concerne les caisses de type Restaurant ou Bar : modifiez d'abord le type de la caisse « " . $caisse['ChkCode'] . ' ».');
        redirect('caisse/index');
    }
    render('salle/index', [
        'caisse' => $caisse,
        'donnees' => [
            'caisseId' => (int) $caisse['ID'],
            'salles' => restaurant_plan((int) $caisse['ID']),
            'urlEnregistrer' => url('salle/enregistrer'),
            'jeton' => ['nom' => '_csrf', 'valeur' => csrf_token()],
        ],
    ]);
}

/** Enregistre tout le plan d'une caisse (salles et tables) envoyé en JSON par l'éditeur. */
function salle_enregistrer(): void
{
    $repondre = function (array $r, int $code = 200): never {
        http_response_code($code);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($r, JSON_UNESCAPED_UNICODE);
        exit;
    };
    if (!is_post()) {
        $repondre(['erreur' => 'Requête invalide.'], 405);
    }
    $plan = json_decode((string) ($_POST['plan'] ?? ''), true);
    if (!is_array($plan)) {
        $repondre(['erreur' => 'Plan illisible.'], 400);
    }
    $caisse = q1('SELECT * FROM Caisses WHERE ID = ? AND ' . tf(), [(int) ($plan['caisseId'] ?? 0)]);
    if (!$caisse) {
        $repondre(['erreur' => 'Caisse introuvable.'], 404);
    }
    $caisseId = (int) $caisse['ID'];
    $tenant = (int) $caisse['TenantId'];
    $sallesExistantes = array_column(q('SELECT Id FROM Salles WHERE CaisseId = ?', [$caisseId]), 'Id');
    $tablesExistantes = [];
    foreach (q('SELECT t.Id, t.Nom FROM TablesRestaurant t JOIN Salles s ON s.Id = t.SalleId WHERE s.CaisseId = ?', [$caisseId]) as $t) {
        $tablesExistantes[(int) $t['Id']] = $t['Nom'];
    }

    // Plan reçu, nettoyé : positions dans le plan de 1000 × 600.
    $salles = [];
    $gardees = [];
    foreach (array_slice((array) ($plan['salles'] ?? []), 0, 30) as $i => $s) {
        $nom = mb_substr(trim((string) ($s['nom'] ?? '')), 0, 50) ?: 'Salle ' . ($i + 1);
        $tables = [];
        foreach (array_slice((array) ($s['tables'] ?? []), 0, 200) as $n => $t) {
            $l = max(40, min(400, (int) ($t['l'] ?? 100)));
            $h = max(40, min(400, (int) ($t['h'] ?? 100)));
            $id = (int) ($t['id'] ?? 0);
            $tables[] = [
                'id' => isset($tablesExistantes[$id]) ? $id : 0,
                'nom' => mb_substr(trim((string) ($t['nom'] ?? '')), 0, 30) ?: 'Table ' . ($n + 1),
                'places' => max(1, min(50, (int) ($t['places'] ?? 4))),
                'forme' => ($t['forme'] ?? '') === 'ronde' ? 'ronde' : 'carree',
                'x' => max(0, min(1000 - $l, (int) ($t['x'] ?? 0))), 'y' => max(0, min(600 - $h, (int) ($t['y'] ?? 0))),
                'l' => $l, 'h' => $h,
            ];
            if (isset($tablesExistantes[$id])) {
                $gardees[$id] = true;
            }
        }
        $sid = (int) ($s['id'] ?? 0);
        $salles[] = ['id' => in_array($sid, array_map('intval', $sallesExistantes), true) ? $sid : 0, 'nom' => $nom, 'tables' => $tables];
    }

    // Une table retirée ne doit pas avoir de commande en cours.
    $retirees = array_diff_key($tablesExistantes, $gardees);
    if ($retirees) {
        $marques = implode(',', array_fill(0, count($retirees), '?'));
        $occupees = q("SELECT t.Nom FROM CommandesOuvertes co JOIN TablesRestaurant t ON t.Id = co.TableId WHERE co.TableId IN ($marques)", array_keys($retirees));
        if ($occupees) {
            $repondre(['erreur' => 'Impossible de retirer ' . implode(', ', array_column($occupees, 'Nom')) . ' : une commande y est en cours. Encaissez-la ou transférez-la d\'abord.'], 409);
        }
    }

    db()->beginTransaction();
    try {
        $sallesGardees = [];
        foreach ($salles as $ordre => $s) {
            if ($s['id']) {
                run('UPDATE Salles SET Nom = ?, Ordre = ? WHERE Id = ?', [$s['nom'], $ordre, $s['id']]);
                $salleId = $s['id'];
            } else {
                $salleId = run('INSERT INTO Salles (TenantId, CaisseId, Nom, Ordre) VALUES (?, ?, ?, ?)', [$tenant, $caisseId, $s['nom'], $ordre]);
            }
            $sallesGardees[] = $salleId;
            foreach ($s['tables'] as $t) {
                $valeurs = [$salleId, $t['nom'], $t['places'], $t['forme'], $t['x'], $t['y'], $t['l'], $t['h']];
                if ($t['id']) {
                    run('UPDATE TablesRestaurant SET SalleId = ?, Nom = ?, Places = ?, Forme = ?, PosX = ?, PosY = ?, Largeur = ?, Hauteur = ? WHERE Id = ?', [...$valeurs, $t['id']]);
                } else {
                    run('INSERT INTO TablesRestaurant (SalleId, Nom, Places, Forme, PosX, PosY, Largeur, Hauteur, TenantId) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', [...$valeurs, $tenant]);
                }
            }
        }
        foreach (array_keys($retirees) as $id) {
            run('DELETE FROM TablesRestaurant WHERE Id = ?', [$id]);
        }
        foreach ($sallesExistantes as $id) {
            if (!in_array((int) $id, $sallesGardees, true)) {
                run('DELETE FROM Salles WHERE Id = ?', [$id]);
            }
        }
        db()->commit();
    } catch (Throwable $e) {
        db()->rollBack();
        throw $e;
    }
    $repondre(['salles' => restaurant_plan($caisseId)]);
}
