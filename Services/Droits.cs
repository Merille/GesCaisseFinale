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
        // Droit d'une rubrique : opérations possibles (c consulter, a ajouter / créer, m modifier, s supprimer) et leur description.
        public record Droit(string Code, string Libelle, string Detail, Dictionary<string, string> Ops);

        // Case sans action pour l'instant dans ce module (cochable, sans effet tant qu'aucune action de ce type n'existe).
        public const string SansAction = "Aucune action de ce type dans ce module pour l'instant";

        private static Dictionary<string, string> O(params (string Op, string Texte)[] ops) => ops.ToDictionary(o => o.Op, o => o.Texte);

        public static readonly (string Rubrique, Droit[] Droits)[] Catalogue =
        {
            ("Activité", new[] {
                new Droit("tableau_bord", "Tableaux de bord", "Tableau de bord général, laverie et restaurant-bar", O(("c", "Consulter les tableaux de bord"))),
                new Droit("caisses", "Caisses", "Liste et paramétrage des caisses", O(("c", "Voir les caisses"), ("a", "Créer une caisse"), ("m", "Modifier une caisse"), ("s", "Supprimer une caisse"))),
                new Droit("journees", "Journées et opérations", "Journées de caisse, encaissements et décaissements", O(("c", "Voir les journées et leurs opérations"), ("a", "Ouvrir une journée, encaisser, décaisser, régler un client"), ("m", "Valider ou rejeter les opérations, clôturer"), ("s", "Supprimer une opération"))),
                new Droit("tiers", "Tiers", "Clients et fournisseurs", O(("c", "Voir et exporter les tiers"), ("a", "Créer et importer des tiers"), ("m", "Modifier un tiers"), ("s", "Supprimer un tiers"))) }),
            ("Analyse", new[] {
                new Droit("rapports", "Rapports de caisse", "Rapport des opérations, export Sage, rapport des tiers", O(("c", "Consulter les rapports à l'écran"), ("a", "Exporter (Excel, export Sage)"), ("m", "Imprimer (aperçu, PDF)"), ("s", SansAction))) }),
            ("Point de vente", new[] {
                new Droit("vendre", "Vendre", "Écran de vente, commandes de table, dépôts de linge", O(("c", "Ouvrir l'écran de vente, voir les tables et les commandes"), ("a", "Encaisser une vente, prendre une commande de table, mettre en attente, déposer du linge"), ("m", "Transférer une table, imprimer l'addition, reprendre une commande en attente, linge prêt, marquer livrée"), ("s", "Supprimer une commande en attente, annuler un dépôt de linge"))),
                new Droit("ventes", "Ventes", "Liste et détail des ventes, factures", O(("c", "Voir les ventes et les factures"), ("a", "Faire un retour, créer une facture"), ("m", "Marquer livrée, vérifier une vente hors ligne, modifier une facture"), ("s", "Annuler une vente"))),
                new Droit("cuisine", "Écran cuisine / bar", "Bons de préparation", O(("c", "Voir les bons"), ("a", SansAction), ("m", "Marquer un bon prêt"), ("s", SansAction))),
                new Droit("stock", "Stock", "Stock par dépôt et mouvements", O(("c", "Voir le stock et les mouvements"), ("a", "Entrées et transferts de stock"), ("m", "Inventaire, options du stock"), ("s", SansAction))),
                new Droit("achats", "Achats", "Achats fournisseurs, consommations, produits d'entretien", O(("c", "Voir les achats et le stock des achats"), ("a", "Saisir un achat, une consommation"), ("m", "Enregistrer un règlement au fournisseur"), ("s", "Annuler un achat"))),
                new Droit("rapports_pdv", "Rapports du point de vente", "Ventes, livraisons, dépôts de linge, achats", O(("c", "Consulter les rapports à l'écran"), ("a", "Exporter (Excel)"), ("m", "Imprimer (aperçu, PDF)"), ("s", SansAction))),
                new Droit("catalogue", "Catalogue", "Catégories, produits, combos, taxes, unités de vente", O(("c", "Voir et exporter"), ("a", "Créer, importer, générer des variantes"), ("m", "Modifier, activer ou désactiver"), ("s", "Supprimer"))),
                new Droit("synchro", "Synchronisation", "Ventes faites hors ligne et postes", O(("c", "Voir la synchronisation"), ("a", SansAction), ("m", "Marquer vérifié, oublier un poste"), ("s", SansAction))) }),
            ("Paramètres", new[] {
                new Droit("parametres", "Motifs et modes de paiement", "Motifs des opérations, modes de paiement", O(("c", "Voir"), ("a", "Créer"), ("m", "Modifier"), ("s", "Supprimer"))),
                new Droit("config_pdv", "Configuration du point de vente", "Dépôts, livreurs, plans de salle", O(("c", "Voir"), ("a", "Créer"), ("m", "Modifier, activer, plans de salle, frais de livraison"), ("s", "Supprimer"))) }),
            ("Droits particuliers", new[] {
                new Droit("prix", "Modifier les prix", "Changer le prix d'un article à l'écran de vente", O(("c", "Autorisé"))),
                new Droit("plafond", "Dépasser le plafond de crédit", "Vente par compte au-delà du plafond d'un client", O(("c", "Autorisé"))) }),
        };

        public static readonly Dictionary<string, Droit> Tous = Catalogue.SelectMany(r => r.Droits).ToDictionary(d => d.Code);

        // Tous les codes valides : « tiers » (consulter), « tiers.a », « tiers.m », « tiers.s ».
        public static readonly List<string> Codes = Catalogue.SelectMany(r => r.Droits)
            .SelectMany(d => d.Ops.Keys.Select(op => op == "c" ? d.Code : d.Code + "." + op)).ToList();

        // Droits des utilisateurs sans profil (anciens comptes Caissier / Vendeur) et des profils créés avec une nouvelle société.
        public static readonly string[] ParDefaut = { "tableau_bord", "caisses", "caisses.a", "caisses.m", "caisses.s", "journees", "journees.a", "journees.m", "journees.s",
            "tiers", "tiers.a", "tiers.m", "tiers.s", "rapports", "rapports.a", "rapports.m", "vendre", "vendre.a", "vendre.m", "vendre.s",
            "ventes", "ventes.a", "ventes.m", "ventes.s", "cuisine", "cuisine.m" };

        // Mots des actions par opération (les autres actions : consulter). Identiques en PHP (DROITS_MOTS).
        public static readonly Dictionary<string, string[]> Mots = new()
        {
            ["s"] = new[] { "delete", "supprimer", "annuler", "supprimerligne" },
            ["a"] = new[] { "create", "nouveau", "import", "entree", "transfert", "genvariantes", "operation", "ajouteroperation", "reglement", "consommation",
                            "retour", "ouvrirjournee", "ligne", "ajouterligne" },
            ["m"] = new[] { "toggle", "basculer", "defaut", "pardefaut", "achats", "frais", "majvariantes", "combo", "validation", "modifiervalidation", "cloturer",
                            "statut", "livree", "verifier", "oublier", "option", "inventaire", "inventairepost", "enregistrer", "valider", "validerfacture" },
        };

        // Mots propres à un droit (prioritaires sur les mots communs). Identiques en PHP (DROITS_MOTS_DROIT).
        public static readonly Dictionary<string, Dictionary<string, string[]>> MotsDroit = new()
        {
            ["vendre"] = new()
            {
                ["a"] = new[] { "vendre", "mettreenattente", "deposer", "enregistrer", "envoyer" },
                ["m"] = new[] { "transferer", "addition", "reprendre", "depotpret", "livree" },
                ["s"] = new[] { "supprimerattente", "depotannuler" },
                ["c"] = new[] { "index", "ticket", "plan", "commande", "additionticket", "bon", "attentes", "depots", "ticketdepot", "jeton" },
            },
            ["rapports"] = new()
            {
                ["a"] = new[] { "sage", "excel", "exportsage", "exportsagecsv", "exportsagetxt" },
                ["m"] = new[] { "preview", "previewoperations", "imprimer", "pdf" },
            },
            ["rapports_pdv"] = new()
            {
                ["a"] = new[] { "excel" },
                ["m"] = new[] { "preview", "imprimer", "pdf" },
            },
            ["achats"] = new() { ["m"] = new[] { "reglement" } },
        };

        // Opération d'une action : c, a, m ou s (« Save » / « Edit » : selon l'identifiant) ; mots propres au droit d'abord.
        public static string Operation(string action, int id, string droit = "")
        {
            var a = action.ToLowerInvariant();
            if (MotsDroit.TryGetValue(droit, out var propres))
                foreach (var (op, mots) in propres)
                    if (mots.Contains(a)) return op;
            if (a is "save" or "edit") return id > 0 ? "m" : "a";
            foreach (var op in new[] { "s", "a", "m" })
                if (Mots[op].Contains(a)) return op;
            return "c";
        }

        private static readonly Dictionary<string, string> Carte = new(StringComparer.OrdinalIgnoreCase)
        {
            ["Dashboard"] = "tableau_bord", ["TableauLaverie"] = "tableau_bord", ["TableauRestaurant"] = "tableau_bord",
            ["Caisse"] = "caisses", ["JourneeCaisse"] = "journees", ["Client"] = "tiers", ["Rapport"] = "rapports", ["RapportTiers"] = "rapports",
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
            if (controleur.Equals("Caisse", StringComparison.OrdinalIgnoreCase) && action is "OuvrirJournee" or "AjouterOperation")
                return "journees";   // ouvrir une journée et ajouter une opération depuis la page des caisses
            if (controleur.Equals("Synchro", StringComparison.OrdinalIgnoreCase) && action == "Rapport")
                return "";   // état du poste envoyé par tous les écrans de vente
            return Carte.TryGetValue(controleur, out var d) ? d : "";
        }

        // Opération retenue pour un droit : une opération que ce droit ne prévoit pas compte comme « consulter ».
        public static string OperationDuDroit(string droit, string action, int id)
        {
            var op = Operation(action, id, droit);
            return Tous.TryGetValue(droit, out var d) && d.Ops.ContainsKey(op) ? op : "c";
        }

        // Correspondance des pages pour le script qui masque les boutons non permis (wwwroot/js/droits.js).
        public static Dictionary<string, string> CarteJs() => Carte.ToDictionary(k => k.Key.ToLowerInvariant(), k => k.Value);

        // Première page permise après la connexion.
        public static readonly (string Droit, string Url)[] Accueils =
        {
            ("tableau_bord", "/Dashboard/Index"), ("vendre", "/Pos/Index"), ("journees", "/Caisse/Index"), ("caisses", "/Caisse/Index"), ("ventes", "/Vente/Index"),
            ("cuisine", "/Cuisine/Index"), ("tiers", "/Client/Index"), ("rapports", "/Rapport/Operations"), ("stock", "/Stock/Index"),
            ("achats", "/Achat/Index"), ("rapports_pdv", "/PosRapport/Index"), ("catalogue", "/Produit/Index"), ("synchro", "/Synchro/Index"),
            ("parametres", "/Motif/Index"), ("config_pdv", "/Depot/Index"),
        };

        // Droits lus d'un profil : codes valides, sans doublon ; une opération sans « consulter » est ignorée.
        public static List<string> Lire(string? droits)
        {
            var liste = (droits ?? "").Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).Where(Codes.Contains).Distinct().ToList();
            return Codes.Where(c => liste.Contains(c) && (!c.Contains('.') || liste.Contains(c.Split('.')[0]))).ToList();
        }
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
            _droits = EstAdmin ? Droits.Codes.ToHashSet()
                : (ligne.ProfilId == null ? Droits.ParDefaut.ToHashSet() : Droits.Lire(ligne.Droits).ToHashSet());
        }

        public bool Peut(string droit, string op = "c")
        {
            if (!_charge) ChargerAsync().GetAwaiter().GetResult();
            return EstAdmin || _droits.Contains(op == "c" ? droit : droit + "." + op);
        }

        public IReadOnlyCollection<string> Accordes => _droits;

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
            var action = context.RouteData.Values["action"]?.ToString() ?? "";
            var droit = Droits.Page(controleur, action);
            // Identifiant de l'enregistrement (« Save » / « Edit » : ajout si absent, modification sinon).
            var id = 0;
            foreach (var v in new[] { context.RouteData.Values["id"]?.ToString(), http.Request.Query["id"].ToString(),
                                      http.Request.HasFormContentType ? http.Request.Form["id"].ToString() : null,
                                      http.Request.HasFormContentType ? http.Request.Form["ID"].ToString() : null })
                if (int.TryParse(v, out var n) && n > id) id = n;
            var op = droit is "" or "admin" ? "c" : Droits.OperationDuDroit(droit, action, id);
            var permis = droit == "" || (droit == "admin" ? _droits.EstAdmin : _droits.Peut(droit) && _droits.Peut(droit, op))
                // Liste et fiche des caisses : aussi pour ouvrir une journée (droit « Journées et opérations »).
                || (droit == "caisses" && op == "c" && _droits.Peut("journees"));
            if (!permis && controleur is "Pos" or "Cuisine" && (HttpMethods.IsPost(http.Request.Method) || http.Request.Headers.Accept.ToString().Contains("json")))
            {
                // Écran de vente et écran cuisine (appels en arrière-plan) : réponse JSON lisible par l'écran.
                context.Result = new JsonResult(new { erreur = "Votre profil ne permet pas cette opération." }) { StatusCode = 403 };
                return;
            }
            if (!permis)
            {
                context.Result = new RedirectToActionResult("AccesRefuse", "Auth", null);
                return;
            }
            await next();
        }
    }
}
