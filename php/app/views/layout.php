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
    'dashboard', 'tableaulaverie', 'tableaurestaurant', 'caisse', 'journee', 'client', 'facture' => 'Activité',
    'rapport', 'rapporttiers' => 'Analyse',
    'pos', 'vente', 'stock', 'posrapport', 'rapportlivraison', 'rapportlinge', 'rapportachat', 'achat', 'cuisine', 'synchro' => 'Point de vente',
    'salle' => 'Activité',
    'produit', 'categorie', 'combo' => 'Configuration',
    'utilisateur', 'profil', 'motif', 'modepaiement', 'taxe', 'unite', 'depot', 'livreur', 'societe' => 'Paramètres',
    'tenant' => 'Administration',
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
    <link rel="stylesheet" href="<?= asset('assets/vendor/bootstrap/bootstrap.min.css') ?>">
    <link rel="stylesheet" href="<?= asset('assets/vendor/fontawesome/css/all.min.css') ?>">
    <link rel="stylesheet" href="<?= asset('assets/css/dataTables.bootstrap5.min.css') ?>">
    <link rel="stylesheet" href="<?= asset('assets/css/theme.css') ?>">
    <link rel="stylesheet" href="<?= asset('assets/css/layout.css') ?>">
    <link rel="manifest" href="manifest.json">
    <meta name="theme-color" content="#1b5e84">
    <link rel="apple-touch-icon" href="assets/icones/icone-192.png">
    <link rel="stylesheet" href="<?= asset('assets/css/print.css') ?>">
    <link rel="stylesheet" href="<?= asset('assets/css/app.css') ?>">
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
            <?php if (peut('tableau_bord')): ?><?= $lien('dashboard/index', 'dashboard', 'fa-house', 'Tableau de bord') ?><?php endif; ?>
            <?php // Laverie : tableau de bord en tuiles (page à part ; le tableau de bord général ne change pas). ?>
            <?php if (peut('tableau_bord') && laverie_actif() && module_pos_actif()): ?>
                <?= $lien('tableaulaverie/index', 'tableaulaverie', 'fa-shirt', 'Tableau de bord laverie') ?>
            <?php endif; ?>
            <?php // Restaurant-bar : tableau de bord en tuiles (page à part, comme la laverie). ?>
            <?php if (peut('tableau_bord') && restaurant_actif() && module_pos_actif()): ?>
                <?= $lien('tableaurestaurant/index', 'tableaurestaurant', 'fa-utensils', 'Tableau resto-bar') ?>
            <?php endif; ?>
            <?php if (peut('caisses') || peut('journees')): ?><?= $lien('caisse/index', 'caisse|journee', 'fa-cash-register', 'Caisses', $badge) ?><?php endif; ?>
            <?php if (peut('tiers')): ?><?= $lien('client/index', 'client', 'fa-address-book', 'Tiers') ?><?php endif; ?>
            <?php // Factures : module masqué, comme dans la version .NET (pages toujours accessibles). ?>
        </div>
        <?php if (peut('rapports')): ?>
        <div class="sb-section">
            <div class="sb-section-title">Analyse</div>
            <?= $lien('rapport/operations', 'rapport', 'fa-chart-column', 'Rapports') ?>
            <?= $lien('rapporttiers/index', 'rapporttiers', 'fa-users-viewfinder', 'Rapport des tiers') ?>
        </div>
        <?php endif; ?>
        <?php if (module_pos_actif() && array_filter(['vendre', 'ventes', 'cuisine', 'achats', 'stock', 'rapports_pdv', 'catalogue', 'synchro'], 'peut')): ?>
        <div class="sb-section">
            <div class="sb-section-title">Point de vente</div>
            <?php if (peut('vendre')): ?><?= $lien('pos/index', 'pos', 'fa-store', 'Vendre') ?><?php endif; ?>
            <?php if (peut('ventes')): ?><?= $lien('vente/index', 'vente', 'fa-receipt', 'Ventes') ?><?php endif; ?>
            <?php if (peut('cuisine') && restaurant_actif()): ?>
                <?= $lien('cuisine/index', 'cuisine', 'fa-fire-burner', 'Écran cuisine / bar') ?>
            <?php endif; ?>
                <?php if (peut('achats') && laverie_actif()): ?>
                    <?= $lien('achat/index', 'achat', 'fa-cart-flatbed', 'Achats') ?>
                <?php endif; ?>
                <?php if (peut('stock')): ?><?= $lien('stock/index', 'stock', 'fa-warehouse', 'Stock') ?><?php endif; ?>
                <?php if (peut('rapports_pdv')): ?>
                <?php // Rapports du point de vente, regroupés (titre complet en infobulle). ?>
                <?php $lienRapport = fn(string $route, string $mod, string $icone, string $libelle, string $titre)
                    => str_replace('title="' . h($libelle) . '"', 'title="' . h($titre) . '"', $lien($route, $mod, $icone, $libelle)); ?>
                <?php $rapportsActif = in_array($module, ['posrapport', 'rapportlivraison', 'rapportlinge', 'rapportachat'], true); ?>
                <button type="button" class="sb-link sb-parent <?= $rapportsActif ? 'parent-actif' : '' ?>" title="Rapports"
                        aria-expanded="<?= $rapportsActif ? 'true' : 'false' ?>" aria-controls="sbRapportsPos" onclick="basculerSousMenu(this)">
                    <i class="fas fa-chart-line"></i><span class="sb-label">Rapports</span><i class="fas fa-chevron-down sb-chevron"></i>
                </button>
                <div class="sb-sub <?= $rapportsActif ? 'open' : '' ?>" id="sbRapportsPos">
                    <?= $lienRapport('posrapport/index', 'posrapport', 'fa-chart-pie', 'Ventes', 'Rapports ventes') ?>
                    <?= $lienRapport('rapportlivraison/index', 'rapportlivraison', 'fa-truck-fast', 'Livraisons', 'Rapport des livraisons') ?>
                    <?php if (laverie_actif()): ?>
                        <?= $lienRapport('rapportlinge/index', 'rapportlinge', 'fa-shirt', 'Dépôts de linge', 'Rapport des dépôts de linge') ?>
                        <?= $lienRapport('rapportachat/index', 'rapportachat', 'fa-chart-bar', 'Achats', 'Rapport des achats et consommations') ?>
                    <?php endif; ?>
                </div>
                <?php endif; ?>
                <?php if (peut('catalogue')): ?>
                <?php $configurationActif = in_array($module, ['categorie', 'produit', 'combo'], true); ?>
                <button type="button" class="sb-link sb-parent <?= $configurationActif ? 'parent-actif' : '' ?>" title="Configuration"
                        aria-expanded="<?= $configurationActif ? 'true' : 'false' ?>" aria-controls="sbConfiguration" onclick="basculerSousMenu(this)">
                    <i class="fas fa-sliders"></i><span class="sb-label">Configuration</span><i class="fas fa-chevron-down sb-chevron"></i>
                </button>
                <div class="sb-sub <?= $configurationActif ? 'open' : '' ?>" id="sbConfiguration">
                    <?= $lien('categorie/index', 'categorie', 'fa-tags', 'Catégories') ?>
                    <?= $lien('produit/index', 'produit', 'fa-box-open', 'Produits') ?>
                    <?= $lien('combo/index', 'combo', 'fa-layer-group', 'Combos') ?>
                </div>
                <?php endif; ?>
                <?php if (peut('synchro')): ?>
                <?php // Synchronisation du mode hors ligne : pastille = postes qui ont des opérations à envoyer. ?>
                <?php $postesEnAttente = (int) qv('SELECT COUNT(*) FROM PostesHorsLigne WHERE EnAttente > 0 AND ' . tf()); ?>
                <?= $lien('synchro/index', 'synchro', 'fa-arrows-rotate', 'Synchronisation',
                    $postesEnAttente ? '<span class="sb-badge" title="Postes avec des opérations à envoyer">' . $postesEnAttente . '</span>' : '') ?>
                <?php endif; ?>
        </div>
        <?php endif; ?>
        <?php $configPdv = peut('config_pdv') && module_pos_actif(); $catalogueParam = peut('catalogue') && module_pos_actif(); ?>
        <?php if (is_admin() || peut('parametres') || $configPdv || $catalogueParam): ?>
        <div class="sb-section">
            <div class="sb-section-title">Administration</div>
            <?php $parametresActif = in_array($module, ['utilisateur', 'profil', 'motif', 'modepaiement', 'taxe', 'unite', 'depot', 'livreur', 'societe'], true); ?>
            <button type="button" class="sb-link sb-parent <?= $parametresActif ? 'parent-actif' : '' ?>" title="Paramètres"
                    aria-expanded="<?= $parametresActif ? 'true' : 'false' ?>" aria-controls="sbParametres" onclick="basculerSousMenu(this)">
                <i class="fas fa-gear"></i><span class="sb-label">Paramètres</span><i class="fas fa-chevron-down sb-chevron"></i>
            </button>
            <div class="sb-sub <?= $parametresActif ? 'open' : '' ?>" id="sbParametres">
                <?php if (is_admin() && tenant_id() > 0): ?>
                    <?= $lien('societe/index', 'societe', 'fa-building-circle-check', 'Ma société') ?>
                <?php endif; ?>
                <?php if (is_admin()): ?>
                    <?= $lien('utilisateur/index', 'utilisateur', 'fa-user-shield', 'Utilisateurs') ?>
                    <?= $lien('profil/index', 'profil', 'fa-user-lock', 'Profils et droits') ?>
                <?php endif; ?>
                <?php if (peut('parametres')): ?>
                    <?= $lien('motif/index', 'motif', 'fa-list-ul', 'Motifs') ?>
                    <?= $lien('modepaiement/index', 'modepaiement', 'fa-money-check-dollar', 'Modes de paiement') ?>
                <?php endif; ?>
                <?php if ($catalogueParam): ?>
                    <?= $lien('taxe/index', 'taxe', 'fa-percent', 'Taxes') ?>
                    <?= $lien('unite/index', 'unite', 'fa-scale-balanced', 'Unités de vente') ?>
                <?php endif; ?>
                <?php if ($configPdv): ?>
                    <?= $lien('depot/index', 'depot', 'fa-warehouse', 'Dépôts') ?>
                    <?= $lien('livreur/index', 'livreur', 'fa-motorcycle', 'Livreurs') ?>
                <?php endif; ?>
            </div>
            <?php if (is_super_admin()): ?>
                <?= $lien('tenant/index', 'tenant', 'fa-building', 'Sociétés') ?>
            <?php endif; ?>
        </div>
        <?php endif; ?>
    </nav>

    <div class="sb-footer">
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
        <?php $notifications = notifications(); $nbNotifications = array_sum(array_column($notifications, 'n')); ?>
        <span class="gc-connexion"></span>
        <button type="button" class="topbar-icone d-none" id="gcInstaller" title="Installer l'application sur ce poste" aria-label="Installer l'application"><i class="fas fa-download"></i></button>
        <div class="dropdown">
            <button type="button" class="topbar-icone<?= $nbNotifications ? ' topbar-alerte' : '' ?>" data-bs-toggle="dropdown" aria-expanded="false" id="cloche"
                    title="<?= $nbNotifications ? $nbNotifications . ' notification' . ($nbNotifications > 1 ? 's' : '') : 'Aucune notification' ?>" aria-label="Notifications">
                <i class="fas fa-bell"></i><?php if ($nbNotifications): ?><span class="topbar-pastille"><?= $nbNotifications > 99 ? '99+' : $nbNotifications ?></span><?php endif; ?>
            </button>
            <div class="dropdown-menu dropdown-menu-end shadow cloche-menu" aria-labelledby="cloche">
                <div class="cloche-titre">Notifications</div>
                <?php foreach ($notifications as $no): ?>
                    <a class="dropdown-item cloche-item" href="<?= h($no['url']) ?>">
                        <span class="cloche-icone" style="background: <?= h($no['couleur']) ?>"><i class="fas <?= h($no['icone']) ?>"></i></span>
                        <span class="flex-grow-1"><?= h($no['texte']) ?></span>
                        <i class="fas fa-chevron-right text-muted small"></i>
                    </a>
                <?php endforeach; ?>
                <?php if (!$notifications): ?>
                    <div class="cloche-vide"><i class="fas fa-circle-check text-success"></i> Rien à traiter pour le moment.</div>
                <?php endif; ?>
            </div>
        </div>
        <div class="topbar-user dropdown">
            <?php // Menu de l'utilisateur (comme Odoo) : installer l'application sur le poste, se déconnecter. ?>
            <button type="button" class="topbar-user-bouton" data-bs-toggle="dropdown" aria-expanded="false" title="Menu de <?= h($u['nom']) ?>">
                <span class="topbar-avatar"><?= h($initiales) ?></span>
                <span class="topbar-user-text">
                    <strong><?= h($u['nom']) ?></strong>
                    <small><?= h($libelleProfil) ?></small>
                </span>
                <i class="fas fa-chevron-down topbar-user-chevron"></i>
            </button>
            <div class="dropdown-menu dropdown-menu-end shadow">
                <button type="button" class="dropdown-item" data-gc-installer><i class="fas fa-desktop fa-fw me-2"></i><span>Installer l'application</span></button>
                <div class="dropdown-divider"></div>
                <a class="dropdown-item" href="<?= h(url('auth/logout')) ?>"><i class="fas fa-right-from-bracket fa-fw me-2"></i>Se déconnecter</a>
            </div>
            <a class="topbar-logout" href="<?= h(url('auth/logout')) ?>" title="Se déconnecter" aria-label="Se déconnecter">
                <i class="fas fa-right-from-bracket"></i>
            </a>
        </div>
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

