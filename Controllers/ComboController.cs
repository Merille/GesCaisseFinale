using System.Globalization;
using System.Text.Json;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Combos (Configuration › Combos), comme dans le point de vente Odoo : un combo regroupe les
    // produits proposés au choix (ex. « Plats » : Poulet, Poisson + 500) et le nombre d'articles à
    // choisir. Un produit combo (fiche produit) se compose d'une liste de combos.
    // Réservé aux profils Admin et SuperAdmin.
    [Authorize(Policy = "Admin")]
    public class ComboController : Controller
    {
        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public ComboController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        public async Task<IActionResult> Index()
        {
            var combos = await _context.Combos.Include(c => c.Choix).OrderBy(c => c.Ordre).ThenBy(c => c.Nom).ThenBy(c => c.Id).ToListAsync();
            var fr = CultureInfo.GetCultureInfo("fr-FR");
            var noms = await _context.Produits.ToDictionaryAsync(p => p.Id, p => p.Nom);
            var liens = await _context.ProduitCombos.ToListAsync();
            ViewBag.Choix = combos.ToDictionary(c => c.Id, c => string.Join(", ", c.Choix.OrderBy(x => x.Ordre).ThenBy(x => x.Id)
                .Select(x => (noms.TryGetValue(x.ProduitId, out var n) ? n : "?") + (x.Supplement > 0 ? $" (+{x.Supplement.ToString("N0", fr)})" : ""))));
            ViewBag.Produits = combos.ToDictionary(c => c.Id, c => liens.Where(l => l.ComboId == c.Id)
                .Select(l => noms.TryGetValue(l.ProduitId, out var n) ? n : "?").OrderBy(n => n).ToList());
            // Formulaire de création en fenêtre modale.
            ViewBag.Donnees = new
            {
                produits = (await ProduitsAsync(_tenant.TenantId)).Select(p => new { id = p.Id, nom = p.Nom, prix = p.PrixVente }),
                choix = Array.Empty<object>()
            };
            return View(combos);
        }

        // Produits proposables dans un combo : actifs, ni modèle à variantes, ni produit combo.
        private async Task<List<Produit>> ProduitsAsync(int tenantId) =>
            await _context.Produits.IgnoreQueryFilters().Where(p => p.TenantId == tenantId && p.Actif && !p.EstModele && !p.EstCombo)
                .OrderBy(p => p.Nom).ToListAsync();

        private async Task<IActionResult> Formulaire(Combo combo, List<ComboChoix> choix)
        {
            var produits = await ProduitsAsync(combo.Id == 0 ? _tenant.TenantId : combo.TenantId);
            ViewBag.Donnees = new
            {
                produits = produits.Select(p => new { id = p.Id, nom = p.Nom, prix = p.PrixVente }),
                choix = choix.Select(c => new { produitId = c.ProduitId, supplement = c.Supplement })
            };
            return View("Form", combo);
        }

        public Task<IActionResult> Create() => Formulaire(new Combo(), new());

        public async Task<IActionResult> Edit(int id)
        {
            var combo = await _context.Combos.Include(c => c.Choix).FirstOrDefaultAsync(c => c.Id == id);
            if (combo == null)
                return NotFound();
            return await Formulaire(combo, combo.Choix.OrderBy(c => c.Ordre).ThenBy(c => c.Id).ToList());
        }

        private sealed class ChoixSaisi
        {
            public int ProduitId { get; set; }
            public decimal Supplement { get; set; }
        }

        // Création (Id = 0) ou modification : nom, nombre à choisir, produits proposés (JSON).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Save(int id, string? nom, int quantite, string? choix)
        {
            var combo = id > 0 ? await _context.Combos.Include(c => c.Choix).FirstOrDefaultAsync(c => c.Id == id) : new Combo { TenantId = _tenant.TenantId };
            if (combo == null)
                return NotFound();
            if (combo.TenantId == 0)
            {
                TempData["Error"] = "Choisissez d'abord la société concernée dans le menu « Société consultée », puis recommencez.";
                return RedirectToAction("Index");
            }
            nom = (nom ?? "").Trim();
            combo.Nom = nom.Length > 50 ? nom[..50] : nom;
            combo.Quantite = Math.Clamp(quantite, 1, 10);
            List<ChoixSaisi> saisis;
            try { saisis = JsonSerializer.Deserialize<List<ChoixSaisi>>(choix ?? "[]", new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new(); }
            catch (JsonException) { saisis = new(); }
            var permis = (await ProduitsAsync(combo.TenantId)).Select(p => p.Id).ToHashSet();
            var liste = saisis.Take(50).Where(c => permis.Contains(c.ProduitId)).GroupBy(c => c.ProduitId).Select(g => g.First())
                .Select((c, k) => new ComboChoix { ProduitId = c.ProduitId, Supplement = Math.Max(0, Math.Round(c.Supplement, 2)), Ordre = k }).ToList();
            var erreur = combo.Nom == "" ? "Le nom du combo est obligatoire." : !liste.Any() ? "Ajoutez au moins un produit proposé." : null;
            if (erreur != null)
            {
                ViewBag.Erreur = erreur;
                return await Formulaire(combo, liste);
            }
            await using var transaction = await _context.Database.BeginTransactionAsync();
            if (combo.Id == 0)
                _context.Combos.Add(combo);
            else
                _context.ComboChoix.RemoveRange(combo.Choix);
            await _context.SaveChangesAsync();
            foreach (var c in liste)
                c.ComboId = combo.Id;
            _context.ComboChoix.AddRange(liste);
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            TempData["Success"] = id > 0 ? "Combo modifié." : "Combo créé.";
            return RedirectToAction("Index");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Delete(int id)
        {
            var combo = await _context.Combos.FirstOrDefaultAsync(c => c.Id == id);
            if (combo != null)
            {
                var nb = await _context.ProduitCombos.CountAsync(pc => pc.ComboId == id);
                if (nb > 0)
                    TempData["Error"] = $"Le combo « {combo.Nom} » compose {nb} produit(s) : retirez-le de leur fiche avant de le supprimer.";
                else
                {
                    _context.Combos.Remove(combo);
                    await _context.SaveChangesAsync();
                    TempData["Success"] = $"Combo « {combo.Nom} » supprimé.";
                }
            }
            return RedirectToAction("Index");
        }
    }
}
