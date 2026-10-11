using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace EasytransitCaisse.Controllers
{
    // Réservé aux profils Admin et SuperAdmin.
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
            var motifs = _context.Motifs.OrderBy(m => m.LibelleMotif).ToList();
            return View(motifs);
        }

        // Liste des Motifs
        //public async Task<IActionResult> Index()
        //{
        //    var motifs = await _context.Motifs
        //        .OrderBy(c => c.LibelleMotif)
        //        .ToListAsync();

        //    return View(motifs);
        //}

        public IActionResult Create() => View();

        [HttpPost]
        public IActionResult Create(Motif motif)
        {
            _context.Motifs.Add(motif);
            _context.SaveChanges();
            TempData["Success"] = "Motif créé avec succès.";
            return RedirectToAction("Index");
        }

        public IActionResult Edit(int id)
        {
            var motif = _context.Motifs.Find(id);
            if (motif == null) return NotFound();
            return View(motif);
        }

        [HttpPost]
        public IActionResult Edit(Motif motif)
        {
            var existing = _context.Motifs.Find(motif.ID);

            if (existing == null)
                return NotFound();

            // Copie champ à champ (et non Update() global) pour ne pas écraser
            // TenantId, absent du formulaire, avec la valeur par défaut 0.
            existing.LibelleMotif = motif.LibelleMotif;
            existing.TypeModif = motif.TypeModif;
            existing.CG_Num = motif.CG_Num;

            _context.SaveChanges();
            TempData["Success"] = "Motif modifié avec succès.";
            return RedirectToAction("Index");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Delete(int id)
        {
            var motif = _context.Motifs.Find(id);
            if (motif != null)
            {
                _context.Motifs.Remove(motif);
                _context.SaveChanges();
            }
            return RedirectToAction("Index");
        }
    }
}
