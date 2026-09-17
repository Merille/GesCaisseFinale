using ClosedXML.Excel;
using EasytransitCaisse.Controllers;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using Rotativa.AspNetCore;



namespace EasytransitCaisse.Controllers
{
    public class RapportController : Controller
    {
        private readonly AppDbContext _context;

        public RapportController(AppDbContext context)
        {
            _context = context;
        }

        public IActionResult Index()
        {
            return View();
        }

        [HttpGet]
        public IActionResult GetOperations(DateTime? dateDebut, DateTime? dateFin, string type, int? caisseId)
        {
            var query = _context.OperationsCaisses
                .Include(x => x.JourneeCaisse)
                .AsQueryable();

            if (dateDebut != null)
                query = query.Where(x => x.DateOperation >= dateDebut);

            if (dateFin != null)
                query = query.Where(x => x.DateOperation <= dateFin);

            if (!string.IsNullOrEmpty(type))
                query = query.Where(x => x.TypeOperation == type);

            if (caisseId != null)
                query = query.Where(x => x.JourneeCaisse.CaisseId == caisseId);

            var data = query.Select(x => new
            {
                x.DateOperation,
                Caisse = x.JourneeCaisse.Caisse.ChkDescription,
                x.TypeOperation,
                x.Montant,
                x.Libelle
            }).ToList();

            return Json(data);
        }

        #region RAPPORT CAISSES
        public IActionResult Operations(DateTime? dateDebut,
                                   DateTime? dateFin,
                                   int? caisseId,
                                   string? typeOperation)
        {
            var query = _context.OperationsCaisses
                .Include(x => x.JourneeCaisse)
                .Include(x => x.Utilisateur)
                .Include(x => x.Client)
                .AsQueryable();

            if (dateDebut.HasValue)
                query = query.Where(x => x.DateOperation >= dateDebut.Value);

            if (dateFin.HasValue)
                query = query.Where(x => x.DateOperation <= dateFin.Value);

            if (caisseId.HasValue)
                query = query.Where(x => x.JourneeCaisse.CaisseId == caisseId);

            if (!string.IsNullOrWhiteSpace(typeOperation))
                query = query.Where(x => x.TypeOperation == typeOperation);

            var model = new RapportOperationsVM
            {
                DateDebut = dateDebut,
                DateFin = dateFin,
                CaisseId = caisseId,
                TypeOperation = typeOperation,
                Operations = query
                    .OrderByDescending(x => x.DateOperation)
                    .ToList()
            };

            model.TotalEntrees = model.Operations
                .Where(x => x.TypeOperation == "Encaissement")
                .Sum(x => x.Montant);

            model.TotalSorties = model.Operations
                .Where(x => x.TypeOperation == "Décaissement")
                .Sum(x => x.Montant);

            model.MontantInitialJournees = _context.JourneesCaisses
                .Where(j =>
                    (!dateDebut.HasValue || j.DateJournee >= dateDebut.Value) &&
                    (!dateFin.HasValue || j.DateJournee <= dateFin.Value) &&
                    (!caisseId.HasValue || j.CaisseId == caisseId.Value))
                .Sum(j => (decimal?)j.SoldeInitial) ?? 0;

            ViewBag.Caisses = new SelectList(_context.Caisses, "ID", "ChkDescription");

            return View(model);
        }

