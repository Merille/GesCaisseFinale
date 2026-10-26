using System.Security.Claims;
using System.Text.Json;
using System.Text.RegularExpressions;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Antiforgery;
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
        private readonly IAntiforgery _antiforgery;

        public PosController(AppDbContext context, IAntiforgery antiforgery)
        {
            _context = context;
            _antiforgery = antiforgery;
        }

        private bool EstAdmin => User.FindFirst(AppClaimTypes.Profil)?.Value is "Admin" or "SuperAdmin";

        // « Espèces » : le seul mode sur lequel on peut rendre la monnaie.
        public static bool EstEspeces(ModePaiement m) =>
            Regex.IsMatch($"{m.Code} {m.Libelle}", @"\b(esp|espèces?|especes?|cash|liquide)\b", RegexOptions.IgnoreCase);

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
            var produits = (await _context.Produits
                .Where(p => p.Actif && p.TenantId == tenant)
                .OrderBy(p => p.Nom)
                .ToListAsync())
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
                    seuil = p.SeuilAlerte,
                    unite = p.Unite,
                    image = Images.UrlImage(p)
                })
                .ToList();
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

            var modes = (await _context.ModesPaiement
                    .Where(m => m.Actif && m.TenantId == tenant)
                    .OrderBy(m => m.Libelle)
                    .ToListAsync())
                .Select(m => new { id = m.Id, libelle = m.Libelle ?? "", especes = EstEspeces(m) })
                .ToList();
            var jetons = _antiforgery.GetAndStoreTokens(HttpContext);

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
                urlFermer = $"/JourneeCaisse/Details/{j.Id}",
                modes,
                urlVendre = "/Pos/Vendre",
                urlTicket = "/Pos/Ticket/",
                urlVentes = $"/Vente/Index?journee={j.Id}",
                venteSansStock = (await _context.Tenants.AsNoTracking().FirstOrDefaultAsync(t => t.Id == tenant))?.PosVenteSansStock ?? true,
                jeton = new { nom = jetons.FormFieldName, valeur = jetons.RequestToken }
            };

            // L'encodeur par défaut échappe < > & ' " : le JSON peut aller dans une balise <script>.
            ViewBag.Donnees = JsonSerializer.Serialize(donnees);
            return View("Ecran");
        }
    
        private sealed class VenteSaisie
        {
            public string? Cle { get; set; }
            public int JourneeId { get; set; }
            public int? ClientId { get; set; }
            public List<LigneSaisie> Lignes { get; set; } = new();
            public List<PaiementSaisi> Paiements { get; set; } = new();
        }

        private sealed class LigneSaisie
        {
            public int ProduitId { get; set; }
            public decimal Qte { get; set; }
            public decimal? Prix { get; set; }
            public decimal Remise { get; set; }
        }

        private sealed class PaiementSaisi
        {
            public int ModeId { get; set; }
            public decimal Montant { get; set; }
        }

        private IActionResult Erreur(int code, string message) => StatusCode(code, new { erreur = message });

        // Enregistre une vente payée : commande, lignes, règlements, un encaissement par
        // règlement dans la journée (motif « Vente POS ») et sortie de stock.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Vendre([FromForm] string vente)
        {
            VenteSaisie? v;
            try
            {
                v = JsonSerializer.Deserialize<VenteSaisie>(vente ?? "", new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            }
            catch (JsonException)
            {
                v = null;
            }
            if (v == null || string.IsNullOrWhiteSpace(v.Cle) || !v.Lignes.Any() || !v.Paiements.Any())
                return Erreur(400, "Vente incomplète.");
            var cle = new string(v.Cle.Where(c => char.IsAsciiLetterOrDigit(c) || c == '-').Take(64).ToArray());

            var j = await _context.JourneesCaisses.Include(x => x.Caisse).FirstOrDefaultAsync(x => x.Id == v.JourneeId);
            if (j == null)
                return Erreur(404, "Journée introuvable.");
            var tenant = j.TenantId;

            // Vente déjà enregistrée (nouvel envoi après une coupure réseau) : on la renvoie telle quelle.
            var deja = await _context.CommandesPos.FirstOrDefaultAsync(c => c.TenantId == tenant && c.CleClient == cle);
            if (deja != null)
                return Json(new { id = deja.Id, numero = deja.Numero });
            if (j.Statut != "Ouverte")
                return Erreur(409, "Cette journée est clôturée : la vente ne peut pas être enregistrée.");

            // Lignes : prix et taxes repris du catalogue ; prix saisi accepté pour un administrateur seulement.
            var taxesProduits = _context.TaxesDesProduits(v.Lignes.Select(l => l.ProduitId));
            var lignes = new List<(Produit Produit, LigneCommandePos Ligne)>();
            decimal ttc = 0, tva = 0;
            foreach (var l in v.Lignes)
            {
                var p = await _context.Produits.FirstOrDefaultAsync(x => x.Id == l.ProduitId && x.TenantId == tenant && x.Actif);
                var qte = Math.Round(l.Qte, 2);
                if (p == null || qte <= 0)
                    return Erreur(400, "Un article du ticket est introuvable, inactif ou de quantité nulle.");
                var prix = EstAdmin && l.Prix.HasValue ? Math.Max(0, Math.Round(l.Prix.Value, 2)) : p.PrixVente;
                var remise = Math.Min(100, Math.Max(0, Math.Round(l.Remise, 2)));
                var total = Math.Round(qte * prix * (1 - remise / 100), 0, MidpointRounding.AwayFromZero);
                ttc += total;
                tva += total - total / (1 + p.TauxTVA / 100);
                lignes.Add((p, new LigneCommandePos
                {
                    TenantId = tenant, ProduitId = p.Id, Libelle = p.Nom, Quantite = qte,
                    PrixUnitaire = prix, Remise = remise, TauxTVA = p.TauxTVA, TotalTTC = total,
                    Taxes = TaxesProduits.TaxesLigne(tenant,
                        (taxesProduits.GetValueOrDefault(p.Id) ?? new List<Taxe>()).Select(t => ((int?)t.Id, t.Code, t.Taux)), total)
                }));
            }
            tva = Math.Round(tva, 0, MidpointRounding.AwayFromZero);

            // Règlements : seuls les espèces peuvent dépasser le reste à payer (monnaie rendue).
            var modes = await _context.ModesPaiement.Where(m => m.Actif && m.TenantId == tenant).ToListAsync();
            var paiements = new List<(ModePaiement Mode, decimal Recu)>();
            decimal recu = 0, especes = 0;
            foreach (var pm in v.Paiements)
            {
                var mode = modes.FirstOrDefault(m => m.Id == pm.ModeId);
                var montant = Math.Round(pm.Montant, 0, MidpointRounding.AwayFromZero);
                if (mode == null || montant <= 0)
                    return Erreur(400, "Mode de paiement invalide ou montant nul.");
                paiements.Add((mode, montant));
                recu += montant;
                if (EstEspeces(mode))
                    especes += montant;
            }
            if (recu < ttc)
                return Erreur(400, "Le montant payé est inférieur au total.");
            var rendu = recu - ttc;
            if (rendu > especes)
                return Erreur(400, "Seule la monnaie sur les espèces peut être rendue : le montant payé par les autres modes dépasse le total.");

            int? clientId = v.ClientId.HasValue && await _context.Clients.AnyAsync(c => c.Id == v.ClientId && c.TenantId == tenant)
                ? v.ClientId : null;
            int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var utilisateurId);

            await using var transaction = await _context.Database.BeginTransactionAsync();
            // Verrou sur la journée : numéros de ticket consécutifs même avec plusieurs postes.
            await _context.Database.ExecuteSqlInterpolatedAsync($"SELECT Id FROM JourneesCaisses WITH (UPDLOCK, HOLDLOCK) WHERE Id = {j.Id}");
            // Vente sans stock interdite (option de la société) : contrôle sous verrou des produits.
            var societe = await _context.Tenants.AsNoTracking().FirstOrDefaultAsync(t => t.Id == tenant);
            if (societe != null && !societe.PosVenteSansStock)
            {
                foreach (var g in lignes.Where(x => x.Produit.SuiviStock).GroupBy(x => x.Produit.Id))
                {
                    var disponible = await _context.Produits
                        .FromSqlInterpolated($"SELECT * FROM Produits WITH (UPDLOCK, ROWLOCK) WHERE Id = {g.Key}")
                        .AsNoTracking().Select(p => p.StockActuel).FirstAsync();
                    if (disponible < g.Sum(x => x.Ligne.Quantite) - 0.001m)
                        return Erreur(409, $"Stock insuffisant pour « {g.First().Produit.Nom} » : {disponible:0.##} disponible(s).");
                }
            }
            var rang = await _context.CommandesPos.CountAsync(c => c.JourneeCaisseId == j.Id) + 1;
            var numero = $"POS-{j.Caisse?.ChkCode}-{j.DateJournee:yyyyMMdd}-{rang:0000}";

            var commande = new CommandePos
            {
                TenantId = tenant, Numero = numero, CleClient = cle, JourneeCaisseId = j.Id, ClientId = clientId,
                UtilisateurId = utilisateurId, DateCommande = DateTime.Now, TotalHT = ttc - tva, TotalTVA = tva,
                TotalTTC = ttc, MontantRecu = recu, MonnaieRendue = rendu, Statut = "Payée",
                Lignes = lignes.Select(x => x.Ligne).ToList()
            };
            var motif = await _context.Motifs.FirstOrDefaultAsync(m => m.LibelleMotif == "Vente POS" && m.TenantId == tenant);
            if (motif == null)
            {
                motif = new Motif { LibelleMotif = "Vente POS", TypeModif = "Client", TenantId = tenant };
                _context.Motifs.Add(motif);
            }
            _context.CommandesPos.Add(commande);
            await _context.SaveChangesAsync();
            foreach (var (produit, ligne) in lignes)
                await _context.MouvementAsync(produit.Id, -ligne.Quantite, "Vente", numero, commande.Id, utilisateurId);

            var aRendre = rendu;
            foreach (var (mode, montantRecu) in paiements)
            {
                var net = montantRecu;
                if (EstEspeces(mode) && aRendre > 0)
                {
                    var deduit = Math.Min(aRendre, net);
                    net -= deduit;
                    aRendre -= deduit;
                }
                OperationCaisse? operation = null;
                if (net > 0)
                {
                    operation = new OperationCaisse
                    {
                        TenantId = tenant, JourneeCaisseId = j.Id, DateOperation = DateTime.Now,
                        TypeOperation = "Encaissement", Montant = net, Libelle = "Vente POS " + numero,
                        ClientId = clientId, MotifId = motif.ID, ModePaiementId = mode.Id,
                        UtilisateurId = utilisateurId, EstJustifie = true,
                        // Validé d'office : vente payée et justifiée par le ticket.
                        StatutValidation = "Validé", Valideur = "Point de vente"
                    };
                    _context.OperationsCaisses.Add(operation);
                    await _context.SaveChangesAsync();
                }
                _context.PaiementsPos.Add(new PaiementPos
                {
                    TenantId = tenant, CommandePosId = commande.Id, ModePaiementId = mode.Id, Libelle = mode.Libelle ?? "",
                    MontantRecu = montantRecu, Montant = net, OperationCaisseId = operation?.Id
                });
            }
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            return Json(new { id = commande.Id, numero, rendu });
        }

        // Ticket de caisse 80 mm d'une vente (impression ou réimpression).
        public async Task<IActionResult> Ticket(int id, bool imprimer = false)
        {
            var commande = await _context.CommandesPos
                .Include(c => c.Lignes).ThenInclude(l => l.Taxes)
                .Include(c => c.Paiements)
                .Include(c => c.JourneeCaisse).ThenInclude(j => j!.Caisse)
                .FirstOrDefaultAsync(c => c.Id == id);
            if (commande == null)
                return NotFound();

            var societe = await _context.Tenants.FirstOrDefaultAsync(t => t.Id == commande.TenantId);
            ViewBag.Societe = societe?.Nom ?? "GesCaisse";
            ViewBag.Logo = Images.UrlLogo(societe);
            ViewBag.Coordonnees = Images.Coordonnees(societe);
            var produitIds = commande.Lignes.Where(l => l.ProduitId.HasValue).Select(l => l.ProduitId!.Value).ToList();
            ViewBag.Unites = await _context.Produits.IgnoreQueryFilters().Where(p => produitIds.Contains(p.Id))
                .ToDictionaryAsync(p => p.Id, p => p.Unite);
            ViewBag.Vendeur = (await _context.Utilisateurs.IgnoreQueryFilters().FirstOrDefaultAsync(u => u.Id == commande.UtilisateurId))?.NomComplet ?? "";
            ViewBag.Client = commande.ClientId.HasValue
                ? (await _context.Clients.FirstOrDefaultAsync(c => c.Id == commande.ClientId))?.NomSociete
                : null;
            ViewBag.NumeroOrigine = commande.CommandeOrigineId.HasValue
                ? (await _context.CommandesPos.FirstOrDefaultAsync(c => c.Id == commande.CommandeOrigineId))?.Numero
                : null;
            ViewBag.Imprimer = imprimer;
            return View(commande);
        }
    }
}
