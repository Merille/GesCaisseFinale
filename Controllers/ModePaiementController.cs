using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace EasytransitCaisse.Controllers
{
    // Modes de paiement (espèces, chèque, mobile money...), comme la version PHP :
    // création et modification dans la même fenêtre (Save). Réservé aux profils Admin et SuperAdmin.
    [Authorize(Policy = "Admin")]
    public class ModePaiementController : Controller
    {
        private readonly AppDbContext _context;

        public ModePaiementController(AppDbContext context)
        {
            _context = context;
        }

        public IActionResult Index()
        {
            return View(_context.ModesPaiement.OrderBy(m => m.Libelle).ToList());
        }

        // Création (sans Id) ou modification (avec Id).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Save(int? id, string? code, string? libelle, bool actif, bool estCompte)
        {
            if (id is > 0)
            {
                var mode = _context.ModesPaiement.FirstOrDefault(m => m.Id == id);
                if (mode == null)
                    return NotFound();
                mode.Code = code ?? "";
                mode.Libelle = libelle ?? "";
                mode.Actif = actif;
                mode.EstCompte = estCompte;
                _context.SaveChanges();
                TempData["Success"] = "Mode de paiement modifié avec succès.";
            }
            else
            {
                _context.ModesPaiement.Add(new ModePaiement { Code = code ?? "", Libelle = libelle ?? "", Actif = actif, EstCompte = estCompte });
                _context.SaveChanges();
                TempData["Success"] = "Mode de paiement créé avec succès.";
            }
            return RedirectToAction("Index");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Delete(int id)
        {
            var mode = _context.ModesPaiement.FirstOrDefault(m => m.Id == id);
            if (mode != null)
            {
                if (_context.OperationsCaisses.Any(o => o.ModePaiementId == id) || _context.PaiementsPos.Any(p => p.ModePaiementId == id))
                    TempData["Error"] = "Ce mode de paiement est utilisé par des opérations ou des ventes : désactivez-le plutôt que de le supprimer.";
                else
                {
                    _context.ModesPaiement.Remove(mode);
                    _context.SaveChanges();
                    TempData["Success"] = "Mode de paiement supprimé.";
                }
            }
            return RedirectToAction("Index");
        }
    }
}
