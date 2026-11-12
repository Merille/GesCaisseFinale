using ClosedXML.Excel;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Models.ViewModels;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Rapport des achats et consommations (laverie) : sur une période (date d'achat) et, au besoin, un
    // fournisseur : cartes (achats, montant, réglé, reste à payer, valeur consommée), synthèse par
    // fournisseur, synthèse par produit (acheté : quantité, montant, prix moyen ; consommé : quantité et
    // valeur au coût ; stock du dépôt des achats) et détail des achats. Les totaux ne comptent pas les
    // achats annulés. Impression / PDF et export Excel. Même fonctionnement que rapportachat.php.
    [Authorize(Policy = "Admin")]
    public class RapportAchatController : Controller
    {
        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public RapportAchatController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        private async Task<RapportAchatVM> Donnees(DateTime? du, DateTime? au, int fournisseur)
        {
            var f = new FiltresRapportAchat
            {
                Du = (du ?? new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1)).Date,
                Au = (au ?? DateTime.Today).Date,
                Fournisseur = fournisseur
            };
            if (f.Au < f.Du)
                (f.Du, f.Au) = (f.Au, f.Du);
            if (fournisseur > 0)
                f.NomFournisseur = await _context.Clients.Where(c => c.Id == fournisseur).Select(c => c.NomSociete).FirstOrDefaultAsync() ?? "";

            var requete = _context.Achats.Where(a => a.DateAchat >= f.Du && a.DateAchat <= f.Au);
            if (fournisseur > 0)
                requete = requete.Where(a => a.FournisseurId == fournisseur);
            var achats = await requete.OrderBy(a => a.DateAchat).ThenBy(a => a.Numero)
                .Select(a => new LigneRapportAchat
                {
                    Achat = a, Regle = a.Reglements.Sum(r => r.Montant),
                    Fournisseur = _context.Clients.Where(c => c.Id == a.FournisseurId).Select(c => c.NomSociete).FirstOrDefault()
                }).ToListAsync();
            var noms = await Restaurant.NomsAsync(_context, achats.Select(a => a.Achat.UtilisateurId));
            var vm = new RapportAchatVM { Filtres = f, Achats = achats };
            foreach (var l in achats)
            {
                l.Utilisateur = l.Achat.UtilisateurId is int u ? noms.GetValueOrDefault(u) : null;
                if (l.Achat.Statut != Achat.Valide)
                    continue;
                l.Reste = Math.Max(0, Math.Round(l.Achat.Total - l.Regle, 2));
                vm.Total.Ajouter(l);
                var nom = l.Fournisseur ?? "Sans fournisseur";
                if (!vm.ParFournisseur.TryGetValue(nom, out var s))
                    vm.ParFournisseur[nom] = s = new SyntheseAchats();
                s.Ajouter(l);
            }

            // Par produit : achats validés de la période et consommations de la période (tous fournisseurs).
            var depot = _tenant.TenantId > 0 ? (await _context.DepotDesAchatsAsync(_tenant.TenantId)).Id : 0;
            var stocks = await _context.StocksDepots.Where(s => s.DepotId == depot).ToDictionaryAsync(s => s.ProduitId, s => s.Quantite);
            var produits = new Dictionary<int, ProduitRapportAchat>();
            ProduitRapportAchat Ligne(Produit p) => produits.TryGetValue(p.Id, out var x) ? x : produits[p.Id] = new ProduitRapportAchat
            {
                Code = p.Code, Nom = p.Nom, Unite = p.Unite, Stock = stocks.GetValueOrDefault(p.Id)
            };
            var ids = achats.Where(a => a.Achat.Statut == Achat.Valide).Select(a => a.Achat.Id).ToList();
            var lignes = await _context.LignesAchats.Where(l => ids.Contains(l.AchatId))
                .Join(_context.Produits, l => l.ProduitId, p => p.Id, (l, p) => new { l.Quantite, l.Montant, Produit = p }).ToListAsync();
            foreach (var g in lignes.GroupBy(l => l.Produit.Id))
            {
                var x = Ligne(g.First().Produit);
                x.QteAchetee = g.Sum(l => l.Quantite);
                x.MontantAchete = g.Sum(l => l.Montant);
            }
            var fin = f.Au.AddDays(1);
            var consommations = await _context.MouvementsStock.Include(m => m.Produit)
                .Where(m => m.TypeMouvement == "Consommation" && m.DateMouvement >= f.Du && m.DateMouvement < fin).ToListAsync();
            foreach (var g in consommations.GroupBy(m => m.ProduitId))
            {
                if (fournisseur > 0 && !produits.ContainsKey(g.Key))
                    continue;
                var p = g.First().Produit;
                var x = Ligne(p);
                x.QteConsommee = -g.Sum(m => m.Quantite);
                x.ValeurConsommee = x.QteConsommee * (p.Cout ?? 0);
            }
            vm.Produits = produits.Values.OrderBy(p => p.Nom, StringComparer.Ordinal).ToList();
            vm.Fournisseurs = await _context.Clients.Where(c => c.Type == "Fournisseur").OrderBy(c => c.NomSociete).ToListAsync();
            return vm;
        }

        public async Task<IActionResult> Index(DateTime? du, DateTime? au, int fournisseur = 0)
            => View(await Donnees(du, au, fournisseur));

        public async Task<IActionResult> Imprimer(DateTime? du, DateTime? au, int fournisseur = 0)
            => View(await Donnees(du, au, fournisseur));

        public async Task<IActionResult> Excel(DateTime? du, DateTime? au, int fournisseur = 0)
        {
            var d = await Donnees(du, au, fournisseur);
            using var classeur = new XLWorkbook();
            void Feuille(string nom, string[] entetes, IEnumerable<object?[]> lignes)
            {
                var f = classeur.Worksheets.Add(nom);
                for (var i = 0; i < entetes.Length; i++)
                    f.Cell(1, i + 1).Value = entetes[i];
                var r = 2;
                foreach (var l in lignes)
                {
                    for (var i = 0; i < l.Length; i++)
                        f.Cell(r, i + 1).Value = l[i] switch
                        {
                            null => "", decimal m => m, int n => n, var o => o.ToString()
                        };
                    r++;
                }
                var entete = f.Row(1);
                entete.Style.Font.Bold = true;
                entete.Style.Fill.BackgroundColor = XLColor.FromHtml("#195D84");
                entete.Style.Font.FontColor = XLColor.White;
                f.Columns().AdjustToContents();
            }
            Feuille("Fournisseurs", new[] { "Fournisseur", "Achats", "Montant", "Réglé", "Reste à payer" },
                d.ParFournisseur.Select(p => new object?[] { p.Key, p.Value.Nombre, p.Value.Montant, p.Value.Regle, p.Value.Reste })
                    .Append(new object?[] { "Total (hors annulés)", d.Total.Nombre, d.Total.Montant, d.Total.Regle, d.Total.Reste }));
            Feuille("Produits", new[] { "Code", "Produit", "Unité", "Quantité achetée", "Montant acheté", "Prix moyen", "Quantité consommée", "Valeur consommée", "Stock (dépôt des achats)" },
                d.Produits.Select(p => new object?[] { p.Code, p.Nom, p.Unite, p.QteAchetee, p.MontantAchete,
                    p.PrixMoyen.HasValue ? Math.Round(p.PrixMoyen.Value, 2) : null, p.QteConsommee, Math.Round(p.ValeurConsommee, 2), p.Stock }));
            Feuille("Achats", new[] { "N°", "Date", "Fournisseur", "Référence", "Montant", "Réglé", "Reste à payer", "Statut", "Saisi par" },
                d.Achats.Select(a => new object?[] { a.Achat.Numero, a.Achat.DateAchat.ToString("dd/MM/yyyy"), a.Fournisseur, a.Achat.Reference,
                    a.Achat.Total, a.Regle, a.Reste, a.Statut, a.Utilisateur }));
            using var flux = new MemoryStream();
            classeur.SaveAs(flux);
            return File(flux.ToArray(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"Rapport_achats_{d.Filtres.Du:yyyyMMdd}_{d.Filtres.Au:yyyyMMdd}.xlsx");
        }
    }
}
