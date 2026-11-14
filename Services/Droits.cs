using System.Security.Claims;
using EasytransitCaisse.Data;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Services
{
    // Profils et droits d'accès. Les profils Admin et SuperAdmin ont tous les droits ; les autres
    // utilisateurs ont les droits de leur profil (créé par l'administrateur : Paramètres › Profils et droits).
    // Utilisateurs, profils et « Ma société » restent réservés aux administrateurs. Comme bootstrap.php en PHP.
    public static class Droits
    {
        public record Droit(string Code, string Libelle, string Detail);

        public static readonly (string Rubrique, Droit[] Droits)[] Catalogue =
        {
            ("Activité", new[] {
                new Droit("tableau_bord", "Tableaux de bord", "Tableau de bord général, laverie et restaurant-bar"),
                new Droit("caisses", "Caisses et journées", "Ouvrir une journée, encaisser, décaisser, clôturer"),
                new Droit("caisses_gerer", "Gérer les caisses", "Créer, modifier et supprimer les caisses"),
                new Droit("tiers", "Tiers", "Clients et fournisseurs, import et export") }),
            ("Analyse", new[] {
                new Droit("rapports", "Rapports de caisse", "Rapport des opérations, export Sage, rapport des tiers") }),
            ("Point de vente", new[] {
                new Droit("vendre", "Vendre", "Écran de vente, commandes de table, dépôts de linge"),
                new Droit("ventes", "Ventes", "Liste et détail des ventes, factures"),
                new Droit("cuisine", "Écran cuisine / bar", "Bons de préparation"),
                new Droit("stock", "Stock", "Entrées, transferts, inventaire"),
                new Droit("achats", "Achats", "Achats fournisseurs, consommations, produits d'entretien"),
                new Droit("rapports_pdv", "Rapports du point de vente", "Ventes, livraisons, dépôts de linge, achats"),
                new Droit("catalogue", "Catalogue", "Catégories, produits, combos, taxes, unités de vente"),
                new Droit("synchro", "Synchronisation", "Ventes faites hors ligne et postes") }),
            ("Paramètres", new[] {
                new Droit("parametres", "Motifs et modes de paiement", "Motifs des opérations, modes de paiement"),
                new Droit("config_pdv", "Configuration du point de vente", "Dépôts, livreurs, plans de salle") }),
            ("Droits particuliers", new[] {
                new Droit("prix", "Modifier les prix", "Changer le prix d'un article à l'écran de vente"),
                new Droit("plafond", "Dépasser le plafond de crédit", "Vente par compte au-delà du plafond d'un client") }),
        };

        public static readonly Dictionary<string, Droit> Tous = Catalogue.SelectMany(r => r.Droits).ToDictionary(d => d.Code);

        // Droits des utilisateurs sans profil (anciens comptes Caissier / Vendeur) et des profils créés avec une nouvelle société.
        public static readonly string[] ParDefaut = { "tableau_bord", "caisses", "caisses_gerer", "tiers", "rapports", "vendre", "ventes", "cuisine" };

        private static readonly Dictionary<string, string> Carte = new(StringComparer.OrdinalIgnoreCase)
        {
            ["Dashboard"] = "tableau_bord", ["TableauLaverie"] = "tableau_bord", ["TableauRestaurant"] = "tableau_bord",
            ["JourneeCaisse"] = "caisses", ["Client"] = "tiers", ["Rapport"] = "rapports", ["RapportTiers"] = "rapports",
            ["Pos"] = "vendre", ["Vente"] = "ventes", ["Facture"] = "ventes", ["Cuisine"] = "cuisine",
            ["Stock"] = "stock", ["Achat"] = "achats",
            ["PosRapport"] = "rapports_pdv", ["RapportLivraison"] = "rapports_pdv", ["RapportLinge"] = "rapports_pdv", ["RapportAchat"] = "rapports_pdv",
            ["Produit"] = "catalogue", ["Categorie"] = "catalogue", ["Combo"] = "catalogue", ["Taxe"] = "catalogue", ["Unite"] = "catalogue",
            ["Synchro"] = "synchro", ["Motif"] = "parametres", ["ModePaiement"] = "parametres",
            ["Depot"] = "config_pdv", ["Livreur"] = "config_pdv", ["Salle"] = "config_pdv",
            ["Utilisateur"] = "admin", ["Profil"] = "admin", ["Societe"] = "admin",
        };

        // Droit exigé par une page : code du droit, "" (toute personne connectée) ou "admin" (administrateurs seulement).
        public static string Page(string controleur, string action)
        {
            if (controleur.Equals("Caisse", StringComparison.OrdinalIgnoreCase))
                return action is "Create" or "Edit" or "Delete" ? "caisses_gerer" : "caisses";
            if (controleur.Equals("Synchro", StringComparison.OrdinalIgnoreCase) && action == "Rapport")
                return "";   // état du poste envoyé par tous les écrans de vente
            return Carte.TryGetValue(controleur, out var d) ? d : "";
        }

        // Première page permise après la connexion.
        public static readonly (string Droit, string Url)[] Accueils =
        {
            ("tableau_bord", "/Dashboard/Index"), ("vendre", "/Pos/Index"), ("caisses", "/Caisse/Index"), ("ventes", "/Vente/Index"),
            ("cuisine", "/Cuisine/Index"), ("tiers", "/Client/Index"), ("rapports", "/Rapport/Operations"), ("stock", "/Stock/Index"),
            ("achats", "/Achat/Index"), ("rapports_pdv", "/PosRapport/Index"), ("catalogue", "/Produit/Index"), ("synchro", "/Synchro/Index"),
            ("parametres", "/Motif/Index"), ("config_pdv", "/Depot/Index"),
        };

        public static List<string> Lire(string? droits) => (droits ?? "").Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).Where(Tous.ContainsKey).ToList();
    }

    // Droits de l'utilisateur connecté, relus une fois par requête (un changement fait par
    // l'administrateur s'applique sans reconnexion).
    public class DroitsUtilisateur
    {
        private readonly AppDbContext _context;
        private readonly IHttpContextAccessor _http;
        private bool _charge;
        private HashSet<string> _droits = new();

        public DroitsUtilisateur(AppDbContext context, IHttpContextAccessor http)
        {
            _context = context;
            _http = http;
        }

        public bool Existe { get; private set; } = true;
        public bool EstAdmin { get; private set; }
        public string Profil { get; private set; } = "";
        public bool PeutValider { get; private set; }

        public async Task ChargerAsync()
        {
            if (_charge) return;
            _charge = true;
            var user = _http.HttpContext?.User;
            if (user?.Identity?.IsAuthenticated != true || !int.TryParse(user.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id))
            {
                Existe = false;
                return;
            }
            var ligne = await (from u in _context.Utilisateurs.IgnoreQueryFilters().AsNoTracking()
                               where u.Id == id
                               join p in _context.Profils.IgnoreQueryFilters() on u.ProfilId equals p.Id into pp
                               from p in pp.DefaultIfEmpty()
                               select new { u.Profil, u.ProfilId, u.PeutValiderOperations, Droits = p != null ? p.Droits : null }).FirstOrDefaultAsync();
            if (ligne == null)
            {
                Existe = false;
                return;
            }
            Profil = ligne.Profil;
            PeutValider = ligne.PeutValiderOperations;
            EstAdmin = ligne.Profil is "Admin" or "SuperAdmin";
            _droits = EstAdmin ? Droits.Tous.Keys.ToHashSet()
                : (ligne.ProfilId == null ? Droits.ParDefaut.ToHashSet() : Droits.Lire(ligne.Droits).ToHashSet());
        }

        public bool Peut(string droit)
        {
            if (!_charge) ChargerAsync().GetAwaiter().GetResult();
            return EstAdmin || _droits.Contains(droit);
        }

        public string Accueil() => Droits.Accueils.FirstOrDefault(a => Peut(a.Droit)).Url ?? "/Auth/AucunAcces";
    }

    // Contrôle des droits sur chaque page ; profil ou droit de validation changé par l'administrateur :
    // cookie de connexion mis à jour ; compte supprimé : déconnexion.
    public class DroitsFilter : IAsyncActionFilter
    {
        private readonly DroitsUtilisateur _droits;

        public DroitsFilter(DroitsUtilisateur droits) => _droits = droits;

        public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
        {
            var http = context.HttpContext;
            var controleur = context.RouteData.Values["controller"]?.ToString() ?? "";
            if (http.User.Identity?.IsAuthenticated != true || controleur.Equals("Auth", StringComparison.OrdinalIgnoreCase))
            {
                await next();
                return;
            }
            await _droits.ChargerAsync();
            if (!_droits.Existe)
            {
                await http.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
                context.Result = new RedirectToActionResult("Login", "Auth", null);
                return;
            }
            var profilClaim = http.User.FindFirst(AppClaimTypes.Profil)?.Value;
            var valideClaim = http.User.FindFirst(AppClaimTypes.PeutValiderOperations)?.Value;
            if (profilClaim != _droits.Profil || valideClaim != _droits.PeutValider.ToString())
            {
                var claims = http.User.Claims.Where(c => c.Type != AppClaimTypes.Profil && c.Type != AppClaimTypes.PeutValiderOperations).ToList();
                claims.Add(new Claim(AppClaimTypes.Profil, _droits.Profil));
                claims.Add(new Claim(AppClaimTypes.PeutValiderOperations, _droits.PeutValider.ToString()));
                var principal = new ClaimsPrincipal(new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme));
                await http.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal);
                http.User = principal;
            }
            var droit = Droits.Page(controleur, context.RouteData.Values["action"]?.ToString() ?? "");
            if (droit != "" && !(droit == "admin" ? _droits.EstAdmin : _droits.Peut(droit)))
            {
                context.Result = new RedirectToActionResult("AccesRefuse", "Auth", null);
                return;
            }
            await next();
        }
    }
}
