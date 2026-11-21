using System.Text.RegularExpressions;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Imprimantes de préparation (cuisine, bar) en réseau : la caisse leur envoie directement les bons des
    // catégories choisies. Epson : impression directe (ePOS) ; Réseau : imprimante ESC/POS par l'agent d'impression.
    public class ImprimanteController : Controller
    {
        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public static readonly Dictionary<string, string> Types = new() { ["Epson"] = "Epson (ePOS)", ["Reseau"] = "Autre (ESC/POS réseau, agent)" };

        public ImprimanteController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        // Imprimante au format du module d'impression (wwwroot/js/imprimantes.js).
        public static object Js(ImprimantePreparation i) => new
        {
            id = i.Id, nom = i.Nom, type = i.Type, ip = i.AdresseIp, port = i.Port, largeur = i.Largeur,
            encodage = i.Encodage, bip = i.Bip, categories = i.Categories.Select(c => c.CategorieId).OrderBy(c => c).ToList()
        };

        // Imprimantes actives d'une caisse (ou de toutes les caisses), pour l'écran de vente.
        public static async Task<List<object>> DeLaCaisseAsync(AppDbContext context, int tenantId, int caisseId)
        {
            var liste = await context.ImprimantesPreparation.IgnoreQueryFilters().Include(i => i.Categories)
                .Where(i => i.TenantId == tenantId && i.Actif && (i.CaisseId == null || i.CaisseId == caisseId))
                .OrderBy(i => i.Nom).ThenBy(i => i.Id).ToListAsync();
            return liste.Select(Js).ToList();
        }

        public async Task<IActionResult> Index()
        {
            var imprimantes = await _context.ImprimantesPreparation.Include(i => i.Categories)
                .OrderByDescending(i => i.Actif).ThenBy(i => i.Nom).ThenBy(i => i.Id).ToListAsync();
            ViewBag.Categories = await _context.Categories.OrderBy(c => c.Ordre).ThenBy(c => c.Nom).ToListAsync();
            ViewBag.Caisses = await _context.Caisses.Where(c => c.TypePointVente == "Restaurant" || c.TypePointVente == "Bar")
                .OrderBy(c => c.ChkCode).ToListAsync();
            return View(imprimantes);
        }

        private static readonly Regex AdresseValide = new(@"^[A-Za-z0-9]([A-Za-z0-9.\-]{0,98}[A-Za-z0-9])?$");

        // Création (Id = 0) ou modification.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Save(int id, string? nom, string? type, string? adresseIp, string? port, int largeur, string? encodage,
            string? bip, string? actif, string? caisseId, List<int>? categories)
        {
            nom = (nom ?? "").Trim();
            if (nom.Length > 100) nom = nom[..100];
            var adresse = (adresseIp ?? "").Trim();
            int? numPort = int.TryParse(port, out var p) ? p : null;
            if (nom == "")
                return Erreur("Le nom de l'imprimante est obligatoire.");
            if (!AdresseValide.IsMatch(adresse) || (numPort != null && (numPort < 1 || numPort > 65535)))
                return Erreur("Adresse IP ou port de l'imprimante invalide.");
            var imprimante = id > 0 ? await _context.ImprimantesPreparation.Include(i => i.Categories).FirstOrDefaultAsync(i => i.Id == id) : null;
            if (id > 0 && imprimante == null)
                return NotFound();
            var tenantId = imprimante?.TenantId ?? _tenant.TenantId;
            if (tenantId == 0)
                return Erreur("Choisissez d'abord la société concernée dans le menu « Société consultée », puis recommencez.");
            int? caisse = int.TryParse(caisseId, out var c) && await _context.Caisses.AnyAsync(x => x.ID == c) ? c : null;
            var ids = (categories ?? new()).Distinct().ToList();
            var cats = await _context.Categories.Where(x => ids.Contains(x.Id)).Select(x => x.Id).ToListAsync();

            if (imprimante == null)
            {
                imprimante = new ImprimantePreparation { TenantId = tenantId };
                _context.ImprimantesPreparation.Add(imprimante);
                TempData["Success"] = "Imprimante créée.";
            }
            else
            {
                _context.ImprimantesPreparationCategories.RemoveRange(imprimante.Categories);
                imprimante.Categories = new();
                TempData["Success"] = "Imprimante modifiée.";
            }
            imprimante.Nom = nom;
            imprimante.Type = ImprimantePreparation.Types.Contains(type) ? type! : "Epson";
            imprimante.AdresseIp = adresse;
            imprimante.Port = numPort;
            imprimante.Largeur = largeur == 58 ? 58 : 80;
            imprimante.Encodage = encodage == "SansAccents" ? "SansAccents" : "PC850";
            imprimante.Bip = !string.IsNullOrEmpty(bip);
            imprimante.Actif = !string.IsNullOrEmpty(actif);
            imprimante.CaisseId = caisse;
            imprimante.Categories = cats.Select(x => new ImprimantePreparationCategorie { CategorieId = x }).ToList();
            await _context.SaveChangesAsync();
            return RedirectToAction("Index");
        }

        // Active ou désactive l'imprimante (la caisse ne lui envoie plus de bons).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Basculer(int id)
        {
            var imprimante = await _context.ImprimantesPreparation.FirstOrDefaultAsync(i => i.Id == id);
            if (imprimante == null)
                return NotFound();
            imprimante.Actif = !imprimante.Actif;
            await _context.SaveChangesAsync();
            TempData["Success"] = imprimante.Actif ? $"Imprimante « {imprimante.Nom} » activée." : $"Imprimante « {imprimante.Nom} » désactivée.";
            return RedirectToAction("Index");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Delete(int id)
        {
            var imprimante = await _context.ImprimantesPreparation.FirstOrDefaultAsync(i => i.Id == id);
            if (imprimante != null)
            {
                _context.ImprimantesPreparation.Remove(imprimante);
                await _context.SaveChangesAsync();
                TempData["Success"] = $"Imprimante « {imprimante.Nom} » supprimée.";
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
