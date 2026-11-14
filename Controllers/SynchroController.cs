using System.Security.Claims;
using System.Text.Json;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Models.ViewModels;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Synchronisation du mode hors ligne (administrateurs) : état de la file de chaque poste (opérations
    // faites sans connexion pas encore envoyées, refusées), ventes et dépôts de linge enregistrés hors
    // ligne sur une période, vérification des ventes arrivées avec des écarts (une par une ou en groupe).
    // Le rapport de chaque poste (Rapport) est envoyé par hors-ligne.js quand le poste est connecté.
    // Même fonctionnement que la version PHP (synchro.php).
    [Authorize]
    public class SynchroController : Controller
    {
        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public SynchroController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        private static readonly JsonSerializerOptions Json = new() { PropertyNameCaseInsensitive = true };

        // État d'un poste : à jour, en attente d'envoi, refus, ou sans nouvelles depuis plus d'une heure.
        public static (string Etat, string Badge) EtatPoste(PosteHorsLigne p)
        {
            if (p.Refusees > 0)
                return ("Refus", "bg-danger");
            if (p.EnAttente > 0)
                return DateTime.Now - p.DernierRapport > TimeSpan.FromHours(1) ? ("Sans nouvelles", "bg-dark") : ("En attente d'envoi", "bg-warning text-dark");
            return ("À jour", "bg-success");
        }

        // « il y a 5 min », « il y a 3 h », « il y a 2 j ».
        public static string Depuis(DateTime? date)
        {
            if (date == null)
                return "";
            var s = Math.Max(0, (int)(DateTime.Now - date.Value).TotalSeconds);
            return s < 60 ? "à l'instant" : s < 3600 ? $"il y a {s / 60} min" : s < 86400 ? $"il y a {s / 3600} h" : $"il y a {s / 86400} j";
        }

        public async Task<IActionResult> Index(DateTime? du, DateTime? au, string? etat)
        {
            var f = new FiltresSynchro
            {
                Du = (du ?? DateTime.Today.AddDays(-30)).Date,
                Au = (au ?? DateTime.Today).Date,
                Etat = FiltresSynchro.Etats.Any(e => e.Valeur == (etat ?? "à vérifier")) ? etat ?? "à vérifier" : "à vérifier"
            };
            if (f.Au < f.Du)
                (f.Du, f.Au) = (f.Au, f.Du);

            // Postes vus depuis 30 jours, ceux qui ont des envois en attente d'abord.
            var limite = DateTime.Now.AddDays(-30);
            var postes = await _context.PostesHorsLigne.Where(p => p.EnAttente > 0 || p.DernierRapport >= limite)
                .OrderByDescending(p => p.EnAttente > 0).ThenByDescending(p => p.Refusees).ThenByDescending(p => p.DernierRapport).ToListAsync();
            var ids = postes.Where(p => p.UtilisateurId != null).Select(p => p.UtilisateurId!.Value).Distinct().ToList();
            var noms = await _context.Utilisateurs.IgnoreQueryFilters().Where(u => ids.Contains(u.Id)).ToDictionaryAsync(u => u.Id, u => u.NomComplet);
            var vm = new SynchroVM
            {
                Filtres = f,
                Postes = postes.Select(p =>
                {
                    var (e, b) = EtatPoste(p);
                    List<ElementPoste> elements;
                    try { elements = JsonSerializer.Deserialize<List<ElementPoste>>(p.Detail ?? "[]", Json) ?? new(); }
                    catch (JsonException) { elements = new(); }
                    return new LignePoste { Poste = p, Utilisateur = p.UtilisateurId is int u ? noms.GetValueOrDefault(u) : null, Elements = elements, Etat = e, Badge = b };
                }).ToList()
            };

            var fin = f.Au.AddDays(1);
            var requete = _context.CommandesPos.Where(c => c.NumeroHorsLigne != null);
            // « À vérifier » : toutes les ventes en attente de vérification, quelle que soit leur date.
            if (f.Etat == "à vérifier")
                requete = requete.Where(c => c.AlerteHorsLigne != null && c.AlerteHorsLigneVue == null);
            else
            {
                requete = requete.Where(c => c.DateCommande >= f.Du && c.DateCommande < fin);
                if (f.Etat == "vérifiées")
                    requete = requete.Where(c => c.AlerteHorsLigneVue != null);
                else if (f.Etat == "sans écart")
                    requete = requete.Where(c => c.AlerteHorsLigne == null);
            }
            var ventes = await requete.Include(c => c.JourneeCaisse).ThenInclude(j => j!.Caisse)
                .OrderByDescending(c => c.DateCommande).ThenByDescending(c => c.Id).Take(500).ToListAsync();
            var vendeurs = ventes.Select(v => v.UtilisateurId).Distinct().ToList();
            var nomsVendeurs = await _context.Utilisateurs.IgnoreQueryFilters().Where(u => vendeurs.Contains(u.Id)).ToDictionaryAsync(u => u.Id, u => u.NomComplet);
            vm.Ventes = ventes.Select(v => new LigneVenteHorsLigne { Vente = v, Caisse = v.JourneeCaisse?.Caisse?.ChkCode, Vendeur = nomsVendeurs.GetValueOrDefault(v.UtilisateurId) }).ToList();

            var periode = _context.CommandesPos.Where(c => c.NumeroHorsLigne != null && c.DateCommande >= f.Du && c.DateCommande < fin);
            vm.NbVentes = await periode.CountAsync();
            vm.MontantVentes = await periode.Where(c => c.Statut != "Annulée").SumAsync(c => (decimal?)c.TotalTTC) ?? 0;
            vm.AVerifier = await _context.CommandesPos.CountAsync(c => c.AlerteHorsLigne != null && c.AlerteHorsLigneVue == null);
            if (await _context.Caisses.AnyAsync(c => c.TypePointVente == "Laverie"))
            {
                var caisses = await _context.Caisses.ToDictionaryAsync(c => c.ID, c => c.ChkCode);
                vm.Depots = (await _context.DepotsLinge.Where(d => d.NumeroHorsLigne != null && d.DateDepot >= f.Du && d.DateDepot < fin)
                        .OrderByDescending(d => d.DateDepot).Take(300).ToListAsync())
                    .Select(d => (d, caisses.GetValueOrDefault(d.CaisseId))).ToList();
            }
            return View(vm);
        }

        // Ventes cochées marquées vérifiées.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Verifier(int[]? ids, DateTime? du, DateTime? au, string? etat)
        {
            var liste = (ids ?? Array.Empty<int>()).ToList();
            var ventes = await _context.CommandesPos.Where(c => liste.Contains(c.Id) && c.AlerteHorsLigne != null && c.AlerteHorsLigneVue == null).ToListAsync();
            foreach (var v in ventes)
                v.AlerteHorsLigneVue = DateTime.Now;
            await _context.SaveChangesAsync();
            var n = ventes.Count;
            if (n > 0)
                TempData["Success"] = $"{n} vente{(n > 1 ? "s" : "")} marquée{(n > 1 ? "s" : "")} vérifiée{(n > 1 ? "s" : "")}.";
            else
                TempData["Error"] = "Aucune vente à vérifier cochée.";
            return RedirectToAction("Index", new { du = du?.ToString("yyyy-MM-dd"), au = au?.ToString("yyyy-MM-dd"), etat });
        }

        // Poste qui ne sert plus : retiré de la liste (il réapparaît s'il envoie un nouveau rapport).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Oublier(int id)
        {
            var p = await _context.PostesHorsLigne.FirstOrDefaultAsync(x => x.Id == id);
            if (p != null)
            {
                _context.PostesHorsLigne.Remove(p);
                await _context.SaveChangesAsync();
            }
            TempData["Success"] = "Poste retiré de la liste.";
            return RedirectToAction("Index");
        }

        private sealed class RapportSaisi
        {
            public string? Poste { get; set; }
            public int EnAttente { get; set; }
            public int Refusees { get; set; }
            public decimal Montant { get; set; }
            public string? PlusAncien { get; set; }
            public string? DernierEnvoi { get; set; }
            public List<ElementSaisi> Elements { get; set; } = new();
        }

        private sealed class ElementSaisi
        {
            public string? Numero { get; set; }
            public string? Type { get; set; }
            public string? Libelle { get; set; }
            public decimal? Montant { get; set; }
            public string? Cree { get; set; }
            public string? Erreur { get; set; }
        }

        private static DateTime? LireDate(string? v)
            => DateTimeOffset.TryParse(v, System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.AssumeLocal, out var d)
                ? (d.ToLocalTime().DateTime is var l && l > DateTime.Now ? DateTime.Now : l) : null;

        private static string Couper(string? s, int max) => (s ?? "").Length > max ? s![..max] : s ?? "";

        // Rapport d'un poste (JSON, champ « rapport ») : état de sa file hors ligne. Envoyé par hors-ligne.js
        // à l'ouverture des pages, après chaque envoi et toutes les 5 minutes, quand le poste est connecté.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Rapport([FromForm] string? rapport)
        {
            RapportSaisi? r;
            try { r = JsonSerializer.Deserialize<RapportSaisi>(rapport ?? "", Json); }
            catch (JsonException) { r = null; }
            var code = new string((r?.Poste ?? "").ToUpperInvariant().Where(char.IsAsciiLetterOrDigit).Take(10).ToArray());
            var tenant = _tenant.TenantId;
            if (r == null || code == "" || tenant == 0)
                return Json(new { ok = false });
            var elements = r.Elements.Take(50).Select(e => new ElementPoste
            {
                Numero = Couper(e.Numero, 30), Type = Couper(e.Type, 10), Libelle = Couper(e.Libelle, 120),
                Montant = e.Montant.HasValue ? Math.Round(e.Montant.Value) : null, Cree = LireDate(e.Cree), Erreur = Couper(e.Erreur, 200)
            }).ToList();
            var p = await _context.PostesHorsLigne.IgnoreQueryFilters().FirstOrDefaultAsync(x => x.TenantId == tenant && x.Code == code);
            if (p == null)
            {
                p = new PosteHorsLigne { TenantId = tenant, Code = code };
                _context.PostesHorsLigne.Add(p);
            }
            p.UtilisateurId = int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var u) ? u : null;
            p.Navigateur = Couper(Request.Headers.UserAgent.ToString(), 150);
            p.EnAttente = Math.Max(0, r.EnAttente);
            p.Refusees = Math.Max(0, r.Refusees);
            p.MontantEnAttente = Math.Max(0, Math.Round(r.Montant, 2));
            p.PlusAncien = LireDate(r.PlusAncien);
            p.DernierEnvoi = LireDate(r.DernierEnvoi) ?? p.DernierEnvoi;
            p.DernierRapport = DateTime.Now;
            p.Detail = JsonSerializer.Serialize(elements, new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase });
            await _context.SaveChangesAsync();
            return Json(new { ok = true });
        }
    }
}