<?php // Bibliothèques servies par l'application (aucune dépendance à Internet) : assets/vendor. ?>
<script src="<?= asset('assets/vendor/bootstrap/bootstrap.bundle.min.js') ?>"></script>
<script src="<?= asset('assets/vendor/chartjs/chart.umd.min.js') ?>"></script>
<script src="<?= asset('assets/vendor/jquery/jquery-3.7.0.min.js') ?>"></script>
<script src="<?= asset('assets/vendor/datatables/jquery.dataTables.min.js') ?>"></script>
<script src="<?= asset('assets/vendor/datatables/dataTables.bootstrap5.min.js') ?>"></script>
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

    // Ouvre / ferme un sous-menu (ex. « Paramètres »).
    function basculerSousMenu(bouton) {
        const sous = document.getElementById(bouton.getAttribute('aria-controls'));
        const ouvert = sous.classList.toggle('open');
        bouton.setAttribute('aria-expanded', ouvert ? 'true' : 'false');
    }

    // Fenêtre de saisie ouverte : curseur dans le premier champ.
    document.addEventListener('shown.bs.modal', function (e) {
        const champ = e.target.querySelector('input:not([type=hidden]):not([type=checkbox]), select, textarea');
        if (champ) champ.focus();
    });
</script>
<script src="<?= asset('assets/js/vues.js') ?>"></script>
<script src="<?= asset('assets/js/listes.js') ?>"></script>
<script>window.GC_DROITS = <?= json_encode(droits_page_js(), JSON_UNESCAPED_UNICODE | JSON_HEX_TAG) ?>;</script>
<script src="<?= asset('assets/js/droits.js') ?>"></script>
<script src="<?= asset('assets/js/hors-ligne.js') ?>" data-sw="sw.js"<?= module_pos_actif() ? ' data-rapport="' . h(url('synchro/rapport')) . '" data-jeton="' . h(url('pos/jeton')) . '"' : '' ?>></script>
<?= $scripts ?? '' ?>
</body>
</html>
