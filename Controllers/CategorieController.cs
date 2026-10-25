using System.Text.RegularExpressions;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace EasytransitCaisse.Controllers
{
    // Catégories de produits du point de vente. Réservé aux profils Admin et SuperAdmin.
    [Authorize(Policy = "Admin")]
    public class CategorieController : Controller
    {
        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public CategorieController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        public IActionResult Index()
        {
            var categories = _context.Categories.OrderBy(c => c.Ordre).ThenBy(c => c.Nom).ToList();
            ViewBag.NbProduits = _context.Produits
                .Where(p => p.CategorieId != null)
                .GroupBy(p => p.CategorieId!.Value)
                .ToDictionary(g => g.Key, g => g.Count());
            return View(categories);
        }

        // Couleur au format #rrggbb, sinon la couleur de la marque.
        public static string NormaliserCouleur(string? couleur)
        {
            var c = (couleur ?? "").Trim().ToLowerInvariant();
            return Regex.IsMatch(c, "^#[0-9a-f]{6}$") ? c : "#195d84";
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Create(Categorie categorie)
        {
            if (_tenant.TenantId == 0)
            {
                TempData["Error"] = "Choisissez d'abord la société concernée dans le menu « Société consultée », puis recommencez.";
                return RedirectToAction("Index");
            }
            if (string.IsNullOrWhiteSpace(categorie.Nom))
            {
                TempData["Error"] = "Le nom de la catégorie est obligatoire.";
                return RedirectToAction("Index");
            }

            categorie.Nom = categorie.Nom.Trim();
            categorie.Couleur = NormaliserCouleur(categorie.Couleur);
            _context.Categories.Add(categorie);
            _context.SaveChanges();
            TempData["Success"] = "Catégorie créée.";
            return RedirectToAction("Index");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Edit(Categorie categorie)
        {
            var existante = _context.Categories.FirstOrDefault(c => c.Id == categorie.Id);
            if (existante == null)
                return NotFound();
            if (string.IsNullOrWhiteSpace(categorie.Nom))
            {
                TempData["Error"] = "Le nom de la catégorie est obligatoire.";
                return RedirectToAction("Index");
            }

            existante.Nom = categorie.Nom.Trim();
            existante.Couleur = NormaliserCouleur(categorie.Couleur);
            existante.Ordre = categorie.Ordre;
            _context.SaveChanges();
            TempData["Success"] = "Catégorie modifiée.";
            return RedirectToAction("Index");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Delete(int id)
        {
            var categorie = _context.Categories.FirstOrDefault(c => c.Id == id);
            if (categorie != null)
            {
                var nb = _context.Produits.Count(p => p.CategorieId == id);
                if (nb > 0)
                {
                    TempData["Error"] = $"Cette catégorie contient {nb} produit(s) : changez-les de catégorie avant de la supprimer.";
                    return RedirectToAction("Index");
                }
                _context.Categories.Remove(categorie);
                _context.SaveChanges();
                TempData["Success"] = "Catégorie supprimée.";
            }
            return RedirectToAction("Index");
        }
    }
}
