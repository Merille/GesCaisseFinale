using System.Text.Json;
using System.Text.RegularExpressions;
using EasytransitCaisse.Models;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Data
{
    // Restaurant et bar : plan de salle, commandes ouvertes sur les tables, bons de préparation.
    // Commun au point de vente, à l'éditeur de plan et à l'écran cuisine / bar.
    public static class Restaurant
    {
        public static readonly JsonSerializerOptions Json = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

        // Contenu JSON d'une commande ouverte (même format que les tickets de l'écran de vente).
        public class Contenu
        {
            public List<Ligne> Lignes { get; set; } = new();
            public int? ClientId { get; set; }
            public RemiseTicket? Remise { get; set; }
        }

        public class Ligne
        {
            public string Uid { get; set; } = "";
            public int ProduitId { get; set; }
            public string Nom { get; set; } = "";
            public decimal Qte { get; set; }
            public decimal Prix { get; set; }
            public decimal Remise { get; set; }
            public decimal Tva { get; set; }
            public string? Unite { get; set; }
            public string? Note { get; set; }
            // Quantité déjà envoyée en préparation (toujours reprise de la version enregistrée).
            public decimal Envoye { get; set; }
            // Combo : articles choisis (contrôlés à l'encaissement).
            public List<Combos.Composant> Composants { get; set; } = new();
        }

        public class RemiseTicket
        {
            public string Type { get; set; } = "pct";
            public decimal Valeur { get; set; }
        }

        // La société (toutes en mode « toutes les sociétés », par les filtres de société) a-t-elle une caisse
        // Restaurant ou Bar ? Sinon, les éléments propres au restaurant sont masqués. Comme restaurant_actif() en PHP.
        public static bool Actif(AppDbContext context)
            => context.Caisses.Any(c => c.TypePointVente == "Restaurant" || c.TypePointVente == "Bar");

        public static Contenu Lire(string? json)
        {
            try { return JsonSerializer.Deserialize<Contenu>(json ?? "", Json) ?? new Contenu(); }
            catch (JsonException) { return new Contenu(); }
        }

        public static string Ecrire(Contenu c) => JsonSerializer.Serialize(c, Json);

        // Total TTC (lignes et remises comprises), comme l'écran de vente.
        public static decimal Total(Contenu c)
        {
            var brut = c.Lignes.Sum(l => Math.Round(l.Qte * l.Prix * (1 - Math.Min(100, l.Remise) / 100), MidpointRounding.AwayFromZero));
            var r = c.Remise;
            var remise = r == null || r.Valeur <= 0 || brut <= 0 ? 0
                : r.Type == "pct" ? Math.Round(brut * Math.Min(100, r.Valeur) / 100, MidpointRounding.AwayFromZero)
                : Math.Min(brut, Math.Round(r.Valeur, MidpointRounding.AwayFromZero));
            return brut - remise;
        }

        // Lignes reçues de l'écran de vente, nettoyées ; « envoye » vient de la version enregistrée.
        // envoyeDuPoste : commande prise hors ligne, la quantité annoncée en cuisine depuis le poste est reprise
        // (jamais au-delà de la quantité).
        public static Contenu Nettoyer(Contenu saisi, Contenu avant, bool envoyeDuPoste = false)
        {
            var envoye = avant.Lignes.Where(l => l.Uid != "").GroupBy(l => l.Uid).ToDictionary(g => g.Key, g => g.First().Envoye);
            string Couper(string? s, int max) => (s ?? "").Length > max ? s![..max] : s ?? "";
            var lignes = saisi.Lignes.Take(300)
                .Where(l => !string.IsNullOrEmpty(l.Uid) && l.ProduitId > 0)
                .Select(l =>
                {
                    var uid = Couper(Regex.Replace(l.Uid, "[^A-Za-z0-9-]", ""), 40);
                    return new Ligne
                    {
                        Uid = uid,
                        ProduitId = l.ProduitId,
                        Nom = Couper(l.Nom, 200),
                        Qte = Math.Max(0, Math.Round(l.Qte, 2)),
                        Prix = Math.Max(0, Math.Round(l.Prix, 2)),
                        Remise = Math.Min(100, Math.Max(0, Math.Round(l.Remise, 2))),
                        Tva = l.Tva,
                        Unite = Couper(l.Unite, 20),
                        Note = Couper((l.Note ?? "").Trim(), 200),
                        Envoye = envoyeDuPoste
                            ? Math.Min(Math.Max(0, Math.Round(l.Qte, 2)), Math.Max(envoye.TryGetValue(uid, out var eb) ? eb : 0, Math.Round(l.Envoye, 2)))
                            : envoye.TryGetValue(uid, out var e) ? e : 0,
                        Composants = (l.Composants ?? new()).Take(30).Select(c => new Combos.Composant
                        {
                            ProduitId = c.ProduitId, GroupeId = c.GroupeId, Nom = Couper(c.Nom, 200),
                            Qte = Math.Max(0, Math.Round(c.Qte, 2)), Supplement = Math.Max(0, Math.Round(c.Supplement, 2))
                        }).ToList()
                    };
                }).ToList();
            var remise = saisi.Remise is { Valeur: > 0 } r ? new RemiseTicket { Type = r.Type == "pct" ? "pct" : "montant", Valeur = r.Valeur } : null;
            return new Contenu { Lignes = lignes, ClientId = saisi.ClientId, Remise = remise };
        }

        // Salles et tables actives d'une caisse ; avec la journée : état de chaque table.
        public static async Task<object> PlanAsync(AppDbContext context, int caisseId, bool avecCommandes)
        {
            var salles = await context.Salles.IgnoreQueryFilters().Where(s => s.CaisseId == caisseId)
                .OrderBy(s => s.Ordre).ThenBy(s => s.Id).ToListAsync();
            var ids = salles.Select(s => s.Id).ToList();
            var tables = await context.TablesRestaurant.IgnoreQueryFilters().Where(t => ids.Contains(t.SalleId) && t.Actif)
                .OrderBy(t => t.Id).ToListAsync();
            var commandes = new Dictionary<int, object>();
            if (avecCommandes)
            {
                var ouvertes = await context.CommandesOuvertes.IgnoreQueryFilters()
                    .Where(c => c.CaisseId == caisseId && c.TableId != null).ToListAsync();
                var serveurs = await NomsAsync(context, ouvertes.Select(c => c.UtilisateurId));
                foreach (var c in ouvertes)
                    commandes[c.TableId!.Value] = Resume(c, c.UtilisateurId is int u && serveurs.TryGetValue(u, out var n) ? n : null);
            }
            return salles.Select(s => new
            {
                id = s.Id,
                nom = s.Nom,
                tables = tables.Where(t => t.SalleId == s.Id).Select(t => new
                {
                    id = t.Id, nom = t.Nom, places = t.Places, forme = t.Forme,
                    x = t.PosX, y = t.PosY, l = t.Largeur, h = t.Hauteur,
                    commande = avecCommandes ? (commandes.TryGetValue(t.Id, out var c) ? c : null) : null
                }).ToList()
            }).ToList();
        }

        public static async Task<Dictionary<int, string>> NomsAsync(AppDbContext context, IEnumerable<int?> ids)
        {
            var liste = ids.Where(i => i != null).Select(i => i!.Value).Distinct().ToList();
            return await context.Utilisateurs.IgnoreQueryFilters().Where(u => liste.Contains(u.Id))
                .ToDictionaryAsync(u => u.Id, u => u.NomComplet ?? u.NomUtilisateur);
        }

        // Résumé d'une commande ouverte pour le plan de salle.
        public static object Resume(CommandeOuverte c, string? serveur)
        {
            var contenu = Lire(c.Contenu);
            return new
            {
                id = c.Id, version = c.Version, couverts = c.Couverts, total = Total(contenu), articles = contenu.Lignes.Count,
                addition = c.AdditionImprimee, aEnvoyer = contenu.Lignes.Any(l => l.Qte - l.Envoye > 0),
                serveur, depuis = c.DateOuverture,
                // Détail de la commande : la table peut être reprise hors ligne sur un autre poste.
                lignes = contenu.Lignes, clientId = contenu.ClientId, remise = contenu.Remise
            };
        }

        // Commande ouverte complète, telle que l'écran de vente la manipule.
        public static object CommandeJson(CommandeOuverte c)
        {
            var contenu = Lire(c.Contenu);
            return new
            {
                id = c.Id, version = c.Version, tableId = c.TableId, couverts = c.Couverts, addition = c.AdditionImprimee,
                lignes = contenu.Lignes, clientId = contenu.ClientId, remise = contenu.Remise
            };
        }

        // Bons de préparation des articles pas encore envoyés (et des annulations) : un bon par
        // poste. Met à jour « envoye » dans le contenu ; les bons sont ajoutés au contexte.
        public static async Task<List<BonPreparation>> EnvoyerAsync(AppDbContext context, CommandeOuverte co, Contenu contenu, Contenu avant,
            string tableNom, string serveur)
        {
            var produitIds = contenu.Lignes.Concat(avant.Lignes)
                .SelectMany(l => l.Composants.Select(c => c.ProduitId).Append(l.ProduitId)).Distinct().ToList();
            var postes = await (from p in context.Produits.IgnoreQueryFilters()
                                join cat in context.Categories.IgnoreQueryFilters() on p.CategorieId equals cat.Id into cats
                                from cat in cats.DefaultIfEmpty()
                                where produitIds.Contains(p.Id)
                                select new { p.Id, Poste = cat != null ? cat.Preparation : "Cuisine" })
                .ToDictionaryAsync(x => x.Id, x => x.Poste);
            string Poste(int id) => postes.TryGetValue(id, out var p) ? p : "Cuisine";

            var parPoste = new Dictionary<string, List<LigneBonPreparation>>();
            // Un combo part en préparation article par article, chacun vers son poste.
            void Ajouter(Ligne ligne, decimal qte, string? note)
            {
                var articles = ligne.Composants.Any()
                    ? ligne.Composants.Select(c => (c.ProduitId, Libelle: $"{c.Nom} ({ligne.Nom})", Qte: qte * c.Qte))
                    : new[] { (ligne.ProduitId, Libelle: ligne.Nom, Qte: qte) };
                foreach (var (id, libelle, q) in articles)
                {
                    var poste = Poste(id);
                    if (poste == "Aucun") continue;
                    if (!parPoste.TryGetValue(poste, out var l)) parPoste[poste] = l = new();
                    l.Add(new LigneBonPreparation { Libelle = libelle.Length > 200 ? libelle[..200] : libelle, Quantite = q, Note = string.IsNullOrEmpty(note) ? null : note });
                }
            }
            foreach (var l in contenu.Lignes)
            {
                var delta = Math.Round(l.Qte - l.Envoye, 2);
                if (Math.Abs(delta) >= 0.01m)
                    Ajouter(l, delta, l.Note);
                l.Envoye = l.Qte;
            }
            // Lignes supprimées après l'envoi : annulation.
            var actuelles = contenu.Lignes.Select(l => l.Uid).ToHashSet();
            foreach (var l in avant.Lignes.Where(l => !actuelles.Contains(l.Uid) && l.Envoye > 0))
                Ajouter(l, -l.Envoye, null);

            var bons = new List<BonPreparation>();
            var numero = await context.BonsPreparation.IgnoreQueryFilters().CountAsync(b => b.JourneeCaisseId == co.JourneeCaisseId);
            foreach (var (poste, lignes) in parPoste)
            {
                var bon = new BonPreparation
                {
                    TenantId = co.TenantId, CaisseId = co.CaisseId, JourneeCaisseId = co.JourneeCaisseId,
                    CommandeOuverteId = co.Id == 0 ? null : co.Id, Numero = ++numero, Poste = poste, TableNom = tableNom,
                    Couverts = co.Couverts, Serveur = serveur, DateEnvoi = DateTime.Now, Lignes = lignes
                };
                context.BonsPreparation.Add(bon);
                bons.Add(bon);
            }
            return bons;
        }
    }
}
