using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Dépôts de stockage (magasin, entrepôt, réserve…) : le stock de chaque produit est suivi par dépôt.
    // Le dépôt par défaut reçoit le stock initial des produits et sert aux caisses sans dépôt choisi ;
    // il ne peut être ni désactivé ni supprimé. Un dépôt qui a un historique se désactive au lieu
    // d'être supprimé. Réservé aux profils Admin et SuperAdmin.
    [Authorize(Policy = "Admin")]
    public class DepotController : Controller
    {
        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public DepotController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        public async Task<IActionResult> Index()
        {
            if (_tenant.TenantId > 0)
                await _context.DepotParDefautAsync(_tenant.TenantId);
            var depots = await _context.Depots
                .OrderByDescending(d => d.ParDefaut).ThenByDescending(d => d.Actif).ThenBy(d => d.Code).ThenBy(d => d.Id)
                .ToListAsync();
            var ids = depots.Select(d => d.Id).ToList();
            ViewBag.NbProduits = await _context.StocksDepots.Where(s => ids.Contains(s.DepotId) && s.Quantite != 0)
                .GroupBy(s => s.DepotId).Select(g => new { g.Key, Nb = g.Count() }).ToDictionaryAsync(x => x.Key, x => x.Nb);
            // Caisses qui vendent depuis le dépôt : comme dépôt principal (une caisse sans dépôt choisi utilise
            // le dépôt par défaut de sa société) ou secondaire.
            var defauts = depots.Where(d => d.ParDefaut).ToDictionary(d => d.TenantId, d => d.Id);
            var principaux = (await _context.Caisses.IgnoreQueryFilters()
                    .Where(c => (c.DepotId != null && ids.Contains(c.DepotId.Value)) || (c.DepotId == null && defauts.Keys.Contains(c.TenantId)))
                    .Select(c => new { c.DepotId, c.TenantId, c.ID }).ToListAsync())
                .Select(c => new { Depot = c.DepotId ?? defauts[c.TenantId], Caisse = c.ID }).ToList();
            var secondaires = await _context.CaissesDepots.Where(c => ids.Contains(c.DepotId))
                .Select(c => new { Depot = c.DepotId, Caisse = c.CaisseId }).ToListAsync();
            ViewBag.NbCaisses = principaux.Concat(secondaires).Distinct()
                .GroupBy(x => x.Depot).ToDictionary(g => g.Key, g => g.Count());
            return View(depots);
        }

        // Message d'erreur si le dépôt ne peut pas être désactivé, sinon null.
        private async Task<string?> RefusDesactivation(Depot d)
        {
            if (d.ParDefaut)
                return "Le dépôt par défaut ne peut pas être désactivé : choisissez d'abord un autre dépôt par défaut.";
            var nb = await _context.Caisses.IgnoreQueryFilters().CountAsync(c => c.DepotId == d.Id);
            return nb > 0 ? $"Le dépôt « {d.Nom} » est utilisé par {nb} caisse(s) : rattachez-les à un autre dépôt avant de le désactiver." : null;
        }

        private static string? Texte(string? valeur, int max)
        {
            var t = (valeur ?? "").Trim();
            return t == "" ? null : t[..Math.Min(max, t.Length)];
        }

        // Création (Id = 0) ou modification.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Save(int id, string? code, string? nom, string? adresse, string? responsable, bool actif)
        {
            code = Texte(code, 20);
            nom = Texte(nom, 100);
            if (code == null || nom == null)
                return Erreur("Le code et le nom du dépôt sont obligatoires.");

            var depot = id > 0 ? await _context.Depots.FirstOrDefaultAsync(d => d.Id == id) : null;
            if (id > 0 && depot == null)
                return NotFound();
            var tenantId = depot?.TenantId ?? _tenant.TenantId;
            if (tenantId == 0)
                return Erreur("Choisissez d'abord la société concernée dans le menu « Société consultée », puis recommencez.");
            if (await _context.Depots.IgnoreQueryFilters().AnyAsync(d => d.TenantId == tenantId && d.Code == code && d.Id != id))
                return Erreur($"Le code « {code} » est déjà utilisé par un autre dépôt.");

            if (depot != null)
            {
                if (depot.Actif && !actif && await RefusDesactivation(depot) is { } refus)
                    return Erreur(refus);
                depot.Code = code;
                depot.Nom = nom;
                depot.Adresse = Texte(adresse, 200);
                depot.Responsable = Texte(responsable, 100);
                depot.Actif = actif;
                await _context.SaveChangesAsync();
                TempData["Success"] = "Dépôt modifié.";
            }
            else
            {
                await _context.DepotParDefautAsync(tenantId);
                _context.Depots.Add(new Depot
                {
                    TenantId = tenantId, Code = code, Nom = nom, Adresse = Texte(adresse, 200),
                    Responsable = Texte(responsable, 100), Actif = actif, ParDefaut = false
                });
                await _context.SaveChangesAsync();
                TempData["Success"] = "Dépôt créé.";
            }
            return RedirectToAction("Index");
        }

        // Active ou désactive le dépôt (il n'est plus proposé pour les caisses ni les mouvements de stock).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Basculer(int id)
        {
            var depot = await _context.Depots.FirstOrDefaultAsync(d => d.Id == id);
            if (depot == null)
                return NotFound();
            if (depot.Actif && await RefusDesactivation(depot) is { } refus)
                return Erreur(refus);
            depot.Actif = !depot.Actif;
            await _context.SaveChangesAsync();
            TempData["Success"] = depot.Actif
                ? $"Dépôt « {depot.Nom} » activé."
                : $"Dépôt « {depot.Nom} » désactivé : il n'est plus proposé pour les caisses ni les mouvements de stock.";
            return RedirectToAction("Index");
        }

        // Choisit le dépôt par défaut de la société.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ParDefaut(int id)
        {
            var depot = await _context.Depots.FirstOrDefaultAsync(d => d.Id == id);
            if (depot == null)
                return NotFound();
            if (!depot.Actif)
                return Erreur($"Activez d'abord le dépôt « {depot.Nom} ».");
            await _context.Depots.IgnoreQueryFilters().Where(d => d.TenantId == depot.TenantId)
                .ExecuteUpdateAsync(s => s.SetProperty(d => d.ParDefaut, d => d.Id == depot.Id));
            TempData["Success"] = $"« {depot.Nom} » est maintenant le dépôt par défaut.";
            return RedirectToAction("Index");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Delete(int id)
        {
            var depot = await _context.Depots.FirstOrDefaultAsync(d => d.Id == id);
            if (depot != null)
            {
                if (depot.ParDefaut)
                    return Erreur("Le dépôt par défaut ne peut pas être supprimé.");
                var utilise = await _context.MouvementsStock.IgnoreQueryFilters().AnyAsync(m => m.DepotId == id)
                    || await _context.Caisses.IgnoreQueryFilters().AnyAsync(c => c.DepotId == id)
                    || await _context.StocksDepots.AnyAsync(s => s.DepotId == id && s.Quantite != 0);
                if (utilise)
                    return Erreur($"Le dépôt « {depot.Nom} » a déjà des mouvements de stock ou des caisses rattachées : désactivez-le plutôt que de le supprimer.");
                await _context.StocksDepots.Where(s => s.DepotId == id).ExecuteDeleteAsync();
                _context.Depots.Remove(depot);
                await _context.SaveChangesAsync();
                TempData["Success"] = $"Dépôt « {depot.Nom} » supprimé.";
            }
            return RedirectToAction("Index");
        }

        private IActionResult Erreur(string message)
        {
            TempData["Error"] = message;
            return RedirectToAction("Index");
        }
    }
}
