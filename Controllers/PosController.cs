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

        // Remise globale sur un ticket : administrateurs et utilisateurs autorisés à valider.
        private bool PeutRemiseGlobale => EstAdmin
            || (bool.TryParse(User.FindFirst(AppClaimTypes.PeutValiderOperations)?.Value, out var pv) && pv);

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
            var catalogue = await _context.Produits
                .Where(p => p.Actif && p.TenantId == tenant)
                .OrderBy(p => p.Nom)
                .ToListAsync();
            // Stock affiché : celui du dépôt de la caisse.
            var depotCaisse = await _context.DepotCaisseAsync(j.CaisseId);
            var stocksDepot = await _context.StocksDepots.AsNoTracking()
                .Where(s => s.DepotId == depotCaisse).ToDictionaryAsync(s => s.ProduitId, s => s.Quantite);
            // Variantes : seulement celles dont le modèle est actif.
            var modelesActifs = catalogue.Where(p => p.EstModele).Select(p => p.Id).ToHashSet();
            var combos = await Combos.SocieteAsync(_context, tenant);
            var produits = catalogue
                .Where(p => p.ParentId == null || modelesActifs.Contains(p.ParentId.Value))
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
                    stock = stocksDepot.GetValueOrDefault(p.Id),
                    seuil = p.SeuilAlerte,
                    unite = p.Unite,
                    image = Images.UrlImage(p),
                    parentId = p.ParentId,
                    modele = p.EstModele,
                    variante = p.LibelleVariante,
                    combo = p.EstCombo
                        ? (combos.GetValueOrDefault(p.Id) ?? new()).Select(g => new
                        {
                            id = g.Id, nom = g.Nom, quantite = g.Quantite,
                            choix = g.Choix.OrderBy(c => c.Ordre).ThenBy(c => c.Id).Select(c => new { produitId = c.ProduitId, supplement = c.Supplement })
                        }).ToList()
                        : null
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
                peutRemiseGlobale = PeutRemiseGlobale,
                urlFermer = $"/JourneeCaisse/Details/{j.Id}",
                modes,
                urlVendre = "/Pos/Vendre",
                urlTicket = "/Pos/Ticket/",
                urlVentes = $"/Vente/Index?journee={j.Id}",
                venteSansStock = (await _context.Tenants.AsNoTracking().FirstOrDefaultAsync(t => t.Id == tenant))?.PosVenteSansStock ?? true,
                jeton = new { nom = jetons.FormFieldName, valeur = jetons.RequestToken },
                restaurant = j.Caisse != null && j.Caisse.EstRestaurant ? new
                {
                    type = j.Caisse.TypePointVente,
                    imprimerBons = j.Caisse.ImprimerBons,
                    salles = await Restaurant.PlanAsync(_context, j.CaisseId, true),
                    urlPlan = $"/Pos/Plan?journee={j.Id}",
                    urlCommande = $"/Pos/Commande?journee={j.Id}",
                    urlEnregistrer = "/Pos/Enregistrer",
                    urlEnvoyer = "/Pos/Envoyer",
                    urlTransferer = "/Pos/Transferer",
                    urlAddition = "/Pos/Addition/",
                    urlBons = "/Pos/Bon?ids=",
                    urlCuisine = $"/Cuisine/Index?caisse={j.CaisseId}"
                } : null
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
            public RemiseSaisie? RemiseGlobale { get; set; }
            // Restaurant / bar : pourboire et commande de table payée (reste : articles qui demeurent sur la table).
            public decimal Pourboire { get; set; }
            public OuverteSaisie? CommandeOuverte { get; set; }
        }

        private sealed class OuverteSaisie
        {
            public int Id { get; set; }
            public int Version { get; set; }
            public List<Restaurant.Ligne> Reste { get; set; } = new();
        }

        private sealed class RemiseSaisie
        {
            public string? Type { get; set; }
            public decimal Valeur { get; set; }
        }

        private sealed class LigneSaisie
        {
            public int ProduitId { get; set; }
            public decimal Qte { get; set; }
            public decimal? Prix { get; set; }
            public decimal Remise { get; set; }
            public string? Note { get; set; }
            public List<Combos.Composant>? Composants { get; set; }
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
                var p = await _context.Produits.FirstOrDefaultAsync(x => x.Id == l.ProduitId && x.TenantId == tenant && x.Actif
                    && (x.ParentId == null || _context.Produits.Any(m => m.Id == x.ParentId && m.Actif)));
                var qte = Math.Round(l.Qte, 2);
                if (p == null || qte <= 0)
                    return Erreur(400, "Un article du ticket est introuvable, inactif ou de quantité nulle.");
                if (p.EstModele)
                    return Erreur(400, $"Choisissez une variante de « {p.Nom} ».");
                // Combo : composants contrôlés, prix du combo plus les suppléments des articles choisis.
                List<Combos.Composant>? composants = null;
                var prixCatalogue = p.PrixVente;
                if (p.EstCombo)
                {
                    var (liste, supplements, erreurCombo) = await Combos.ControlerAsync(_context, p, l.Composants ?? new());
                    if (erreurCombo != null)
                        return Erreur(400, erreurCombo);
                    composants = liste;
                    prixCatalogue += supplements;
                }
                var prix = EstAdmin && l.Prix.HasValue ? Math.Max(0, Math.Round(l.Prix.Value, 2)) : prixCatalogue;
                var remise = Math.Min(100, Math.Max(0, Math.Round(l.Remise, 2)));
                var total = Math.Round(qte * prix * (1 - remise / 100), 0, MidpointRounding.AwayFromZero);
                ttc += total;
                tva += total - total / (1 + p.TauxTVA / 100);
                var note = (l.Note ?? "").Trim();
                lignes.Add((p, new LigneCommandePos
                {
                    TenantId = tenant, ProduitId = p.Id, Libelle = p.Nom, Quantite = qte,
                    PrixUnitaire = prix, Remise = remise, TauxTVA = p.TauxTVA, TotalTTC = total,
                    Note = note == "" ? null : note.Length > 200 ? note[..200] : note,
                    Composants = composants == null ? null : Combos.Ecrire(composants)
                }));
            }

            // Remise globale (administrateurs et utilisateurs autorisés à valider) : en % ou en montant,
            // répartie sur les lignes au prorata ; les totaux et les taxes portent sur le net.
            decimal remiseGlobale = 0;
            decimal? tauxRemise = null;
            if (v.RemiseGlobale != null && v.RemiseGlobale.Valeur > 0 && ttc > 0)
            {
                if (!PeutRemiseGlobale)
                    return Erreur(403, "La remise globale est réservée aux administrateurs et aux utilisateurs autorisés à valider.");
                if (v.RemiseGlobale.Type == "pct")
                {
                    tauxRemise = Math.Min(100, Math.Round(v.RemiseGlobale.Valeur, 2));
                    remiseGlobale = Math.Round(ttc * tauxRemise.Value / 100, 0, MidpointRounding.AwayFromZero);
                }
                else
                {
                    remiseGlobale = Math.Min(ttc, Math.Round(v.RemiseGlobale.Valeur, 0, MidpointRounding.AwayFromZero));
                }
                var reste = remiseGlobale;
                for (var i = 0; i < lignes.Count; i++)
                {
                    var ligne = lignes[i].Ligne;
                    var part = i == lignes.Count - 1 ? reste
                        : Math.Min(reste, Math.Round(remiseGlobale * ligne.TotalTTC / ttc, 0, MidpointRounding.AwayFromZero));
                    ligne.RemiseGlobale = part;
                    ligne.TotalTTC -= part;
                    reste -= part;
                }
                ttc = lignes.Sum(x => x.Ligne.TotalTTC);
                tva = lignes.Sum(x => x.Ligne.TotalTTC - x.Ligne.TotalTTC / (1 + x.Ligne.TauxTVA / 100));
            }
            foreach (var (p, ligne) in lignes)
                ligne.Taxes = TaxesProduits.TaxesLigne(tenant,
                    (taxesProduits.GetValueOrDefault(p.Id) ?? new List<Taxe>()).Select(t => ((int?)t.Id, t.Code, t.Taux)), ligne.TotalTTC);
            tva = Math.Round(tva, 0, MidpointRounding.AwayFromZero);

            // Restaurant / bar : pourboire (en plus du total).
            var pourboire = Math.Max(0, Math.Round(v.Pourboire, 0, MidpointRounding.AwayFromZero));

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
            if (recu < ttc + pourboire)
                return Erreur(400, "Le montant payé est inférieur au total.");
            var rendu = recu - ttc - pourboire;
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
                // Quantités par produit (les composants pour un combo).
                var besoins = lignes.SelectMany(x => Combos.Lire(x.Ligne.Composants) is { Count: > 0 } comp
                        ? comp.Select(c => (c.ProduitId, Qte: x.Ligne.Quantite * c.Qte))
                        : new[] { (x.Produit.Id, Qte: x.Ligne.Quantite) })
                    .GroupBy(x => x.Item1);
                // Stock du dépôt de la caisse.
                var depotVente = await _context.DepotCaisseAsync(j.CaisseId);
                foreach (var g in besoins)
                {
                    var stock = await _context.Produits
                        .FromSqlInterpolated($"SELECT * FROM Produits WITH (UPDLOCK, ROWLOCK) WHERE Id = {g.Key}")
                        .AsNoTracking().Select(p => new { p.Nom, p.SuiviStock }).FirstAsync();
                    var dispo = await _context.StockDepotAsync(g.Key, depotVente);
                    if (stock.SuiviStock && dispo < g.Sum(x => x.Qte) - 0.001m)
                        return Erreur(409, $"Stock insuffisant pour « {stock.Nom} » : {dispo:0.##} disponible(s).");
                }
            }
            // Commande de table : payée en entier (table libérée) ou en partie (addition partagée : le
            // reste des articles demeure sur la table).
            string? tableNom = null;
            int? couverts = null;
            CommandeOuverte? restante = null;
            if (v.CommandeOuverte != null)
            {
                var co = await _context.CommandesOuvertes
                    .FromSqlInterpolated($"SELECT * FROM CommandesOuvertes WITH (UPDLOCK, ROWLOCK) WHERE Id = {v.CommandeOuverte.Id}")
                    .FirstOrDefaultAsync();
                if (co == null || co.JourneeCaisseId != j.Id || co.Version != v.CommandeOuverte.Version)
                    return Erreur(409, "La commande de la table a été modifiée sur un autre appareil : rechargez la table puis recommencez.");
                tableNom = co.TableId.HasValue ? (await _context.TablesRestaurant.FirstOrDefaultAsync(t => t.Id == co.TableId))?.Nom : null;
                couverts = co.Couverts;
                var avant = Restaurant.Lire(co.Contenu);
                var reste = Restaurant.Nettoyer(new Restaurant.Contenu { Lignes = v.CommandeOuverte.Reste }, avant).Lignes;
                if (!reste.Any())
                {
                    await DetacherBonsAsync(co.Id, null);
                    _context.CommandesOuvertes.Remove(co);
                }
                else
                {
                    foreach (var r in reste)
                        r.Envoye = Math.Min(r.Envoye, r.Qte);
                    avant.Lignes = reste;
                    co.Contenu = Restaurant.Ecrire(avant);
                    co.Version++;
                    co.DateMaj = DateTime.Now;
                    co.AdditionImprimee = false;
                    restante = co;
                }
            }

            var rang = await _context.CommandesPos.CountAsync(c => c.JourneeCaisseId == j.Id) + 1;
            var numero = $"POS-{j.Caisse?.ChkCode}-{j.DateJournee:yyyyMMdd}-{rang:0000}";

            var commande = new CommandePos
            {
                TenantId = tenant, Numero = numero, CleClient = cle, JourneeCaisseId = j.Id, ClientId = clientId,
                UtilisateurId = utilisateurId, DateCommande = DateTime.Now, TotalHT = ttc - tva, TotalTVA = tva,
                TotalTTC = ttc, MontantRecu = recu, MonnaieRendue = rendu, Statut = "Payée",
                RemiseGlobale = remiseGlobale, RemiseGlobaleTaux = tauxRemise,
                TableNom = tableNom, Couverts = couverts, Pourboire = pourboire,
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
                await _context.MouvementLigneAsync(produit.Id, ligne.Composants, -ligne.Quantite, "Vente", numero, commande.Id, utilisateurId,
                    depotId: await _context.DepotCaisseAsync(j.CaisseId));

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
                        TypeOperation = "Encaissement", Montant = net,
                        Libelle = "Vente POS " + numero + (pourboire > 0 ? " (dont pourboire " + pourboire.ToString("N0", System.Globalization.CultureInfo.GetCultureInfo("fr-FR")) + ")" : ""),
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

            return Json(new { id = commande.Id, numero, rendu, commande = restante == null ? null : Restaurant.CommandeJson(restante) });
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
            // ---------------------------------------------------------------------------
        // Restaurant / bar : commandes ouvertes sur les tables
        // ---------------------------------------------------------------------------

        private int UtilisateurId => int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id) ? id : 0;

        private string Serveur => User.FindFirst(AppClaimTypes.NomComplet)?.Value is { Length: > 0 } n ? n : User.FindFirst(ClaimTypes.Name)?.Value ?? "";

        // Journée ouverte d'une caisse restaurant / bar ; message d'erreur sinon.
        private async Task<(JourneeCaisse? Journee, IActionResult? Erreur)> JourneeRestaurantAsync(int id)
        {
            var j = await _context.JourneesCaisses.Include(x => x.Caisse).FirstOrDefaultAsync(x => x.Id == id);
            if (j == null)
                return (null, Erreur(404, "Journée introuvable."));
            if (j.Caisse == null || !j.Caisse.EstRestaurant)
                return (null, Erreur(400, "Cette caisse n'est pas de type Restaurant ou Bar."));
            if (j.Statut != "Ouverte")
                return (null, Erreur(409, "Cette journée est clôturée : ouvrez une nouvelle journée pour servir."));
            return (j, null);
        }

        private async Task<TableRestaurant?> TableAsync(int id, int caisseId) =>
            await (from t in _context.TablesRestaurant
                   join s in _context.Salles on t.SalleId equals s.Id
                   where t.Id == id && s.CaisseId == caisseId && t.Actif
                   select t).FirstOrDefaultAsync();

        // Les bons gardent leur historique quand la commande disparaît (payée, vidée ou regroupée).
        private async Task DetacherBonsAsync(int commandeId, int? vers) =>
            await _context.Database.ExecuteSqlInterpolatedAsync($"UPDATE BonsPreparation SET CommandeOuverteId = {vers} WHERE CommandeOuverteId = {commandeId}");

        private sealed class CommandeSaisie
        {
            public int JourneeId { get; set; }
            public int TableId { get; set; }
            public int Id { get; set; }
            public int Version { get; set; }
            public int Couverts { get; set; } = 1;
            public int CibleId { get; set; }
            public List<Restaurant.Ligne> Lignes { get; set; } = new();
            public int? ClientId { get; set; }
            public Restaurant.RemiseTicket? Remise { get; set; }
        }

        private static CommandeSaisie? LireSaisie(string? json)
        {
            try { return JsonSerializer.Deserialize<CommandeSaisie>(json ?? "", new JsonSerializerOptions { PropertyNameCaseInsensitive = true }); }
            catch (JsonException) { return null; }
        }

        // État des tables (plan de salle), pour l'actualisation de l'écran de vente.
        public async Task<IActionResult> Plan(int journee)
        {
            var (j, erreur) = await JourneeRestaurantAsync(journee);
            if (erreur != null)
                return erreur;
            return Json(new { salles = await Restaurant.PlanAsync(_context, j!.CaisseId, true) });
        }

        // Commande en cours sur une table (null si la table est libre).
        public async Task<IActionResult> Commande(int journee, int table)
        {
            var (j, erreur) = await JourneeRestaurantAsync(journee);
            if (erreur != null)
                return erreur;
            var t = await TableAsync(table, j!.CaisseId);
            if (t == null)
                return Erreur(404, "Table introuvable.");
            var co = await _context.CommandesOuvertes.FirstOrDefaultAsync(c => c.TableId == t.Id);
            return Json(new { commande = co == null ? null : Restaurant.CommandeJson(co) });
        }

        // Enregistre la commande d'une table : création à la première ligne, mise à jour ensuite
        // (refusée si la commande a changé entre-temps sur un autre appareil), suppression quand
        // elle est vidée. Avec envoyer : bons de préparation des articles pas encore envoyés.
        private async Task<IActionResult> EnregistrerCommandeAsync(string? commande, bool envoyer)
        {
            var c = LireSaisie(commande);
            if (c == null)
                return Erreur(400, "Commande illisible.");
            var (j, erreur) = await JourneeRestaurantAsync(c.JourneeId);
            if (erreur != null)
                return erreur;
            var table = await TableAsync(c.TableId, j!.CaisseId);
            if (table == null)
                return Erreur(404, "Table introuvable.");
            var couverts = Math.Clamp(c.Couverts, 1, 99);

            await using var transaction = await _context.Database.BeginTransactionAsync();
            var co = await _context.CommandesOuvertes
                .FromSqlInterpolated($"SELECT * FROM CommandesOuvertes WITH (UPDLOCK, HOLDLOCK) WHERE TableId = {table.Id}")
                .FirstOrDefaultAsync();
            if (co != null && (co.Id != c.Id || co.Version != c.Version))
                return StatusCode(409, new { erreur = $"La commande de {table.Nom} a été modifiée sur un autre appareil : elle a été rechargée.", commande = Restaurant.CommandeJson(co) });
            if (co == null && c.Id > 0)
                return StatusCode(409, new { erreur = $"La commande de {table.Nom} n'existe plus (encaissée ou transférée sur un autre appareil).", commande = (object?)null });

            var avant = co == null ? new Restaurant.Contenu() : Restaurant.Lire(co.Contenu);
            var contenu = Restaurant.Nettoyer(new Restaurant.Contenu { Lignes = c.Lignes, ClientId = c.ClientId, Remise = c.Remise }, avant);
            if (co == null && !contenu.Lignes.Any())
                return Json(new { commande = (object?)null, bons = Array.Empty<int>() });
            if (co == null)
            {
                co = new CommandeOuverte
                {
                    TenantId = j.TenantId, CaisseId = j.CaisseId, JourneeCaisseId = j.Id, TableId = table.Id, Couverts = couverts,
                    UtilisateurId = UtilisateurId, DateOuverture = DateTime.Now, DateMaj = DateTime.Now, Version = 0, Contenu = Restaurant.Ecrire(contenu)
                };
                _context.CommandesOuvertes.Add(co);
                await _context.SaveChangesAsync();
            }
            var bons = new List<BonPreparation>();
            // Commande vidée : annulation en préparation des articles déjà envoyés, puis table libérée.
            if (!contenu.Lignes.Any())
            {
                bons = await Restaurant.EnvoyerAsync(_context, co, contenu, avant, table.Nom, Serveur);
                await _context.SaveChangesAsync();
                await DetacherBonsAsync(co.Id, null);
                _context.CommandesOuvertes.Remove(co);
                await _context.SaveChangesAsync();
                await transaction.CommitAsync();
                return Json(new { commande = (object?)null, bons = bons.Select(b => b.Id) });
            }
            if (envoyer)
                bons = await Restaurant.EnvoyerAsync(_context, co, contenu, avant, table.Nom, Serveur);
            var json = Restaurant.Ecrire(contenu);
            // L'addition imprimée n'est plus à jour quand les articles changent.
            if (json != Restaurant.Ecrire(Restaurant.Lire(co.Contenu)) || co.Couverts != couverts)
                co.AdditionImprimee = false;
            co.Contenu = json;
            co.Couverts = couverts;
            co.Version++;
            co.DateMaj = DateTime.Now;
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return Json(new { commande = Restaurant.CommandeJson(co), bons = bons.Select(b => b.Id) });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public Task<IActionResult> Enregistrer([FromForm] string? commande) => EnregistrerCommandeAsync(commande, false);

        // Enregistre la commande et envoie les nouveaux articles en cuisine / au bar.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public Task<IActionResult> Envoyer([FromForm] string? commande) => EnregistrerCommandeAsync(commande, true);

        // Transfère la commande vers une autre table (regroupée avec sa commande si elle est occupée).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Transferer([FromForm] string? commande)
        {
            var c = LireSaisie(commande);
            if (c == null)
                return Erreur(400, "Commande illisible.");
            var (j, erreur) = await JourneeRestaurantAsync(c.JourneeId);
            if (erreur != null)
                return erreur;
            var cible = await TableAsync(c.CibleId, j!.CaisseId);
            if (cible == null)
                return Erreur(404, "Table introuvable.");
            await using var transaction = await _context.Database.BeginTransactionAsync();
            var co = await _context.CommandesOuvertes
                .FromSqlInterpolated($"SELECT * FROM CommandesOuvertes WITH (UPDLOCK, ROWLOCK) WHERE Id = {c.Id}")
                .FirstOrDefaultAsync();
            if (co == null || co.CaisseId != j.CaisseId || co.Version != c.Version)
                return Erreur(409, "La commande a été modifiée sur un autre appareil : rechargez la table puis recommencez.");
            if (co.TableId == cible.Id)
                return Json(new { commande = Restaurant.CommandeJson(co) });
            var existante = await _context.CommandesOuvertes
                .FromSqlInterpolated($"SELECT * FROM CommandesOuvertes WITH (UPDLOCK, HOLDLOCK) WHERE TableId = {cible.Id}")
                .FirstOrDefaultAsync();
            CommandeOuverte resultat;
            if (existante != null)
            {
                // Regroupement : les lignes et les couverts s'ajoutent à la commande de la table choisie.
                var a = Restaurant.Lire(existante.Contenu);
                a.Lignes.AddRange(Restaurant.Lire(co.Contenu).Lignes);
                existante.Contenu = Restaurant.Ecrire(a);
                existante.Couverts += co.Couverts;
                existante.Version++;
                existante.DateMaj = DateTime.Now;
                existante.AdditionImprimee = false;
                await DetacherBonsAsync(co.Id, existante.Id);
                _context.CommandesOuvertes.Remove(co);
                resultat = existante;
            }
            else
            {
                co.TableId = cible.Id;
                co.Version++;
                co.DateMaj = DateTime.Now;
                resultat = co;
            }
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return Json(new { commande = Restaurant.CommandeJson(resultat) });
        }

        // Addition (note provisoire) d'une table, avant le paiement ; la table passe en « addition demandée ».
        public async Task<IActionResult> Addition(int id)
        {
            var co = await _context.CommandesOuvertes.FirstOrDefaultAsync(c => c.Id == id);
            if (co == null)
                return NotFound();
            co.AdditionImprimee = true;
            await _context.SaveChangesAsync();
            var societe = await _context.Tenants.FirstOrDefaultAsync(t => t.Id == co.TenantId);
            ViewBag.Societe = societe?.Nom ?? "GesCaisse";
            ViewBag.Logo = Images.UrlLogo(societe);
            ViewBag.Coordonnees = Images.Coordonnees(societe);
            ViewBag.Table = co.TableId.HasValue ? (await _context.TablesRestaurant.FirstOrDefaultAsync(t => t.Id == co.TableId))?.Nom : null;
            ViewBag.Serveur = (await Restaurant.NomsAsync(_context, new[] { co.UtilisateurId })).Values.FirstOrDefault() ?? "";
            ViewBag.Contenu = Restaurant.Lire(co.Contenu);
            return View(co);
        }

        // Bons de préparation 80 mm (un par page), imprimés à l'envoi.
        public async Task<IActionResult> Bon(string? ids)
        {
            var liste = (ids ?? "").Split(',').Select(x => int.TryParse(x, out var i) ? i : 0).Where(i => i > 0).ToList();
            var bons = await _context.BonsPreparation.Include(b => b.Lignes).Where(b => liste.Contains(b.Id)).OrderBy(b => b.Id).ToListAsync();
            return View(bons);
        }
    }
}
