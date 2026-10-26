using System.Globalization;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace EasytransitCaisse.Controllers
{
    // Taxes appliquées aux produits du point de vente (TVA, CSS…). Un produit peut en porter
    // plusieurs : elles s'additionnent sur le HT et sont comprises dans le prix TTC.
    // Réservé aux profils Admin et SuperAdmin.
    [Authorize(Policy = "Admin")]
    public class TaxeController : Controller
    {
        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public TaxeController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        public IActionResult Index()
        {
            ViewBag.NbProduits = _context.ProduitTaxes
                .GroupBy(pt => pt.TaxeId)
                .ToDictionary(g => g.Key, g => g.Count());
            return View(_context.ListeTaxes());
        }

        // Création (Id = 0) ou modification ; le taux total des produits concernés suit.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Save(int id, string? code, string? libelle, string? taux, bool parDefaut)
        {
            code = (code ?? "").Trim().ToUpperInvariant();
            libelle = (libelle ?? "").Trim();
            var t = (taux ?? "").Replace(" ", "").Replace(" ", "").Replace(" ", "").Replace(',', '.');
            if (code == "" || libelle == "")
                return Erreur("Le code et le libellé de la taxe sont obligatoires.");
            if (!decimal.TryParse(t, NumberStyles.Number, CultureInfo.InvariantCulture, out var valeur) || valeur < 0 || valeur > 100)
                return Erreur("Le taux doit être compris entre 0 et 100 %.");
            if (_context.Taxes.Any(x => x.Code == code && x.Id != id))
                return Erreur($"Le code « {code} » est déjà utilisé par une autre taxe.");

            if (id > 0)
            {
                var taxe = _context.Taxes.FirstOrDefault(x => x.Id == id);
                if (taxe == null)
                    return NotFound();
                taxe.Code = code;
                taxe.Libelle = libelle;
                taxe.Taux = valeur;
                taxe.ParDefaut = parDefaut;
                _context.SaveChanges();
                _context.RecalculerTauxProduits(id);
                _context.SaveChanges();
                TempData["Success"] = "Taxe modifiée ; le taux total des produits concernés a été mis à jour.";
            }
            else
            {
                if (_tenant.TenantId == 0)
                    return Erreur("Choisissez d'abord la société concernée dans le menu « Société consultée », puis recommencez.");
                _context.Taxes.Add(new Taxe { Code = code, Libelle = libelle, Taux = valeur, ParDefaut = parDefaut });
                _context.SaveChanges();
                TempData["Success"] = "Taxe créée.";
            }
            return RedirectToAction("Index");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Delete(int id)
        {
            var taxe = _context.Taxes.FirstOrDefault(x => x.Id == id);
            if (taxe != null)
            {
                var nb = _context.ProduitTaxes.Count(pt => pt.TaxeId == id);
                if (nb > 0)
                    return Erreur($"Cette taxe est appliquée à {nb} produit(s) : retirez-la de ces produits avant de la supprimer.");
                _context.Taxes.Remove(taxe);
                _context.SaveChanges();
                TempData["Success"] = "Taxe supprimée.";
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
