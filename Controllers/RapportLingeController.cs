using ClosedXML.Excel;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Models.ViewModels;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Rapport des dépôts de linge (laverie) : sur une période (date de dépôt), synthèse par statut
    // (nombre, articles, montant, acomptes, reste à encaisser) et détail des dépôts. Les filtres
    // « À retirer » et « En retard » prennent tous les dépôts non retirés, quelle que soit leur date.
    // Impression / PDF et export Excel. Même fonctionnement que la version PHP (rapportlinge.php).
    [Authorize(Policy = "Admin")]
    public class RapportLingeController : Controller
    {
        private readonly AppDbContext _context;

        public RapportLingeController(AppDbContext context)
        {
            _context = context;
        }

        private static FiltresRapportLinge Filtres(DateTime? du, DateTime? au, string? statut)
        {
            var f = new FiltresRapportLinge
            {
                Du = (du ?? new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1)).Date,
                Au = (au ?? DateTime.Today).Date,
                Statut = FiltresRapportLinge.Choix.Contains(statut) ? statut! : ""
            };
            if (f.Au < f.Du)
                (f.Du, f.Au) = (f.Au, f.Du);
            return f;
        }

        private async Task<RapportLingeVM> Donnees(FiltresRapportLinge f)
        {
            var requete = _context.DepotsLinge.AsQueryable();
            if (f.SansPeriode)
            {
                requete = requete.Where(d => d.Statut == DepotLinge.EnCours || d.Statut == DepotLinge.Pret);
                if (f.Statut == "En retard")
                    requete = requete.Where(d => d.DateRetraitPrevue < DateTime.Today);
            }
            else
            {
                var fin = f.Au.AddDays(1);
                requete = requete.Where(d => d.DateDepot >= f.Du && d.DateDepot < fin);
                if (f.Statut != "")
                    requete = requete.Where(d => d.Statut == f.Statut);
            }
            var depots = await requete.OrderBy(d => d.DateDepot).ThenBy(d => d.Numero).ToListAsync();
            var caisses = await _context.Caisses.ToDictionaryAsync(c => c.ID, c => c.ChkCode);
            var utilisateurs = await Restaurant.NomsAsync(_context, depots.Select(d => d.UtilisateurId));
            var ventes = depots.Where(d => d.CommandePosId.HasValue).Select(d => d.CommandePosId!.Value).ToList();
            var numeros = await _context.CommandesPos.Where(c => ventes.Contains(c.Id)).ToDictionaryAsync(c => c.Id, c => c.Numero);
            var lignes = depots.Select(d =>
            {
                var actif = DepotLinge.Actifs.Contains(d.Statut);
                return new LigneDepotLinge
                {
                    Depot = d, Caisse = caisses.GetValueOrDefault(d.CaisseId),
                    Utilisateur = d.UtilisateurId.HasValue ? utilisateurs.GetValueOrDefault(d.UtilisateurId.Value) : null,
                    NumeroVente = d.CommandePosId.HasValue ? numeros.GetValueOrDefault(d.CommandePosId.Value) : null,
                    Reste = actif ? Math.Max(0, d.Total - d.Acompte) : 0,
                    EnRetard = actif && d.DateRetraitPrevue.HasValue && d.DateRetraitPrevue.Value.Date < DateTime.Today
                };
            }).ToList();
            var parStatut = FiltresRapportLinge.Statuts.ToDictionary(s => s, _ => new SyntheseLinge());
            var total = new SyntheseLinge();
            foreach (var l in lignes)
            {
                if (parStatut.TryGetValue(l.Depot.Statut, out var s))
                    s.Ajouter(l);
                if (l.Depot.Statut != DepotLinge.Annule)
                    total.Ajouter(l);
            }
            return new RapportLingeVM { Filtres = f, Lignes = lignes, ParStatut = parStatut, Total = total };
        }

        public async Task<IActionResult> Index(DateTime? du, DateTime? au, string? statut)
            => View(await Donnees(Filtres(du, au, statut)));

        public async Task<IActionResult> Imprimer(DateTime? du, DateTime? au, string? statut)
            => View(await Donnees(Filtres(du, au, statut)));

        public async Task<IActionResult> Excel(DateTime? du, DateTime? au, string? statut)
        {
            var d = await Donnees(Filtres(du, au, statut));
            using var classeur = new XLWorkbook();
            var synthese = classeur.Worksheets.Add("Synthèse");
            var entetes = new[] { "Statut", "Dépôts", "Articles", "Montant", "Acomptes", "Reste à encaisser", "En retard" };
            for (var i = 0; i < entetes.Length; i++)
                synthese.Cell(1, i + 1).Value = entetes[i];
            var ligne = 2;
            foreach (var (statut2, s) in d.ParStatut.Append(new KeyValuePair<string, SyntheseLinge>("Total (hors annulés)", d.Total)))
            {
                synthese.Cell(ligne, 1).Value = statut2;
                synthese.Cell(ligne, 2).Value = s.Nombre;
                synthese.Cell(ligne, 3).Value = s.Articles;
                synthese.Cell(ligne, 4).Value = s.Montant;
                synthese.Cell(ligne, 5).Value = s.Acomptes;
                synthese.Cell(ligne, 6).Value = s.Reste;
                synthese.Cell(ligne, 7).Value = s.EnRetard;
                ligne++;
            }
            var detail = classeur.Worksheets.Add("Dépôts");
            entetes = new[] { "N°", "Déposé le", "Caisse", "Client", "Téléphone", "Articles", "Montant", "Acompte", "Reste à encaisser", "Retrait prévu", "Statut", "Retiré / annulé le", "Vente", "Reçu par" };
            for (var i = 0; i < entetes.Length; i++)
                detail.Cell(1, i + 1).Value = entetes[i];
            ligne = 2;
            foreach (var l in d.Lignes)
            {
                var x = l.Depot;
                detail.Cell(ligne, 1).Value = x.Numero;
                detail.Cell(ligne, 2).Value = x.DateDepot.ToString("dd/MM/yyyy HH:mm");
                detail.Cell(ligne, 3).Value = l.Caisse ?? "";
                detail.Cell(ligne, 4).Value = x.NomClient;
                detail.Cell(ligne, 5).Value = x.TelephoneClient ?? "";
                detail.Cell(ligne, 6).Value = x.NbArticles;
                detail.Cell(ligne, 7).Value = x.Total;
                detail.Cell(ligne, 8).Value = x.Acompte;
                detail.Cell(ligne, 9).Value = l.Reste;
                detail.Cell(ligne, 10).Value = x.DateRetraitPrevue?.ToString("dd/MM/yyyy") ?? "";
                detail.Cell(ligne, 11).Value = x.Statut + (l.EnRetard ? " (en retard)" : "");
                detail.Cell(ligne, 12).Value = l.Fin?.ToString("dd/MM/yyyy HH:mm") ?? "";
                detail.Cell(ligne, 13).Value = l.NumeroVente ?? "";
                detail.Cell(ligne, 14).Value = l.Utilisateur ?? "";
                ligne++;
            }
            foreach (var feuille in classeur.Worksheets)
            {
                var entete = feuille.Row(1);
                entete.Style.Font.Bold = true;
                entete.Style.Fill.BackgroundColor = XLColor.FromHtml("#195D84");
                entete.Style.Font.FontColor = XLColor.White;
                feuille.Columns().AdjustToContents();
            }
            using var flux = new MemoryStream();
            classeur.SaveAs(flux);
            return File(flux.ToArray(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"Rapport_depots_linge_{d.Filtres.Du:yyyyMMdd}_{d.Filtres.Au:yyyyMMdd}.xlsx");
        }
    }
}
