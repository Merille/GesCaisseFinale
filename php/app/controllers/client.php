<?php
// Tiers (clients, fournisseurs, salariés...) : liste, fiche, suppression, export / import Excel.

require_once __DIR__ . '/../xlsx.php';

const CLIENT_CHAMPS = [
    'CodeClient', 'NomSociete', 'Adresse', 'Telephone', 'Email', 'Type', 'CompteGeneral',
    'NomContact', 'FonctionContact', 'TelephoneContact', 'EmailContact',
];

// Ordre des colonnes du fichier Excel (export et import), identique à la version .NET.
const CLIENT_COLONNES_EXCEL = [
    'CodeClient' => 'Code', 'NomSociete' => 'Société', 'NomContact' => 'Contact', 'Telephone' => 'Téléphone',
    'EmailContact' => 'EmailContact', 'Adresse' => 'Adresse', 'Email' => 'Email', 'Type' => 'Type',
    'FonctionContact' => 'FonctionContact', 'TelephoneContact' => 'TelephoneContact', 'CompteGeneral' => 'CompteGeneral',
];

/** Nombre de tiers affichés par page dans la liste. */
const CLIENTS_PAR_PAGE = 20;

/** Condition de recherche et ses paramètres (liste, comptage et export). */
function client_filtre(string $search, bool $etendue): array
{
    $sql = tf();
    $p = [];
    if ($search !== '') {
        $champs = $etendue ? CLIENT_CHAMPS : ['CodeClient', 'NomSociete', 'NomContact', 'Telephone', 'Type'];
        $conds = [];
        foreach ($champs as $i => $c) {
            $conds[] = "$c LIKE :s$i";
            $p["s$i"] = '%' . $search . '%';
        }
        $sql .= ' AND (' . implode(' OR ', $conds) . ')';
    }
    return [$sql, $p];
}

function client_recherche(string $search, bool $etendue = false): array
{
    [$where, $p] = client_filtre($search, $etendue);
    return q('SELECT * FROM Clients WHERE ' . $where . ' ORDER BY NomSociete', $p);
}

function client_index(): void
{
    $search = (string) get('search', '');
    [$where, $p] = client_filtre($search, false);
    $total = (int) qv('SELECT COUNT(*) FROM Clients WHERE ' . $where, $p);
    $pages = max(1, (int) ceil($total / CLIENTS_PAR_PAGE));
    $page = min(max(1, (int) get('page', 1)), $pages);
    $clients = q(
        'SELECT * FROM Clients WHERE ' . $where . ' ORDER BY NomSociete, Id LIMIT ' . CLIENTS_PAR_PAGE
        . ' OFFSET ' . (($page - 1) * CLIENTS_PAR_PAGE),
        $p
    );
    render('client/index', [
        'clients' => $clients,
        'search' => $search,
        'pagination' => [
            'page' => $page, 'pages' => $pages, 'total' => $total, 'parPage' => CLIENTS_PAR_PAGE,
            'route' => 'client/index', 'params' => ['search' => $search], 'libelle' => 'Tiers',
        ],
    ]);
}

function client_charger(int $id): array
{
    $c = q1('SELECT * FROM Clients WHERE Id = ? AND ' . tf(), [$id]);
    if (!$c) {
        not_found('Tiers introuvable.');
    }
    return $c;
}

function client_valeurs(): array
{
    $v = [];
    foreach (CLIENT_CHAMPS as $c) {
        $v[$c] = (string) post($c, '');
    }
    return $v;
}

function client_create(): void
{
    $client = [];
    if (is_post()) {
        $client = client_valeurs();
        if ($client['CodeClient'] === '' || $client['NomSociete'] === '') {
            flash('danger', 'Le code et le nom de la société sont obligatoires.');
        } elseif (qv('SELECT COUNT(*) FROM Clients WHERE CodeClient = ? AND ' . tf(), [$client['CodeClient']])) {
            flash('danger', "Le code « {$client['CodeClient']} » existe déjà.");
        } else {
            $cols = implode(', ', CLIENT_CHAMPS);
            $marques = implode(', ', array_fill(0, count(CLIENT_CHAMPS), '?'));
            run("INSERT INTO Clients ($cols, TenantId) VALUES ($marques, ?)", [...array_values($client), tenant_insert()]);
            flash('success', 'Tiers créé.');
            redirect('client/index');
        }
    }
    render('client/form', ['client' => $client, 'edition' => false]);
}

