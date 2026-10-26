using System.Globalization;
using System.Security.Claims;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Stock du point de vente : historique des mouvements, entrées de marchandises,
    // inventaire et option « vente sans stock ». Réservé aux profils Admin et SuperAdmin.
    [Authorize(Policy = "Admin")]
    public class StockController : Controller
    {
        private const string MessageSociete = "Choisissez d'abord la société concernée dans le menu « Société consultée », puis recommencez.";

        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public StockController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        private int UtilisateurId => int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id) ? id : 0;

        private static decimal? Nombre(string? texte)
        {
            var t = (texte ?? "").Replace(" ", "").Replace(" ", "").Replace(" ", "").Replace(',', '.');
            return decimal.TryParse(t, NumberStyles.Number, CultureInfo.InvariantCulture, out var n) ? n : null;
        }

        public async Task<IActionResult> Index(int produit = 0, string type = "", DateTime? du = null, DateTime? au = null)
        {
            var query = _context.MouvementsStock.Include(m => m.Produit).AsQueryable();
            if (produit > 0)
                query = query.Where(m => m.ProduitId == produit);
            if (MouvementStock.Types.Contains(type))
                query = query.Where(m => m.TypeMouvement == type);
            if (du.HasValue)
                query = query.Where(m => m.DateMouvement >= du.Value.Date);
            if (au.HasValue)
                query = query.Where(m => m.DateMouvement < au.Value.Date.AddDays(1));
            var mouvements = await query.OrderByDescending(m => m.DateMouvement).ThenByDescending(m => m.Id).Take(2000).ToListAsync();

            var userIds = mouvements.Where(m => m.UtilisateurId.HasValue).Select(m => m.UtilisateurId!.Value).Distinct().ToList();
            ViewBag.Utilisateurs = await _context.Utilisateurs.IgnoreQueryFilters().Where(u => userIds.Contains(u.Id)).ToDictionaryAsync(u => u.Id, u => u.NomComplet);
            ViewBag.Produits = await _context.Produits.Where(p => p.SuiviStock).OrderBy(p => p.Nom).ToListAsync();
            ViewBag.Alertes = await _context.Produits
                .Where(p => p.SuiviStock && p.Actif && p.SeuilAlerte != null && p.StockActuel <= p.SeuilAlerte)
                .OrderBy(p => p.StockActuel - p.SeuilAlerte).ThenBy(p => p.Nom).ToListAsync();
            ViewBag.VenteSansStock = _tenant.TenantId == 0 ? (bool?)null
                : (await _context.Tenants.AsNoTracking().FirstOrDefaultAsync(t => t.Id == _tenant.TenantId))?.PosVenteSansStock ?? true;
            ViewBag.Filtres = new { produit, type, du = du?.ToString("yyyy-MM-dd") ?? "", au = au?.ToString("yyyy-MM-dd") ?? "" };
            return View(mouvements);
        }

        public async Task<IActionResult> Entree(int produit = 0)
        {
            ViewBag.Choisi = produit;
            return View(await _context.Produits.Where(p => p.SuiviStock && p.Actif).OrderBy(p => p.Nom).ToListAsync());
        }

        // Entrée de marchandises : plusieurs produits reçus en une fois (bon de livraison).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Entree(List<int> produit, List<string> qte, string? reference, string? commentaire)
        {
            if (_tenant.TenantId == 0)
            {
                TempData["Error"] = MessageSociete;
                return RedirectToAction("Entree");
            }
            var lignes = new List<(int Id, decimal Qte)>();
            for (var i = 0; i < produit.Count; i++)
            {
                var q = Math.Round(Nombre(i < qte.Count ? qte[i] : null) ?? 0, 2);
                if (produit[i] <= 0 || q <= 0)
                    continue;
                if (!await _context.Produits.AnyAsync(p => p.Id == produit[i] && p.TenantId == _tenant.TenantId && p.SuiviStock))
                {
                    TempData["Error"] = "Un produit de la liste est introuvable ou sans suivi de stock.";
                    return RedirectToAction("Entree");
                }
                lignes.Add((produit[i], q));
            }
            if (!lignes.Any())
            {
                TempData["Error"] = "Indiquez au moins un produit et une quantité reçue.";
                return RedirectToAction("Entree");
            }
            reference = string.IsNullOrWhiteSpace(reference) ? null : reference.Trim();
            commentaire = string.IsNullOrWhiteSpace(commentaire) ? null : commentaire.Trim();
            await using var transaction = await _context.Database.BeginTransactionAsync();
            foreach (var (id, q) in lignes)
                await _context.MouvementAsync(id, q, "Entrée", reference, null, UtilisateurId, commentaire);
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            TempData["Success"] = $"{lignes.Count} produit(s) entré(s) en stock.";
            return RedirectToAction("Index", new { type = "Entrée" });
        }

        public async Task<IActionResult> Inventaire(int categorie = 0)
        {
            ViewBag.Categories = await _context.Categories.OrderBy(c => c.Ordre).ThenBy(c => c.Nom).ToListAsync();
            ViewBag.Categorie = categorie;
            var query = _context.Produits.Include(p => p.Categorie).Where(p => p.SuiviStock && p.Actif);
            if (categorie > 0)
                query = query.Where(p => p.CategorieId == categorie);
            return View(await query.OrderBy(p => p.Nom).ToListAsync());
        }

        // Inventaire : stock compté saisi par produit ; l'écart devient un mouvement « Inventaire ».
        [HttpPost]
        [ValidateAntiForgeryToken]
        [ActionName("Inventaire")]
        public async Task<IActionResult> InventairePost(string? commentaire)
        {
            if (_tenant.TenantId == 0)
            {
                TempData["Error"] = MessageSociete;
                return RedirectToAction("Inventaire");
            }
            var reference = $"INV-{DateTime.Now:yyyyMMdd-HHmm}";
            commentaire = string.IsNullOrWhiteSpace(commentaire) ? null : commentaire.Trim();
            var nb = 0;
            await using var transaction = await _context.Database.BeginTransactionAsync();
            foreach (var cle in Request.Form.Keys.Where(k => k.StartsWith("compte[")))
            {
                if (!int.TryParse(cle[7..^1], out var id))
                    continue;
                var compte = Nombre(Request.Form[cle]);
                if (compte == null)
                    continue;
                var stock = await _context.Produits
                    .FromSqlInterpolated($"SELECT * FROM Produits WITH (UPDLOCK, ROWLOCK) WHERE Id = {id}")
                    .Where(p => p.SuiviStock).AsNoTracking().Select(p => (decimal?)p.StockActuel).FirstOrDefaultAsync();
                if (stock == null)
                    continue;
                var ecart = Math.Round(compte.Value - stock.Value, 2);
                if (Math.Abs(ecart) >= 0.01m)
                {
                    await _context.MouvementAsync(id, ecart, "Inventaire", reference, null, UtilisateurId, commentaire);
                    nb++;
                }
            }
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            TempData["Success"] = nb > 0 ? $"Inventaire {reference} enregistré : {nb} produit(s) ajusté(s)." : "Inventaire enregistré : aucun écart.";
            return RedirectToAction("Index", new { type = "Inventaire" });
        }

        // Option de la société : autoriser ou non la vente quand le stock est épuisé.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Option(string? venteSansStock)
        {
            var societe = await _context.Tenants.FirstOrDefaultAsync(t => t.Id == _tenant.TenantId);
            if (societe == null)
            {
                TempData["Error"] = MessageSociete;
                return RedirectToAction("Index");
            }
            societe.PosVenteSansStock = venteSansStock == "1";
            await _context.SaveChangesAsync();
            TempData["Success"] = societe.PosVenteSansStock
                ? "Vente sans stock autorisée : le point de vente affiche seulement un avertissement."
                : "Vente sans stock interdite : un produit épuisé ne peut plus être vendu.";
            return RedirectToAction("Index");
        }
    }
}
