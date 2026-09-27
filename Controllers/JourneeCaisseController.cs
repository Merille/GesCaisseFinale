using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Models.ViewModels;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Rotativa.AspNetCore;
using System.Security.Claims;

namespace EasytransitCaisse.Controllers
{
    public class JourneeCaisseController : Controller
    {
        private readonly AppDbContext _context;

        public JourneeCaisseController(AppDbContext context)
        {
            _context = context;
        }

        // Totaux encaissés/décaissés par mode de paiement pour une journée
        // (utilisé à l'écran et sur le PDF imprimé).
        private List<TotalModePaiementVM> GetTotauxParModePaiement(int journeeId)
        {
            var operations = _context.OperationsCaisses
                .NonRejetees()
                .Where(x => x.JourneeCaisseId == journeeId)
                .Select(x => new { x.TypeOperation, x.Montant, x.ModePaiementId })
                .ToList();

            var libelles = _context.ModesPaiement
                .ToDictionary(m => m.Id, m => m.Libelle ?? "-");

            return operations
                .GroupBy(x => x.ModePaiementId)
                .Select(g => new TotalModePaiementVM
                {
                    Libelle = g.Key.HasValue && libelles.TryGetValue(g.Key.Value, out var lib)
                        ? lib
                        : "Non renseigné",
                    Encaisse = g.Where(o => o.TypeOperation == "Encaissement").Sum(o => o.Montant),
                    Decaisse = g.Where(o => o.TypeOperation == "Décaissement").Sum(o => o.Montant)
                })
                .OrderBy(t => t.Libelle)
                .ToList();
        }

        public IActionResult Details(int id)
        {
            var journee = _context.JourneesCaisses
                .FirstOrDefault(x => x.Id == id);

            if (journee == null)
                return NotFound();

            var encaisse = _context.OperationsCaisses
                .NonRejetees()
                .Where(x =>
                    x.JourneeCaisseId == id &&
                    x.TypeOperation == "Encaissement")
                .Sum(x => (decimal?)x.Montant) ?? 0;

            var decaisse = _context.OperationsCaisses
                .NonRejetees()
                .Where(x =>
                    x.JourneeCaisseId == id &&
                    x.TypeOperation == "Décaissement")
                .Sum(x => (decimal?)x.Montant) ?? 0;

            ViewBag.TotalEncaisse = encaisse;
            ViewBag.TotalDecaisse = decaisse;
            ViewBag.SoldeActuel =
                journee.SoldeInitial +
                encaisse -
                decaisse;

            ViewBag.Clients = _context.Clients
                .OrderBy(x => x.NomSociete)
                .ToList();

            ViewBag.Motifs = _context.Motifs
                .OrderBy(m => m.LibelleMotif)
                .ToList();

            ViewBag.ModesPaiement = _context.ModesPaiement
                .Where(m => m.Actif)
                .OrderBy(m => m.Libelle)
                .ToList();

            ViewBag.PeutValider = bool.TryParse(
                User.FindFirst(AppClaimTypes.PeutValiderOperations)?.Value, out var pv) && pv;

            ViewBag.TotauxParModePaiement = GetTotauxParModePaiement(id);

            ViewBag.Operations = _context.OperationsCaisses
                .Where(x => x.JourneeCaisseId == id)
                .OrderByDescending(x => x.DateOperation)
                .Select(x => new {
                            x.Id,
                            x.DateOperation,
                            x.TypeOperation,
                            x.Montant,
                            x.Libelle,
                            x.EstJustifie,
                            x.StatutValidation,
                            x.Observation,
                            MotifLibelle = x.MotifId != null
                    ? _context.Motifs
                        .Where(m => m.ID == x.MotifId)
                        .Select(m => m.LibelleMotif)
                        .FirstOrDefault()
                    : "-",
                            ModePaiementLibelle = x.ModePaiementId != null
                    ? _context.ModesPaiement
                        .Where(m => m.Id == x.ModePaiementId)
                        .Select(m => m.Libelle)
                        .FirstOrDefault()
                    : "-"
                        })
                .ToList();

            return View(journee);
        }
        [HttpPost]
        public IActionResult AjouterOperation(
        int journeeId,
        string typeOperation,
        decimal montant,
        string libelle,
        int? motifId,
        int? clientId,
        int? modePaiementId,
        bool estJustifie,
        string statutValidation,
        string? valideur,
        string? observation)
        {
            var utilisateurId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

            // Droit vérifié côté serveur (pas seulement désactivé côté formulaire) :
            // sans le droit, le statut posté est ignoré et reste "En attente".
            var peutValider = bool.TryParse(
                User.FindFirst(AppClaimTypes.PeutValiderOperations)?.Value, out var pv) && pv;

            var operation = new OperationCaisse
            {
                JourneeCaisseId = journeeId,
                DateOperation = DateTime.Now,
                TypeOperation = typeOperation,
                Montant = montant,
                Libelle = libelle,
                ClientId = clientId,
                MotifId = motifId,
                ModePaiementId = modePaiementId,
                UtilisateurId = utilisateurId,
                EstJustifie = estJustifie,
                StatutValidation = peutValider && !string.IsNullOrWhiteSpace(statutValidation)
                    ? statutValidation
                    : "En attente",
                Valideur = valideur,
                Observation = observation
            };

            _context.OperationsCaisses.Add(operation);

            _context.SaveChanges();

            return RedirectToAction(
                "Details",
                new { id = journeeId });
        }

