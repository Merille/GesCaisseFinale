<?php
// Gabarit commun : barre latérale regroupée et repliable + barre du haut.
// Variables : $contenu (HTML de la page), $titre (facultatif), $module (route courante).
$u = user();
$module = explode('/', (string) ($_GET['r'] ?? 'dashboard/index'))[0];
$titrePage = $titre ?? 'GesCaisse';

$societesDisponibles = [];
$societeConsultee = null;
if (is_super_admin()) {
    $societesDisponibles = q('SELECT Id, Nom FROM Tenants ORDER BY Nom');
    foreach ($societesDisponibles as $s) {
        if ((int) $s['Id'] === tenant_id()) {
            $societeConsultee = $s['Nom'];
        }
    }
}

$nbJourneesOuvertes = (int) qv("SELECT COUNT(*) FROM JourneesCaisses WHERE Statut = 'Ouverte' AND " . tf());

$rubrique = match ($module) {
    'dashboard', 'caisse', 'journee', 'client', 'facture' => 'Activité',
    'rapport' => 'Analyse',
    'utilisateur', 'motif', 'modepaiement', 'tenant' => 'Administration',
    default => null,
};

$initiales = mb_substr((string) $u['nom'], 0, 2);
$libelleProfil = is_super_admin() ? 'Super administrateur' : $u['profil'];

$lien = function (string $route, string $mod, string $icone, string $libelle, string $extra = '') use ($module): string {
    $actif = in_array($module, explode('|', $mod), true) ? ' active' : '';
    return '<a class="sb-link' . $actif . '" href="' . h(url($route)) . '" title="' . h($libelle) . '">'
        . '<i class="fas ' . $icone . '"></i><span class="sb-label">' . h($libelle) . '</span>' . $extra . '</a>';
};
$badge = $nbJourneesOuvertes > 0
    ? '<span class="sb-badge">' . $nbJourneesOuvertes . ' ouverte' . ($nbJourneesOuvertes > 1 ? 's' : '') . '</span>'
    : '';
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title><?= h($titrePage) ?> - GesCaisse</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css" rel="stylesheet">
    <link rel="stylesheet" href="assets/css/theme.css">
    <link rel="stylesheet" href="assets/css/layout.css">
    <link rel="stylesheet" href="assets/css/print.css">
    <link rel="stylesheet" href="assets/css/app.css">
    <script>
        // Applique l'état replié du menu avant l'affichage (pas de saut visuel).
        try { if (localStorage.getItem('sidebarReplie') === '1') document.documentElement.classList.add('sidebar-replie'); } catch (e) { }
    </script>
</head>
<body>

