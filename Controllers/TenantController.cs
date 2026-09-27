using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Gestion des sociétés (tenants) — réservée au SuperAdmin, portée globale.
    [Authorize(Policy = "SuperAdmin")]
    public class TenantController : Controller
    {
        private readonly AppDbContext _context;

        public TenantController(AppDbContext context)
        {
            _context = context;
        }

        public async Task<IActionResult> Index()
        {
            var tenants = await _context.Tenants
                .OrderBy(t => t.Nom)
                .ToListAsync();

            return View(tenants);
        }

        public IActionResult Create() => View();

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Create(Tenant tenant)
        {
            if (!ModelState.IsValid)
                return View(tenant);

            _context.Tenants.Add(tenant);
            _context.SaveChanges();

            return RedirectToAction(nameof(Index));
        }

        public IActionResult Edit(int id)
        {
            var tenant = _context.Tenants.Find(id);

            if (tenant == null)
                return NotFound();

            return View(tenant);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Edit(Tenant tenant)
        {
            var existing = _context.Tenants.Find(tenant.Id);

            if (existing == null)
                return NotFound();

            existing.Nom = tenant.Nom;
            existing.Code = tenant.Code;
            existing.Actif = tenant.Actif;
            existing.ModeAcces = tenant.ModeAcces;
            existing.DateExpiration = tenant.DateExpiration;

            _context.SaveChanges();

            return RedirectToAction(nameof(Index));
        }

        // Raccourci de renouvellement (+1 mois / +1 an) depuis la liste des
        // sociétés — prolonge à partir d'aujourd'hui si déjà expirée, sinon
        // à partir de la date d'expiration actuelle.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Prolonger(int id, int mois)
        {
            var tenant = _context.Tenants.Find(id);

            if (tenant == null)
                return NotFound();

            var depart = tenant.DateExpiration.HasValue && tenant.DateExpiration.Value.Date >= DateTime.Today
                ? tenant.DateExpiration.Value
                : DateTime.Today;

            tenant.DateExpiration = depart.AddMonths(mois);

            _context.SaveChanges();

            return RedirectToAction(nameof(Index));
        }

        // Change la société "consultée" par le SuperAdmin (sélecteur du menu),
        // qui scope alors toutes les données affichées à cette seule société.
        // tenantId vide/0 = revenir à la portée globale ("Toutes les sociétés").
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Consulter(int? tenantId, string? returnUrl)
        {
            if (tenantId.HasValue && tenantId.Value > 0)
            {
                Response.Cookies.Append(
                    TenantProvider.CookieConsultation,
                    tenantId.Value.ToString(),
                    new CookieOptions { HttpOnly = true, IsEssential = true, SameSite = SameSiteMode.Lax });
            }
            else
            {
                Response.Cookies.Delete(TenantProvider.CookieConsultation);
            }

            if (!string.IsNullOrWhiteSpace(returnUrl) && Url.IsLocalUrl(returnUrl))
                return Redirect(returnUrl);

            return RedirectToAction("Index", "Dashboard");
        }
    }
}
