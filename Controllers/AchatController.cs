using System.Globalization;
using System.Security.Claims;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Models.ViewModels;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Achats (laverie : lessive, javel, assouplissant…) et consommations internes.
    // - Achat : un fournisseur (tiers de type Fournisseur), un dépôt, des lignes produit × quantité ×
    //   prix d'achat. À l'enregistrement, les quantités entrent en stock (mouvement « Achat ») et le
    //   coût du produit est recalculé (coût moyen pondéré).
    // - Règlement : par la caisse (décaissement dans une journée ouverte), hors caisse (virement,
    //   chèque…) ou plus tard : l'achat reste dû au fournisseur (achat à crédit).
    // - Annulation : les quantités ressortent du stock (refus si elles ont déjà été consommées ou
    //   vendues) ; les règlements passés par une caisse dont la journée est encore ouverte y sont
    //   remboursés (encaissement) ; journée clôturée : refus.
    // - Consommation : sortie du stock des produits utilisés pour le service (mouvement « Consommation »).
    // Réservé aux profils Admin et SuperAdmin. Même fonctionnement que la version PHP (achat.php).
    [Authorize(Policy = "Admin")]
    public class AchatController : Controller
    {
        public static readonly (string Code, string Libelle)[] Paiements =
        {
            ("credit", "À crédit (à régler plus tard)"), ("caisse", "Payé par la caisse (décaissement)"), ("hors", "Payé hors caisse (virement, chèque…)")
        };
        private const string MessageSociete = "Choisissez d'abord la société concernée dans le menu « Société consultée », puis recommencez.";
        private static readonly CultureInfo Fr = CultureInfo.GetCultureInfo("fr-FR");

        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public AchatController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        private int UtilisateurId => int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id) ? id : 0;
        private bool PeutValider => bool.TryParse(User.FindFirst(AppClaimTypes.PeutValiderOperations)?.Value, out var pv) && pv;
        private string? NomComplet => User.FindFirst(AppClaimTypes.NomComplet)?.Value;
        private static string Fcfa(decimal n) => n.ToString("N0", Fr);
        private static string Qte(decimal n) => n.ToString(n == Math.Round(n) ? "#,0" : "#,0.00", Fr);

        private static decimal? Nombre(string? texte)
        {
            var t = (texte ?? "").Replace(" ", "").Replace(" ", "").Replace(" ", "").Replace(',', '.');
            return decimal.TryParse(t, NumberStyles.Number, CultureInfo.InvariantCulture, out var n) ? n : null;
        }

        private static FiltresAchats Filtres(DateTime? du, DateTime? au, int fournisseur, string? statut)
        {
            var f = new FiltresAchats
            {
                Du = (du ?? new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1)).Date,
                Au = (au ?? DateTime.Today).Date,
                Fournisseur = fournisseur,
                Statut = FiltresAchats.Choix.Contains(statut) ? statut! : ""
            };
            if (f.Au < f.Du)
                (f.Du, f.Au) = (f.Au, f.Du);
            return f;
        }

        // Tiers de type Fournisseur de la société.
        private Task<List<Client>> Fournisseurs()
            => _context.Clients.Where(c => c.Type == "Fournisseur").OrderBy(c => c.NomSociete).ToListAsync();

        // Produits achetables (suivis en stock, hors modèles et combos), les consommables en premier.
        private Task<List<Produit>> ProduitsAchetables()
            => _context.Produits.Where(p => p.SuiviStock && p.Actif && !p.EstModele && !p.EstCombo)
                .OrderByDescending(p => p.Consommable).ThenBy(p => p.Nom).ToListAsync();

        // Dépôts actifs, le dépôt par défaut en premier.
        private async Task<List<Depot>> DepotsActifs()
        {
            if (_tenant.TenantId > 0)
                await _context.DepotParDefautAsync(_tenant.TenantId);
            return await _context.Depots.Where(d => d.Actif).OrderByDescending(d => d.ParDefaut).ThenBy(d => d.Code).ToListAsync();
        }

        private async Task ListesSaisie()
        {
            ViewBag.Journees = await _context.JourneesCaisses.Include(j => j.Caisse).Where(j => j.Statut == "Ouverte")
                .OrderBy(j => j.Caisse.ChkCode).ThenBy(j => j.Id).ToListAsync();
            ViewBag.Modes = await _context.ModesPaiement.Where(m => m.Actif && !m.EstCompte).OrderBy(m => m.Libelle).ToListAsync();
        }

        // Motif des décaissements d'achat (créé au besoin).
        private async Task<int> MotifAchatAsync(int tenant)
        {
            var motif = await _context.Motifs.IgnoreQueryFilters().FirstOrDefaultAsync(m => m.LibelleMotif == "Achat fournisseur" && m.TenantId == tenant);
            if (motif == null)
            {
                motif = new Motif { LibelleMotif = "Achat fournisseur", TypeModif = "Fournisseur", TenantId = tenant };
                _context.Motifs.Add(motif);
                await _context.SaveChangesAsync();
            }
            return motif.ID;
        }

        private async Task<string?> NomFournisseur(int? id)
            => id == null ? null : await _context.Clients.IgnoreQueryFilters().Where(c => c.Id == id).Select(c => c.NomSociete).FirstOrDefaultAsync();

        // Règlement d'un achat. mode : « caisse » (décaissement dans la journée) ou « hors ».
        // Renvoie un message d'erreur, ou null si le règlement est enregistré (au prochain SaveChanges).
        private async Task<string?> Regler(Achat a, decimal montant, string mode, int journeeId, int modeId)
        {
            var modePaiement = await _context.ModesPaiement.IgnoreQueryFilters()
                .FirstOrDefaultAsync(m => m.Id == modeId && m.TenantId == a.TenantId && m.Actif && !m.EstCompte);
            if (modePaiement == null)
                return "Choisissez le mode de paiement du règlement.";
            OperationCaisse? operation = null;
            if (mode == "caisse")
            {
                var journee = await _context.JourneesCaisses.IgnoreQueryFilters()
                    .FirstOrDefaultAsync(j => j.Id == journeeId && j.TenantId == a.TenantId && j.Statut == "Ouverte");
                if (journee == null)
                    return "Choisissez la journée de caisse ouverte qui paie le fournisseur.";
                var fournisseur = await NomFournisseur(a.FournisseurId);
                operation = new OperationCaisse
                {
                    TenantId = a.TenantId, JourneeCaisseId = journee.Id, DateOperation = DateTime.Now, TypeOperation = "Décaissement",
                    Montant = montant, Libelle = $"Achat n° {a.Numero}" + (fournisseur != null ? $" — {fournisseur}" : ""), ClientId = a.FournisseurId,
                    MotifId = await MotifAchatAsync(a.TenantId), ModePaiementId = modePaiement.Id, UtilisateurId = UtilisateurId, EstJustifie = true,
                    StatutValidation = PeutValider ? "Validé" : "En attente", Valideur = PeutValider ? NomComplet : null
                };
                _context.OperationsCaisses.Add(operation);
                await _context.SaveChangesAsync();
            }
            _context.ReglementsAchats.Add(new ReglementAchat
            {
                AchatId = a.Id, DateReglement = DateTime.Now, Montant = montant, ModePaiementId = modePaiement.Id,
                OperationCaisseId = operation?.Id, UtilisateurId = UtilisateurId
            });
            return null;
        }

        // Liste des achats avec totaux.
        public async Task<IActionResult> Index(DateTime? du = null, DateTime? au = null, int fournisseur = 0, string? statut = null)
        {
            var f = Filtres(du, au, fournisseur, statut);
            var requete = _context.Achats.Where(a => a.DateAchat >= f.Du && a.DateAchat <= f.Au);
            if (f.Fournisseur > 0)
                requete = requete.Where(a => a.FournisseurId == f.Fournisseur);
            if (f.Statut == Achat.Valide || f.Statut == Achat.Annule)
                requete = requete.Where(a => a.Statut == f.Statut);
            var achats = await requete.OrderByDescending(a => a.DateAchat).ThenByDescending(a => a.Numero)
                .Select(a => new LigneListeAchat
                {
                    Achat = a, Regle = a.Reglements.Sum(r => r.Montant),
                    Fournisseur = _context.Clients.Where(c => c.Id == a.FournisseurId).Select(c => c.NomSociete).FirstOrDefault(),
                    Depot = _context.Depots.Where(d => d.Id == a.DepotId).Select(d => d.Nom).FirstOrDefault()
                }).ToListAsync();
            foreach (var a in achats)
                a.Reste = a.Achat.Statut == Achat.Valide ? Math.Max(0, a.Achat.Total - a.Regle) : 0;
            if (f.Statut == "Non soldé")
                achats = achats.Where(a => a.Achat.Statut == Achat.Valide && a.Reste > 0).ToList();
            var valides = achats.Where(a => a.Achat.Statut == Achat.Valide).ToList();
            // Dette fournisseurs : tous les achats validés non soldés, quelle que soit leur date.
            var dette = await _context.Achats.Where(a => a.Statut == Achat.Valide).SumAsync(a => (decimal?)(a.Total - a.Reglements.Sum(r => r.Montant))) ?? 0;
            return View(new AchatsVM
            {
                Filtres = f, Achats = achats, Fournisseurs = await Fournisseurs(), Dette = Math.Max(0, dette),
                Nombre = valides.Count, Montant = valides.Sum(a => a.Achat.Total), Regle = valides.Sum(a => a.Regle), Reste = valides.Sum(a => a.Reste)
            });
        }

        public async Task<IActionResult> Nouveau()
        {
            ViewBag.Fournisseurs = await Fournisseurs();
            ViewBag.Depots = await DepotsActifs();
            await ListesSaisie();
            return View(await ProduitsAchetables());
        }

        // Nouvel achat : entrée en stock, coût moyen pondéré, règlement éventuel.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Nouveau(int fournisseur, string? date, int depot, string? reference, string? commentaire,
            List<int> produit, List<string> qte, List<string> prix, string? paiement, string? montantRegle, int mode, int journee)
        {
            IActionResult Retour(string m)
            {
                TempData["Error"] = m;
                return RedirectToAction("Nouveau");
            }
            var tenant = _tenant.TenantId;
            if (tenant == 0)
                return Retour(MessageSociete);
            if (depot == 0)
                depot = await _context.DepotParDefautAsync(tenant);
            var dDepot = await _context.Depots.FirstOrDefaultAsync(d => d.Id == depot && d.TenantId == tenant && d.Actif);
            if (dDepot == null)
                return Retour("Choisissez le dépôt qui reçoit l'achat.");
            if (fournisseur > 0 && !await _context.Clients.AnyAsync(c => c.Id == fournisseur && c.TenantId == tenant && c.Type == "Fournisseur"))
                return Retour("Fournisseur introuvable.");
            var jour = DateTime.TryParseExact(date ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var dt) ? dt.Date : DateTime.Today;
            if (jour > DateTime.Today)
                return Retour("La date d'achat ne peut pas être dans le futur.");
            reference = string.IsNullOrWhiteSpace(reference) ? null : reference.Trim()[..Math.Min(100, reference.Trim().Length)];
            commentaire = string.IsNullOrWhiteSpace(commentaire) ? null : commentaire.Trim()[..Math.Min(300, commentaire.Trim().Length)];
            var lignes = new List<LigneAchat>();
            for (var i = 0; i < produit.Count; i++)
            {
                var q = Math.Round(Nombre(i < qte.Count ? qte[i] : null) ?? 0, 2);
                var pu = Math.Round(Nombre(i < prix.Count ? prix[i] : null) ?? 0, 2);
                if (produit[i] <= 0 || q <= 0)
                    continue;
                if (pu < 0)
                    return Retour("Le prix d'achat ne peut pas être négatif.");
                if (!await _context.Produits.AnyAsync(p => p.Id == produit[i] && p.TenantId == tenant && p.SuiviStock && !p.EstModele && !p.EstCombo))
                    return Retour("Un produit de la liste est introuvable ou sans suivi de stock.");
                lignes.Add(new LigneAchat { ProduitId = produit[i], Quantite = q, PrixUnitaire = pu, Montant = Math.Round(q * pu, 2) });
            }
            if (!lignes.Any())
                return Retour("Indiquez au moins un produit, sa quantité et son prix d'achat.");
            var total = Math.Round(lignes.Sum(l => l.Montant), 2);
            paiement = Paiements.Any(p => p.Code == paiement) ? paiement! : "credit";
            var regle = paiement == "credit" ? 0 : Math.Round(Nombre(montantRegle) ?? total, 2);
            if (paiement != "credit" && (regle <= 0 || regle > total))
                return Retour($"Le montant réglé doit être compris entre 1 et le total de l'achat ({Fcfa(total)} FCFA).");

            await using var transaction = await _context.Database.BeginTransactionAsync();
            var numero = (await _context.Achats.IgnoreQueryFilters().Where(a => a.TenantId == tenant).MaxAsync(a => (int?)a.Numero) ?? 0) + 1;
            var achat = new Achat
            {
                TenantId = tenant, Numero = numero, DateAchat = jour, FournisseurId = fournisseur > 0 ? fournisseur : null, DepotId = dDepot.Id,
                Reference = reference, Commentaire = commentaire, Total = total, Statut = Achat.Valide, UtilisateurId = UtilisateurId,
                DateCreation = DateTime.Now, Lignes = lignes
            };
            _context.Achats.Add(achat);
            await _context.SaveChangesAsync();
            foreach (var l in lignes)
            {
                // Coût moyen pondéré : (stock existant × coût actuel + quantité achetée × prix) / stock après achat.
                var p = await _context.Produits.FromSqlInterpolated($"SELECT * FROM Produits WITH (UPDLOCK, ROWLOCK) WHERE Id = {l.ProduitId}")
                    .AsNoTracking().Select(x => new { x.StockActuel, x.Cout }).FirstAsync();
                var stock = Math.Max(0, p.StockActuel);
                var cout = Math.Round(p.Cout.HasValue && stock > 0 ? (stock * p.Cout.Value + l.Quantite * l.PrixUnitaire) / (stock + l.Quantite) : l.PrixUnitaire, 2);
                await _context.Database.ExecuteSqlInterpolatedAsync($"UPDATE Produits SET Cout = {cout} WHERE Id = {l.ProduitId}");
                await _context.MouvementAsync(l.ProduitId, l.Quantite, "Achat", $"Achat n° {numero}", null, UtilisateurId, reference, dDepot.Id);
            }
            if (regle > 0)
            {
                var erreur = await Regler(achat, regle, paiement, journee, mode);
                if (erreur != null)
                {
                    await transaction.RollbackAsync();
                    return Retour(erreur);
                }
            }
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            TempData["Success"] = $"Achat n° {numero} enregistré : {lignes.Count} produit(s) entré(s) en stock ({dDepot.Nom}).";
            return RedirectToAction("Details", new { id = achat.Id });
        }

        // Détail d'un achat : lignes, règlements, formulaire de règlement, annulation.
        public async Task<IActionResult> Details(int id)
        {
            var a = await _context.Achats.Include(x => x.Lignes).Include(x => x.Reglements).FirstOrDefaultAsync(x => x.Id == id);
            if (a == null)
                return NotFound();
            var ids = a.Lignes.Select(l => l.ProduitId).ToList();
            ViewBag.Produits = await _context.Produits.IgnoreQueryFilters().Where(p => ids.Contains(p.Id)).ToDictionaryAsync(p => p.Id);
            var fournisseur = a.FournisseurId == null ? null : await _context.Clients.IgnoreQueryFilters().FirstOrDefaultAsync(c => c.Id == a.FournisseurId);
            ViewBag.Fournisseur = fournisseur == null ? null : $"{fournisseur.CodeClient} · {fournisseur.NomSociete}";
            ViewBag.Depot = await _context.Depots.IgnoreQueryFilters().Where(d => d.Id == a.DepotId).Select(d => d.Nom).FirstOrDefaultAsync();
            var noms = await Restaurant.NomsAsync(_context, a.Reglements.Select(r => r.UtilisateurId).Append(a.UtilisateurId));
            ViewBag.Noms = noms;
            var modes = a.Reglements.Select(r => r.ModePaiementId).ToList();
            ViewBag.ModesReglements = await _context.ModesPaiement.IgnoreQueryFilters().Where(m => modes.Contains(m.Id)).ToDictionaryAsync(m => m.Id, m => m.Libelle);
            var ops = a.Reglements.Where(r => r.OperationCaisseId.HasValue).Select(r => r.OperationCaisseId!.Value).ToList();
            ViewBag.Caisses = await _context.OperationsCaisses.IgnoreQueryFilters().Where(o => ops.Contains(o.Id))
                .Select(o => new { o.Id, o.JourneeCaisse.NumeroJournee, o.JourneeCaisse.Caisse.ChkCode })
                .ToDictionaryAsync(o => o.Id, o => $"{o.ChkCode} · journée {o.NumeroJournee}");
            await ListesSaisie();
            return View(a);
        }

        // Règlement (complément) d'un achat à crédit.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Reglement(int id, string? montant, string? paiement, int mode, int journee)
        {
            await using var transaction = await _context.Database.BeginTransactionAsync();
            var a = await _context.Achats.FromSqlInterpolated($"SELECT * FROM Achats WITH (UPDLOCK, ROWLOCK) WHERE Id = {id}").FirstOrDefaultAsync();
            if (a == null)
                return NotFound();
            var regle = await _context.ReglementsAchats.Where(r => r.AchatId == a.Id).SumAsync(r => (decimal?)r.Montant) ?? 0;
            var reste = Math.Round(a.Total - regle, 2);
            var somme = Math.Round(Nombre(montant) ?? 0, 2);
            string? erreur;
            if (a.Statut != Achat.Valide)
                erreur = "Cet achat est annulé.";
            else if (reste <= 0)
                erreur = "Cet achat est déjà entièrement réglé.";
            else if (somme <= 0 || somme > reste)
                erreur = $"Le montant doit être compris entre 1 et le reste à payer ({Fcfa(reste)} FCFA).";
            else
                erreur = await Regler(a, somme, paiement == "caisse" ? "caisse" : "hors", journee, mode);
            if (erreur != null)
            {
                await transaction.RollbackAsync();
                TempData["Error"] = erreur;
            }
            else
            {
                await _context.SaveChangesAsync();
                await transaction.CommitAsync();
                TempData["Success"] = $"Règlement de {Fcfa(somme)} FCFA enregistré : reste à payer {Fcfa(reste - somme)} FCFA.";
            }
            return RedirectToAction("Details", new { id });
        }

        // Annulation : sortie du stock et remboursement des règlements passés par une caisse ouverte.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Annuler(int id)
        {
            IActionResult Retour(string type, string m)
            {
                TempData[type] = m;
                return RedirectToAction("Details", new { id });
            }
            await using var transaction = await _context.Database.BeginTransactionAsync();
            var a = await _context.Achats.FromSqlInterpolated($"SELECT * FROM Achats WITH (UPDLOCK, ROWLOCK) WHERE Id = {id}").FirstOrDefaultAsync();
            if (a == null)
                return NotFound();
            if (a.Statut != Achat.Valide)
                return Retour("Error", "Cet achat est déjà annulé.");
            var caisse = await _context.ReglementsAchats.Where(r => r.AchatId == id && r.OperationCaisseId != null)
                .Join(_context.OperationsCaisses.IgnoreQueryFilters(), r => r.OperationCaisseId, o => o.Id, (r, o) => new
                {
                    r.Montant, r.ModePaiementId, o.JourneeCaisseId, o.JourneeCaisse.Statut, o.JourneeCaisse.NumeroJournee
                }).ToListAsync();
            var fermee = caisse.FirstOrDefault(r => r.Statut != "Ouverte");
            if (fermee != null)
                return Retour("Error", $"Annulation impossible : un règlement a été payé par la journée {fermee.NumeroJournee}, déjà clôturée.");
            var depot = await _context.Depots.IgnoreQueryFilters().Where(d => d.Id == a.DepotId).Select(d => d.Nom).FirstOrDefaultAsync();
            var lignes = await _context.LignesAchats.Where(l => l.AchatId == id).OrderBy(l => l.Id).ToListAsync();
            foreach (var l in lignes)
            {
                var nom = await _context.Produits.FromSqlInterpolated($"SELECT * FROM Produits WITH (UPDLOCK, ROWLOCK) WHERE Id = {l.ProduitId}")
                    .IgnoreQueryFilters().AsNoTracking().Select(p => p.Nom).FirstAsync();
                var dispo = await _context.StockDepotAsync(l.ProduitId, a.DepotId);
                if (dispo < l.Quantite - 0.001m)
                    return Retour("Error", $"Annulation impossible : il ne reste que {Qte(dispo)} « {nom} » dans {depot} (quantité déjà consommée ou vendue). Corrigez plutôt le stock par un inventaire.");
            }
            var fournisseur = await NomFournisseur(a.FournisseurId);
            foreach (var r in caisse)
            {
                _context.OperationsCaisses.Add(new OperationCaisse
                {
                    TenantId = a.TenantId, JourneeCaisseId = r.JourneeCaisseId, DateOperation = DateTime.Now, TypeOperation = "Encaissement",
                    Montant = r.Montant, Libelle = $"Annulation achat n° {a.Numero}" + (fournisseur != null ? $" — {fournisseur}" : ""), ClientId = a.FournisseurId,
                    MotifId = await MotifAchatAsync(a.TenantId), ModePaiementId = r.ModePaiementId, UtilisateurId = UtilisateurId, EstJustifie = true,
                    StatutValidation = "Validé", Valideur = NomComplet
                });
            }
            foreach (var l in lignes)
                await _context.MouvementAsync(l.ProduitId, -l.Quantite, "Annulation", $"Achat n° {a.Numero}", null, UtilisateurId, "Annulation de l'achat", a.DepotId);
            a.Statut = Achat.Annule;
            a.DateAnnulation = DateTime.Now;
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return Retour("Success", $"Achat n° {a.Numero} annulé : les quantités sont sorties du stock" + (caisse.Any() ? ", les paiements par la caisse remboursés" : "") + ".");
        }

        // Consommations : saisie et suivi des produits utilisés pour le service, valorisés au coût.
        public async Task<IActionResult> Consommation(DateTime? du = null, DateTime? au = null)
        {
            var f = Filtres(du, au, 0, null);
            var fin = f.Au.AddDays(1);
            var mouvements = await _context.MouvementsStock.Include(m => m.Produit).Include(m => m.Depot)
                .Where(m => m.TypeMouvement == "Consommation" && m.DateMouvement >= f.Du && m.DateMouvement < fin)
                .OrderByDescending(m => m.DateMouvement).ThenByDescending(m => m.Id).ToListAsync();
            ViewBag.Utilisateurs = await Restaurant.NomsAsync(_context, mouvements.Select(m => m.UtilisateurId));
            ViewBag.Synthese = mouvements.GroupBy(m => m.ProduitId).Select(g => new SyntheseConsommation
            {
                Code = g.First().Produit.Code, Nom = g.First().Produit.Nom, Unite = g.First().Produit.Unite,
                Quantite = -g.Sum(m => m.Quantite), Valeur = -g.Sum(m => m.Quantite * (m.Produit.Cout ?? 0))
            }).OrderByDescending(s => s.Valeur).ThenBy(s => s.Nom, StringComparer.Ordinal).ToList();
            ViewBag.Filtres = f;
            ViewBag.Produits = await ProduitsAchetables();
            ViewBag.Depots = await DepotsActifs();
            return View(mouvements);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Consommation(int depot, string? commentaire, List<int> produit, List<string> qte)
        {
            IActionResult Retour(string m)
            {
                TempData["Error"] = m;
                return RedirectToAction("Consommation");
            }
            var tenant = _tenant.TenantId;
            if (tenant == 0)
                return Retour(MessageSociete);
            if (depot == 0)
                depot = await _context.DepotParDefautAsync(tenant);
            var dDepot = await _context.Depots.FirstOrDefaultAsync(d => d.Id == depot && d.TenantId == tenant && d.Actif);
            if (dDepot == null)
                return Retour("Choisissez le dépôt où les produits sont pris.");
            commentaire = string.IsNullOrWhiteSpace(commentaire) ? null : commentaire.Trim()[..Math.Min(300, commentaire.Trim().Length)];
            var lignes = new Dictionary<int, decimal>();
            for (var i = 0; i < produit.Count; i++)
            {
                var q = Math.Round(Nombre(i < qte.Count ? qte[i] : null) ?? 0, 2);
                if (produit[i] <= 0 || q <= 0)
                    continue;
                if (!await _context.Produits.AnyAsync(p => p.Id == produit[i] && p.TenantId == tenant && p.SuiviStock && !p.EstModele && !p.EstCombo))
                    return Retour("Un produit de la liste est introuvable ou sans suivi de stock.");
                lignes[produit[i]] = lignes.GetValueOrDefault(produit[i]) + q;
            }
            if (!lignes.Any())
                return Retour("Indiquez au moins un produit et la quantité utilisée.");
            await using var transaction = await _context.Database.BeginTransactionAsync();
            foreach (var (id, q) in lignes)
            {
                var nom = await _context.Produits.FromSqlInterpolated($"SELECT * FROM Produits WITH (UPDLOCK, ROWLOCK) WHERE Id = {id}")
                    .AsNoTracking().Select(p => p.Nom).FirstAsync();
                var dispo = await _context.StockDepotAsync(id, dDepot.Id);
                if (dispo < q - 0.001m)
                {
                    await transaction.RollbackAsync();
                    return Retour($"Stock insuffisant pour « {nom} » dans {dDepot.Nom} : {Qte(dispo)} disponible(s).");
                }
                await _context.MouvementAsync(id, -q, "Consommation", $"CONSO-{DateTime.Today:yyyyMMdd}", null, UtilisateurId, commentaire, dDepot.Id);
            }
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            TempData["Success"] = $"{lignes.Count} produit(s) sorti(s) du stock (consommation, {dDepot.Nom}).";
            return RedirectToAction("Consommation");
        }
    }
}
