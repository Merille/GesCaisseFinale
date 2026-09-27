using ClosedXML.Excel;
using EasytransitCaisse.Controllers;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using Rotativa.AspNetCore;
using System.Globalization;
using System.Text;



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

        // Une ligne d'écriture comptable (débit ou crédit), commune aux trois
        // formats d'export Sage (Excel, CSV, texte).
        private class LigneEcritureVM
        {
            public string? CodeCaisse { get; set; }
            public DateTime DateEcriture { get; set; }
            public string? CompteGeneral { get; set; }
            public string? CompteTiers { get; set; }
            public string Libelle { get; set; } = "";
            public decimal Debit { get; set; }
            public decimal Credit { get; set; }
            public string NumeroPiece { get; set; } = "";
        }

        // Construit les écritures (2 lignes par mouvement : débit/crédit) pour
        // l'export Sage, quel que soit le format de fichier de sortie.
        private (List<LigneEcritureVM> Lignes, List<string> Anomalies) GetLignesEcrituresSage(
            DateTime? dateDebut, DateTime? dateFin, int? caisseId, string? typeOperation)
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

            var lignes = new List<LigneEcritureVM>();
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
                lignes.Add(new LigneEcritureVM
                {
                    CodeCaisse = caisse.ChkCode,
                    DateEcriture = op.DateOperation,
                    CompteGeneral = compteCaisse,
                    CompteTiers = null,
                    Libelle = libelle,
                    Debit = estEncaissement ? op.Montant : 0,
                    Credit = estEncaissement ? 0 : op.Montant,
                    NumeroPiece = numeroPiece
                });

                // Ligne côté contrepartie (motif / tiers)
                lignes.Add(new LigneEcritureVM
                {
                    CodeCaisse = caisse.ChkCode,
                    DateEcriture = op.DateOperation,
                    CompteGeneral = compteContrepartie,
                    CompteTiers = compteTiers,
                    Libelle = libelle,
                    Debit = estEncaissement ? 0 : op.Montant,
                    Credit = estEncaissement ? op.Montant : 0,
                    NumeroPiece = numeroPiece
                });
            }

            return (lignes, anomalies);
        }

        // Export des écritures (encaissements/décaissements) au format Sage 100
        // Comptabilité : 2 lignes par mouvement (débit/crédit), fichier Excel.
        public IActionResult ExportSage(DateTime? dateDebut,
                                         DateTime? dateFin,
                                         int? caisseId,
                                         string? typeOperation)
        {
            var (lignes, anomalies) = GetLignesEcrituresSage(dateDebut, dateFin, caisseId, typeOperation);

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

            for (int i = 0; i < lignes.Count; i++)
            {
                var l = lignes[i];
                int r = i + 2;
                sheet.Cell(r, 1).Value = l.CodeCaisse;
                // Texte brut "jjmmaa" (ex: 050825) — format cellule forcé en texte
                // AVANT d'assigner la valeur, sinon Excel interpréterait la chaîne
                // numérique comme un nombre et supprimerait le zéro de tête.
                sheet.Cell(r, 2).Style.NumberFormat.Format = "@";
                sheet.Cell(r, 2).Value = l.DateEcriture.ToString("ddMMyy");
                sheet.Cell(r, 3).Value = l.CompteGeneral;
                sheet.Cell(r, 4).Value = l.CompteTiers;
                sheet.Cell(r, 5).Value = l.Libelle;
                sheet.Cell(r, 6).Value = l.Debit;
                sheet.Cell(r, 7).Value = l.Credit;
                sheet.Cell(r, 8).Value = l.NumeroPiece;
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

        // Même export, au format CSV (point-virgule, avec en-têtes) : plus
        // simple à importer directement dans Sage qu'un classeur Excel.
        public IActionResult ExportSageCsv(DateTime? dateDebut,
                                            DateTime? dateFin,
                                            int? caisseId,
                                            string? typeOperation)
        {
            var (lignes, _) = GetLignesEcrituresSage(dateDebut, dateFin, caisseId, typeOperation);

            var sb = new StringBuilder();
            sb.AppendLine(string.Join(";",
                "CodeCaisse", "DateEcriture", "CompteGeneral", "CompteTiers",
                "Libelle", "Debit", "Credit", "NumeroPiece"));

            foreach (var l in lignes)
            {
                sb.AppendLine(string.Join(";",
                    ChampCsv(l.CodeCaisse),
                    l.DateEcriture.ToString("ddMMyy"),
                    ChampCsv(l.CompteGeneral),
                    ChampCsv(l.CompteTiers),
                    ChampCsv(l.Libelle),
                    l.Debit.ToString("0.00", CultureInfo.InvariantCulture),
                    l.Credit.ToString("0.00", CultureInfo.InvariantCulture),
                    ChampCsv(l.NumeroPiece)));
            }

            var bytes = AvecBom(sb.ToString());
            var fileName = $"Export_Sage_{DateTime.Now:yyyyMMdd_HHmm}.csv";
            return File(bytes, "text/csv", fileName);
        }

        // Même export, au format texte brut (point-virgule, sans en-têtes) :
        // format d'import "standard" attendu par certaines versions de Sage.
        public IActionResult ExportSageTxt(DateTime? dateDebut,
                                            DateTime? dateFin,
                                            int? caisseId,
                                            string? typeOperation)
        {
            var (lignes, _) = GetLignesEcrituresSage(dateDebut, dateFin, caisseId, typeOperation);

            var sb = new StringBuilder();

            foreach (var l in lignes)
            {
                sb.AppendLine(string.Join(";",
                    ChampTxt(l.CodeCaisse),
                    l.DateEcriture.ToString("dd/MM/yyyy"),
                    ChampTxt(l.CompteGeneral),
                    ChampTxt(l.CompteTiers),
                    ChampTxt(l.Libelle),
                    l.Debit.ToString("0.00", CultureInfo.InvariantCulture),
                    l.Credit.ToString("0.00", CultureInfo.InvariantCulture),
                    ChampTxt(l.NumeroPiece)));
            }

            var bytes = AvecBom(sb.ToString());
            var fileName = $"Export_Sage_{DateTime.Now:yyyyMMdd_HHmm}.txt";
            return File(bytes, "text/plain", fileName);
        }

        // Échappement CSV standard : entoure de guillemets si le champ contient
        // le séparateur, un guillemet ou un retour à la ligne.
        private static string ChampCsv(string? valeur)
        {
            valeur ??= "";
            if (valeur.Contains(';') || valeur.Contains('"') || valeur.Contains('\n'))
                return "\"" + valeur.Replace("\"", "\"\"") + "\"";
            return valeur;
        }

        // Le format texte brut ne supporte pas l'échappement par guillemets :
        // on neutralise simplement le séparateur s'il apparaît dans le champ.
        private static string ChampTxt(string? valeur) => (valeur ?? "").Replace(";", ",");

        private static byte[] AvecBom(string contenu) =>
            Encoding.UTF8.GetPreamble().Concat(Encoding.UTF8.GetBytes(contenu)).ToArray();
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