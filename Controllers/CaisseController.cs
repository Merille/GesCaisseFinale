using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Rotativa.AspNetCore;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace EasytransitCaisse.Controllers
{
    public class CaisseController : Controller
    {
        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenantProvider;

        public CaisseController(AppDbContext context, ITenantProvider tenantProvider)
        {
            _context = context;
            _tenantProvider = tenantProvider;
        }

        // Boutique (affiché « Vente en détail ») : vente au comptoir. Restaurant / Bar : plan de
        // salle, commandes sur les tables, bons de préparation envoyés en cuisine ou au bar.
        // Laverie : vente au comptoir comme la vente en détail (prestations sans suivi de stock).
        public static readonly string[] Types = { "Boutique", "Restaurant", "Bar", "Laverie" };

        // Badge et icône du type dans la liste des caisses.
        public static string Badge(string? type) => type switch
        {
            "Bar" => "bg-info text-dark", "Restaurant" => "bg-warning text-dark", "Laverie" => "bg-primary", _ => "bg-secondary"
        };
        public static string Icone(string? type) => type switch
        {
            "Bar" => "fa-martini-glass", "Restaurant" => "fa-utensils", "Laverie" => "fa-shirt", _ => "fa-store"
        };

        // Libellé affiché du type de point de vente.
        public static string Libelle(string? type) => type is null or "Boutique" ? "Vente en détail" : type;

        // Dépôt saisi sur la fiche caisse, s'il est actif et de la société ; sinon null (dépôt par défaut).
        private int? DepotValide(int? depotId)
            => depotId.HasValue && _context.Depots.Any(d => d.Id == depotId && d.Actif) ? depotId : null;

        // LISTE
        public IActionResult Index()
        {
            // Left join (et non Join) : une caisse sans caissier par défaut assigné
            // (CashierDefault null ou ne correspondant à aucun utilisateur) doit
            // rester visible, pas disparaître silencieusement de la liste.
            var caisses = _context.Caisses
            .GroupJoin(_context.Utilisateurs,
                c => c.CashierDefault,
                u => u.Id,
                (c, users) => new { c, users })
            .SelectMany(
                x => x.users.DefaultIfEmpty(),
                (x, u) => new CaisseViewModel
                {
                    ID = x.c.ID,
                    ChkCode = x.c.ChkCode,
                    ChkDescription = x.c.ChkDescription,
                    StCode = x.c.StCode,
                    TypePointVente = x.c.TypePointVente,
                    CompteComptable = x.c.CompteComptable,
                    CashierName = u != null ? u.NomComplet : null
                })
            .OrderBy(c => c.ChkCode)
            .ToList();
            ViewBag.Users = _context.Utilisateurs
                .Select(u => new SelectListItem { Value = u.Id.ToString(), Text = u.NomComplet })
                .ToList();

            return View(caisses);
        }

        // CREATE - GET
        public IActionResult Create()
        {
            ViewBag.Users = _context.Utilisateurs
                .Select(u => new SelectListItem
                {
                    Value = u.Id.ToString(),
                    Text = u.NomComplet
                })
                .ToList();

            return View();
        }

        // CREATE - POST
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Create(Caisse caisse)
        {
            // Forcer des valeurs vides pour éviter l'erreur Required
            caisse.CustomerDefaultCode ??= "";
            caisse.JournalDefaultCode ??= "";
            caisse.ChkCode ??= "";
            caisse.ChkDescription ??= "";
            caisse.StCode ??= "";
            if (!Types.Contains(caisse.TypePointVente))
                caisse.TypePointVente = "Boutique";

            ModelState.Clear();

            if (!ModelState.IsValid)
            {
                ViewBag.Users = _context.Utilisateurs
                    .Select(u => new SelectListItem
                    {
                        Value = u.Id.ToString(),
                        Text = u.NomComplet
                    })
                    .ToList();
                return View(caisse);
            }

            var tenantCreation = _tenantProvider.TenantId;
            caisse.DepotId = DepotValide(caisse.DepotId)
                ?? (tenantCreation > 0 ? _context.DepotParDefautAsync(tenantCreation).GetAwaiter().GetResult() : null);
            _context.Caisses.Add(caisse);
            _context.SaveChanges();
            TempData["Success"] = "Caisse créée.";

            return RedirectToAction(nameof(Index));
        }
        public IActionResult Edit(int id)
        {
            var caisse = _context.Caisses.FirstOrDefault(c => c.ID == id);

            if (caisse == null)
                return NotFound();

            ViewBag.Users = _context.Utilisateurs
                .Select(u => new SelectListItem
                {
                    Value = u.Id.ToString(),
                    Text = u.NomComplet
                })
                .ToList();

            return View(caisse);
        }

        // EDIT - POST
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Edit(Caisse caisse)
        {
            var existing = _context.Caisses.FirstOrDefault(c => c.ID == caisse.ID);

            if (existing == null)
                return NotFound();

            // Copie champ à champ (et non Update() global) pour ne pas écraser
            // TenantId, absent du formulaire, avec la valeur par défaut 0.
            existing.ChkCode = caisse.ChkCode;
            existing.ChkDescription = caisse.ChkDescription;
            existing.StCode = caisse.StCode;
            existing.SalesPersonDefault = caisse.SalesPersonDefault;
            existing.CashierDefault = caisse.CashierDefault;
            existing.CustomerDefaultCode = caisse.CustomerDefaultCode;
            existing.JournalDefaultCode = caisse.JournalDefaultCode;
            existing.CompteComptable = caisse.CompteComptable;
            existing.TypePointVente = Types.Contains(caisse.TypePointVente) ? caisse.TypePointVente : "Boutique";
            existing.ImprimerBons = caisse.ImprimerBons;
            existing.DepotId = DepotValide(caisse.DepotId) ?? existing.DepotId
                ?? _context.DepotParDefautAsync(existing.TenantId).GetAwaiter().GetResult();

            _context.SaveChanges();
            TempData["Success"] = "Caisse modifiée.";

            return RedirectToAction("Index");
        }

        // DELETE
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Delete(int id)
        {
            var caisse = _context.Caisses.Find(id);

            if (caisse != null)
            {
                // Comme la version PHP : une caisse qui a des journées est conservée.
                var nb = _context.JourneesCaisses.Count(j => j.CaisseId == caisse.ID);
                if (nb > 0)
                    TempData["Error"] = $"Impossible de supprimer cette caisse : elle a {nb} journée(s) enregistrée(s).";
                else
                {
                    _context.Caisses.Remove(caisse);
                    _context.SaveChanges();
                    TempData["Success"] = "Caisse supprimée.";
                }
            }

            return RedirectToAction("Index");
        }
        public IActionResult Details(int id)
        {
            var caisse = _context.Caisses
                .FirstOrDefault(x => x.ID == id);

            if (caisse == null)
                return NotFound();

            var journees = _context.JourneesCaisses
                .Where(x => x.CaisseId == id)
                .OrderByDescending(x => x.DateOuverture).ThenByDescending(x => x.Id)
                .ToList();

            var resultat = new List<dynamic>();

            foreach (var journee in journees)
            {
                decimal encaisse = _context.OperationsCaisses
                    .NonRejetees()
                    .Where(x =>
                        x.JourneeCaisseId == journee.Id &&
                        x.TypeOperation == "Encaissement")
                    .Sum(x => (decimal?)x.Montant) ?? 0;

                decimal decaisse = _context.OperationsCaisses
                    .NonRejetees()
                    .Where(x =>
                        x.JourneeCaisseId == journee.Id &&
                        x.TypeOperation == "Décaissement")
                    .Sum(x => (decimal?)x.Montant) ?? 0;

                resultat.Add(new
                {
                    JourneeId = journee.Id,
                    Numero = journee.NumeroJournee,
                    Date = journee.DateOuverture,
                    DateJournee = journee.DateJournee,
                    Initial = journee.SoldeInitial,
                    Encaisse = encaisse,
                    Decaisse = decaisse,
                    Solde = journee.SoldeInitial + encaisse - decaisse,
                    Statut = journee.Statut
                });
            }

            ViewBag.Journees = resultat;

            return View(caisse);
        }

        [HttpPost]
        public IActionResult OuvrirJournee(
            int caisseId,
            string soldeInitial)
                {
                    var dejaOuverte = _context.JourneesCaisses
                        .Any(j => j.CaisseId == caisseId
                               && j.Statut == "Ouverte");

                    if (dejaOuverte)
                    {
                        return RedirectToAction("Details",
                            new { id = caisseId });
                    }

                    var journee = new JourneeCaisse
                    {
                        CaisseId = caisseId,
                        NumeroJournee = $"JC-{DateTime.Now:yyyyMMddHHmmss}",
                        DateOuverture = DateTime.Now,
                        SoldeInitial = MontantHelper.Parse(soldeInitial),
                        Statut = "Ouverte"
                    };

                    _context.JourneesCaisses.Add(journee);

                    _context.SaveChanges();

                    return RedirectToAction("Details",
                        new { id = caisseId });
                }

        [HttpPost]
        public IActionResult AjouterOperation(
    int journeeId,
    string typeOperation,
    string montant,
    string libelle,
    int? clientId)
        {
            var journee = _context.JourneesCaisses
                .FirstOrDefault(x => x.Id == journeeId);

            if (journee == null)
                return NotFound();

            // 🔒 BLOQUAGE
            if (journee.Statut == "Cloturee")
            {
                TempData["Error"] =
                    "Cette journée est clôturée. Aucune opération autorisée.";

                return RedirectToAction("Details", new { id = journeeId });
            }

            var operation = new OperationCaisse
            {
                JourneeCaisseId = journeeId,
                DateOperation = DateTime.Now,
                TypeOperation = typeOperation,
                Montant = MontantHelper.Parse(montant),
                Libelle = libelle,
                ClientId = clientId,
                UtilisateurId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!)
            };

            _context.OperationsCaisses.Add(operation);
            _context.SaveChanges();

            return RedirectToAction("Details", new { id = journeeId });
        }

        public IActionResult PrintCaisses()
        {
            var caissiers = _context.Utilisateurs.ToDictionary(u => u.Id, u => u.NomComplet);
            var caisses = _context.Caisses.OrderBy(c => c.ChkCode).ToList()
                .Select(c => new EasytransitCaisse.Models.ViewModels.CaisseImpressionVM
                {
                    Caisse = c,
                    Caissier = c.CashierDefault.HasValue && caissiers.TryGetValue(c.CashierDefault.Value, out var nom) ? nom : null
                })
                .ToList();

            return new ViewAsPdf("PrintCaisses", caisses)
            {
                FileName = "Liste_Caisses.pdf"
            };
        }

    }
}