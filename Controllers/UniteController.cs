using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Unités de vente des produits (Kg, Litre, Carton…). Produits.Unite garde le nom de l'unité :
    // renommer une unité met à jour ses produits ; une unité désactivée n'est plus proposée
    // sur la fiche produit mais reste sur les produits qui l'utilisent.
    // Réservé aux profils Admin et SuperAdmin.
    [Authorize(Policy = "Admin")]
    public class UniteController : Controller
    {
        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public UniteController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        public IActionResult Index()
        {
            var unites = _context.Unites.AsEnumerable()
                .OrderByDescending(u => u.Actif).ThenBy(u => u.Nom == "Unité" ? 0 : 1).ThenBy(u => u.Nom, StringComparer.CurrentCultureIgnoreCase)
                .ToList();
            ViewBag.NbProduits = _context.Produits
                .GroupBy(p => new { p.TenantId, p.Unite })
                .Select(g => new { g.Key.TenantId, g.Key.Unite, Nb = g.Count() })
                .AsEnumerable()
                .ToDictionary(x => (x.TenantId, x.Unite.ToLowerInvariant()), x => x.Nb);
            return View(unites);
        }

        // Création (Id = 0) ou modification ; un nouveau nom est reporté sur les produits.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Save(int id, string? nom, string? libelle, bool actif)
        {
            nom = (nom ?? "").Trim();
            nom = nom[..Math.Min(20, nom.Length)];
            libelle = string.IsNullOrWhiteSpace(libelle) ? null : libelle.Trim()[..Math.Min(100, libelle.Trim().Length)];
            if (nom == "")
                return Erreur("Le nom de l'unité est obligatoire.");

            var unite = id > 0 ? await _context.Unites.FirstOrDefaultAsync(u => u.Id == id) : null;
            if (id > 0 && unite == null)
                return NotFound();
            var tenantId = unite?.TenantId ?? _tenant.TenantId;
            if (tenantId == 0)
                return Erreur("Choisissez d'abord la société concernée dans le menu « Société consultée », puis recommencez.");
            if (await _context.Unites.IgnoreQueryFilters().AnyAsync(u => u.TenantId == tenantId && u.Nom == nom && u.Id != id))
                return Erreur($"L'unité « {nom} » existe déjà.");

            if (unite != null)
            {
                var ancien = unite.Nom;
                unite.Nom = nom;
                unite.Libelle = libelle;
                unite.Actif = actif;
                await using var transaction = await _context.Database.BeginTransactionAsync();
                await _context.SaveChangesAsync();
                var nb = ancien == nom ? 0 : await _context.Produits.IgnoreQueryFilters()
                    .Where(p => p.TenantId == tenantId && p.Unite == ancien)
                    .ExecuteUpdateAsync(s => s.SetProperty(p => p.Unite, nom));
                await transaction.CommitAsync();
                TempData["Success"] = nb > 0 ? $"Unité modifiée ; {nb} produit(s) utilisent maintenant « {nom} »." : "Unité modifiée.";
            }
            else
            {
                _context.Unites.Add(new UniteVente { TenantId = tenantId, Nom = nom, Libelle = libelle, Actif = actif });
                await _context.SaveChangesAsync();
                TempData["Success"] = "Unité créée.";
            }
            return RedirectToAction("Index");
        }

        // Active ou désactive l'unité (elle n'est plus proposée sur la fiche produit).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Basculer(int id)
        {
            var unite = await _context.Unites.FirstOrDefaultAsync(u => u.Id == id);
            if (unite == null)
                return NotFound();
            unite.Actif = !unite.Actif;
            await _context.SaveChangesAsync();
            TempData["Success"] = unite.Actif
                ? $"Unité « {unite.Nom} » activée."
                : $"Unité « {unite.Nom} » désactivée : elle n'est plus proposée sur les produits.";
            return RedirectToAction("Index");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Delete(int id)
        {
            var unite = await _context.Unites.FirstOrDefaultAsync(u => u.Id == id);
            if (unite != null)
            {
                var nb = await _context.Produits.IgnoreQueryFilters().CountAsync(p => p.TenantId == unite.TenantId && p.Unite == unite.Nom);
                if (nb > 0)
                    return Erreur($"L'unité « {unite.Nom} » est utilisée par {nb} produit(s) : changez leur unité ou désactivez-la plutôt que de la supprimer.");
                _context.Unites.Remove(unite);
                await _context.SaveChangesAsync();
                TempData["Success"] = $"Unité « {unite.Nom} » supprimée.";
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
