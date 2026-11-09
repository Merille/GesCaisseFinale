using ClosedXML.Excel;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Rapport des tiers : synthèse par tiers sur une période (ventes du point de vente, encaissements,
    // décaissements, solde), export Excel et impression ; relevé détaillé d'un tiers (opérations de
    // caisse et ventes de la période), imprimable. Les opérations rejetées et les ventes annulées
    // sont exclues des montants. Même fonctionnement que la version PHP (rapporttiers.php).
    public class RapportTiersController : Controller
    {
        private readonly AppDbContext _context;

        public RapportTiersController(AppDbContext context)
        {
            _context = context;
        }

        private static FiltresRapportTiers Filtres(DateTime? du, DateTime? au, string? type, string? genre, string? tous)
        {
            var f = new FiltresRapportTiers
            {
                Du = (du ?? new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1)).Date,
                Au = (au ?? DateTime.Today).Date,
                Type = FiltresRapportTiers.Types.Contains(type) ? type! : "",
                Genre = Client.Genres.Contains(genre) ? genre! : "",
                Tous = tous == "1"
            };
            if (f.Au < f.Du)
                (f.Du, f.Au) = (f.Au, f.Du);
            return f;
        }

        private async Task<RapportTiersVM> Donnees(FiltresRapportTiers f)
        {
            var fin = f.Au.AddDays(1);
            var clients = _context.Clients.AsQueryable();
            if (f.Type != "")
                clients = clients.Where(c => c.Type == f.Type);
            if (f.Genre != "")
                clients = clients.Where(c => c.Genre == f.Genre);
            var listeClients = await clients.OrderBy(c => c.NomSociete).ThenBy(c => c.Id).ToListAsync();

            var ventes = (await _context.CommandesPos
                    .Where(c => c.ClientId != null && c.Statut != "Annulée" && c.DateCommande >= f.Du && c.DateCommande < fin)
                    .Select(c => new { c.ClientId, c.CommandeOrigineId, c.TotalTTC, c.DateCommande }).ToListAsync())
                .GroupBy(c => c.ClientId!.Value)
                .ToDictionary(g => g.Key, g => (Nb: g.Count(c => c.CommandeOrigineId == null), Total: g.Sum(c => c.TotalTTC), Derniere: g.Max(c => c.DateCommande)));
            var operations = (await _context.OperationsCaisses
                    .Where(o => o.ClientId != null && o.StatutValidation != OperationCaisseQueries.StatutRejete
                        && o.DateOperation >= f.Du && o.DateOperation < fin)
                    .Select(o => new { o.ClientId, o.TypeOperation, o.Montant, o.DateOperation }).ToListAsync())
                .GroupBy(o => o.ClientId!.Value)
                .ToDictionary(g => g.Key, g => (
                    Enc: g.Where(o => o.TypeOperation == "Encaissement").Sum(o => o.Montant),
                    Dec: g.Where(o => o.TypeOperation == "Décaissement").Sum(o => o.Montant),
                    Derniere: g.Max(o => o.DateOperation)));

            var lignes = new List<LigneRapportTiers>();
            foreach (var c in listeClients)
            {
                var aVentes = ventes.TryGetValue(c.Id, out var v);
                var aOps = operations.TryGetValue(c.Id, out var o);
                if (!f.Tous && !aVentes && !aOps)
                    continue;
                DateTime? dernier = aVentes ? v.Derniere : null;
                if (aOps && (dernier == null || o.Derniere > dernier))
                    dernier = o.Derniere;
                lignes.Add(new LigneRapportTiers
                {
                    Id = c.Id, Code = c.CodeClient, Nom = c.NomSociete, Genre = c.Genre, Type = c.Type,
                    NbVentes = aVentes ? v.Nb : 0, Ventes = aVentes ? v.Total : 0,
                    Encaissements = aOps ? o.Enc : 0, Decaissements = aOps ? o.Dec : 0, Dernier = dernier
                });
            }
            return new RapportTiersVM { Filtres = f, Lignes = lignes };
        }

        public async Task<IActionResult> Index(DateTime? du, DateTime? au, string? type, string? genre, string? tous)
            => View(await Donnees(Filtres(du, au, type, genre, tous)));

        public async Task<IActionResult> Imprimer(DateTime? du, DateTime? au, string? type, string? genre, string? tous)
            => View(await Donnees(Filtres(du, au, type, genre, tous)));

        public async Task<IActionResult> Excel(DateTime? du, DateTime? au, string? type, string? genre, string? tous)
        {
            var d = await Donnees(Filtres(du, au, type, genre, tous));
            using var classeur = new XLWorkbook();
            var feuille = classeur.Worksheets.Add("Tiers");
            var entetes = new[] { "Code", "Tiers", "Genre", "Type", "Nombre de ventes", "Ventes nettes", "Encaissements", "Décaissements", "Solde", "Dernier mouvement" };
            for (var i = 0; i < entetes.Length; i++)
                feuille.Cell(1, i + 1).Value = entetes[i];
            var ligne = 2;
            foreach (var l in d.Lignes)
            {
                feuille.Cell(ligne, 1).Value = l.Code;
                feuille.Cell(ligne, 2).Value = l.Nom;
                feuille.Cell(ligne, 3).Value = l.Genre;
                feuille.Cell(ligne, 4).Value = l.Type ?? "";
                feuille.Cell(ligne, 5).Value = l.NbVentes;
                feuille.Cell(ligne, 6).Value = l.Ventes;
                feuille.Cell(ligne, 7).Value = l.Encaissements;
                feuille.Cell(ligne, 8).Value = l.Decaissements;
                feuille.Cell(ligne, 9).Value = l.Solde;
                feuille.Cell(ligne, 10).Value = l.Dernier?.ToString("dd/MM/yyyy HH:mm") ?? "";
                ligne++;
            }
            feuille.Cell(ligne, 1).Value = "Total";
            feuille.Cell(ligne, 2).Value = $"{d.Lignes.Count} tiers";
            feuille.Cell(ligne, 5).Value = d.NbVentes;
            feuille.Cell(ligne, 6).Value = d.Ventes;
            feuille.Cell(ligne, 7).Value = d.Encaissements;
            feuille.Cell(ligne, 8).Value = d.Decaissements;
            feuille.Cell(ligne, 9).Value = d.Solde;
            var entete = feuille.Row(1);
            entete.Style.Font.Bold = true;
            entete.Style.Fill.BackgroundColor = XLColor.FromHtml("#195D84");
            entete.Style.Font.FontColor = XLColor.White;
            feuille.Columns().AdjustToContents();
            using var flux = new MemoryStream();
            classeur.SaveAs(flux);
            return File(flux.ToArray(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"Rapport_tiers_{d.Filtres.Du:yyyyMMdd}_{d.Filtres.Au:yyyyMMdd}.xlsx");
        }

        // Relevé d'un tiers sur la période : opérations de caisse et ventes du point de vente.
        public async Task<IActionResult> Releve(int id, DateTime? du, DateTime? au, string? type, string? genre, string? tous)
        {
            var f = Filtres(du, au, type, genre, tous);
            var tiers = await _context.Clients.FirstOrDefaultAsync(c => c.Id == id);
            if (tiers == null)
                return NotFound();
            var fin = f.Au.AddDays(1);
            var operations = await _context.OperationsCaisses.Include(o => o.JourneeCaisse).Include(o => o.ModePaiement)
                .Where(o => o.ClientId == id && o.DateOperation >= f.Du && o.DateOperation < fin)
                .OrderBy(o => o.DateOperation).ThenBy(o => o.Id).ToListAsync();
            var ventes = await _context.CommandesPos
                .Where(c => c.ClientId == id && c.DateCommande >= f.Du && c.DateCommande < fin)
                .OrderBy(c => c.DateCommande).ThenBy(c => c.Id).ToListAsync();
            var retenues = operations.NonRejetees().ToList();
            return View(new ReleveTiersVM
            {
                Filtres = f, Tiers = tiers, Operations = operations, Ventes = ventes,
                Encaissements = retenues.Where(o => o.TypeOperation == "Encaissement").Sum(o => o.Montant),
                Decaissements = retenues.Where(o => o.TypeOperation == "Décaissement").Sum(o => o.Montant),
                VentesNettes = ventes.Where(v => v.Statut != "Annulée").Sum(v => v.TotalTTC)
            });
        }
    }
}
