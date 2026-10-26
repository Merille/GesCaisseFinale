using ClosedXML.Excel;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models.ViewModels;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using Rotativa.AspNetCore;

namespace EasytransitCaisse.Controllers
{
    // Rapports du point de vente : tableau de bord, ventes par produit, catégorie, vendeur,
    // heure et mode de paiement, meilleures ventes et panier moyen ; export Excel et PDF.
    // Chiffre d'affaires net TTC = ventes - retours ; les ventes annulées sont exclues.
    [Authorize(Policy = "Admin")]
    public class PosRapportController : Controller
    {
        private const string Annulee = "Annulée";
        private const string Retour = "Retour";

        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public PosRapportController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        public IActionResult Index(DateTime? dateDebut, DateTime? dateFin, int? caisseId)
        {
            ViewBag.Caisses = new SelectList(
                _context.Caisses.OrderBy(c => c.ChkDescription)
                    .Select(c => new { c.ID, Libelle = c.ChkCode + " - " + c.ChkDescription }).ToList(),
                "ID", "Libelle", caisseId);
            return View(Construire(dateDebut, dateFin, caisseId));
        }

        public IActionResult Pdf(DateTime? dateDebut, DateTime? dateFin, int? caisseId)
        {
            var model = Construire(dateDebut, dateFin, caisseId);
            return new ViewAsPdf("Pdf", model)
            {
                FileName = $"Rapport_POS_{model.DateDebut:yyyyMMdd}_{model.DateFin:yyyyMMdd}.pdf",
                PageSize = Rotativa.AspNetCore.Options.Size.A4,
                PageMargins = new Rotativa.AspNetCore.Options.Margins(10, 10, 10, 10)
            };
        }

