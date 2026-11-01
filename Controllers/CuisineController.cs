using EasytransitCaisse.Data;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Écran cuisine / bar : bons de préparation des caisses restaurant / bar, actualisés en continu.
    // Ouvert à tous les profils connectés (cuisiniers, barmans, serveurs).
    public class CuisineController : Controller
    {
        private readonly AppDbContext _context;
        private readonly IAntiforgery _antiforgery;

        public CuisineController(AppDbContext context, IAntiforgery antiforgery)
        {
            _context = context;
            _antiforgery = antiforgery;
        }

        public async Task<IActionResult> Index(int caisse = 0, string? poste = null)
        {
            var caisses = await _context.Caisses.Where(c => c.TypePointVente == "Restaurant" || c.TypePointVente == "Bar")
                .OrderBy(c => c.ChkCode).ToListAsync();
            var choisie = caisses.FirstOrDefault(c => c.ID == caisse) ?? (caisses.Count == 1 ? caisses[0] : null);
            if (choisie == null)
                return View("Choix", caisses);
            var jetons = _antiforgery.GetAndStoreTokens(HttpContext);
            ViewBag.Donnees = new
            {
                caisse = choisie.ChkCode ?? "",
                poste = poste is "Cuisine" or "Bar" ? poste : "",
                urlBons = $"/Cuisine/Bons?caisse={choisie.ID}",
                urlStatut = "/Cuisine/Statut",
                urlRetour = "/Dashboard/Index",
                jeton = new { nom = jetons.FormFieldName, valeur = jetons.RequestToken }
            };
            return View();
        }

        // Bons à préparer (et prêts depuis moins de 2 heures) d'une caisse, en JSON.
        public async Task<IActionResult> Bons(int caisse, string? poste)
        {
            if (!await _context.Caisses.AnyAsync(c => c.ID == caisse))
                return NotFound(new { erreur = "Caisse introuvable." });
            var requete = _context.BonsPreparation.Include(b => b.Lignes).Where(b => b.CaisseId == caisse);
            if (poste is "Cuisine" or "Bar")
                requete = requete.Where(b => b.Poste == poste);
            var depuis = DateTime.Now.AddHours(-2);
            var aPreparer = await requete.Where(b => b.Statut == "À préparer").OrderBy(b => b.DateEnvoi).ThenBy(b => b.Id).Take(60).ToListAsync();
            var prets = await requete.Where(b => b.Statut == "Prêt" && b.DatePret >= depuis).OrderByDescending(b => b.DatePret).Take(8).ToListAsync();
            object Json(Models.BonPreparation b) => new
            {
                id = b.Id, numero = b.Numero, poste = b.Poste, table = b.TableNom, couverts = b.Couverts, serveur = b.Serveur,
                date = b.DateEnvoi.ToString("yyyy-MM-ddTHH:mm:ss"),
                lignes = b.Lignes.OrderBy(l => l.Id).Select(l => new { libelle = l.Libelle, qte = l.Quantite, note = l.Note })
            };
            return base.Json(new { bons = aPreparer.Select(Json), prets = prets.Select(Json) });
        }

        // « Prêt » (retiré de l'écran) ou « À préparer » (rappelé).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Statut(int id, string? statut)
        {
            var bon = await _context.BonsPreparation.FirstOrDefaultAsync(b => b.Id == id);
            if (bon != null)
            {
                bon.Statut = statut == "Prêt" ? "Prêt" : "À préparer";
                bon.DatePret = bon.Statut == "Prêt" ? DateTime.Now : null;
                await _context.SaveChangesAsync();
            }
            return base.Json(new { ok = true });
        }
    }
}
