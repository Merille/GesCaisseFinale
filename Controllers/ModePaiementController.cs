using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using Microsoft.AspNetCore.Mvc;

namespace EasytransitCaisse.Controllers
{
    public class ModePaiementController : Controller
    {
        private readonly AppDbContext _context;

        public ModePaiementController(AppDbContext context)
        {
            _context = context;
        }

        public IActionResult Index()
        {
            var modes = _context.ModesPaiement.OrderBy(m => m.Libelle).ToList();
            return View(modes);
        }

        [HttpPost]
        public IActionResult Create(ModePaiement mode)
        {
            _context.ModesPaiement.Add(mode);
            _context.SaveChanges();
            TempData["Success"] = "Mode de paiement créé avec succès.";
            return RedirectToAction("Index");
        }

        [HttpPost]
        public IActionResult Edit(ModePaiement mode)
        {
            var existing = _context.ModesPaiement.Find(mode.Id);

            if (existing == null)
                return NotFound();

            existing.Code = mode.Code;
            existing.Libelle = mode.Libelle;
            existing.Actif = mode.Actif;

            _context.SaveChanges();
            TempData["Success"] = "Mode de paiement modifié avec succès.";
            return RedirectToAction("Index");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Delete(int id)
        {
            var mode = _context.ModesPaiement.Find(id);

            if (mode != null)
            {
                _context.ModesPaiement.Remove(mode);
                _context.SaveChanges();
            }

            return RedirectToAction("Index");
        }
    }
}
