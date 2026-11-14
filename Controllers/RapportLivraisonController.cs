using System.Text.Json;
using ClosedXML.Excel;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models.ViewModels;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Rapport des livraisons : sur une période, synthèse par livreur (livraisons, livrées, en cours,
    // montant des ventes, frais de livraison) et détail des livraisons — ventes livrées ou à livrer,
    // et commandes confiées au livreur, à encaisser à son retour. Les ventes annulées sont exclues.
    // Impression / PDF et export Excel. Même fonctionnement que la version PHP (rapportlivraison.php).
    public class RapportLivraisonController : Controller
    {
        private readonly AppDbContext _context;

        public RapportLivraisonController(AppDbContext context)
        {
            _context = context;
        }

        private static FiltresRapportLivraison Filtres(DateTime? du, DateTime? au, int? livreur, string? statut)
        {
            var f = new FiltresRapportLivraison
            {
                Du = (du ?? new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1)).Date,
                Au = (au ?? DateTime.Today).Date,
                Livreur = livreur ?? 0,
                Statut = FiltresRapportLivraison.Statuts.Contains(statut) ? statut! : ""
            };
            if (f.Au < f.Du)
                (f.Du, f.Au) = (f.Au, f.Du);
            return f;
        }

        private async Task<RapportLivraisonVM> Donnees(FiltresRapportLivraison f)
        {
            var fin = f.Au.AddDays(1);
            var livreurs = await _context.Livreurs.OrderBy(l => l.Nom).ToListAsync();
            var parId = livreurs.ToDictionary(l => l.Id);
            var clients = await _context.Clients.ToDictionaryAsync(c => c.Id, c => c.NomSociete);
            var ventes = await _context.CommandesPos
                .Where(c => c.LivreurId != null && c.Statut != "Annulée" && c.CommandeOrigineId == null
                            && c.DateCommande >= f.Du && c.DateCommande < fin && (f.Livreur == 0 || c.LivreurId == f.Livreur))
                .ToListAsync();
            var attentes = await _context.CommandesAttente
                .Where(a => a.LivreurId != null && a.DateCreation >= f.Du && a.DateCreation < fin && (f.Livreur == 0 || a.LivreurId == f.Livreur))
                .ToListAsync();
            var lignes = ventes.Select(c => new LigneLivraison
            {
                Id = c.Id, Vente = true, Numero = c.Numero, Date = c.DateCommande, Montant = c.TotalTTC, Frais = c.FraisLivraison,
                Statut = c.StatutLivraison ?? "À livrer", DateLivraison = c.DateLivraison, Destinataire = c.NomLivraison,
                Telephone = c.TelephoneLivraison, Adresse = c.AdresseLivraison, LivreurId = c.LivreurId!.Value,
                Client = c.ClientId.HasValue ? clients.GetValueOrDefault(c.ClientId.Value) : null
            }).ToList();
            foreach (var a in attentes)
            {
                var frais = FraisAttente(a.Contenu);
                lignes.Add(new LigneLivraison
                {
                    Id = a.Id, Numero = "Attente n° " + a.Numero, Date = a.DateCreation, Montant = a.Total - frais, Frais = frais,
                    Statut = "À encaisser", Destinataire = a.NomLivraison, Telephone = a.TelephoneLivraison, Adresse = a.AdresseLivraison,
                    LivreurId = a.LivreurId!.Value, Client = a.ClientId.HasValue ? clients.GetValueOrDefault(a.ClientId.Value) : null
                });
            }
            foreach (var l in lignes)
            {
                var livreur = parId.GetValueOrDefault(l.LivreurId);
                l.Livreur = livreur?.Nom;
                l.Moyen = livreur?.MoyenLivraison;
            }
            if (f.Statut != "")
                lignes = lignes.Where(l => l.Statut == f.Statut).ToList();
            // Tri à la seconde près puis par numéro (comme la version PHP : MySQL ne garde pas les millisecondes).
            lignes = lignes.OrderBy(l => l.Date.Ticks - l.Date.Ticks % TimeSpan.TicksPerSecond).ThenBy(l => l.Numero, StringComparer.Ordinal).ToList();

            var total = new SyntheseLivreur();
            var parLivreur = new Dictionary<int, SyntheseLivreur>();
            foreach (var l in lignes)
            {
                if (!parLivreur.TryGetValue(l.LivreurId, out var s))
                    parLivreur[l.LivreurId] = s = new SyntheseLivreur { Livreur = l.Livreur, Moyen = l.Moyen };
                s.Ajouter(l);
                total.Ajouter(l);
            }
            return new RapportLivraisonVM
            {
                Filtres = f, Lignes = lignes, Total = total, Livreurs = livreurs,
                ParLivreur = parLivreur.Values.OrderBy(s => s.Livreur, StringComparer.Ordinal).ToList()
            };
        }

        // Frais de livraison d'une commande en attente (contenu JSON : livraison.frais).
        private static decimal FraisAttente(string? contenu)
        {
            try
            {
                using var doc = JsonDocument.Parse(string.IsNullOrEmpty(contenu) ? "{}" : contenu);
                return doc.RootElement.TryGetProperty("livraison", out var l) && l.ValueKind == JsonValueKind.Object
                       && l.TryGetProperty("frais", out var fr) && fr.TryGetDecimal(out var v) ? v : 0;
            }
            catch (JsonException) { return 0; }
        }

        public async Task<IActionResult> Index(DateTime? du, DateTime? au, int? livreur, string? statut)
            => View(await Donnees(Filtres(du, au, livreur, statut)));

        public async Task<IActionResult> Imprimer(DateTime? du, DateTime? au, int? livreur, string? statut)
            => View(await Donnees(Filtres(du, au, livreur, statut)));

        public async Task<IActionResult> Excel(DateTime? du, DateTime? au, int? livreur, string? statut)
        {
            var d = await Donnees(Filtres(du, au, livreur, statut));
            using var classeur = new XLWorkbook();
            var synthese = classeur.Worksheets.Add("Livreurs");
            var entetes = new[] { "Livreur", "Moyen", "Livraisons", "Livrées", "À livrer", "À encaisser", "Montant des ventes", "Frais de livraison" };
            for (var i = 0; i < entetes.Length; i++)
                synthese.Cell(1, i + 1).Value = entetes[i];
            var ligne = 2;
            foreach (var s in d.ParLivreur.Append(new SyntheseLivreur
                     {
                         Livreur = "Total", Moyen = "", Livraisons = d.Total.Livraisons, Livrees = d.Total.Livrees, ALivrer = d.Total.ALivrer,
                         AEncaisser = d.Total.AEncaisser, Montant = d.Total.Montant, Frais = d.Total.Frais
                     }))
            {
                synthese.Cell(ligne, 1).Value = s.Livreur ?? "";
                synthese.Cell(ligne, 2).Value = s.Moyen ?? "";
                synthese.Cell(ligne, 3).Value = s.Livraisons;
                synthese.Cell(ligne, 4).Value = s.Livrees;
                synthese.Cell(ligne, 5).Value = s.ALivrer;
                synthese.Cell(ligne, 6).Value = s.AEncaisser;
                synthese.Cell(ligne, 7).Value = s.Montant;
                synthese.Cell(ligne, 8).Value = s.Frais;
                ligne++;
            }
            var detail = classeur.Worksheets.Add("Livraisons");
            entetes = new[] { "Date", "N°", "Livreur", "Moyen", "Client", "Destinataire", "Téléphone", "Adresse", "Montant des ventes", "Frais de livraison", "Statut", "Livrée le" };
            for (var i = 0; i < entetes.Length; i++)
                detail.Cell(1, i + 1).Value = entetes[i];
            ligne = 2;
            foreach (var l in d.Lignes)
            {
                detail.Cell(ligne, 1).Value = l.Date.ToString("dd/MM/yyyy HH:mm");
                detail.Cell(ligne, 2).Value = l.Numero;
                detail.Cell(ligne, 3).Value = l.Livreur ?? "";
                detail.Cell(ligne, 4).Value = l.Moyen ?? "";
                detail.Cell(ligne, 5).Value = l.Client ?? "";
                detail.Cell(ligne, 6).Value = l.Destinataire ?? "";
                detail.Cell(ligne, 7).Value = l.Telephone ?? "";
                detail.Cell(ligne, 8).Value = l.Adresse ?? "";
                detail.Cell(ligne, 9).Value = l.Montant;
                detail.Cell(ligne, 10).Value = l.Frais;
                detail.Cell(ligne, 11).Value = l.Statut;
                detail.Cell(ligne, 12).Value = l.DateLivraison?.ToString("dd/MM/yyyy HH:mm") ?? "";
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
                $"Rapport_livraisons_{d.Filtres.Du:yyyyMMdd}_{d.Filtres.Au:yyyyMMdd}.xlsx");
        }
    }
}
