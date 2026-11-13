<?php
// Synchronisation du mode hors ligne (administrateurs) : état de la file de chaque poste (opérations
// faites sans connexion pas encore envoyées, refusées), ventes et dépôts de linge enregistrés hors
// ligne sur une période, vérification des ventes arrivées avec des écarts (une par une ou en groupe).
// Le rapport de chaque poste (synchro/rapport) est envoyé par hors-ligne.js quand le poste est connecté.

const SYNCHRO_ETATS = ['à vérifier' => 'À vérifier', 'vérifiées' => 'Vérifiées', 'sans écart' => 'Sans écart', 'toutes' => 'Toutes'];

/** Filtres : période (date de la vente, 30 derniers jours par défaut) et état des ventes. */
function synchro_filtres(): array
{
    $d = fn($v) => ($v && DateTime::createFromFormat('!Y-m-d', (string) $v)) ? (string) $v : null;
    $etat = (string) get('etat', 'à vérifier');
    $f = [
        'du' => $d(get('du')) ?? date('Y-m-d', strtotime('-30 days')),
        'au' => $d(get('au')) ?? date('Y-m-d'),
        'etat' => array_key_exists($etat, SYNCHRO_ETATS) ? $etat : 'à vérifier',
    ];
    if ($f['au'] < $f['du']) {
        [$f['du'], $f['au']] = [$f['au'], $f['du']];
    }
    return $f;
}

/** État d'un poste : à jour, en attente d'envoi, refus, ou sans nouvelles depuis plus d'une heure. */
function synchro_etat_poste(array $p): array
{
    $silence = time() - strtotime($p['DernierRapport']);
    if ((int) $p['Refusees'] > 0) {
        return ['Refus', 'bg-danger'];
    }
    if ((int) $p['EnAttente'] > 0) {
        return $silence > 3600 ? ['Sans nouvelles', 'bg-dark'] : ["En attente d'envoi", 'bg-warning text-dark'];
    }
    return ['À jour', 'bg-success'];
}

/** « il y a 5 min », « il y a 3 h », « il y a 2 j ». */
function synchro_depuis(?string $date): string
{
    if (!$date) {
        return '';
    }
    $s = max(0, time() - strtotime($date));
    return $s < 60 ? "à l'instant" : ($s < 3600 ? 'il y a ' . intdiv($s, 60) . ' min' : ($s < 86400 ? 'il y a ' . intdiv($s, 3600) . ' h' : 'il y a ' . intdiv($s, 86400) . ' j'));
}

function synchro_json(array $reponse): never
{
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($reponse, JSON_UNESCAPED_UNICODE);
    exit;
}

