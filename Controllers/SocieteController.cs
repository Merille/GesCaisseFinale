using EasytransitCaisse.Data;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Ma société (Paramètres) : l'administrateur modifie les coordonnées et le logo de sa société
    // (en-tête des tickets, factures et impressions). Le nom, le code, la licence et les modules
    // restent gérés par le SuperAdmin (Administration › Sociétés).
    [Authorize(Policy = "Admin")]
    public class SocieteController : Controller
    {
        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public SocieteController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        public async Task<IActionResult> Index()
        {
            var t = await _context.Tenants.FirstOrDefaultAsync(x => x.Id == _tenant.TenantId);
            if (t == null)
            {
                TempData["Error"] = "Choisissez d'abord la société concernée dans le menu « Société consultée ».";
                return RedirectToAction("Index", "Dashboard");
            }
            return View(t);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Index(string? adresse, string? ville, string? pays, string? email, string? telephone, string? nif,
            IFormFile? logo, bool supprimerLogo)
        {
            var t = await _context.Tenants.FirstOrDefaultAsync(x => x.Id == _tenant.TenantId);
            if (t == null)
                return RedirectToAction("Index", "Dashboard");
            string? Texte(string? v, int max)
            {
                var s = (v ?? "").Trim();
                return s == "" ? null : s.Length > max ? s[..max] : s;
            }
            t.Adresse = Texte(adresse, 250);
            t.Ville = Texte(ville, 100);
            t.Pays = Texte(pays, 100);
            t.Email = Texte(email, 150);
            t.Telephone = Texte(telephone, 50);
            t.NIF = Texte(nif, 50);
            var image = Images.Lire(logo, out var erreurImage);
            var erreur = t.Email != null && !new System.ComponentModel.DataAnnotations.EmailAddressAttribute().IsValid(t.Email)
                ? "L'adresse e-mail n'est pas valide." : erreurImage;
            if (erreur != null)
            {
                ViewBag.Erreur = erreur;
                return View(t);
            }
            _context.EnregistrerLogo(t, image, supprimerLogo);
            await _context.SaveChangesAsync();
            TempData["Success"] = "Informations de la société enregistrées.";
            return RedirectToAction(nameof(Index));
        }
    }
}
