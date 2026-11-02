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
    // Stock du point de vente, suivi par dépôt : historique des mouvements, stock par dépôt, entrées
    // de marchandises, transferts entre dépôts, inventaire et option « vente sans stock ».
    // Réservé aux profils Admin et SuperAdmin.
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

        // Dépôts actifs de la société, le dépôt par défaut en premier.
        private async Task<List<Depot>> DepotsActifs()
        {
            if (_tenant.TenantId > 0)
                await _context.DepotParDefautAsync(_tenant.TenantId);
            return await _context.Depots.Where(d => d.Actif).OrderByDescending(d => d.ParDefaut).ThenBy(d => d.Code).ToListAsync();
        }

        // Dépôt actif de la société, sinon null. Aucun dépôt indiqué et parDefaut : dépôt par défaut
        // de la société (comme pour une caisse sans dépôt choisi).
        private async Task<Depot?> DepotSaisi(int id, bool parDefaut = false)
        {
            if (id == 0 && parDefaut)
                id = await _context.DepotParDefautAsync(_tenant.TenantId);
            return await _context.Depots.FirstOrDefaultAsync(d => d.Id == id && d.TenantId == _tenant.TenantId && d.Actif);
        }

        // Dépôt choisi dans l'adresse (?depot=), sinon le premier dépôt actif (le dépôt par défaut).
        private static int DepotChoisi(List<Depot> depots, int depot)
            => depots.Any(d => d.Id == depot) ? depot : depots.FirstOrDefault()?.Id ?? 0;

        // Quantités des produits dans un dépôt.
        private Task<Dictionary<int, decimal>> QuantitesDepot(int depot)
            => _context.StocksDepots.Where(s => s.DepotId == depot).ToDictionaryAsync(s => s.ProduitId, s => s.Quantite);

        public async Task<IActionResult> Index(int produit = 0, int depot = 0, string type = "", DateTime? du = null, DateTime? au = null)
        {
            var query = _context.MouvementsStock.Include(m => m.Produit).Include(m => m.Depot).AsQueryable();
            if (produit > 0)
                query = query.Where(m => m.ProduitId == produit);
            if (depot > 0)
                query = query.Where(m => m.DepotId == depot);
            if (MouvementStock.Types.Contains(type))
                query = query.Where(m => m.TypeMouvement == type);
            if (du.HasValue)
                query = query.Where(m => m.DateMouvement >= du.Value.Date);
            if (au.HasValue)
                query = query.Where(m => m.DateMouvement < au.Value.Date.AddDays(1));
            var mouvements = await query.OrderByDescending(m => m.DateMouvement).ThenByDescending(m => m.Id).Take(2000).ToListAsync();

            var userIds = mouvements.Where(m => m.UtilisateurId.HasValue).Select(m => m.UtilisateurId!.Value).Distinct().ToList();
            ViewBag.Utilisateurs = await _context.Utilisateurs.IgnoreQueryFilters().Where(u => userIds.Contains(u.Id)).ToDictionaryAsync(u => u.Id, u => u.NomComplet);
            ViewBag.Produits = await _context.Produits.Where(p => p.SuiviStock && !p.EstModele).OrderBy(p => p.Nom).ToListAsync();
            ViewBag.Alertes = await _context.Produits
                .Where(p => p.SuiviStock && p.Actif && !p.EstModele && p.SeuilAlerte != null && p.StockActuel <= p.SeuilAlerte)
                .OrderBy(p => p.StockActuel - p.SeuilAlerte).ThenBy(p => p.Nom).ToListAsync();
            ViewBag.VenteSansStock = _tenant.TenantId == 0 ? (bool?)null
                : (await _context.Tenants.AsNoTracking().FirstOrDefaultAsync(t => t.Id == _tenant.TenantId))?.PosVenteSansStock ?? true;
            ViewBag.Depots = await _context.Depots.OrderByDescending(d => d.ParDefaut).ThenBy(d => d.Code).ToListAsync();
            ViewBag.Filtres = new { produit, depot, type, du = du?.ToString("yyyy-MM-dd") ?? "", au = au?.ToString("yyyy-MM-dd") ?? "" };
            return View(mouvements);
        }

        // Stock par dépôt : quantité de chaque produit suivi dans chaque dépôt, et total.
        public async Task<IActionResult> Depots(int categorie = 0)
        {
            var avecStock = _context.StocksDepots.Where(s => s.Quantite != 0).Select(s => s.DepotId);
            ViewBag.Depots = await _context.Depots.Where(d => d.Actif || avecStock.Contains(d.Id))
                .OrderByDescending(d => d.ParDefaut).ThenBy(d => d.Code).ToListAsync();
            var ids = ((List<Depot>)ViewBag.Depots).Select(d => d.Id).ToList();
            ViewBag.Quantites = (await _context.StocksDepots.Where(s => ids.Contains(s.DepotId)).ToListAsync())
                .ToDictionary(s => (s.ProduitId, s.DepotId), s => s.Quantite);
            ViewBag.Categories = await _context.Categories.OrderBy(c => c.Ordre).ThenBy(c => c.Nom).ToListAsync();
            ViewBag.Categorie = categorie;
            var query = _context.Produits.Include(p => p.Categorie).Where(p => p.SuiviStock && p.Actif && !p.EstModele);
            if (categorie > 0)
                query = query.Where(p => p.CategorieId == categorie);
            return View(await query.OrderBy(p => p.Nom).ToListAsync());
        }

        public async Task<IActionResult> Entree(int produit = 0)
        {
            ViewBag.Choisi = produit;
            ViewBag.Depots = await DepotsActifs();
            return View(await _context.Produits.Where(p => p.SuiviStock && p.Actif && !p.EstModele).OrderBy(p => p.Nom).ToListAsync());
        }

        // Entrée de marchandises : plusieurs produits reçus en une fois (bon de livraison), dans un dépôt.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Entree(int depot, List<int> produit, List<string> qte, string? reference, string? commentaire)
        {
            if (_tenant.TenantId == 0)
            {
                TempData["Error"] = MessageSociete;
                return RedirectToAction("Entree");
            }
            var depotRecu = await DepotSaisi(depot, true);
            if (depotRecu == null)
            {
                TempData["Error"] = "Choisissez le dépôt qui reçoit les marchandises.";
                return RedirectToAction("Entree");
            }
            var lignes = new List<(int Id, decimal Qte)>();
            for (var i = 0; i < produit.Count; i++)
            {
                var q = Math.Round(Nombre(i < qte.Count ? qte[i] : null) ?? 0, 2);
                if (produit[i] <= 0 || q <= 0)
                    continue;
                if (!await _context.Produits.AnyAsync(p => p.Id == produit[i] && p.TenantId == _tenant.TenantId && p.SuiviStock && !p.EstModele))
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
                await _context.MouvementAsync(id, q, "Entrée", reference, null, UtilisateurId, commentaire, depotRecu.Id);
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            TempData["Success"] = $"{lignes.Count} produit(s) entré(s) en stock ({depotRecu.Nom}).";
            return RedirectToAction("Index", new { type = "Entrée" });
        }

        public async Task<IActionResult> Transfert(int depot = 0)
        {
            var depots = await DepotsActifs();
            var depart = DepotChoisi(depots, depot);
            ViewBag.Depots = depots;
            ViewBag.Depart = depart;
            ViewBag.Quantites = await QuantitesDepot(depart);
            return View(await _context.Produits.Where(p => p.SuiviStock && p.Actif && !p.EstModele).OrderBy(p => p.Nom).ToListAsync());
        }

        // Transfert entre deux dépôts : chaque produit sort du dépôt de départ et entre dans le dépôt
        // d'arrivée (deux mouvements « Transfert ») ; le stock total ne change pas.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Transfert(int depart, int arrivee, List<int> produit, List<string> qte, string? reference, string? commentaire)
        {
            if (_tenant.TenantId == 0)
            {
                TempData["Error"] = MessageSociete;
                return RedirectToAction("Transfert");
            }
            var dDepart = await DepotSaisi(depart);
            var dArrivee = await DepotSaisi(arrivee);
            if (dDepart == null || dArrivee == null)
                return Refus("Choisissez le dépôt de départ et le dépôt d'arrivée.");
            if (dDepart.Id == dArrivee.Id)
                return Refus("Le dépôt d'arrivée doit être différent du dépôt de départ.");
            reference = string.IsNullOrWhiteSpace(reference) ? $"TRF-{DateTime.Now:yyyyMMdd-HHmm}" : reference.Trim();
            commentaire = string.IsNullOrWhiteSpace(commentaire) ? null : commentaire.Trim();
            var lignes = new Dictionary<int, decimal>();
            for (var i = 0; i < produit.Count; i++)
            {
                var q = Math.Round(Nombre(i < qte.Count ? qte[i] : null) ?? 0, 2);
                if (produit[i] <= 0 || q <= 0)
                    continue;
                if (!await _context.Produits.AnyAsync(p => p.Id == produit[i] && p.TenantId == _tenant.TenantId && p.SuiviStock && !p.EstModele))
                    return Refus("Un produit de la liste est introuvable ou sans suivi de stock.");
                lignes[produit[i]] = lignes.GetValueOrDefault(produit[i]) + q;
            }
            if (!lignes.Any())
                return Refus("Indiquez au moins un produit et une quantité à transférer.");
            await using var transaction = await _context.Database.BeginTransactionAsync();
            foreach (var (id, q) in lignes)
            {
                var nom = await _context.Produits
                    .FromSqlInterpolated($"SELECT * FROM Produits WITH (UPDLOCK, ROWLOCK) WHERE Id = {id}")
                    .AsNoTracking().Select(p => p.Nom).FirstAsync();
                var dispo = await _context.StockDepotAsync(id, dDepart.Id);
                if (dispo < q - 0.001m)
                {
                    await transaction.RollbackAsync();
                    return Refus($"Stock insuffisant dans « {dDepart.Nom} » pour « {nom} » : {dispo.ToString("#,0.##", CultureInfo.GetCultureInfo("fr-FR"))} disponible(s).");
                }
                await _context.MouvementAsync(id, -q, "Transfert", reference, null, UtilisateurId, commentaire ?? $"Vers {dArrivee.Nom}", dDepart.Id);
                await _context.MouvementAsync(id, q, "Transfert", reference, null, UtilisateurId, commentaire ?? $"Depuis {dDepart.Nom}", dArrivee.Id);
            }
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            TempData["Success"] = $"{lignes.Count} produit(s) transféré(s) de « {dDepart.Nom} » vers « {dArrivee.Nom} ».";
            return RedirectToAction("Index", new { type = "Transfert" });

            IActionResult Refus(string message)
            {
                TempData["Error"] = message;
                return RedirectToAction("Transfert");
            }
        }

        public async Task<IActionResult> Inventaire(int categorie = 0, int depot = 0)
        {
            var depots = await DepotsActifs();
            var choisi = DepotChoisi(depots, depot);
            ViewBag.Depots = depots;
            ViewBag.Depot = choisi;
            ViewBag.Quantites = await QuantitesDepot(choisi);
            ViewBag.Categories = await _context.Categories.OrderBy(c => c.Ordre).ThenBy(c => c.Nom).ToListAsync();
            ViewBag.Categorie = categorie;
            var query = _context.Produits.Include(p => p.Categorie).Where(p => p.SuiviStock && p.Actif && !p.EstModele);
            if (categorie > 0)
                query = query.Where(p => p.CategorieId == categorie);
            return View(await query.OrderBy(p => p.Nom).ToListAsync());
        }

        // Inventaire : stock compté saisi par produit ; l'écart devient un mouvement « Inventaire ».
        [HttpPost]
        [ValidateAntiForgeryToken]
        [ActionName("Inventaire")]
        public async Task<IActionResult> InventairePost(int depot, string? commentaire)
        {
            if (_tenant.TenantId == 0)
            {
                TempData["Error"] = MessageSociete;
                return RedirectToAction("Inventaire");
            }
            var dInventaire = await DepotSaisi(depot, true);
            if (dInventaire == null)
            {
                TempData["Error"] = "Choisissez le dépôt inventorié.";
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
                var suivi = await _context.Produits
                    .FromSqlInterpolated($"SELECT * FROM Produits WITH (UPDLOCK, ROWLOCK) WHERE Id = {id}")
                    .Where(p => p.SuiviStock && !p.EstModele).AsNoTracking().AnyAsync();
                if (!suivi)
                    continue;
                var ecart = Math.Round(compte.Value - await _context.StockDepotAsync(id, dInventaire.Id), 2);
                if (Math.Abs(ecart) >= 0.01m)
                {
                    await _context.MouvementAsync(id, ecart, "Inventaire", reference, null, UtilisateurId, commentaire, dInventaire.Id);
                    nb++;
                }
            }
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            TempData["Success"] = nb > 0 ? $"Inventaire {reference} ({dInventaire.Nom}) enregistré : {nb} produit(s) ajusté(s)." : "Inventaire enregistré : aucun écart.";
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
