using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Livreurs (sans compte de connexion) : choisis au point de vente sur une commande à livrer.
    // Un livreur qui a déjà des livraisons se désactive au lieu d'être supprimé.
    // Réservé aux profils Admin et SuperAdmin.
    [Authorize(Policy = "Admin")]
    public class LivreurController : Controller
    {
        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public LivreurController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        public async Task<IActionResult> Index()
        {
            var livreurs = await _context.Livreurs.OrderByDescending(l => l.Actif).ThenBy(l => l.Nom).ThenBy(l => l.Id).ToListAsync();
            ViewBag.NbLivraisons = await _context.CommandesPos.Where(c => c.LivreurId != null)
                .GroupBy(c => c.LivreurId!.Value).Select(g => new { g.Key, Nb = g.Count() }).ToDictionaryAsync(x => x.Key, x => x.Nb);
            return View(livreurs);
        }

        private static string? Texte(string? valeur, int max)
        {
            var t = (valeur ?? "").Trim();
            return t == "" ? null : t[..Math.Min(max, t.Length)];
        }

        // Création (Id = 0) ou modification.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Save(int id, string? nom, string? telephone, bool actif)
        {
            nom = Texte(nom, 100);
            if (nom == null)
                return Erreur("Le nom du livreur est obligatoire.");
            var livreur = id > 0 ? await _context.Livreurs.FirstOrDefaultAsync(l => l.Id == id) : null;
            if (id > 0 && livreur == null)
                return NotFound();
            var tenantId = livreur?.TenantId ?? _tenant.TenantId;
            if (tenantId == 0)
                return Erreur("Choisissez d'abord la société concernée dans le menu « Société consultée », puis recommencez.");
            if (livreur != null)
            {
                livreur.Nom = nom;
                livreur.Telephone = Texte(telephone, 30);
                livreur.Actif = actif;
                TempData["Success"] = "Livreur modifié.";
            }
            else
            {
                _context.Livreurs.Add(new Livreur { TenantId = tenantId, Nom = nom, Telephone = Texte(telephone, 30), Actif = actif });
                TempData["Success"] = "Livreur créé.";
            }
            await _context.SaveChangesAsync();
            return RedirectToAction("Index");
        }

        // Active ou désactive le livreur (il n'est plus proposé au point de vente).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Basculer(int id)
        {
            var livreur = await _context.Livreurs.FirstOrDefaultAsync(l => l.Id == id);
            if (livreur == null)
                return NotFound();
            livreur.Actif = !livreur.Actif;
            await _context.SaveChangesAsync();
            TempData["Success"] = livreur.Actif
                ? $"Livreur « {livreur.Nom} » activé."
                : $"Livreur « {livreur.Nom} » désactivé : il n'est plus proposé au point de vente.";
            return RedirectToAction("Index");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Delete(int id)
        {
            var livreur = await _context.Livreurs.FirstOrDefaultAsync(l => l.Id == id);
            if (livreur != null)
            {
                var utilise = await _context.CommandesPos.IgnoreQueryFilters().AnyAsync(c => c.LivreurId == id)
                    || await _context.CommandesAttente.IgnoreQueryFilters().AnyAsync(c => c.LivreurId == id);
                if (utilise)
                    return Erreur($"Le livreur « {livreur.Nom} » a déjà des livraisons : désactivez-le plutôt que de le supprimer.");
                _context.Livreurs.Remove(livreur);
                await _context.SaveChangesAsync();
                TempData["Success"] = $"Livreur « {livreur.Nom} » supprimé.";
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