function synchro_index(): void
{
    require_admin();
    $f = synchro_filtres();
    // Postes vus depuis 30 jours, ceux qui ont des envois en attente d'abord.
    $postes = q('SELECT p.*, u.NomComplet AS Utilisateur FROM PostesHorsLigne p LEFT JOIN Utilisateurs u ON u.Id = p.UtilisateurId
                 WHERE ' . tf('p') . ' AND (p.EnAttente > 0 OR p.DernierRapport >= ?)
                 ORDER BY p.EnAttente > 0 DESC, p.Refusees DESC, p.DernierRapport DESC', [date('Y-m-d H:i:s', strtotime('-30 days'))]);
    foreach ($postes as &$p) {
        $p['Elements'] = json_decode((string) $p['Detail'], true) ?: [];
        [$p['Etat'], $p['Badge']] = synchro_etat_poste($p);
    }
    unset($p);

    $sql = 'SELECT cmd.Id, cmd.Numero, cmd.NumeroHorsLigne, cmd.DateCommande, cmd.TotalTTC, cmd.Statut, cmd.AlerteHorsLigne, cmd.AlerteHorsLigneVue,
                   c.ChkCode, u.NomComplet AS Vendeur
            FROM CommandesPos cmd JOIN JourneesCaisses j ON j.Id = cmd.JourneeCaisseId JOIN Caisses c ON c.ID = j.CaisseId
            LEFT JOIN Utilisateurs u ON u.Id = cmd.UtilisateurId
            WHERE cmd.NumeroHorsLigne IS NOT NULL AND ' . tf('cmd');
    $p = [];
    // « À vérifier » : toutes les ventes en attente de vérification, quelle que soit leur date.
    if ($f['etat'] === 'à vérifier') {
        $sql .= ' AND cmd.AlerteHorsLigne IS NOT NULL AND cmd.AlerteHorsLigneVue IS NULL';
    } else {
        $sql .= ' AND cmd.DateCommande >= ? AND cmd.DateCommande < DATE_ADD(?, INTERVAL 1 DAY)';
        $p = [$f['du'], $f['au']];
        if ($f['etat'] === 'vérifiées') {
            $sql .= ' AND cmd.AlerteHorsLigneVue IS NOT NULL';
        } elseif ($f['etat'] === 'sans écart') {
            $sql .= ' AND cmd.AlerteHorsLigne IS NULL';
        }
    }
    $ventes = q($sql . ' ORDER BY cmd.DateCommande DESC, cmd.Id DESC LIMIT 500', $p);

    $periode = q1("SELECT COUNT(*) AS Nombre, COALESCE(SUM(CASE WHEN Statut <> 'Annulée' THEN TotalTTC ELSE 0 END), 0) AS Montant
                   FROM CommandesPos WHERE NumeroHorsLigne IS NOT NULL AND DateCommande >= ? AND DateCommande < DATE_ADD(?, INTERVAL 1 DAY) AND " . tf(),
                  [$f['du'], $f['au']]);
    $depots = laverie_actif() ? q('SELECT d.*, c.ChkCode FROM DepotsLinge d LEFT JOIN Caisses c ON c.ID = d.CaisseId
                                   WHERE d.NumeroHorsLigne IS NOT NULL AND d.DateDepot >= ? AND d.DateDepot < DATE_ADD(?, INTERVAL 1 DAY) AND ' . tf('d') . '
                                   ORDER BY d.DateDepot DESC LIMIT 300', [$f['du'], $f['au']]) : null;
    render('synchro/index', [
        'f' => $f,
        'postes' => $postes,
        'ventes' => $ventes,
        'depots' => $depots,
        'kpi' => [
            'postes' => count($postes),
            'postesEnAttente' => count(array_filter($postes, fn($x) => (int) $x['EnAttente'] > 0)),
            'enAttente' => array_sum(array_map(fn($x) => (int) $x['EnAttente'], $postes)),
            'montantEnAttente' => array_sum(array_map(fn($x) => (float) $x['MontantEnAttente'], $postes)),
            'ventes' => (int) $periode['Nombre'],
            'montant' => (float) $periode['Montant'],
            'aVerifier' => (int) qv('SELECT COUNT(*) FROM CommandesPos WHERE AlerteHorsLigne IS NOT NULL AND AlerteHorsLigneVue IS NULL AND ' . tf()),
        ],
    ]);
}

/** Ventes cochées marquées vérifiées. */
function synchro_verifier(): void
{
    require_admin();
    $ids = array_values(array_filter(array_map('intval', (array) ($_POST['ids'] ?? []))));
    $n = 0;
    if ($ids) {
        $marques = implode(',', array_fill(0, count($ids), '?'));
        $st = db()->prepare("UPDATE CommandesPos SET AlerteHorsLigneVue = ? WHERE Id IN ($marques) AND AlerteHorsLigne IS NOT NULL AND AlerteHorsLigneVue IS NULL AND " . tf());
        $st->execute(array_merge([date('Y-m-d H:i:s')], $ids));
        $n = $st->rowCount();
    }
    flash($n ? 'success' : 'warning', $n ? $n . ' vente' . ($n > 1 ? 's' : '') . ' marquée' . ($n > 1 ? 's' : '') . ' vérifiée' . ($n > 1 ? 's' : '') . '.' : 'Aucune vente à vérifier cochée.');
    redirect('synchro/index', array_filter(['du' => post('du'), 'au' => post('au'), 'etat' => post('etat')], fn($v) => $v !== null));
}

/** Poste qui ne sert plus : retiré de la liste (il réapparaît s'il envoie un nouveau rapport). */
function synchro_oublier(): void
{
    require_admin();
    run('DELETE FROM PostesHorsLigne WHERE Id = ? AND ' . tf(), [(int) post('id')]);
    flash('success', 'Poste retiré de la liste.');
    redirect('synchro/index');
}

/**
 * Rapport d'un poste (JSON, champ « rapport ») : état de sa file hors ligne. Envoyé par hors-ligne.js
 * à l'ouverture des pages, après chaque envoi et toutes les 5 minutes, quand le poste est connecté.
 */
function synchro_rapport(): void
{
    $r = json_decode((string) ($_POST['rapport'] ?? ''), true);
    $code = is_array($r) ? substr(preg_replace('/[^A-Z0-9]/', '', strtoupper((string) ($r['poste'] ?? ''))), 0, 10) : '';
    $tenant = tenant_id();
    if ($code === '' || $tenant === 0) {
        synchro_json(['ok' => false]);
    }
    $date = function ($v): ?string {
        $t = is_string($v) ? strtotime($v) : false;
        return $t ? date('Y-m-d H:i:s', min($t, time())) : null;
    };
    $elements = [];
    foreach (array_slice(array_filter((array) ($r['elements'] ?? []), 'is_array'), 0, 50) as $e) {
        $elements[] = [
            'numero' => mb_substr((string) ($e['numero'] ?? ''), 0, 30), 'type' => mb_substr((string) ($e['type'] ?? ''), 0, 10),
            'libelle' => mb_substr((string) ($e['libelle'] ?? ''), 0, 120), 'montant' => isset($e['montant']) ? round((float) $e['montant']) : null,
            'cree' => $date($e['cree'] ?? null), 'erreur' => mb_substr((string) ($e['erreur'] ?? ''), 0, 200),
        ];
    }
    $valeurs = [
        user()['id'], mb_substr((string) ($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 150),
        max(0, (int) ($r['enAttente'] ?? 0)), max(0, (int) ($r['refusees'] ?? 0)), max(0, round((float) ($r['montant'] ?? 0), 2)),
        $date($r['plusAncien'] ?? null), $date($r['dernierEnvoi'] ?? null), json_encode($elements, JSON_UNESCAPED_UNICODE),
    ];
    if (q1('SELECT Id FROM PostesHorsLigne WHERE TenantId = ? AND Code = ?', [$tenant, $code])) {
        run('UPDATE PostesHorsLigne SET UtilisateurId = ?, Navigateur = ?, EnAttente = ?, Refusees = ?, MontantEnAttente = ?, PlusAncien = ?,
                DernierEnvoi = COALESCE(?, DernierEnvoi), Detail = ?, DernierRapport = ? WHERE TenantId = ? AND Code = ?', array_merge($valeurs, [date('Y-m-d H:i:s'), $tenant, $code]));
    } else {
        run('INSERT INTO PostesHorsLigne (UtilisateurId, Navigateur, EnAttente, Refusees, MontantEnAttente, PlusAncien, DernierEnvoi, Detail, DernierRapport, TenantId, Code)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', array_merge($valeurs, [date('Y-m-d H:i:s'), $tenant, $code]));
    }
    synchro_json(['ok' => true]);
}