<aside class="sidebar">

    <div class="sb-brand">
        <span class="sb-logo">GC</span>
        <div class="sb-brand-text">
            <strong>GesCaisse</strong>
            <small>par M-ITECH AFRICA</small>
        </div>
    </div>

    <?php if (is_super_admin()): ?>
        <form class="sb-societe" method="post" action="<?= h(url('tenant/consulter')) ?>">
            <?= csrf_field() ?>
            <input type="hidden" name="retour" value="<?= h($_SERVER['REQUEST_URI'] ?? '') ?>">
            <label for="sbSociete">Société consultée</label>
            <select id="sbSociete" name="tenantId" class="form-select form-select-sm" onchange="this.form.submit()">
                <option value="">Toutes les sociétés</option>
                <?php foreach ($societesDisponibles as $s): ?>
                    <option value="<?= (int) $s['Id'] ?>" <?= (int) $s['Id'] === tenant_id() ? 'selected' : '' ?>><?= h($s['Nom']) ?></option>
                <?php endforeach; ?>
            </select>
        </form>
    <?php elseif (!empty($u['tenantNom'])): ?>
        <div class="sb-societe">
            <label>Société</label>
            <div class="sb-societe-nom" title="<?= h($u['tenantNom']) ?>"><?= h($u['tenantNom']) ?></div>
        </div>
    <?php endif; ?>

    <nav class="sb-nav" aria-label="Menu principal">
        <div class="sb-section">
            <div class="sb-section-title">Activité</div>
            <?= $lien('dashboard/index', 'dashboard', 'fa-house', 'Tableau de bord') ?>
            <?= $lien('caisse/index', 'caisse|journee', 'fa-cash-register', 'Caisses', $badge) ?>
            <?= $lien('client/index', 'client', 'fa-address-book', 'Tiers') ?>
            <?= $lien('facture/index', 'facture', 'fa-file-invoice', 'Factures') ?>
        </div>
        <div class="sb-section">
            <div class="sb-section-title">Analyse</div>
            <?= $lien('rapport/operations', 'rapport', 'fa-chart-column', 'Rapports') ?>
        </div>
        <div class="sb-section">
            <div class="sb-section-title">Administration</div>
            <?= $lien('utilisateur/index', 'utilisateur', 'fa-user-shield', 'Utilisateurs') ?>
            <?= $lien('motif/index', 'motif', 'fa-list-ul', 'Motifs') ?>
            <?= $lien('modepaiement/index', 'modepaiement', 'fa-money-check-dollar', 'Modes de paiement') ?>
            <?php if (is_super_admin()): ?>
                <?= $lien('tenant/index', 'tenant', 'fa-building', 'Sociétés') ?>
            <?php endif; ?>
        </div>
    </nav>

    <div class="sb-footer">
        <div class="sb-user">
            <span class="sb-avatar" title="<?= h($u['nom']) ?>"><?= h($initiales) ?></span>
            <div class="sb-user-text">
                <strong><?= h($u['nom']) ?></strong>
                <small><?= h($libelleProfil) ?></small>
            </div>
            <a class="sb-logout" href="<?= h(url('auth/logout')) ?>" title="Se déconnecter" aria-label="Se déconnecter">
                <i class="fas fa-right-from-bracket"></i>
            </a>
        </div>
        <button type="button" class="sb-toggle" onclick="basculerMenu()" aria-label="Réduire ou agrandir le menu">
            <i class="fas fa-angles-left" id="sbToggleIcone"></i>
            <span class="sb-toggle-texte">Réduire le menu</span>
        </button>
    </div>
</aside>

<div class="content">
    <header class="topbar">
        <div class="topbar-titre">
            <?php if ($rubrique): ?>
                <div class="topbar-fil"><?= h($rubrique) ?> › <strong><?= h($titrePage) ?></strong></div>
            <?php endif; ?>
            <h1><?= h($titrePage) ?></h1>
        </div>
        <?php if (is_super_admin() && $societeConsultee): ?>
            <div class="topbar-societe">Consultation : <strong><?= h($societeConsultee) ?></strong></div>
        <?php endif; ?>
        <span class="topbar-icone" title="Notifications"><i class="fas fa-bell"></i></span>
    </header>

    <div class="page-content">
        <?php foreach (flashes() as [$type, $message]): ?>
            <div class="alert alert-<?= h($type) ?> alert-dismissible fade show">
                <?= nl2br(h($message)) ?>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Fermer"></button>
            </div>
        <?php endforeach; ?>

        <?= $contenu ?>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
    // Menu latéral replié / déplié, mémorisé dans le navigateur.
    function basculerMenu() {
        const replie = document.documentElement.classList.toggle('sidebar-replie');
        try { localStorage.setItem('sidebarReplie', replie ? '1' : '0'); } catch (e) { }
        majIconeMenu();
    }
    function majIconeMenu() {
        const icone = document.getElementById('sbToggleIcone');
        if (!icone) return;
        const replie = document.documentElement.classList.contains('sidebar-replie');
        icone.className = 'fas ' + (replie ? 'fa-angles-right' : 'fa-angles-left');
    }
    majIconeMenu();
</script>
<?= $scripts ?? '' ?>
</body>
</html>
