using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace EasytransitCaisse.Controllers
{
    // Motifs d'opération (avec compte général pour l'export Sage), comme la version PHP :
    // création et modification dans la même fenêtre (Save). Réservé aux profils Admin et SuperAdmin.
    [Authorize(Policy = "Admin")]
    public class MotifController : Controller
    {
        private readonly AppDbContext _context;

        public MotifController(AppDbContext context)
        {
            _context = context;
        }

        public IActionResult Index()
        {
            return View(_context.Motifs.OrderBy(m => m.LibelleMotif).ToList());
        }

        // Création (sans ID) ou modification (avec ID).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Save(int? id, string? libelleMotif, string? typeModif, string? cG_Num)
        {
            if (id is > 0)
            {
                var motif = _context.Motifs.FirstOrDefault(m => m.ID == id);
                if (motif == null)
                    return NotFound();
                motif.LibelleMotif = libelleMotif ?? "";
                motif.TypeModif = string.IsNullOrEmpty(typeModif) ? null : typeModif;
                motif.CG_Num = string.IsNullOrEmpty(cG_Num) ? null : cG_Num;
                _context.SaveChanges();
                TempData["Success"] = "Motif modifié avec succès.";
            }
            else
            {
                _context.Motifs.Add(new Motif
                {
                    LibelleMotif = libelleMotif ?? "",
                    TypeModif = string.IsNullOrEmpty(typeModif) ? null : typeModif,
                    CG_Num = string.IsNullOrEmpty(cG_Num) ? null : cG_Num
                });
                _context.SaveChanges();
                TempData["Success"] = "Motif créé avec succès.";
            }
            return RedirectToAction("Index");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Delete(int id)
        {
            var motif = _context.Motifs.FirstOrDefault(m => m.ID == id);
            if (motif != null)
            {
                if (_context.OperationsCaisses.Any(o => o.MotifId == id))
                    TempData["Error"] = "Ce motif est utilisé par des opérations : il ne peut pas être supprimé.";
                else
                {
                    _context.Motifs.Remove(motif);
                    _context.SaveChanges();
                    TempData["Success"] = "Motif supprimé.";
                }
            }
            return RedirectToAction("Index");
        }
    }
}
