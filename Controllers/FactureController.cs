using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Models.ViewModels;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using Rotativa.AspNetCore;

namespace EasytransitCaisse.Controllers
{
    public class FactureController : Controller
    {
        private readonly AppDbContext _context;

        public FactureController(AppDbContext context)
        {
            _context = context;
        }

        public IActionResult Index()
        {
            var factures = _context.Factures.Include(f => f.Client)
                .OrderByDescending(f => f.DateFacture).ThenByDescending(f => f.Id).ToList();
            return View(factures);
        }

        // Clients et numéro proposé (FAC-AAAA-0001, suivant le nombre de factures de l'année), comme la version PHP.
        private void DonneesCreation()
        {
            ViewBag.Clients = _context.Clients.OrderBy(x => x.NomSociete).ToList();
            var n = _context.Factures.Count(f => f.DateFacture.Year == DateTime.Today.Year) + 1;
            ViewBag.NumeroPropose = $"FAC-{DateTime.Today.Year}-{n:D4}";
        }

        public IActionResult Create()
        {
            DonneesCreation();
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Create(int clientId, string? numero, string? tauxTVA)
        {
            numero = (numero ?? "").Trim();
            string? erreur = !_context.Clients.Any(c => c.Id == clientId) ? "Choisissez un client."
                : numero == "" ? "Le numéro de facture est obligatoire."
                : _context.Factures.Any(f => f.Numero == numero) ? $"Le numéro « {numero} » existe déjà."
                : null;
            if (erreur != null)
            {
                TempData["Error"] = erreur;
                DonneesCreation();
                ViewBag.Saisie = new { ClientId = clientId, Numero = numero, TauxTVA = tauxTVA };
                return View();
            }
            var facture = new Facture
            {
                Numero = numero,
                ClientId = clientId,
                TauxTVA = MontantHelper.Parse(tauxTVA),
                DateFacture = DateTime.Now,
                Statut = "Brouillon"
            };
            _context.Factures.Add(facture);
            _context.SaveChanges();

            return RedirectToAction("Edit", new { id = facture.Id });
        }

        public IActionResult Edit(int id)
        {
            var facture = _context.Factures
                .Include(f => f.Client)
                .FirstOrDefault(f => f.Id == id);

            if (facture == null)
                return NotFound();

            ViewBag.Lignes = _context.LignesFactures
                .Where(x => x.FactureId == id)
                .OrderBy(x => x.Id)
                .ToList();

            return View(facture);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult AjouterLigne(
    int factureId,
    string designation,
    string quantite,
    string prixUnitaire)
        {
            var facture = _context.Factures.FirstOrDefault(f => f.Id == factureId);
            if (facture == null)
                return NotFound();

            if (facture.Statut != "Brouillon")
            {
                TempData["Error"] = "Une facture validée ne peut plus être modifiée.";
                return RedirectToAction(nameof(Edit), new { id = factureId });
            }

            var quantiteMontant = MontantHelper.Parse(quantite);
            var prixUnitaireMontant = MontantHelper.Parse(prixUnitaire);

            if (string.IsNullOrWhiteSpace(designation) || quantiteMontant <= 0)
            {
                TempData["Error"] = "Indiquez une désignation et une quantité supérieure à zéro.";
                return RedirectToAction(nameof(Edit), new { id = factureId });
            }

            using var transaction = _context.Database.BeginTransaction();

            try
            {
                var ligne = new LigneFacture
                {
                    FactureId = factureId,
                    Designation = designation,
                    Quantite = quantiteMontant,
                    PrixUnitaire = prixUnitaireMontant,
                    TotalLigne = Math.Round(quantiteMontant * prixUnitaireMontant, 2)
                };

                _context.LignesFactures.Add(ligne);
                _context.SaveChanges();

                RecalculerFacture(factureId);

                _context.SaveChanges();

                transaction.Commit();

                return RedirectToAction(nameof(Edit), new { id = factureId });
            }
            catch
            {
                transaction.Rollback();
                throw;
            }
        }
        private void RecalculerFacture(int factureId)
        {
            var facture = _context.Factures
                .SingleOrDefault(x => x.Id == factureId);

            if (facture == null)
                return;

            facture.MontantHT = _context.LignesFactures
                .Where(x => x.FactureId == factureId)
                .Sum(x => (decimal?)x.TotalLigne) ?? 0;

            facture.MontantTVA = Math.Round(
                facture.MontantHT * facture.TauxTVA / 100, 2);

            facture.MontantTTC = facture.MontantHT + facture.MontantTVA;
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult ValiderFacture(int factureId)
        {
            var facture = _context.Factures.FirstOrDefault(x => x.Id == factureId);
            if (facture == null)
                return NotFound();

            if (!_context.LignesFactures.Any(l => l.FactureId == factureId))
            {
                TempData["Error"] = "Ajoutez au moins une ligne avant de valider la facture.";
            }
            else
            {
                facture.Statut = "Validée";
                _context.SaveChanges();
                TempData["Success"] = "Facture validée.";
            }

            return RedirectToAction("Edit",
                new { id = factureId });
        }

        public IActionResult Print(int id)
        {
            var facture = _context.Factures
                .Include(f => f.Client)
                .FirstOrDefault(x => x.Id == id);

            if (facture == null)
                return NotFound();

            var model = new FacturePrintViewModel
            {
                Facture = facture,
                Lignes = _context.LignesFactures
                    .Where(x => x.FactureId == id)
                    .OrderBy(x => x.Id)
                    .ToList()
            };

            return new ViewAsPdf("Print", model)
            {
                FileName = $"Facture_{facture.Numero}.pdf",
                PageSize = Rotativa.AspNetCore.Options.Size.A4,
                PageMargins = new Rotativa.AspNetCore.Options.Margins(10, 10, 10, 10)
            };
        }

        public IActionResult Preview(int id)
        {
            var facture = _context.Factures
                .Include(f => f.Client)
                .FirstOrDefault(f => f.Id == id);

            if (facture == null)
                return NotFound();

            var model = new FacturePrintViewModel
            {
                Facture = facture,
                Lignes = _context.LignesFactures
                    .Where(x => x.FactureId == id)
                    .OrderBy(x => x.Id)
                    .ToList()
            };

            return View(model);
        }
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult SupprimerLigne(int id)
        {
            var ligne = _context.LignesFactures
                .FirstOrDefault(x => x.Id == id);

            if (ligne == null)
                return NotFound();

            int factureId = ligne.FactureId;
            var facture = _context.Factures.First(f => f.Id == factureId);

            if (facture.Statut != "Brouillon")
            {
                TempData["Error"] = "Une facture validée ne peut plus être modifiée.";
                return RedirectToAction(nameof(Edit), new { id = factureId });
            }

            _context.LignesFactures.Remove(ligne);

            _context.SaveChanges();

            RecalculerFacture(factureId);

            _context.SaveChanges();

            return RedirectToAction(nameof(Edit), new { id = factureId });
        }


    }
}