        public IActionResult PreviewOperations(DateTime? dateDebut,
                                       DateTime? dateFin,
                                       int? caisseId,
                                       string? typeOperation)
        {
            var query = _context.OperationsCaisses
                .Include(x => x.JourneeCaisse)
                .Include(x => x.Utilisateur)
                .Include(x => x.Client)
                .AsQueryable();

            if (dateDebut.HasValue)
                query = query.Where(x => x.DateOperation >= dateDebut);

            if (dateFin.HasValue)
                query = query.Where(x => x.DateOperation <= dateFin);

            if (caisseId.HasValue)
                query = query.Where(x => x.JourneeCaisse.CaisseId == caisseId);

            if (!string.IsNullOrEmpty(typeOperation))
                query = query.Where(x => x.TypeOperation == typeOperation);

            var model = new RapportOperationsVM
            {
                DateDebut = dateDebut,
                DateFin = dateFin,
                CaisseId = caisseId,
                TypeOperation = typeOperation,
                Operations = query.OrderByDescending(x => x.DateOperation).ToList()
            };

            model.TotalEntrees = model.Operations
                .Where(x => x.TypeOperation == "Encaissement")
                .Sum(x => x.Montant);

            model.TotalSorties = model.Operations
                .Where(x => x.TypeOperation == "Décaissement")
                .Sum(x => x.Montant);

            model.MontantInitialJournees = _context.JourneesCaisses
                .Where(j =>
                    (!dateDebut.HasValue || j.DateJournee >= dateDebut.Value) &&
                    (!dateFin.HasValue || j.DateJournee <= dateFin.Value) &&
                    (!caisseId.HasValue || j.CaisseId == caisseId.Value))
                .Sum(j => (decimal?)j.SoldeInitial) ?? 0;

            return View(model);
        }

        // Export des écritures (encaissements/décaissements) au format Sage 100
        // Comptabilité : 2 lignes par mouvement (débit/crédit).
        public IActionResult ExportSage(DateTime? dateDebut,
                                         DateTime? dateFin,
                                         int? caisseId,
                                         string? typeOperation)
        {
            var query = _context.OperationsCaisses
                .Include(x => x.JourneeCaisse).ThenInclude(j => j.Caisse)
                .Include(x => x.Motif)
                .Include(x => x.Client)
                .AsQueryable();

            if (dateDebut.HasValue)
                query = query.Where(x => x.DateOperation >= dateDebut.Value);

            if (dateFin.HasValue)
                query = query.Where(x => x.DateOperation <= dateFin.Value);

            if (caisseId.HasValue)
                query = query.Where(x => x.JourneeCaisse.CaisseId == caisseId);

            if (!string.IsNullOrWhiteSpace(typeOperation))
                query = query.Where(x => x.TypeOperation == typeOperation);

            var operations = query.OrderBy(x => x.DateOperation).ToList();

            using var workbook = new XLWorkbook();
            var sheet = workbook.Worksheets.Add("Ecritures");

            string[] entetes =
            {
                "CodeCaisse", "DateEcriture", "CompteGeneral", "CompteTiers",
                "Libelle", "Debit", "Credit", "NumeroPiece"
            };

            for (int c = 0; c < entetes.Length; c++)
            {
                sheet.Cell(1, c + 1).Value = entetes[c];
            }

            var headerRow = sheet.Range(1, 1, 1, entetes.Length);
            headerRow.Style.Font.Bold = true;
            headerRow.Style.Fill.BackgroundColor = XLColor.DarkBlue;
            headerRow.Style.Font.FontColor = XLColor.White;

            int ligne = 2;
            var anomalies = new List<string>();

            foreach (var op in operations)
            {
                var caisse = op.JourneeCaisse.Caisse;
                var numeroPiece = "OP" + op.Id.ToString("000000");
                var libelle = string.IsNullOrWhiteSpace(op.Libelle)
                    ? (op.Motif?.LibelleMotif ?? op.TypeOperation)
                    : op.Libelle;
                var compteCaisse = caisse.CompteComptable;
                // Compte du motif en priorité (plus spécifique), sinon celui du tiers.
                var compteContrepartie = op.Motif?.CG_Num;
                if (string.IsNullOrWhiteSpace(compteContrepartie))
                    compteContrepartie = op.Client?.CompteGeneral;
                var compteTiers = op.Client?.CodeClient;

                if (string.IsNullOrWhiteSpace(compteCaisse))
                    anomalies.Add($"{numeroPiece} : compte comptable manquant sur la caisse \"{caisse.ChkDescription}\".");

                if (string.IsNullOrWhiteSpace(compteContrepartie))
                    anomalies.Add($"{numeroPiece} : aucun motif ni tiers avec compte général renseigné, compte de contrepartie vide.");

                bool estEncaissement = op.TypeOperation == "Encaissement";

                // Ligne côté caisse
                EcrireLigne(sheet, ligne++, caisse.ChkCode, op.DateOperation,
                    compteCaisse, null, libelle,
                    debit: estEncaissement ? op.Montant : 0,
                    credit: estEncaissement ? 0 : op.Montant,
                    numeroPiece);

                // Ligne côté contrepartie (motif / tiers)
                EcrireLigne(sheet, ligne++, caisse.ChkCode, op.DateOperation,
                    compteContrepartie, compteTiers, libelle,
                    debit: estEncaissement ? 0 : op.Montant,
                    credit: estEncaissement ? op.Montant : 0,
                    numeroPiece);
            }

            sheet.Columns().AdjustToContents();

            if (anomalies.Any())
            {
                var feuilleAnomalies = workbook.Worksheets.Add("Anomalies");
                feuilleAnomalies.Cell(1, 1).Value = "Écritures à compléter avant import (compte manquant)";
                feuilleAnomalies.Cell(1, 1).Style.Font.Bold = true;

                for (int i = 0; i < anomalies.Count; i++)
                {
                    feuilleAnomalies.Cell(i + 2, 1).Value = anomalies[i];
                }

                feuilleAnomalies.Column(1).AdjustToContents();
            }

            using var stream = new MemoryStream();
            workbook.SaveAs(stream);
            stream.Position = 0;

            var fileName = $"Export_Sage_{DateTime.Now:yyyyMMdd_HHmm}.xlsx";
            return File(stream.ToArray(),
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                fileName);
        }

