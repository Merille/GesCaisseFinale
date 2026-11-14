using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Profils et droits d'accès (administrateurs) : l'administrateur crée des profils (Caissier, Serveur,
    // Gérant…) et coche les droits de chacun ; il attribue ensuite un profil à chaque utilisateur
    // (Paramètres › Utilisateurs). Le profil Administrateur a toujours tous les droits. Comme profil.php.
    [Authorize(Policy = "Admin")]
    public class ProfilController : Controller
    {
        private static readonly string[] Reserves = { "admin", "administrateur", "superadmin" };

        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public ProfilController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        public class LigneProfil
        {
            public Profil Profil { get; set; } = new();
            public string Societe { get; set; } = "";
            public int Utilisateurs { get; set; }
            public List<string> Droits { get; set; } = new();
        }

        public async Task<IActionResult> Index()
        {
            // Profils de la société (filtre par société) ; le nombre d'utilisateurs est compté à part :
            // IgnoreQueryFilters dans la même requête retirerait aussi le filtre des profils.
            var profils = await (from p in _context.Profils.AsNoTracking()
                                 join t in _context.Tenants on p.TenantId equals t.Id
                                 orderby t.Nom, p.Nom
                                 select new LigneProfil { Profil = p, Societe = t.Nom }).ToListAsync();
            var ids = profils.Select(l => l.Profil.Id).ToList();
            var nombres = await _context.Utilisateurs.IgnoreQueryFilters().Where(u => u.ProfilId != null && ids.Contains(u.ProfilId.Value))
                .GroupBy(u => u.ProfilId!.Value).Select(g => new { g.Key, N = g.Count() }).ToDictionaryAsync(x => x.Key, x => x.N);
            foreach (var l in profils)
            {
                l.Droits = Droits.Lire(l.Profil.Droits);
                l.Utilisateurs = nombres.GetValueOrDefault(l.Profil.Id);
            }
            ViewBag.Admins = await _context.Utilisateurs.CountAsync(u => u.Profil == "Admin");
            ViewBag.TenantId = _tenant.TenantId;
            ViewBag.Toutes = _tenant.IsSuperAdmin && _tenant.TenantId == 0;
            return View(profils);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Save(int id, string? nom, string? description, List<string>? droits)
        {
            nom = (nom ?? "").Trim();
            if (nom.Length > 50) nom = nom[..50];
            description = (description ?? "").Trim();
            if (description.Length > 200) description = description[..200];
            // Codes cochés (« tiers », « tiers.a »…) ; une opération sans « consulter » est ignorée.
            var codes = Droits.Lire(string.Join(",", droits ?? new()));
            var existant = id > 0 ? await _context.Profils.FirstOrDefaultAsync(p => p.Id == id) : null;
            if (id > 0 && existant == null)
                return NotFound();
            var tenant = existant?.TenantId ?? _tenant.TenantId;
            if (nom == "")
                TempData["Error"] = "Le nom du profil est obligatoire.";
            else if (Reserves.Contains(nom.ToLowerInvariant()))
                TempData["Error"] = "Ce nom est réservé : choisissez un autre nom de profil.";
            else if (tenant == 0)
                TempData["Error"] = "Consultez d'abord une société pour lui créer des profils.";
            else if (await _context.Profils.IgnoreQueryFilters().AnyAsync(p => p.TenantId == tenant && p.Nom == nom && p.Id != id))
                TempData["Error"] = $"Le profil « {nom} » existe déjà.";
            else if (existant != null)
            {
                existant.Nom = nom;
                existant.Description = description == "" ? null : description;
                existant.Droits = string.Join(",", codes);
                // Le nom du profil est affiché sur les comptes des utilisateurs.
                await _context.Utilisateurs.IgnoreQueryFilters().Where(u => u.ProfilId == id).ExecuteUpdateAsync(s => s.SetProperty(u => u.Profil, nom));
                await _context.SaveChangesAsync();
                TempData["Success"] = "Profil modifié.";
            }
            else
            {
                _context.Profils.Add(new Profil { TenantId = tenant, Nom = nom, Description = description == "" ? null : description, Droits = string.Join(",", codes) });
                await _context.SaveChangesAsync();
                TempData["Success"] = "Profil créé.";
            }
            return RedirectToAction("Index");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Delete(int id)
        {
            var p = await _context.Profils.FirstOrDefaultAsync(x => x.Id == id);
            if (p == null)
                return NotFound();
            var n = await _context.Utilisateurs.IgnoreQueryFilters().CountAsync(u => u.ProfilId == id);
            if (n > 0)
                TempData["Error"] = $"Ce profil est attribué à {n} utilisateur{(n > 1 ? "s" : "")} : changez d'abord leur profil.";
            else
            {
                _context.Profils.Remove(p);
                await _context.SaveChangesAsync();
                TempData["Success"] = "Profil supprimé.";
            }
            return RedirectToAction("Index");
        }
    }
}
