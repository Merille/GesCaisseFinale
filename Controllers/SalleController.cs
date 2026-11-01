using System.Text.Json;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Plan de salle d'une caisse restaurant / bar : salles et tables placées sur un plan.
    // Réservé aux profils Admin et SuperAdmin.
    [Authorize(Policy = "Admin")]
    public class SalleController : Controller
    {
        private readonly AppDbContext _context;
        private readonly IAntiforgery _antiforgery;

        public SalleController(AppDbContext context, IAntiforgery antiforgery)
        {
            _context = context;
            _antiforgery = antiforgery;
        }

        public async Task<IActionResult> Index(int caisse)
        {
            var c = await _context.Caisses.FirstOrDefaultAsync(x => x.ID == caisse);
            if (c == null)
                return NotFound();
            if (!c.EstRestaurant)
            {
                TempData["Error"] = $"Le plan de salle concerne les caisses de type Restaurant ou Bar : modifiez d'abord le type de la caisse « {c.ChkCode} ».";
                return RedirectToAction("Index", "Caisse");
            }
            var jetons = _antiforgery.GetAndStoreTokens(HttpContext);
            ViewBag.Donnees = new
            {
                caisseId = c.ID,
                salles = await Restaurant.PlanAsync(_context, c.ID, false),
                urlEnregistrer = "/Salle/Enregistrer",
                jeton = new { nom = jetons.FormFieldName, valeur = jetons.RequestToken }
            };
            return View(c);
        }

        private class PlanSaisi
        {
            public int CaisseId { get; set; }
            public List<SalleSaisie> Salles { get; set; } = new();
        }

        private class SalleSaisie
        {
            public int Id { get; set; }
            public string? Nom { get; set; }
            public List<TableSaisie> Tables { get; set; } = new();
        }

        private class TableSaisie
        {
            public int Id { get; set; }
            public string? Nom { get; set; }
            public int Places { get; set; } = 4;
            public string? Forme { get; set; }
            public int X { get; set; }
            public int Y { get; set; }
            public int L { get; set; } = 100;
            public int H { get; set; } = 100;
        }

        // Enregistre tout le plan d'une caisse (salles et tables) envoyé en JSON par l'éditeur.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Enregistrer(string? plan)
        {
            PlanSaisi? saisi;
            try { saisi = JsonSerializer.Deserialize<PlanSaisi>(plan ?? "", Restaurant.Json); }
            catch (JsonException) { saisi = null; }
            if (saisi == null)
                return BadRequest(new { erreur = "Plan illisible." });
            var caisse = await _context.Caisses.FirstOrDefaultAsync(c => c.ID == saisi.CaisseId);
            if (caisse == null)
                return NotFound(new { erreur = "Caisse introuvable." });

            var salles = await _context.Salles.Include(s => s.Tables).Where(s => s.CaisseId == caisse.ID).ToListAsync();
            var tables = salles.SelectMany(s => s.Tables).ToDictionary(t => t.Id);
            string Couper(string? s, int max) => (s ?? "").Trim().Length > max ? s!.Trim()[..max] : (s ?? "").Trim();
            var gardees = saisi.Salles.Take(30).SelectMany(s => s.Tables.Take(200)).Select(t => t.Id).Where(tables.ContainsKey).ToHashSet();

            // Une table retirée ne doit pas avoir de commande en cours.
            var retirees = tables.Keys.Where(id => !gardees.Contains(id)).ToList();
            var occupees = await _context.CommandesOuvertes.Where(c => c.TableId != null && retirees.Contains(c.TableId.Value))
                .Select(c => c.TableId!.Value).ToListAsync();
            if (occupees.Any())
                return Conflict(new { erreur = $"Impossible de retirer {string.Join(", ", occupees.Select(id => tables[id].Nom))} : une commande y est en cours. Encaissez-la ou transférez-la d'abord." });

            await using var transaction = await _context.Database.BeginTransactionAsync();
            var sallesGardees = new HashSet<int>();
            var ordre = 0;
            foreach (var s in saisi.Salles.Take(30))
            {
                var salle = salles.FirstOrDefault(x => x.Id == s.Id);
                if (salle == null)
                {
                    salle = new Salle { TenantId = caisse.TenantId, CaisseId = caisse.ID };
                    _context.Salles.Add(salle);
                }
                salle.Nom = Couper(s.Nom, 50) is { Length: > 0 } nom ? nom : $"Salle {ordre + 1}";
                salle.Ordre = ordre++;
                await _context.SaveChangesAsync();
                sallesGardees.Add(salle.Id);
                var n = 0;
                foreach (var t in s.Tables.Take(200))
                {
                    n++;
                    if (!tables.TryGetValue(t.Id, out var table))
                    {
                        table = new TableRestaurant { TenantId = caisse.TenantId };
                        _context.TablesRestaurant.Add(table);
                    }
                    table.SalleId = salle.Id;
                    table.Nom = Couper(t.Nom, 30) is { Length: > 0 } tn ? tn : $"Table {n}";
                    table.Places = Math.Clamp(t.Places, 1, 50);
                    table.Forme = t.Forme == "ronde" ? "ronde" : "carree";
                    table.Largeur = Math.Clamp(t.L, 40, 400);
                    table.Hauteur = Math.Clamp(t.H, 40, 400);
                    table.PosX = Math.Clamp(t.X, 0, 1000 - table.Largeur);
                    table.PosY = Math.Clamp(t.Y, 0, 600 - table.Hauteur);
                }
            }
            _context.TablesRestaurant.RemoveRange(retirees.Select(id => tables[id]));
            await _context.SaveChangesAsync();
            _context.Salles.RemoveRange(salles.Where(s => !sallesGardees.Contains(s.Id)));
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return Json(new { salles = await Restaurant.PlanAsync(_context, caisse.ID, false) });
        }
    }
}
