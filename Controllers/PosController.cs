using System.Security.Claims;
using System.Text.Json;
using EasytransitCaisse.Data;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Point de vente : choix de la journée ouverte, puis écran de vente plein écran.
    // Ouvert à tous les profils connectés. Les tickets en cours sont gardés dans le
    // navigateur jusqu'au paiement.
    public class PosController : Controller
    {
        private readonly AppDbContext _context;

        public PosController(AppDbContext context)
        {
            _context = context;
        }

        public async Task<IActionResult> Index(int journee = 0)
        {
            if (journee == 0)
            {
                var ouvertes = await _context.JourneesCaisses
                    .Include(j => j.Caisse)
                    .Where(j => j.Statut == "Ouverte")
                    .OrderByDescending(j => j.DateJournee).ThenBy(j => j.Caisse.ChkCode)
                    .ToListAsync();
                return View("Choix", ouvertes);
            }

            var j = await _context.JourneesCaisses.Include(x => x.Caisse).FirstOrDefaultAsync(x => x.Id == journee);
            if (j == null)
                return NotFound();
            if (j.Statut != "Ouverte")
            {
                TempData["Error"] = "Cette journée est clôturée : ouvrez une nouvelle journée pour vendre.";
                return RedirectToAction("Index");
            }

            // Catalogue de la société de la journée (aussi pour le SuperAdmin en mode « toutes »).
            var tenant = j.TenantId;
            var produits = await _context.Produits
                .Where(p => p.Actif && p.TenantId == tenant)
                .OrderBy(p => p.Nom)
                .Select(p => new
                {
                    id = p.Id,
                    code = p.Code,
                    codeBarres = p.CodeBarres,
                    nom = p.Nom,
                    categorieId = p.CategorieId,
                    prix = p.PrixVente,
                    tva = p.TauxTVA,
                    suivi = p.SuiviStock,
                    stock = p.StockActuel,
                    seuil = p.SeuilAlerte
                })
                .ToListAsync();
            var categories = await _context.Categories
                .Where(c => c.TenantId == tenant)
                .OrderBy(c => c.Ordre).ThenBy(c => c.Nom)
                .Select(c => new { id = c.Id, nom = c.Nom, couleur = c.Couleur })
                .ToListAsync();
            var clients = await _context.Clients
                .Where(c => c.TenantId == tenant)
                .OrderBy(c => c.NomSociete)
                .Select(c => new { id = c.Id, nom = c.NomSociete, code = c.CodeClient })
                .ToListAsync();

            var profil = User.FindFirst(AppClaimTypes.Profil)?.Value ?? "";
            var nom = User.FindFirst(AppClaimTypes.NomComplet)?.Value;
            var donnees = new
            {
                cle = $"gescaisse-pos:{tenant}:{j.Id}",
                journee = new
                {
                    id = j.Id,
                    caisse = j.Caisse?.ChkCode ?? "",
                    libelle = $"{j.Caisse?.ChkDescription} · Journée du {j.DateJournee:dd/MM/yyyy} (ouverte)"
                },
                produits,
                categories,
                clients,
                utilisateur = new
                {
                    nom = string.IsNullOrWhiteSpace(nom) ? User.FindFirst(ClaimTypes.Name)?.Value : nom,
                    profil
                },
                peutModifierPrix = profil is "Admin" or "SuperAdmin",
                urlFermer = $"/JourneeCaisse/Details/{j.Id}"
            };

            // L'encodeur par défaut échappe < > & ' " : le JSON peut aller dans une balise <script>.
            ViewBag.Donnees = JsonSerializer.Serialize(donnees);
            return View("Ecran");
        }
    }
}
