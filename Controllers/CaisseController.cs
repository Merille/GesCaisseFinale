using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
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

        public CaisseController(AppDbContext context)
        {
            _context = context;
        }

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
                    CashierName = u != null ? u.NomComplet : null
                })
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

            _context.Caisses.Add(caisse);
            _context.SaveChanges();

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

            _context.SaveChanges();

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
                _context.Caisses.Remove(caisse);
                _context.SaveChanges();
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
                .OrderByDescending(x => x.DateOuverture)
                .ToList();

            var resultat = new List<dynamic>();

            foreach (var journee in journees)
            {
                decimal encaisse = _context.OperationsCaisses
                    .Where(x =>
                        x.JourneeCaisseId == journee.Id &&
                        x.TypeOperation == "Encaissement")
                    .Sum(x => (decimal?)x.Montant) ?? 0;

                decimal decaisse = _context.OperationsCaisses
                    .Where(x =>
                        x.JourneeCaisseId == journee.Id &&
                        x.TypeOperation == "Décaissement")
                    .Sum(x => (decimal?)x.Montant) ?? 0;

                resultat.Add(new
                {
                    JourneeId = journee.Id,
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
            decimal soldeInitial)
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
                        SoldeInitial = soldeInitial,
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
    decimal montant,
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
                TempData["Erreur"] =
                    "Cette journée est clôturée. Aucune opération autorisée.";

                return RedirectToAction("Details", new { id = journeeId });
            }

            var operation = new OperationCaisse
            {
                JourneeCaisseId = journeeId,
                DateOperation = DateTime.Now,
                TypeOperation = typeOperation,
                Montant = montant,
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
            var caisses = _context.Caisses.ToList();

            return new ViewAsPdf("PrintCaisses", caisses)
            {
                FileName = "Liste_Caisses.pdf"
            };
        }

    }
}