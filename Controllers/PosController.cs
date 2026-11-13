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
    public partial class PosController : Controller
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
        // Annulation d'un dépôt de linge : administrateurs et utilisateurs autorisés à valider.
        private bool PeutAnnuler => EstAdmin
            || (bool.TryParse(User.FindFirst(AppClaimTypes.PeutValiderOperations)?.Value, out var pv) && pv);

        // Droit d'accorder des remises (sur un article et globale) : (autorisé, pourcentage maximal ou null).
        // Administrateurs : toujours, sans limite ; autres : fiche de l'utilisateur, relue à chaque appel (un
        // changement fait par l'administrateur s'applique sans reconnexion). Comme pos_droit_remise() en PHP.
        private async Task<(bool Peut, decimal? Max)> DroitRemiseAsync()
        {
            if (EstAdmin)
                return (true, null);
            var id = int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var u) ? u : 0;
            var droit = await _context.Utilisateurs.IgnoreQueryFilters().Where(x => x.Id == id)
                .Select(x => new { x.PeutRemise, x.RemiseMax }).FirstOrDefaultAsync();
            return (droit?.PeutRemise ?? false, droit?.RemiseMax);
        }

        // Contrôle des remises d'un ticket : remises des lignes (nom, %), remise globale en % (ou null).
        // Renvoie le message d'erreur, ou null si l'utilisateur a le droit.
        private async Task<string?> ControleRemisesAsync(IEnumerable<(string Nom, decimal Pct)> lignes, decimal? globalePct)
        {
            var avecRemise = lignes.Where(l => l.Pct > 0).ToList();
            if (!avecRemise.Any() && !(globalePct > 0))
                return null;
            var (peut, max) = await DroitRemiseAsync();
            if (!peut)
                return "Vous n'avez pas le droit d'accorder des remises : demandez à un administrateur.";
            if (max.HasValue)
            {
                var fr = System.Globalization.CultureInfo.GetCultureInfo("fr-FR");
                foreach (var (nom, pct) in avecRemise)
                    if (pct > max.Value + 0.001m)
                        return $"Remise de {pct.ToString("0.##", fr)} % sur « {nom} » : votre remise maximale est de {max.Value.ToString("0.##", fr)} %.";
                if (globalePct.HasValue && globalePct.Value > max.Value + 0.001m)
                    return $"Remise globale de {Math.Round(globalePct.Value, 2).ToString("0.##", fr)} % : votre remise maximale est de {max.Value.ToString("0.##", fr)} %.";
            }
            return null;
        }

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
                .Where(p => p.Actif && !p.Consommable && p.TenantId == tenant)
                .OrderBy(p => p.Nom)
                .ToListAsync();
            // Stock affiché : celui des dépôts de la caisse (principal et secondaires).
            var depotsCaisse = await _context.DepotsCaisseAsync(j.CaisseId);
            var stocksDepot = await _context.StocksDepots.AsNoTracking()
                .Where(s => depotsCaisse.Contains(s.DepotId))
                .GroupBy(s => s.ProduitId).Select(g => new { g.Key, Q = g.Sum(s => s.Quantite) })
                .ToDictionaryAsync(x => x.Key, x => x.Q);
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
            // Clients en compte : solde dû et plafond de crédit (contrôle de la vente par compte).
            var soldes = await _context.SoldesComptesAsync(tenant);
            var clients = (await _context.Clients
                .Where(c => c.TenantId == tenant)
                .OrderBy(c => c.NomSociete)
                .ToListAsync())
                .Select(c => new { id = c.Id, nom = c.NomSociete, code = c.CodeClient, telephone = c.Telephone, adresse = c.Adresse,
                                   compte = c.EnCompte, du = soldes.GetValueOrDefault(c.Id), plafond = c.PlafondCredit })
                .ToList();
            var livreurs = await _context.Livreurs
                .Where(l => l.Actif && l.TenantId == tenant)
                .OrderBy(l => l.Nom)
                .Select(l => new { id = l.Id, nom = l.Nom, telephone = l.Telephone, moyen = l.MoyenLivraison })
                .ToListAsync();

            var modes = (await _context.ModesPaiement
                    .Where(m => m.Actif && m.TenantId == tenant)
                    .OrderBy(m => m.Libelle)
                    .ToListAsync())
                .Select(m => new { id = m.Id, libelle = m.Libelle ?? "", especes = EstEspeces(m), compte = m.EstCompte })
                .ToList();
            var jetons = _antiforgery.GetAndStoreTokens(HttpContext);

            var profil = User.FindFirst(AppClaimTypes.Profil)?.Value ?? "";
            var nom = User.FindFirst(AppClaimTypes.NomComplet)?.Value;
            var societeTicket = await _context.Tenants.AsNoTracking().FirstOrDefaultAsync(t => t.Id == tenant);
            var droitRemise = await DroitRemiseAsync();
            var donnees = new
            {
                cle = $"gescaisse-pos:{tenant}:{j.Id}",
                journee = new
                {
                    id = j.Id,
                    caisse = j.Caisse?.ChkCode ?? "",
                    type = j.Caisse?.TypePointVente ?? "Boutique",
                    libelle = $"{j.Caisse?.ChkDescription} · Journée du {j.DateJournee:dd/MM/yyyy} (ouverte)"
                },
                produits,
                categories,
                clients,
                livreurs,
                utilisateur = new
                {
                    nom = string.IsNullOrWhiteSpace(nom) ? User.FindFirst(ClaimTypes.Name)?.Value : nom,
                    profil
                },
                peutModifierPrix = profil is "Admin" or "SuperAdmin",
                // Vente par compte au-delà du plafond de crédit : administrateurs seulement.
                peutDepasserPlafond = profil is "Admin" or "SuperAdmin",
                // Frais de livraison proposés par défaut (modifiables à chaque vente).
                fraisLivraison = await _context.Tenants.Where(t => t.Id == tenant).Select(t => t.FraisLivraisonDefaut).FirstOrDefaultAsync(),
                // Remises (article et globale) : droit donné par l'administrateur sur la fiche de l'utilisateur.
                remise = new { peut = droitRemise.Peut, max = droitRemise.Max },
                urlFermer = $"/JourneeCaisse/Details/{j.Id}",
                modes,
                urlVendre = "/Pos/Vendre",
                urlAdditionTicket = "/Pos/AdditionTicket",
                urlTicket = "/Pos/Ticket/",
                urlVentes = $"/Vente/Index?journee={j.Id}",
                // Commandes en attente (partagées entre postes) et livraisons.
                urlAttentes = $"/Pos/Attentes?journee={j.Id}",
                urlMettreEnAttente = "/Pos/MettreEnAttente",
                urlReprendre = "/Pos/Reprendre",
                urlSupprimerAttente = "/Pos/SupprimerAttente",
                urlLivree = "/Pos/Livree",
                venteSansStock = (await _context.Tenants.AsNoTracking().FirstOrDefaultAsync(t => t.Id == tenant))?.PosVenteSansStock ?? true,
                jeton = new { nom = jetons.FormFieldName, valeur = jetons.RequestToken },
                // Hors ligne : jeton frais pour les envois différés, et en-tête du ticket provisoire imprimé sur le poste.
                urlJeton = "/Pos/Jeton",
                ticket = new
                {
                    societe = societeTicket?.Nom ?? "GesCaisse",
                    coordonnees = Images.Coordonnees(societeTicket),
                    description = j.Caisse?.ChkDescription ?? "",
                    // Même adresse que les tickets du serveur (asp-append-version) : une seule copie gardée sur le poste.
                    css = HttpContext.RequestServices.GetRequiredService<Microsoft.AspNetCore.Mvc.ViewFeatures.IFileVersionProvider>()
                        .AddFileVersionToPath(Request.PathBase, "/css/ticket.css")
                },
                // Laverie : dépôts de linge payés au retrait.
                laverie = j.Caisse?.TypePointVente == "Laverie" ? new
                {
                    urlDeposer = "/Pos/Deposer",
                    urlDepots = $"/Pos/Depots?journee={j.Id}",
                    urlPret = "/Pos/DepotPret",
                    urlAnnuler = "/Pos/DepotAnnuler",
                    urlTicket = "/Pos/TicketDepot/",
                    peutAnnuler = PeutAnnuler
                } : null,
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
            // Commande à livrer : livreur, destinataire, payée maintenant ou à la livraison.
            public LivraisonSaisie? Livraison { get; set; }
            // Laverie : retrait d'un dépôt de linge (acompte déduit).
            public int? DepotId { get; set; }
            // Vente faite sans connexion, envoyée au retour de la connexion.
            public HorsLigneSaisie? HorsLigne { get; set; }
        }

        // Vente ou dépôt fait hors ligne sur le poste : date et heure réelles, numéro provisoire,
        // vendeur connecté sur le poste.
        private sealed class HorsLigneSaisie
        {
            public string? Date { get; set; }
            public string? Numero { get; set; }
            public string? Vendeur { get; set; }
        }

        private sealed record HorsLigneInfo(DateTime Date, string Numero, string Vendeur);

        // Date bornée : pas dans le futur, ni plus d'un jour avant l'ouverture de la journée.
        private static HorsLigneInfo? LireHorsLigne(HorsLigneSaisie? hl, JourneeCaisse j)
        {
            if (hl == null)
                return null;
            var maintenant = DateTime.Now;
            var date = DateTimeOffset.TryParse(hl.Date, System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.AssumeLocal, out var d)
                ? d.ToLocalTime().DateTime : maintenant;
            if (date > maintenant.AddMinutes(5) || date < j.DateOuverture.AddDays(-1))
                date = maintenant;
            if (date > maintenant)
                date = maintenant;
            date = new DateTime(date.Year, date.Month, date.Day, date.Hour, date.Minute, date.Second);
            var numero = new string((hl.Numero ?? "").Where(c => char.IsAsciiLetterOrDigit(c) || c == '-').Take(30).ToArray());
            var vendeur = (hl.Vendeur ?? "").Trim();
            return new HorsLigneInfo(date, numero == "" ? "hors ligne" : numero, vendeur.Length > 100 ? vendeur[..100] : vendeur);
        }

        // Jeton anti-falsification à jour, pour envoyer les ventes et dépôts faits hors ligne (le jeton
        // de l'écran de vente gardé sur le poste peut avoir changé depuis). Session expirée : connexion.
        [HttpGet]
        public IActionResult Jeton()
        {
            var jetons = _antiforgery.GetAndStoreTokens(HttpContext);
            return Json(new { nom = jetons.FormFieldName, valeur = jetons.RequestToken });
        }

        private sealed class OuverteSaisie
        {
            public int Id { get; set; }
            public int Version { get; set; }
            // Hors ligne : nom de la table (contrôle et ticket si sa commande a changé sur le serveur).
            public string? Table { get; set; }
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
            // Sans règlement : seulement pour un dépôt de linge entièrement payé par son acompte.
            if (v == null || string.IsNullOrWhiteSpace(v.Cle) || !v.Lignes.Any() || (!v.Paiements.Any() && v.DepotId == null))
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
            // Vente faite hors ligne : elle a déjà eu lieu, elle est enregistrée même si la journée a été
            // clôturée, un prix a changé, le stock manque ou le plafond est dépassé ; ces écarts sont notés
            // (AlerteHorsLigne) pour vérification par un administrateur.
            var hl = LireHorsLigne(v.HorsLigne, j);
            var alertes = new List<string>();
            var nomSession = User.FindFirst(AppClaimTypes.NomComplet)?.Value;
            var loginSession = User.FindFirst(ClaimTypes.Name)?.Value ?? "";
            if (hl != null && hl.Vendeur != "" && hl.Vendeur != nomSession && hl.Vendeur != loginSession)
                alertes.Add($"faite par « {hl.Vendeur} », envoyée sous la session de « {(string.IsNullOrWhiteSpace(nomSession) ? loginSession : nomSession)} »");
            if (j.Statut != "Ouverte")
            {
                if (hl == null)
                    return Erreur(409, "Cette journée est clôturée : la vente ne peut pas être enregistrée.");
                alertes.Add("arrivée après la clôture de la journée");
            }

            // Lignes : prix et taxes repris du catalogue ; prix saisi accepté pour un administrateur seulement
            // (et, hors ligne, le prix encaissé sur le poste).
            var taxesProduits = _context.TaxesDesProduits(v.Lignes.Select(l => l.ProduitId));
            var lignes = new List<(Produit Produit, LigneCommandePos Ligne)>();
            decimal ttc = 0, tva = 0;
            foreach (var l in v.Lignes)
            {
                var p = await _context.Produits.FirstOrDefaultAsync(x => x.Id == l.ProduitId && x.TenantId == tenant && !x.Consommable
                    && (hl != null || x.Actif && (x.ParentId == null || _context.Produits.Any(m => m.Id == x.ParentId && m.Actif))));
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
                var prix = (EstAdmin || hl != null) && l.Prix.HasValue ? Math.Max(0, Math.Round(l.Prix.Value, 2)) : prixCatalogue;
                if (hl != null && !EstAdmin && Math.Abs(prix - prixCatalogue) > 0.001m)
                    alertes.Add($"prix de « {p.Nom} » : {Fcfa(prix)} encaissé, {Fcfa(prixCatalogue)} au catalogue");
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

            // Droit de remise de l'utilisateur (hors ligne : la vente est gardée et l'écart noté).
            decimal? pctGlobal = v.RemiseGlobale != null && v.RemiseGlobale.Valeur > 0 && ttc > 0
                ? (v.RemiseGlobale.Type == "pct" ? v.RemiseGlobale.Valeur : Math.Min(ttc, v.RemiseGlobale.Valeur) / ttc * 100) : null;
            var refus = await ControleRemisesAsync(lignes.Select(x => (x.Produit.Nom, x.Ligne.Remise)), pctGlobal);
            if (refus != null)
            {
                if (hl == null)
                    return Erreur(403, refus);
                alertes.Add($"remise au-delà du droit du vendeur ({refus})");
            }

            // Remise globale (selon le droit de remise de l'utilisateur) : en % ou en montant,
            // répartie sur les lignes au prorata ; les totaux et les taxes portent sur le net.
            decimal remiseGlobale = 0;
            decimal? tauxRemise = null;
            if (v.RemiseGlobale != null && v.RemiseGlobale.Valeur > 0 && ttc > 0)
            {
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
            decimal recu = 0, especes = 0, parCompte = 0;
            foreach (var pm in v.Paiements)
            {
                var mode = modes.FirstOrDefault(m => m.Id == pm.ModeId);
                var montant = Math.Round(pm.Montant, 0, MidpointRounding.AwayFromZero);
                if (mode == null || montant <= 0)
                    return Erreur(400, "Mode de paiement invalide ou montant nul.");
                paiements.Add((mode, montant));
                recu += montant;
                if (mode.EstCompte)
                    parCompte += montant;
                if (EstEspeces(mode))
                    especes += montant;
            }
            // Frais de livraison (commande à livrer) : en plus du total, hors taxes, comme le pourboire.
            var fraisLivraison = v.Livraison != null ? Math.Max(0, Math.Round(v.Livraison.Frais, 0, MidpointRounding.AwayFromZero)) : 0;
            // Laverie : retrait d'un dépôt de linge, l'acompte versé au dépôt est déduit.
            DepotLinge? depot = null;
            decimal acompte = 0;
            if (v.DepotId.HasValue)
            {
                depot = await _context.DepotsLinge.IgnoreQueryFilters()
                    .FirstOrDefaultAsync(d => d.Id == v.DepotId && d.TenantId == tenant && DepotLinge.Actifs.Contains(d.Statut));
                if (depot == null && hl != null)
                {
                    // Retiré ou annulé sur un autre poste pendant la coupure : vente gardée, acompte non déduit.
                    var autre = await _context.DepotsLinge.IgnoreQueryFilters().AsNoTracking().FirstOrDefaultAsync(d => d.Id == v.DepotId && d.TenantId == tenant);
                    alertes.Add("dépôt de linge" + (autre != null ? $" n° {autre.Numero} déjà {autre.Statut.ToLowerInvariant()}" : " introuvable") + " : acompte non déduit");
                }
                else if (depot == null)
                    return Erreur(409, "Ce dépôt de linge a déjà été retiré ou annulé.");
                acompte = depot?.Acompte ?? 0;
                if (acompte > ttc + pourboire + fraisLivraison)
                    return Erreur(400, $"L'acompte versé ({Fcfa(acompte)} FCFA) dépasse le total : remettez les articles du dépôt sur le ticket.");
            }
            if (recu + acompte < ttc + pourboire + fraisLivraison)
            {
                if (hl == null)
                    return Erreur(400, "Le montant payé est inférieur au total.");
                alertes.Add($"montant payé inférieur au total de {Fcfa(ttc + pourboire + fraisLivraison - recu - acompte)} FCFA");
            }
            var rendu = Math.Max(0, recu + acompte - ttc - pourboire - fraisLivraison);
            if (rendu > especes)
                return Erreur(400, "Seule la monnaie sur les espèces peut être rendue : le montant payé par les autres modes dépasse le total.");

            int? clientId = v.ClientId.HasValue && await _context.Clients.AnyAsync(c => c.Id == v.ClientId && c.TenantId == tenant)
                ? v.ClientId : null;
            // Paiement par compte : client en compte obligatoire (plafond contrôlé sous verrou, plus bas).
            if (parCompte > 0)
            {
                var fiche = clientId.HasValue ? await _context.Clients.AsNoTracking().FirstOrDefaultAsync(c => c.Id == clientId) : null;
                if (fiche == null)
                    return Erreur(400, "Le paiement par compte demande un client : choisissez le client sur le ticket.");
                if (!fiche.EnCompte)
                    return Erreur(400, $"« {fiche.NomSociete} » n'est pas un client en compte : cochez « Client en compte » sur sa fiche (Tiers).");
            }
            int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var utilisateurId);
            var (livraison, erreurLivraison) = await ControlerLivraisonAsync(v.Livraison, tenant);
            if (erreurLivraison != null)
                return Erreur(400, erreurLivraison);

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
                // Stock des dépôts de la caisse (principal et secondaires).
                var depotsVente = await _context.DepotsCaisseAsync(j.CaisseId);
                foreach (var g in besoins)
                {
                    var stock = await _context.Produits
                        .FromSqlInterpolated($"SELECT * FROM Produits WITH (UPDLOCK, ROWLOCK) WHERE Id = {g.Key}")
                        .AsNoTracking().Select(p => new { p.Nom, p.SuiviStock }).FirstAsync();
                    var dispo = await _context.StockCaisseAsync(g.Key, depotsVente);
                    if (stock.SuiviStock && dispo < g.Sum(x => x.Qte) - 0.001m && hl != null)
                        alertes.Add($"stock insuffisant pour « {stock.Nom} » ({dispo.ToString("0.##", System.Globalization.CultureInfo.GetCultureInfo("fr-FR"))} disponible(s))");
                    else if (stock.SuiviStock && dispo < g.Sum(x => x.Qte) - 0.001m)
                        return Erreur(409, $"Stock insuffisant pour « {stock.Nom} » : {dispo:0.##} disponible(s).");
                }
            }
            // Vente par compte : plafond de crédit (sauf administrateur), sous verrou du client.
            if (parCompte > 0)
            {
                await _context.Database.ExecuteSqlInterpolatedAsync($"SELECT Id FROM Clients WITH (UPDLOCK, HOLDLOCK) WHERE Id = {clientId}");
                var fiche = await _context.Clients.AsNoTracking().FirstAsync(c => c.Id == clientId);
                var du = await _context.SoldeCompteAsync(tenant, clientId!.Value);
                if (fiche.PlafondCredit.HasValue && !EstAdmin && du + parCompte > fiche.PlafondCredit.Value + 0.001m && hl != null)
                    alertes.Add($"plafond de crédit de « {fiche.NomSociete} » dépassé (solde dû {Fcfa(du + parCompte)}, plafond {Fcfa(fiche.PlafondCredit.Value)})");
                else if (fiche.PlafondCredit.HasValue && !EstAdmin && du + parCompte > fiche.PlafondCredit.Value + 0.001m)
                {
                    var fr = System.Globalization.CultureInfo.GetCultureInfo("fr-FR");
                    return Erreur(409, $"Plafond de crédit dépassé pour « {fiche.NomSociete} » : solde dû {du.ToString("N0", fr)} FCFA, plafond "
                        + $"{fiche.PlafondCredit.Value.ToString("N0", fr)} FCFA (encore {Math.Max(0, fiche.PlafondCredit.Value - du).ToString("N0", fr)} FCFA possibles).");
                }
            }
            // Dépôt de linge : verrouillé, il ne peut être retiré qu'une fois.
            if (depot != null)
            {
                await _context.Database.ExecuteSqlInterpolatedAsync($"SELECT Id FROM DepotsLinge WITH (UPDLOCK, ROWLOCK) WHERE Id = {depot.Id}");
                await _context.Entry(depot).ReloadAsync();
                if (!DepotLinge.Actifs.Contains(depot.Statut) && hl == null)
                    return Erreur(409, "Ce dépôt de linge a déjà été retiré ou annulé.");
            }
            // Commande de table : payée en entier (table libérée) ou en partie (addition partagée : le
            // reste des articles demeure sur la table).
            string? tableNom = null;
            int? couverts = null;
            CommandeOuverte? restante = null;
            CommandeOuverte? co = null;
            if (v.CommandeOuverte != null)
            {
                co = await _context.CommandesOuvertes
                    .FromSqlInterpolated($"SELECT * FROM CommandesOuvertes WITH (UPDLOCK, ROWLOCK) WHERE Id = {v.CommandeOuverte.Id}")
                    .FirstOrDefaultAsync();
                if ((co == null || co.JourneeCaisseId != j.Id || co.Version != v.CommandeOuverte.Version) && hl == null)
                    return Erreur(409, "La commande de la table a été modifiée sur un autre appareil : rechargez la table puis recommencez.");
                // Table encaissée hors ligne, mais sa commande a changé (ou n'a pas pu être enregistrée) sur
                // le serveur : la vente est gardée, la table n'est pas touchée, à vérifier.
                if (co == null || co.JourneeCaisseId != j.Id || co.Version != v.CommandeOuverte.Version)
                {
                    var nomTable = Texte(v.CommandeOuverte.Table, 60)
                        ?? (co?.TableId is int idTable ? (await _context.TablesRestaurant.FirstOrDefaultAsync(t => t.Id == idTable))?.Nom : null) ?? "table";
                    alertes.Add($"commande de « {nomTable} » modifiée ou introuvable sur le serveur : table à vérifier");
                    tableNom = nomTable;
                    co = null;
                }
            }
            if (v.CommandeOuverte != null && co != null)
            {
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
                UtilisateurId = utilisateurId, DateCommande = hl?.Date ?? DateTime.Now, TotalHT = ttc - tva, TotalTVA = tva,
                TotalTTC = ttc, MontantRecu = recu + acompte, MonnaieRendue = rendu, Statut = "Payée",
                RemiseGlobale = remiseGlobale, RemiseGlobaleTaux = tauxRemise,
                TableNom = tableNom, Couverts = couverts, Pourboire = pourboire,
                Lignes = lignes.Select(x => x.Ligne).ToList(),
                NumeroHorsLigne = hl?.Numero,
                AlerteHorsLigne = alertes.Count == 0 ? null : string.Join(" ; ", alertes) is var a && a.Length > 500 ? a[..500] : a
            };
            if (livraison != null)
            {
                // Payée à la livraison : le livreur est revenu, la commande est livrée.
                var livree = livraison.Paiement == "livraison";
                commande.LivreurId = livraison.LivreurId;
                commande.NomLivraison = livraison.Nom;
                commande.TelephoneLivraison = livraison.Telephone;
                commande.AdresseLivraison = livraison.Adresse;
                commande.StatutLivraison = livree ? "Livrée" : "À livrer";
                commande.DateLivraison = livree ? hl?.Date ?? DateTime.Now : null;
                commande.FraisLivraison = fraisLivraison;
            }
            var motif = await _context.Motifs.FirstOrDefaultAsync(m => m.LibelleMotif == "Vente POS" && m.TenantId == tenant);
            if (motif == null)
            {
                motif = new Motif { LibelleMotif = "Vente POS", TypeModif = "Client", TenantId = tenant };
                _context.Motifs.Add(motif);
            }
            _context.CommandesPos.Add(commande);
            await _context.SaveChangesAsync();
            var depotsSortie = await _context.DepotsCaisseAsync(j.CaisseId);
            foreach (var (produit, ligne) in lignes)
                await _context.LigneSortieStockAsync(produit.Id, ligne.Composants, ligne.Quantite, numero, commande.Id, utilisateurId, depotsSortie);

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
                // Paiement par compte : pas d'encaissement en caisse, le montant s'ajoute au solde dû.
                if (net > 0 && !mode.EstCompte)
                {
                    operation = new OperationCaisse
                    {
                        TenantId = tenant, JourneeCaisseId = j.Id, DateOperation = hl?.Date ?? DateTime.Now,
                        TypeOperation = "Encaissement", Montant = net,
                        Libelle = "Vente POS " + numero + (hl != null ? " (hors ligne)" : "") + (pourboire > 0 ? " (dont pourboire " + pourboire.ToString("N0", System.Globalization.CultureInfo.GetCultureInfo("fr-FR")) + ")" : "")
                            + (livraison != null && fraisLivraison > 0 ? " (dont frais de livraison " + fraisLivraison.ToString("N0", System.Globalization.CultureInfo.GetCultureInfo("fr-FR")) + ")" : ""),
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
            // Dépôt de linge retiré : l'acompte (encaissé dans la journée du dépôt) figure parmi les
            // règlements de la vente, rattaché à son encaissement d'origine.
            if (depot != null)
            {
                if (acompte > 0)
                    _context.PaiementsPos.Add(new PaiementPos
                    {
                        TenantId = tenant, CommandePosId = commande.Id, ModePaiementId = depot.AcompteModePaiementId,
                        Libelle = $"Acompte (dépôt n° {depot.Numero})", MontantRecu = acompte, Montant = acompte, OperationCaisseId = depot.AcompteOperationId
                    });
                if (DepotLinge.Actifs.Contains(depot.Statut))
                {
                    depot.Statut = DepotLinge.Retire;
                    depot.DateRetrait = hl?.Date ?? DateTime.Now;
                    depot.CommandePosId = commande.Id;
                }
            }
            // Vente directe d'une caisse restaurant / bar : à l'encaissement, les articles partent en
            // préparation (un bon par poste, comme pour une table).
            var bons = new List<BonPreparation>();
            // (Pas pour une vente faite hors ligne : elle a déjà été servie.)
            if (v.CommandeOuverte == null && hl == null && j.Caisse != null && j.Caisse.EstRestaurant)
            {
                var contenu = new Restaurant.Contenu
                {
                    Lignes = lignes.Select((x, i) => new Restaurant.Ligne
                    {
                        Uid = i.ToString(), ProduitId = x.Produit.Id, Nom = x.Produit.Nom, Qte = x.Ligne.Quantite,
                        Note = x.Ligne.Note, Composants = Combos.Lire(x.Ligne.Composants)
                    }).ToList()
                };
                bons = await Restaurant.EnvoyerAsync(_context, new CommandeOuverte { TenantId = tenant, CaisseId = j.CaisseId, JourneeCaisseId = j.Id },
                    contenu, new Restaurant.Contenu(), $"Vente directe · ticket {rang}", Serveur);
                foreach (var b in bons)
                    b.Couverts = null;
            }
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            return Json(new { id = commande.Id, numero, rendu, bons = bons.Select(b => b.Id),
                commande = restante == null ? null : Restaurant.CommandeJson(restante) });
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
            // Vente ou retour par compte : solde dû du client (à la date d'impression).
            var parCompte = commande.ClientId.HasValue && await (from p in _context.PaiementsPos
                                                                  join m in _context.ModesPaiement on p.ModePaiementId equals m.Id
                                                                  where p.CommandePosId == commande.Id && m.EstCompte
                                                                  select p.Id).AnyAsync();
            ViewBag.SoldeCompte = parCompte ? await _context.SoldeCompteAsync(commande.TenantId, commande.ClientId!.Value) : (decimal?)null;
            var livreurTicket = commande.LivreurId.HasValue
                ? await _context.Livreurs.IgnoreQueryFilters().FirstOrDefaultAsync(l => l.Id == commande.LivreurId) : null;
            ViewBag.Livreur = livreurTicket == null ? null : $"{livreurTicket.Nom} ({livreurTicket.MoyenLivraison})";
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
            // Commande prise hors ligne, envoyée au retour de la connexion.
            public HorsLigneSaisie? HorsLigne { get; set; }
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
            // Commande prise hors ligne : les articles annoncés en cuisine depuis le poste sont « envoyés ».
            var contenu = Restaurant.Nettoyer(new Restaurant.Contenu { Lignes = c.Lignes, ClientId = c.ClientId, Remise = c.Remise }, avant, c.HorsLigne != null);
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
            var contenu = Restaurant.Lire(co.Contenu);
            ViewBag.Contenu = contenu;
            ViewBag.Titre = $"{ViewBag.Table} · {co.Couverts} couvert(s)";
            ViewBag.Client = contenu.ClientId.HasValue
                ? await _context.Clients.Where(c => c.Id == contenu.ClientId).Select(c => c.NomSociete).FirstOrDefaultAsync() : null;
            ViewBag.Frais = 0m;
            return View(co);
        }

        private sealed class TicketAddition
        {
            public int JourneeId { get; set; }
            public int Numero { get; set; }
            public int? ClientId { get; set; }
            public Restaurant.RemiseTicket? Remise { get; set; }
            public LivraisonAddition? Livraison { get; set; }
            public List<Restaurant.Ligne> Lignes { get; set; } = new();
        }

        private sealed class LivraisonAddition
        {
            public decimal Frais { get; set; }
        }

        // Addition (note provisoire, NON PAYÉE) d'un ticket hors table : vente au comptoir, vente directe,
        // laverie… Reçoit le ticket en JSON (champ « ticket ») ; les prix sont repris du catalogue (prix
        // saisi accepté pour un administrateur seulement, comme à l'encaissement).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> AdditionTicket(string? ticket)
        {
            TicketAddition? t;
            try { t = JsonSerializer.Deserialize<TicketAddition>(ticket ?? "", new JsonSerializerOptions { PropertyNameCaseInsensitive = true }); }
            catch (JsonException) { t = null; }
            var j = t == null ? null : await _context.JourneesCaisses.Include(x => x.Caisse).FirstOrDefaultAsync(x => x.Id == t.JourneeId);
            if (t == null || j == null)
                return NotFound();
            var lignes = await LignesCatalogueAsync(t.Lignes, j.TenantId);
            var remise = await RemiseAutoriseeAsync(t.Remise);
            var societe = await _context.Tenants.FirstOrDefaultAsync(x => x.Id == j.TenantId);
            ViewBag.Societe = societe?.Nom ?? "GesCaisse";
            ViewBag.Logo = Images.UrlLogo(societe);
            ViewBag.Coordonnees = Images.Coordonnees(societe);
            ViewBag.Titre = (j.Caisse != null && j.Caisse.EstRestaurant ? "Vente directe" : "Ticket") + (t.Numero > 0 ? $" n° {t.Numero}" : "");
            ViewBag.Serveur = Serveur;
            ViewBag.Client = t.ClientId.HasValue
                ? await _context.Clients.Where(c => c.Id == t.ClientId && c.TenantId == j.TenantId).Select(c => c.NomSociete).FirstOrDefaultAsync() : null;
            ViewBag.Frais = t.Livraison == null ? 0m : Math.Max(0, Math.Round(t.Livraison.Frais, MidpointRounding.AwayFromZero));
            ViewBag.Contenu = new Restaurant.Contenu { Lignes = lignes, Remise = remise };
            return View("Addition", new CommandeOuverte { Couverts = 0 });
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
