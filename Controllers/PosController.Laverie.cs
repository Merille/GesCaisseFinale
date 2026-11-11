using System.Globalization;
using System.Text.Json;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Laverie : dépôts de linge payés au retrait (table DepotsLinge). Au dépôt, la commande est
    // enregistrée avec un numéro, le client, son téléphone, la date de retrait prévue et un acompte
    // facultatif (encaissé dans la journée du dépôt) ; un ticket « NON PAYÉ » est imprimé en deux
    // exemplaires (client et souche jointe au linge). Le dépôt ne bloque pas la clôture de la journée.
    // Au retrait, il est encaissé dans la journée du jour comme une vente (acompte déduit, voir Vendre).
    // Même fonctionnement que la version PHP (php/app/laverie.php).
    public partial class PosController
    {
        private sealed class DepotSaisi
        {
            public string? Cle { get; set; }
            public int JourneeId { get; set; }
            public int Id { get; set; }
            public int? ClientId { get; set; }
            public Restaurant.RemiseTicket? Remise { get; set; }
            public string? Nom { get; set; }
            public string? Telephone { get; set; }
            public string? Retrait { get; set; }
            public decimal Acompte { get; set; }
            public int? ModeId { get; set; }
            public List<Restaurant.Ligne> Lignes { get; set; } = new();
        }

        // Lignes d'un ticket reçu de l'écran de vente, reprises du catalogue : nom, taux et prix du
        // produit actif (prix du combo plus les suppléments choisis) ; prix saisi accepté pour un
        // administrateur seulement. Les composants gardent leur groupe (contrôlés à l'encaissement).
        private async Task<List<Restaurant.Ligne>> LignesCatalogueAsync(List<Restaurant.Ligne> saisies, int tenant)
        {
            var lignes = new List<Restaurant.Ligne>();
            foreach (var l in Restaurant.Nettoyer(new Restaurant.Contenu { Lignes = saisies }, new Restaurant.Contenu()).Lignes)
            {
                var p = await _context.Produits.IgnoreQueryFilters().FirstOrDefaultAsync(x => x.Id == l.ProduitId && x.TenantId == tenant && x.Actif);
                if (p == null || l.Qte <= 0 || p.EstModele)
                    continue;
                var prix = p.PrixVente;
                if (p.EstCombo)
                {
                    var (_, supplements, erreur) = await Combos.ControlerAsync(_context, p, l.Composants);
                    if (erreur == null)
                        prix += supplements;
                }
                l.Nom = p.Nom;
                l.Tva = p.TauxTVA;
                l.Unite = p.Unite ?? "";
                if (!EstAdmin)
                    l.Prix = prix;
                lignes.Add(l);
            }
            return lignes;
        }

        // Remise globale saisie, si l'utilisateur y a droit.
        private Restaurant.RemiseTicket? RemiseAutorisee(Restaurant.RemiseTicket? r)
            => r is { Valeur: > 0 } && PeutRemiseGlobale ? new Restaurant.RemiseTicket { Type = r.Type == "pct" ? "pct" : "montant", Valeur = r.Valeur } : null;

        private static DepotSaisi? LireDepot(string? json)
        {
            try { return JsonSerializer.Deserialize<DepotSaisi>(json ?? "", JsonAttente); }
            catch (JsonException) { return null; }
        }

        // Motif des acomptes de laverie (créé au besoin).
        private async Task<int> MotifLaverieAsync(int tenant)
        {
            var motif = await _context.Motifs.IgnoreQueryFilters().FirstOrDefaultAsync(m => m.LibelleMotif == "Acompte laverie" && m.TenantId == tenant);
            if (motif == null)
            {
                motif = new Motif { LibelleMotif = "Acompte laverie", TypeModif = "Client", TenantId = tenant };
                _context.Motifs.Add(motif);
                await _context.SaveChangesAsync();
            }
            return motif.ID;
        }

        // Journée ouverte d'une caisse Laverie, pour un dépôt ; sinon le message d'erreur et son code.
        private async Task<(JourneeCaisse? Journee, IActionResult? Erreur)> JourneeLaverieAsync(int id)
        {
            var j = await _context.JourneesCaisses.Include(x => x.Caisse).FirstOrDefaultAsync(x => x.Id == id);
            if (j == null)
                return (null, Erreur(404, "Journée introuvable."));
            if (j.Caisse?.TypePointVente != "Laverie")
                return (null, Erreur(400, "Les dépôts de linge sont réservés aux caisses de type Laverie."));
            if (j.Statut != "Ouverte")
                return (null, Erreur(409, "Cette journée est clôturée : ouvrez une nouvelle journée."));
            return (j, null);
        }

        private static string Fcfa(decimal n) => n.ToString("N0", CultureInfo.GetCultureInfo("fr-FR"));

        // Enregistre un dépôt de linge (articles, client, retrait prévu, acompte). Répond { id, numero }.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Deposer([FromForm] string? commande)
        {
            var s = LireDepot(commande);
            if (s == null)
                return Erreur(400, "Dépôt illisible.");
            var (j, refus) = await JourneeLaverieAsync(s.JourneeId);
            if (j == null)
                return refus!;
            var tenant = j.TenantId;
            // Nouvel envoi après une coupure réseau : le dépôt déjà enregistré est renvoyé.
            var cle = new string((s.Cle ?? "").Where(c => char.IsAsciiLetterOrDigit(c) || c == '-').Take(64).ToArray());
            if (cle != "")
            {
                var deja = await _context.DepotsLinge.IgnoreQueryFilters().FirstOrDefaultAsync(d => d.TenantId == tenant && d.CleClient == cle);
                if (deja != null)
                    return Json(new { id = deja.Id, numero = deja.Numero });
            }
            var lignes = await LignesCatalogueAsync(s.Lignes, tenant);
            if (!lignes.Any())
                return Erreur(400, "Le ticket est vide.");
            var remise = RemiseAutorisee(s.Remise);
            var total = Restaurant.Total(new Restaurant.Contenu { Lignes = lignes, Remise = remise });
            var nom = Texte(s.Nom, 100);
            var telephone = Texte(s.Telephone, 30);
            if (nom == null || telephone == null)
                return Erreur(400, "Indiquez le nom et le téléphone du client.");
            DateTime? retrait = DateTime.TryParseExact(s.Retrait ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var r) ? r : null;
            if (retrait.HasValue && retrait.Value < DateTime.Today)
                return Erreur(400, "La date de retrait prévue est déjà passée.");
            int? clientId = s.ClientId.HasValue && await _context.Clients.AnyAsync(c => c.Id == s.ClientId && c.TenantId == tenant) ? s.ClientId : null;
            var acompte = Math.Max(0, Math.Round(s.Acompte, 0, MidpointRounding.AwayFromZero));
            if (acompte > total)
                return Erreur(400, $"L'acompte dépasse le total du dépôt ({Fcfa(total)} FCFA).");
            ModePaiement? mode = null;
            if (acompte > 0)
            {
                mode = await _context.ModesPaiement.FirstOrDefaultAsync(m => m.Id == s.ModeId && m.TenantId == tenant && m.Actif && !m.EstCompte);
                if (mode == null)
                    return Erreur(400, "Choisissez le mode de paiement de l'acompte.");
            }

            await using var transaction = await _context.Database.BeginTransactionAsync();
            await _context.Database.ExecuteSqlInterpolatedAsync($"SELECT Id FROM JourneesCaisses WITH (UPDLOCK, HOLDLOCK) WHERE Id = {j.Id}");
            var numero = (await _context.DepotsLinge.IgnoreQueryFilters().Where(d => d.TenantId == tenant).MaxAsync(d => (int?)d.Numero) ?? 0) + 1;
            OperationCaisse? operation = null;
            if (acompte > 0)
            {
                operation = new OperationCaisse
                {
                    TenantId = tenant, JourneeCaisseId = j.Id, DateOperation = DateTime.Now, TypeOperation = "Encaissement",
                    Montant = acompte, Libelle = $"Acompte dépôt de linge n° {numero} ({nom})", ClientId = clientId,
                    MotifId = await MotifLaverieAsync(tenant), ModePaiementId = mode!.Id, UtilisateurId = UtilisateurConnecte,
                    EstJustifie = true, StatutValidation = "Validé", Valideur = "Point de vente"
                };
                _context.OperationsCaisses.Add(operation);
                await _context.SaveChangesAsync();
            }
            var depot = new DepotLinge
            {
                TenantId = tenant, CaisseId = j.CaisseId, JourneeCaisseId = j.Id, Numero = numero, CleClient = cle == "" ? null : cle,
                DateDepot = DateTime.Now, DateRetraitPrevue = retrait, NomClient = nom, TelephoneClient = telephone, ClientId = clientId,
                UtilisateurId = UtilisateurConnecte,
                Contenu = Restaurant.Ecrire(new Restaurant.Contenu { Lignes = lignes, ClientId = clientId, Remise = remise }),
                Total = total, NbArticles = lignes.Sum(l => l.Qte), Acompte = acompte, AcompteModePaiementId = mode?.Id,
                AcompteOperationId = operation?.Id, Statut = DepotLinge.EnCours
            };
            _context.DepotsLinge.Add(depot);
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return Json(new { id = depot.Id, numero });
        }

        // Dépôt de linge au format de l'écran de vente.
        private static object DepotJson(DepotLinge d)
        {
            var actif = DepotLinge.Actifs.Contains(d.Statut);
            return new
            {
                id = d.Id, numero = d.Numero, nom = d.NomClient, telephone = d.TelephoneClient,
                depose = d.DateDepot.ToString("dd/MM/yyyy HH:mm"),
                retrait = d.DateRetraitPrevue?.ToString("dd/MM/yyyy"),
                enRetard = actif && d.DateRetraitPrevue.HasValue && d.DateRetraitPrevue.Value.Date < DateTime.Today,
                jours = (int)(DateTime.Today - d.DateDepot.Date).TotalDays,
                articles = d.NbArticles, total = d.Total, acompte = d.Acompte, reste = Math.Max(0, d.Total - d.Acompte), statut = d.Statut,
                retire = d.DateRetrait?.ToString("dd/MM/yyyy HH:mm"),
                venteId = d.CommandePosId,
                contenu = actif ? Restaurant.Lire(d.Contenu) : null
            };
        }

        // Dépôts de linge de la société : en cours et prêts, puis retirés ou annulés depuis 30 jours.
        public async Task<IActionResult> Depots(int journee)
        {
            var j = await _context.JourneesCaisses.FirstOrDefaultAsync(x => x.Id == journee);
            if (j == null)
                return Erreur(404, "Journée introuvable.");
            var depuis = DateTime.Today.AddDays(-30);
            var depots = await _context.DepotsLinge.IgnoreQueryFilters()
                .Where(d => d.TenantId == j.TenantId && (DepotLinge.Actifs.Contains(d.Statut) || (d.DateRetrait ?? d.DateAnnulation) >= depuis))
                .OrderByDescending(d => d.Statut == DepotLinge.EnCours || d.Statut == DepotLinge.Pret).ThenByDescending(d => d.Numero)
                .Take(300).ToListAsync();
            return new JsonResult(new { depots = depots.Select(DepotJson) }, Restaurant.Json);
        }

        // Dépôt de linge actif de la société, verrouillé (dans une transaction).
        private async Task<DepotLinge?> DepotActifAsync(int id)
        {
            await _context.Database.ExecuteSqlInterpolatedAsync($"SELECT Id FROM DepotsLinge WITH (UPDLOCK, ROWLOCK) WHERE Id = {id}");
            var d = await _context.DepotsLinge.FirstOrDefaultAsync(x => x.Id == id);
            return d != null && DepotLinge.Actifs.Contains(d.Statut) ? d : null;
        }

        // Linge prêt (client à prévenir), ou remis « En cours ».
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DepotPret([FromForm] string? commande)
        {
            var s = LireDepot(commande);
            await using var transaction = await _context.Database.BeginTransactionAsync();
            var d = s == null ? null : await DepotActifAsync(s.Id);
            if (d == null)
                return Erreur(409, "Ce dépôt a déjà été retiré ou annulé.");
            var pret = d.Statut == DepotLinge.EnCours;
            d.Statut = pret ? DepotLinge.Pret : DepotLinge.EnCours;
            d.DatePret = pret ? DateTime.Now : null;
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return Json(new { statut = d.Statut });
        }

        // Annulation d'un dépôt (administrateurs et utilisateurs autorisés à valider) : l'acompte
        // éventuel est remboursé par un décaissement dans la journée ouverte du poste.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DepotAnnuler([FromForm] string? commande)
        {
            var s = LireDepot(commande);
            if (!PeutRemiseGlobale)
                return Erreur(403, "L'annulation d'un dépôt est réservée aux administrateurs et aux utilisateurs autorisés à valider.");
            var (j, refus) = await JourneeLaverieAsync(s?.JourneeId ?? 0);
            if (j == null)
                return refus!;
            await using var transaction = await _context.Database.BeginTransactionAsync();
            var d = await DepotActifAsync(s!.Id);
            if (d == null)
                return Erreur(409, "Ce dépôt a déjà été retiré ou annulé.");
            if (d.Acompte > 0)
            {
                _context.OperationsCaisses.Add(new OperationCaisse
                {
                    TenantId = d.TenantId, JourneeCaisseId = j.Id, DateOperation = DateTime.Now, TypeOperation = "Décaissement",
                    Montant = d.Acompte, Libelle = $"Remboursement acompte dépôt de linge n° {d.Numero} ({d.NomClient})", ClientId = d.ClientId,
                    MotifId = await MotifLaverieAsync(d.TenantId), ModePaiementId = d.AcompteModePaiementId, UtilisateurId = UtilisateurConnecte,
                    EstJustifie = true, StatutValidation = "Validé", Valideur = "Point de vente"
                });
            }
            d.Statut = DepotLinge.Annule;
            d.DateAnnulation = DateTime.Now;
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return Json(new { ok = true, rembourse = d.Acompte });
        }

        // Ticket de dépôt 80 mm « NON PAYÉ » : exemplaire client et souche jointe au linge.
        public async Task<IActionResult> TicketDepot(int id)
        {
            var d = await _context.DepotsLinge.FirstOrDefaultAsync(x => x.Id == id);
            if (d == null)
                return NotFound();
            var societe = await _context.Tenants.FirstOrDefaultAsync(t => t.Id == d.TenantId);
            ViewBag.Societe = societe?.Nom ?? "GesCaisse";
            ViewBag.Logo = Images.UrlLogo(societe);
            ViewBag.Coordonnees = Images.Coordonnees(societe);
            ViewBag.Utilisateur = d.UtilisateurId.HasValue
                ? (await Restaurant.NomsAsync(_context, new int?[] { d.UtilisateurId })).Values.FirstOrDefault() ?? "" : "";
            ViewBag.ModeAcompte = d.AcompteModePaiementId.HasValue
                ? await _context.ModesPaiement.Where(m => m.Id == d.AcompteModePaiementId).Select(m => m.Libelle).FirstOrDefaultAsync() : null;
            ViewBag.Contenu = Restaurant.Lire(d.Contenu);
            return View(d);
        }
    }
}
