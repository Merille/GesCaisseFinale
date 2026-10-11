using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Réservé aux profils Admin et SuperAdmin.
    [Authorize(Policy = "Admin")]
    public class UtilisateurController : Controller
    {
        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenantProvider;

        public UtilisateurController(AppDbContext context, ITenantProvider tenantProvider)
        {
            _context = context;
            _tenantProvider = tenantProvider;
        }

        // Seul le SuperAdmin choisit le tenant explicitement (les autres profils
        // sont automatiquement rattachés à leur propre tenant à l'enregistrement).
        private void ChargerTenantsSiSuperAdmin()
        {
            ViewBag.IsSuperAdmin = _tenantProvider.IsSuperAdmin;

            if (_tenantProvider.IsSuperAdmin)
            {
                ViewBag.Tenants = _context.Tenants
                    .OrderBy(t => t.Nom)
                    .Select(t => new SelectListItem
                    {
                        Value = t.Id.ToString(),
                        Text = t.Nom
                    })
                    .ToList();
            }
        }

        // LISTE

        public async Task<IActionResult> Index()
        {
            ViewBag.IsSuperAdmin = _tenantProvider.IsSuperAdmin;

            var users = await _context.Utilisateurs
                .Include(u => u.Tenant)
                .OrderBy(c => c.NomUtilisateur)
                .ToListAsync();

            return View(users);
        }
        //public IActionResult Index()
        //{
        //    var users = _context.Utilisateurs.ToList();
        //    return View(users);
        //}

        // CREATE GET
        public IActionResult Create()
        {
            ChargerTenantsSiSuperAdmin();
            return View();
        }

        // CREATE POST
        [HttpPost]
        public IActionResult Create(Utilisateur user)
        {
            if (!ModelState.IsValid)
            {
                ChargerTenantsSiSuperAdmin();
                return View(user);
            }

            // Seul le SuperAdmin choisit librement le tenant (y compris "aucun").
            // Un Admin/Caissier rattache toujours le nouvel utilisateur à son propre tenant.
            if (!_tenantProvider.IsSuperAdmin)
            {
                user.TenantId = _tenantProvider.TenantId;
            }

            user.MotPasse = HashPassword(user.MotPasse);

            _context.Utilisateurs.Add(user);
            _context.SaveChanges();

            return RedirectToAction("Index");
        }

        // EDIT GET
        public IActionResult Edit(int id)
        {
            var user = _context.Utilisateurs.Find(id);

            if (user == null)
                return NotFound();

            user.MotPasse = ""; // ne pas afficher le hash

            ChargerTenantsSiSuperAdmin();

            return View(user);
        }

        // EDIT POST
        [HttpPost]
        public IActionResult Edit(Utilisateur user)
        {
            var existing = _context.Utilisateurs.Find(user.Id);

            if (existing == null)
                return NotFound();

            existing.NomUtilisateur = user.NomUtilisateur;
            existing.NomComplet = user.NomComplet;
            existing.Profil = user.Profil;
            existing.PeutValiderOperations = user.PeutValiderOperations;

            // Seul le SuperAdmin peut changer le tenant d'un utilisateur.
            if (_tenantProvider.IsSuperAdmin)
            {
                existing.TenantId = user.TenantId;
            }

            // si mot de passe rempli → update
            if (!string.IsNullOrEmpty(user.MotPasse))
            {
                existing.MotPasse = HashPassword(user.MotPasse);
            }

            _context.SaveChanges();

            return RedirectToAction("Index");
        }

        // DELETE
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Delete(int id)
        {
            var user = _context.Utilisateurs.Find(id);

            if (user != null)
            {
                _context.Utilisateurs.Remove(user);
                _context.SaveChanges();
            }

            return RedirectToAction("Index");
        }

        // HASH PASSWORD
        private string HashPassword(string password)
        {
            using var sha = SHA256.Create();
            var bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(password));
            return Convert.ToBase64String(bytes);
        }
    }
}