        [HttpPost]
        public IActionResult ModifierValidation(
        int id,
        int journeeId,
        bool estJustifie,
        string statutValidation,
        string? observation)
        {
            // Droit vérifié côté serveur : sans lui, impossible de changer le
            // statut d'un mouvement déjà saisi (même via une requête forgée).
            var peutValider = bool.TryParse(
                User.FindFirst(AppClaimTypes.PeutValiderOperations)?.Value, out var pv) && pv;

            if (!peutValider)
            {
                TempData["Erreur"] =
                    "Vous n'avez pas le droit de valider/rejeter les opérations de caisse.";

                return RedirectToAction("Details", new { id = journeeId });
            }

            var operation = _context.OperationsCaisses
                .FirstOrDefault(x => x.Id == id);

            if (operation == null)
                return NotFound();

            operation.EstJustifie = estJustifie;
            operation.StatutValidation = string.IsNullOrWhiteSpace(statutValidation)
                ? "En attente"
                : statutValidation;
            operation.Observation = observation;
            operation.Valideur = User.FindFirst(AppClaimTypes.NomComplet)?.Value;

            _context.SaveChanges();

            return RedirectToAction("Details", new { id = journeeId });
        }

        public IActionResult Create(int id)
        {
            ViewBag.CaisseId = id;

            return View();
        }

        [HttpPost]
        public IActionResult Create(
    int caisseId,
    DateTime dateJournee,
    decimal soldeInitial)
        {
            var caisse = _context.Caisses
                .FirstOrDefault(x => x.ID == caisseId);

            if (caisse == null)
                return NotFound();

            // vérifier doublon
            var existe = _context.JourneesCaisses
                .Any(x =>
                    x.CaisseId == caisseId &&
                    x.DateJournee.Date == dateJournee.Date);

            if (existe)
            {
                TempData["Erreur"] =
                    "Cette journée existe déjà.";

                ViewBag.CaisseId = caisseId;

                return View();
            }

            var journee = new JourneeCaisse
            {
                CaisseId = caisseId,
                DateJournee = dateJournee,
                DateOuverture = DateTime.Now,
                SoldeInitial = soldeInitial,
                Statut = "Ouverte",

                // 🔥 ICI le numéro propre
                NumeroJournee = $"{caisse.ChkCode}-{dateJournee:yyyyMMdd}"
            };

            _context.JourneesCaisses.Add(journee);
            _context.SaveChanges();

            return RedirectToAction("Details", new { id = journee.Id });
        }

        [HttpPost]
        public IActionResult Cloturer(int id)
        {
            var journee = _context.JourneesCaisses
                .FirstOrDefault(x => x.Id == id);

            if (journee == null)
                return NotFound();

            journee.Statut = "Cloturee";
            journee.DateFermeture = DateTime.Now;

            _context.SaveChanges();

            return RedirectToAction("Details", new { id });
        }