        private static void EcrireLigne(
            IXLWorksheet sheet, int ligne,
            string? codeCaisse, DateTime dateEcriture,
            string? compteGeneral, string? compteTiers,
            string libelle, decimal debit, decimal credit,
            string numeroPiece)
        {
            sheet.Cell(ligne, 1).Value = codeCaisse;
            sheet.Cell(ligne, 2).Value = dateEcriture.Date;
            sheet.Cell(ligne, 2).Style.DateFormat.Format = "dd/MM/yyyy";
            sheet.Cell(ligne, 3).Value = compteGeneral;
            sheet.Cell(ligne, 4).Value = compteTiers;
            sheet.Cell(ligne, 5).Value = libelle;
            sheet.Cell(ligne, 6).Value = debit;
            sheet.Cell(ligne, 7).Value = credit;
            sheet.Cell(ligne, 8).Value = numeroPiece;
        }
        #endregion

        #region RAPPORT JOURNEES

        public IActionResult Journees(DateTime? dateDebut,
                                      DateTime? dateFin,
                                      int? caisseId,
                                      string? statut)
        {
            var query = _context.JourneesCaisses
                .Include(x => x.Caisse)
                .AsQueryable();

            if (dateDebut.HasValue)
                query = query.Where(x => x.DateJournee >= dateDebut.Value);

            if (dateFin.HasValue)
                query = query.Where(x => x.DateJournee <= dateFin.Value);

            if (caisseId.HasValue)
                query = query.Where(x => x.CaisseId == caisseId);

            if (!string.IsNullOrWhiteSpace(statut))
                query = query.Where(x => x.Statut == statut);

            var model = new RapportJourneesVM
            {
                DateDebut = dateDebut,
                DateFin = dateFin,
                CaisseId = caisseId,
                Statut = statut,
                Journees = query
                    .OrderByDescending(x => x.DateJournee)
                    .ToList()
            };

            ViewBag.Caisses = new SelectList(_context.Caisses, "ID", "ChkDescription");

            return View(model);
        }

        #endregion

        #region RAPPORT CAISSES

        public IActionResult Caisses(string? recherche)
        {
            var query = _context.Caisses.AsQueryable();

            if (!string.IsNullOrWhiteSpace(recherche))
            {
                query = query.Where(x =>
                    x.ChkCode.Contains(recherche) ||
                    x.ChkDescription.Contains(recherche));
            }

            var model = new RapportCaissesVM
            {
                Recherche = recherche,
                Caisses = query
                    .OrderBy(x => x.ChkDescription)
                    .ToList()
            };

            return View(model);
        }

        #endregion

    }
}