function client_edit(): void
{
    $existant = client_charger((int) get('id'));
    $client = $existant;
    if (is_post()) {
        $client = client_valeurs() + ['Id' => $existant['Id']];
        if ($client['CodeClient'] === '' || $client['NomSociete'] === '') {
            flash('danger', 'Le code et le nom de la société sont obligatoires.');
        } else {
            $set = implode(', ', array_map(fn($c) => "$c = ?", CLIENT_CHAMPS));
            run("UPDATE Clients SET $set WHERE Id = ?", [...array_values(client_valeurs()), $existant['Id']]);
            flash('success', 'Tiers modifié.');
            redirect('client/index');
        }
    }
    render('client/form', ['client' => $client, 'edition' => true]);
}

function client_delete(): void
{
    if (is_post()) {
        $client = client_charger((int) post('id'));
        $utilise = (int) qv('SELECT COUNT(*) FROM OperationsCaisses WHERE ClientId = ?', [$client['Id']])
                 + (int) qv('SELECT COUNT(*) FROM Factures WHERE ClientId = ?', [$client['Id']]);
        if ($utilise > 0) {
            flash('danger', 'Ce tiers est utilisé par des opérations ou des factures : il ne peut pas être supprimé.');
        } else {
            run('DELETE FROM Clients WHERE Id = ?', [$client['Id']]);
            flash('success', 'Tiers supprimé.');
        }
    }
    redirect('client/index');
}

function client_export(): void
{
    $lignes = [array_values(CLIENT_COLONNES_EXCEL)];
    foreach (client_recherche((string) get('search', ''), true) as $c) {
        $ligne = [];
        foreach (array_keys(CLIENT_COLONNES_EXCEL) as $champ) {
            $ligne[] = (string) ($c[$champ] ?? '');
        }
        $lignes[] = $ligne;
    }
    xlsx_envoyer('Clients_' . date('Ymd_Hi') . '.xlsx', ['Clients' => $lignes]);
}

function client_import(): void
{
    $fichier = $_FILES['file'] ?? null;
    if (!is_post() || !$fichier || $fichier['error'] !== UPLOAD_ERR_OK || $fichier['size'] === 0) {
        flash('danger', 'Veuillez sélectionner un fichier Excel.');
        redirect('client/index');
    }
    if (strtolower(pathinfo($fichier['name'], PATHINFO_EXTENSION)) !== 'xlsx') {
        flash('danger', 'Le fichier doit être au format .xlsx');
        redirect('client/index');
    }

    try {
        $lignes = xlsx_lire($fichier['tmp_name']);
    } catch (Throwable $e) {
        flash('danger', 'Fichier Excel illisible : ' . $e->getMessage());
        redirect('client/index');
    }

    $champs = array_keys(CLIENT_COLONNES_EXCEL);
    $erreurs = [];
    $importes = 0;
    $codesVus = [];
    foreach (array_slice($lignes, 1) as $ligne) {
        $n = $ligne['_ligne'];
        $client = [];
        foreach ($champs as $i => $champ) {
            $client[$champ] = (string) ($ligne[$i] ?? '');
        }
        if (implode('', $client) === '') {
            continue;
        }
        if ($client['CodeClient'] === '' || $client['NomSociete'] === '') {
            $erreurs[] = "Ligne $n : Code ou Société manquant.";
            continue;
        }
        if (isset($codesVus[$client['CodeClient']])
            || qv('SELECT COUNT(*) FROM Clients WHERE CodeClient = ? AND ' . tf(), [$client['CodeClient']])) {
            $erreurs[] = "Ligne $n : Code '{$client['CodeClient']}' déjà existant.";
            continue;
        }
        $codesVus[$client['CodeClient']] = true;
        $cols = implode(', ', $champs);
        $marques = implode(', ', array_fill(0, count($champs), '?'));
        run("INSERT INTO Clients ($cols, TenantId) VALUES ($marques, ?)", [...array_values($client), tenant_insert()]);
        $importes++;
    }

    flash('success', "$importes tiers importé(s) avec succès.");
    if ($erreurs) {
        flash('warning', implode("\n", $erreurs));
    }
    redirect('client/index');
}