        [HttpPost]
        public IActionResult Supprimer(int id)
        {
            var journee = _context.JourneesCaisses
                .FirstOrDefault(x => x.Id == id);

            if (journee == null)
                return NotFound();

            // empêcher suppression si clôturée
            if (journee.Statut == "Cloturee")
            {
                TempData["Erreur"] =
                    "Impossible de supprimer une journée clôturée.";

                return RedirectToAction("Details", new { id });
            }

            _context.JourneesCaisses.Remove(journee);
            _context.SaveChanges();

            return RedirectToAction("Details", "Caisse", new { id = journee.CaisseId });
        }

        public IActionResult PrintJournees(int caisseId)
        {
            var caisse = _context.Caisses
                .FirstOrDefault(x => x.ID == caisseId);

            if (caisse == null)
            {
                return Content($"Aucune caisse trouvée pour l'ID {caisseId}");
            }


            var journees = _context.JourneesCaisses
                .Where(x => x.CaisseId == caisseId)
                .ToList();

            var lignes = journees.Select(j => new JourneeLigneVM
            {
                DateJournee = j.DateJournee,
                SoldeInitial = j.SoldeInitial,

                Encaisse = _context.OperationsCaisses
                    .NonRejetees()
                    .Where(o => o.JourneeCaisseId == j.Id &&
                                o.TypeOperation == "Encaissement")
                    .Sum(o => (decimal?)o.Montant) ?? 0,

                Decaisse = _context.OperationsCaisses
                    .NonRejetees()
                    .Where(o => o.JourneeCaisseId == j.Id &&
                                o.TypeOperation == "Décaissement")
                    .Sum(o => (decimal?)o.Montant) ?? 0,

                Solde =
                    j.SoldeInitial +
                    (_context.OperationsCaisses
                        .NonRejetees()
                        .Where(o => o.JourneeCaisseId == j.Id &&
                                    o.TypeOperation == "Encaissement")
                        .Sum(o => (decimal?)o.Montant) ?? 0)
                    -
                    (_context.OperationsCaisses
                        .NonRejetees()
                        .Where(o => o.JourneeCaisseId == j.Id &&
                                    o.TypeOperation == "Décaissement")
                        .Sum(o => (decimal?)o.Montant) ?? 0),

                Statut = j.Statut
            }).ToList();

            // NB: Rotativa.ViewAsPdf ne propage pas le ViewBag du contrôleur vers la
            // vue rendue en PDF — le nom de la caisse doit voyager dans le modèle.
            var model = new PrintJourneesVM
            {
                CaisseName = caisse.ChkDescription + " - " + caisse.ChkCode,
                Journees = lignes
            };

            return new ViewAsPdf("PrintJournees", model)
            {
                FileName = "Journees.pdf"
            };
        }

        public IActionResult PrintOperations(int journeeId)
        {
            var journee = _context.JourneesCaisses
                .FirstOrDefault(x => x.Id == journeeId);

            if (journee == null)
                return NotFound();

            var ops = _context.OperationsCaisses
                .Include(x => x.ModePaiement)
                .Where(x => x.JourneeCaisseId == journeeId)
                .ToList();

            var totalEncaisse = ops
                .NonRejetees()
                .Where(o => o.TypeOperation == "Encaissement")
                .Sum(o => o.Montant);

            var totalDecaisse = ops
                .NonRejetees()
                .Where(o => o.TypeOperation == "Décaissement")
                .Sum(o => o.Montant);

            // NB: Rotativa.ViewAsPdf ne propage pas le ViewBag du contrôleur vers la
            // vue rendue en PDF — les totaux doivent voyager dans le modèle lui-même.
            var model = new PrintOperationsVM
            {
                NumeroJournee = journee.NumeroJournee,
                SoldeInitial = journee.SoldeInitial,
                TotalEncaisse = totalEncaisse,
                TotalDecaisse = totalDecaisse,
                SoldeActuel = journee.SoldeInitial + totalEncaisse - totalDecaisse,
                Operations = ops,
                TotauxParModePaiement = GetTotauxParModePaiement(journeeId)
            };

            return new ViewAsPdf("PrintOperations", model)
            {
                FileName = "Operations_Caisse.pdf"
            };
        }

    }
}