        public IActionResult Excel(DateTime? dateDebut, DateTime? dateFin, int? caisseId)
        {
            var m = Construire(dateDebut, dateFin, caisseId);
            using var classeur = new XLWorkbook();

            var synthese = new List<object[]>
            {
                new object[] { "Période", $"{m.DateDebut:dd/MM/yyyy} au {m.DateFin:dd/MM/yyyy}" },
                new object[] { "Caisse", m.CaisseLibelle ?? "Toutes" },
                new object[] { "Chiffre d'affaires net TTC", m.ChiffreAffaires },
                new object[] { "Chiffre d'affaires net HT", m.ChiffreAffairesHT },
                new object[] { "Ventes TTC", m.Ventes },
                new object[] { "Retours TTC", m.Retours },
                new object[] { "Tickets de vente", m.Tickets },
                new object[] { "Panier moyen TTC", Math.Round(m.PanierMoyen, 2) },
                new object[] { "Articles vendus (net)", m.Articles },
                new object[] { "Retours", m.NbRetours },
                new object[] { "Ventes annulées", m.Annulees }
            };
            Feuille(classeur, "Synthèse", new[] { "Indicateur", "Valeur" }, synthese);
            Feuille(classeur, "Par produit", new[] { "Rang", "Code", "Produit", "Catégorie", "Quantité", "CA TTC", "Part %" },
                m.Produits.Select((p, i) => new object[] { i + 1, p.Code ?? "", p.Nom, p.Categorie, p.Quantite, p.Montant, Math.Round(m.Part(p.Montant), 1) }));
            Feuille(classeur, "Par catégorie", new[] { "Catégorie", "Quantité", "CA TTC", "Part %" },
                m.Categories.Select(c => new object[] { c.Nom, c.Quantite, c.Montant, Math.Round(m.Part(c.Montant), 1) }));
            Feuille(classeur, "Par vendeur", new[] { "Vendeur", "Tickets", "Ventes TTC", "Retours TTC", "CA net TTC", "Panier moyen" },
                m.Vendeurs.Select(v => new object[] { v.Nom, v.Tickets, v.Ventes, v.Retours, v.Montant, Math.Round(v.PanierMoyen ?? 0, 2) }));
            Feuille(classeur, "Par heure", new[] { "Heure", "Tickets", "CA net TTC" },
                m.ParHeure.Select(h => new object[] { $"{h.Heure:00}h - {(h.Heure + 1) % 24:00}h", h.Tickets, h.Montant }));
            Feuille(classeur, "Par jour", new[] { "Date", "Tickets", "CA net TTC" },
                m.ParJour.Select(j => new object[] { j.Date.ToString("dd/MM/yyyy"), j.Tickets, j.Montant }));
            Feuille(classeur, "Par mode de paiement", new[] { "Mode de paiement", "Tickets", "Encaissé net" },
                m.Modes.Select(x => new object[] { x.Nom, x.Tickets, x.Montant }));
            Feuille(classeur, "Taxes", new[] { "Taxe", "Montant collecté" },
                m.Taxes.Select(x => new object[] { x.Nom, x.Montant }));

            using var flux = new MemoryStream();
            classeur.SaveAs(flux);
            return File(flux.ToArray(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"Rapport_POS_{m.DateDebut:yyyyMMdd}_{m.DateFin:yyyyMMdd}.xlsx");
        }

        private static void Feuille(XLWorkbook classeur, string nom, string[] entetes, IEnumerable<object[]> lignes)
        {
            var f = classeur.Worksheets.Add(nom);
            for (var c = 0; c < entetes.Length; c++)
                f.Cell(1, c + 1).Value = entetes[c];
            var entete = f.Range(1, 1, 1, entetes.Length);
            entete.Style.Font.Bold = true;
            entete.Style.Fill.BackgroundColor = XLColor.FromHtml("#195d84");
            entete.Style.Font.FontColor = XLColor.White;

            var l = 2;
            foreach (var ligne in lignes)
            {
                for (var c = 0; c < ligne.Length; c++)
                {
                    var cellule = f.Cell(l, c + 1);
                    switch (ligne[c])
                    {
                        case decimal d: cellule.Value = d; cellule.Style.NumberFormat.Format = "#,##0.##"; break;
                        case int i: cellule.Value = i; break;
                        default: cellule.Value = ligne[c]?.ToString() ?? ""; break;
                    }
                }
                l++;
            }
            f.Columns().AdjustToContents();
        }

        private PosRapportVM Construire(DateTime? dateDebut, DateTime? dateFin, int? caisseId)
        {
            var aujourdhui = DateTime.Today;
            var du = (dateDebut ?? new DateTime(aujourdhui.Year, aujourdhui.Month, 1)).Date;
            var au = (dateFin ?? aujourdhui).Date;
            if (au < du)
                (du, au) = (au, du);
            var finExclue = au.AddDays(1);

            var commandes = _context.CommandesPos
                .Where(c => c.DateCommande >= du && c.DateCommande < finExclue);
            if (caisseId.HasValue)
                commandes = commandes.Where(c => c.JourneeCaisse!.CaisseId == caisseId);

            var cmds = (from c in commandes
                        join u in _context.Utilisateurs on c.UtilisateurId equals u.Id into us
                        from u in us.DefaultIfEmpty()
                        select new
                        {
                            c.Id, c.Statut, c.DateCommande, c.TotalTTC, c.TotalHT, c.UtilisateurId,
                            Vendeur = u == null ? "?" : (u.NomComplet != null && u.NomComplet != "" ? u.NomComplet : u.NomUtilisateur)
                        }).ToList();

            var nettes = commandes.Where(c => c.Statut != Annulee).Select(c => c.Id);
            var lignes = (from l in _context.LignesCommandePos
                          where nettes.Contains(l.CommandePosId)
                          join p in _context.Produits on l.ProduitId equals p.Id into ps
                          from p in ps.DefaultIfEmpty()
                          join cat in _context.Categories on (p == null ? null : p.CategorieId) equals (int?)cat.Id into cs
                          from cat in cs.DefaultIfEmpty()
                          select new
                          {
                              l.Id, l.TauxTVA, l.ProduitId, l.Libelle, l.Quantite, l.TotalTTC,
                              Nom = p == null ? null : p.Nom,
                              Code = p == null ? null : p.Code,
                              CategorieId = cat == null ? (int?)null : cat.Id,
                              Categorie = cat == null ? null : cat.Nom,
                              Couleur = cat == null ? null : cat.Couleur
                          }).ToList();
            var detailTaxes = (from x in _context.LignesCommandePosTaxes
                               join l in _context.LignesCommandePos on x.LigneCommandePosId equals l.Id
                               where nettes.Contains(l.CommandePosId)
                               select new { x.LigneCommandePosId, x.Code, x.Taux, x.Montant }).ToList();
            var paiements = (from pp in _context.PaiementsPos
                             where nettes.Contains(pp.CommandePosId)
                             select new { pp.CommandePosId, pp.Libelle, pp.Montant }).ToList();

            bool EstVente(string statut) => statut != Retour && statut != Annulee;
            var net = cmds.Where(c => c.Statut != Annulee).ToList();
            var ventes = cmds.Where(c => EstVente(c.Statut)).ToList();
            var idsVentes = ventes.Select(c => c.Id).ToHashSet();
            var retours = net.Where(c => c.Statut == Retour).ToList();

            var model = new PosRapportVM
            {
                DateDebut = du,
                DateFin = au,
                CaisseId = caisseId,
                CaisseLibelle = caisseId.HasValue
                    ? _context.Caisses.Where(c => c.ID == caisseId).Select(c => c.ChkCode + " - " + c.ChkDescription).FirstOrDefault()
                    : null,
                Societe = Societe(),
                EditePar = User.FindFirst(AppClaimTypes.NomComplet)?.Value ?? User.Identity?.Name ?? "",
                Ventes = ventes.Sum(c => c.TotalTTC),
                Tickets = ventes.Count,
                Retours = -retours.Sum(c => c.TotalTTC),
                NbRetours = retours.Count,
                Annulees = cmds.Count(c => c.Statut == Annulee),
                ChiffreAffairesHT = net.Sum(c => c.TotalHT),
                Articles = lignes.Sum(l => l.Quantite)
            };
            model.ChiffreAffaires = model.Ventes - model.Retours;

            model.ParJour = net.GroupBy(c => c.DateCommande.Date).OrderBy(g => g.Key)
                .Select(g => new PosRapportPeriode { Date = g.Key, Tickets = g.Count(c => EstVente(c.Statut)), Montant = g.Sum(c => c.TotalTTC) })
                .ToList();
            model.ParHeure = net.GroupBy(c => c.DateCommande.Hour).OrderBy(g => g.Key)
                .Select(g => new PosRapportPeriode { Heure = g.Key, Tickets = g.Count(c => EstVente(c.Statut)), Montant = g.Sum(c => c.TotalTTC) })
                .ToList();
            model.Produits = lignes
                .GroupBy(l => l.ProduitId.HasValue ? l.ProduitId.Value.ToString() : "#" + l.Libelle)
                .Select(g => new PosRapportProduit
                {
                    Code = g.First().Code,
                    Nom = g.First().Nom ?? g.First().Libelle,
                    Categorie = g.First().Categorie ?? "Sans catégorie",
                    Quantite = g.Sum(l => l.Quantite),
                    Montant = g.Sum(l => l.TotalTTC)
                })
                .OrderByDescending(p => p.Montant).ThenByDescending(p => p.Quantite).ThenBy(p => p.Nom)
                .ToList();
            model.Categories = lignes.GroupBy(l => l.CategorieId)
                .Select(g => new PosRapportCategorie
                {
                    Nom = g.First().Categorie ?? "Sans catégorie",
                    Couleur = g.First().Couleur,
                    Quantite = g.Sum(l => l.Quantite),
                    Montant = g.Sum(l => l.TotalTTC)
                })
                .OrderByDescending(c => c.Montant).ThenBy(c => c.Nom)
                .ToList();
            model.Vendeurs = net.GroupBy(c => c.UtilisateurId)
                .Select(g => new PosRapportVendeur
                {
                    Nom = g.First().Vendeur,
                    Tickets = g.Count(c => EstVente(c.Statut)),
                    Ventes = g.Where(c => EstVente(c.Statut)).Sum(c => c.TotalTTC),
                    Retours = -g.Where(c => c.Statut == Retour).Sum(c => c.TotalTTC),
                    Montant = g.Sum(c => c.TotalTTC)
                })
                .OrderByDescending(v => v.Montant).ThenBy(v => v.Nom)
                .ToList();
            model.Modes = paiements.GroupBy(p => p.Libelle)
                .Select(g => new PosRapportMode
                {
                    Nom = g.Key,
                    Tickets = g.Where(p => idsVentes.Contains(p.CommandePosId)).Select(p => p.CommandePosId).Distinct().Count(),
                    Montant = g.Sum(p => p.Montant)
                })
                .OrderByDescending(x => x.Montant).ThenBy(x => x.Nom)
                .ToList();
            // Taxes collectées : détail figé à la vente ; lignes plus anciennes comptées en TVA à leur taux total.
            var avecDetail = detailTaxes.Select(x => x.LigneCommandePosId).ToHashSet();
            model.Taxes = detailTaxes.Select(x => (Nom: TaxesProduits.Libelle(x.Code, x.Taux), x.Montant))
                .Concat(lignes.Where(l => l.TauxTVA > 0 && !avecDetail.Contains(l.Id))
                    .Select(l => (Nom: TaxesProduits.Libelle("TVA", l.TauxTVA), Montant: l.TotalTTC - l.TotalTTC / (1 + l.TauxTVA / 100))))
                .GroupBy(x => x.Nom)
                .Select(g => new PosRapportMode { Nom = g.Key, Montant = Math.Round(g.Sum(x => x.Montant), 2) })
                .OrderByDescending(x => x.Montant)
                .ToList();
            return model;
        }

        private string Societe()
        {
            if (_tenant.IsSuperAdmin && _tenant.TenantId != 0)
                return _context.Tenants.Where(t => t.Id == _tenant.TenantId).Select(t => t.Nom).FirstOrDefault() ?? "";
            return User.FindFirst(AppClaimTypes.TenantName)?.Value ?? "";
        }
    }
}
