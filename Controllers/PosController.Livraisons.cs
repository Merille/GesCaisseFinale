using System.Security.Claims;
using System.Text.Json;
using EasytransitCaisse.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Point de vente : commandes mises en attente (gardées sur le serveur, visibles depuis tous les
    // postes de la journée) et commandes à livrer (livreur, destinataire, payées maintenant ou à la
    // livraison). Même fonctionnement que la version PHP (php/app/controllers/pos.php).
    public partial class PosController
    {
        private static readonly JsonSerializerOptions JsonAttente = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true
        };

        private sealed class LivraisonSaisie
        {
            public int? LivreurId { get; set; }
            public string? Nom { get; set; }
            public string? Telephone { get; set; }
            public string? Adresse { get; set; }
            // « maintenant » : vente payée à la commande, livrée ensuite ; « livraison » : encaissée au retour du livreur.
            public string? Paiement { get; set; }
            // Frais de livraison (en plus du total, hors taxes).
            public decimal Frais { get; set; }
        }

        private sealed class AttenteLigne
        {
            public string? Uid { get; set; }
            public int ProduitId { get; set; }
            public string? Nom { get; set; }
            public decimal Qte { get; set; }
            public decimal Prix { get; set; }
            public decimal Remise { get; set; }
            public decimal Tva { get; set; }
            public string? Unite { get; set; }
            public string? Note { get; set; }
            public JsonElement? Composants { get; set; }
        }

        private sealed class AttenteSaisie
        {
            public int JourneeId { get; set; }
            public int Id { get; set; }
            public List<AttenteLigne> Lignes { get; set; } = new();
            public int? ClientId { get; set; }
            public RemiseSaisie? Remise { get; set; }
            public LivraisonSaisie? Livraison { get; set; }
        }

        private static string? Texte(string? valeur, int max)
        {
            var t = (valeur ?? "").Trim();
            return t == "" ? null : t.Length > max ? t[..max] : t;
        }

        // Livraison saisie : livreur actif de la société et adresse obligatoires.
        private async Task<(LivraisonSaisie? Livraison, string? Erreur)> ControlerLivraisonAsync(LivraisonSaisie? l, int tenant)
        {
            if (l == null)
                return (null, null);
            if (!l.LivreurId.HasValue || !await _context.Livreurs.AnyAsync(x => x.Id == l.LivreurId && x.TenantId == tenant && x.Actif))
                return (null, "Choisissez un livreur actif pour la livraison.");
            var adresse = Texte(l.Adresse, 200);
            if (adresse == null)
                return (null, "Indiquez l'adresse de livraison.");
            return (new LivraisonSaisie
            {
                LivreurId = l.LivreurId, Nom = Texte(l.Nom, 100), Telephone = Texte(l.Telephone, 30), Adresse = adresse,
                Paiement = l.Paiement == "livraison" ? "livraison" : "maintenant",
                Frais = Math.Max(0, Math.Round(l.Frais, 0, MidpointRounding.AwayFromZero))
            }, null);
        }

        private static AttenteSaisie? LireAttente(string? json)
        {
            try { return JsonSerializer.Deserialize<AttenteSaisie>(json ?? "", JsonAttente); }
            catch (JsonException) { return null; }
        }

        private int UtilisateurConnecte => int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id) ? id : 0;

        // Liste du bouton « Commandes en attente » : commandes en attente de la journée et ventes payées
        // qui restent à livrer.
        public async Task<IActionResult> Attentes(int journee)
        {
            var j = await _context.JourneesCaisses.FirstOrDefaultAsync(x => x.Id == journee);
            if (j == null)
                return Erreur(404, "Journée introuvable.");
            var livreurs = await _context.Livreurs.IgnoreQueryFilters().Where(l => l.TenantId == j.TenantId)
                .ToDictionaryAsync(l => l.Id);
            var clients = await _context.Clients.IgnoreQueryFilters().Where(c => c.TenantId == j.TenantId)
                .ToDictionaryAsync(c => c.Id, c => c.NomSociete);
            var utilisateurs = await _context.Utilisateurs.IgnoreQueryFilters()
                .ToDictionaryAsync(u => u.Id, u => u.NomComplet);
            var attentes = (await _context.CommandesAttente.Where(c => c.JourneeCaisseId == j.Id)
                    .OrderBy(c => c.Numero).ToListAsync())
                .Select(c => new
                {
                    id = c.Id, numero = c.Numero, heure = c.DateCreation.ToString("HH:mm"),
                    client = c.ClientId.HasValue ? clients.GetValueOrDefault(c.ClientId.Value) : null,
                    articles = c.NbArticles, total = c.Total, utilisateur = utilisateurs.GetValueOrDefault(c.UtilisateurId),
                    livraison = c.LivreurId.HasValue || c.AdresseLivraison != null
                        ? new
                        {
                            livreur = c.LivreurId.HasValue ? livreurs.GetValueOrDefault(c.LivreurId.Value)?.Nom : null,
                            moyen = c.LivreurId.HasValue ? livreurs.GetValueOrDefault(c.LivreurId.Value)?.MoyenLivraison : null,
                            nom = c.NomLivraison, telephone = c.TelephoneLivraison, adresse = c.AdresseLivraison
                        }
                        : null
                });
            var livraisons = (await _context.CommandesPos
                    .Where(c => c.JourneeCaisseId == j.Id && c.StatutLivraison == "À livrer")
                    .OrderBy(c => c.DateCommande).ToListAsync())
                .Select(c => new
                {
                    id = c.Id, numero = c.Numero, heure = c.DateCommande.ToString("HH:mm"),
                    client = c.ClientId.HasValue ? clients.GetValueOrDefault(c.ClientId.Value) : null,
                    total = c.TotalTTC + c.FraisLivraison,
                    livreur = c.LivreurId.HasValue ? livreurs.GetValueOrDefault(c.LivreurId.Value)?.Nom : null,
                    moyen = c.LivreurId.HasValue ? livreurs.GetValueOrDefault(c.LivreurId.Value)?.MoyenLivraison : null,
                    nom = c.NomLivraison, telephone = c.TelephoneLivraison, adresse = c.AdresseLivraison
                });
            return Json(new { attentes, livraisons });
        }

        // « Mettre en attente » : le ticket est enregistré sur le serveur (avec sa livraison s'il est à
        // encaisser à la livraison) et quitte l'écran ; il se reprend depuis n'importe quel poste.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> MettreEnAttente([FromForm] string? commande)
        {
            var s = LireAttente(commande);
            if (s == null)
                return Erreur(400, "Commande illisible.");
            var j = await _context.JourneesCaisses.FirstOrDefaultAsync(x => x.Id == s.JourneeId);
            if (j == null)
                return Erreur(404, "Journée introuvable.");
            if (j.Statut != "Ouverte")
                return Erreur(409, "Cette journée est clôturée : la commande ne peut pas être mise en attente.");
            var tenant = j.TenantId;

            // Lignes : produits actifs de la société ; nom, taux et unité repris du catalogue.
            var ids = s.Lignes.Select(l => l.ProduitId).Distinct().ToList();
            var catalogue = await _context.Produits.IgnoreQueryFilters()
                .Where(p => ids.Contains(p.Id) && p.TenantId == tenant && p.Actif).ToDictionaryAsync(p => p.Id);
            var lignes = new List<AttenteLigne>();
            foreach (var l in s.Lignes)
            {
                var qte = Math.Round(l.Qte, 2);
                if (!catalogue.TryGetValue(l.ProduitId, out var p) || qte <= 0)
                    continue;
                lignes.Add(new AttenteLigne
                {
                    Uid = Texte(l.Uid, 60) ?? Guid.NewGuid().ToString("N"), ProduitId = p.Id, Nom = Texte(l.Nom, 250) ?? p.Nom,
                    Qte = qte, Prix = Math.Max(0, Math.Round(l.Prix, 2)), Remise = Math.Min(100, Math.Max(0, Math.Round(l.Remise, 2))),
                    Tva = p.TauxTVA, Unite = p.Unite, Note = Texte(l.Note, 200) ?? "", Composants = l.Composants
                });
            }
            if (!lignes.Any())
                return Erreur(400, "Le ticket est vide.");
            int? clientId = s.ClientId.HasValue && await _context.Clients.AnyAsync(c => c.Id == s.ClientId && c.TenantId == tenant) ? s.ClientId : null;
            var (livraison, erreur) = await ControlerLivraisonAsync(s.Livraison, tenant);
            if (erreur != null)
                return Erreur(400, erreur);
            var remise = s.Remise != null && s.Remise.Valeur > 0 && PeutRemiseGlobale
                ? new RemiseSaisie { Type = s.Remise.Type == "pct" ? "pct" : "montant", Valeur = s.Remise.Valeur } : null;

            // Total affiché dans la liste (même calcul que l'écran de vente).
            decimal brut = lignes.Sum(l => Math.Round(l.Qte * l.Prix * (1 - l.Remise / 100), 0, MidpointRounding.AwayFromZero));
            decimal montantRemise = remise == null || brut <= 0 ? 0
                : remise.Type == "pct" ? Math.Round(brut * Math.Min(100, remise.Valeur) / 100, 0, MidpointRounding.AwayFromZero)
                : Math.Min(brut, Math.Round(remise.Valeur, 0, MidpointRounding.AwayFromZero));

            await using var transaction = await _context.Database.BeginTransactionAsync();
            await _context.Database.ExecuteSqlInterpolatedAsync($"SELECT Id FROM JourneesCaisses WITH (UPDLOCK, HOLDLOCK) WHERE Id = {j.Id}");
            var numero = (await _context.CommandesAttente.IgnoreQueryFilters().Where(c => c.JourneeCaisseId == j.Id)
                .MaxAsync(c => (int?)c.Numero) ?? 0) + 1;
            var attente = new CommandeAttente
            {
                TenantId = tenant, JourneeCaisseId = j.Id, Numero = numero, DateCreation = DateTime.Now,
                UtilisateurId = UtilisateurConnecte, ClientId = clientId,
                Contenu = JsonSerializer.Serialize(new AttenteSaisie { Lignes = lignes, ClientId = clientId, Remise = remise, Livraison = livraison }, JsonAttente),
                Total = brut - montantRemise + (livraison?.Frais ?? 0), NbArticles = lignes.Count,
                LivreurId = livraison?.LivreurId, NomLivraison = livraison?.Nom,
                TelephoneLivraison = livraison?.Telephone, AdresseLivraison = livraison?.Adresse
            };
            _context.CommandesAttente.Add(attente);
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return Json(new { id = attente.Id, numero });
        }

        // Reprise d'une commande en attente : elle est retirée de la liste (sous verrou : un seul poste la
        // reprend) et son contenu revient à l'écran de vente.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Reprendre([FromForm] string? commande)
        {
            var s = LireAttente(commande);
            await using var transaction = await _context.Database.BeginTransactionAsync();
            var c = s == null ? null : await _context.CommandesAttente
                .FromSqlInterpolated($"SELECT * FROM CommandesAttente WITH (UPDLOCK, ROWLOCK) WHERE Id = {s.Id}").FirstOrDefaultAsync();
            if (c == null)
                return Erreur(404, "Cette commande a déjà été reprise ou supprimée sur un autre poste.");
            var j = await _context.JourneesCaisses.FirstOrDefaultAsync(x => x.Id == c.JourneeCaisseId);
            if (j == null || j.Statut != "Ouverte")
                return Erreur(409, "Cette journée est clôturée.");
            _context.CommandesAttente.Remove(c);
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            using var doc = JsonDocument.Parse(c.Contenu);
            return Json(new { numero = c.Numero, contenu = doc.RootElement.Clone() });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> SupprimerAttente([FromForm] string? commande)
        {
            var s = LireAttente(commande);
            var c = s == null ? null : await _context.CommandesAttente.FirstOrDefaultAsync(x => x.Id == s.Id);
            if (c == null)
                return Erreur(404, "Cette commande a déjà été reprise ou supprimée sur un autre poste.");
            _context.CommandesAttente.Remove(c);
            await _context.SaveChangesAsync();
            return Json(new { ok = true });
        }

        // Vente payée à la commande, livrée ensuite : le retour du livreur la marque « Livrée ».
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Livree([FromForm] string? commande)
        {
            var s = LireAttente(commande);
            var c = s == null ? null : await _context.CommandesPos.FirstOrDefaultAsync(x => x.Id == s.Id);
            if (c == null || c.StatutLivraison == null)
                return Erreur(404, "Livraison introuvable.");
            if (c.StatutLivraison != "Livrée")
            {
                c.StatutLivraison = "Livrée";
                c.DateLivraison = DateTime.Now;
                await _context.SaveChangesAsync();
            }
            return Json(new { ok = true });
        }
    }
}
