using System.Text.Json;
using EasytransitCaisse.Models;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Data
{
    // Combos (menus, formules) : groupes de choix d'un produit combo, contrôle des composants choisis
    // à la vente, stock des composants. Commun au point de vente, à la fiche produit et aux retours.
    public static class Combos
    {
        // Composant d'un combo vendu (JSON de LignesCommandePos.Composants).
        public class Composant
        {
            public int ProduitId { get; set; }
            public int GroupeId { get; set; }
            public string Nom { get; set; } = "";
            public decimal Qte { get; set; } = 1;
            public decimal Supplement { get; set; }
            public string? Groupe { get; set; }
        }

        // Combos qui composent chaque produit combo d'une société (dans l'ordre), par produit.
        public static async Task<Dictionary<int, List<Combo>>> SocieteAsync(AppDbContext context, int tenantId)
        {
            var combos = await context.Combos.IgnoreQueryFilters().Include(c => c.Choix)
                .Where(c => c.TenantId == tenantId).ToDictionaryAsync(c => c.Id);
            var liens = await (from pc in context.ProduitCombos
                               join p in context.Produits.IgnoreQueryFilters() on pc.ProduitId equals p.Id
                               where p.TenantId == tenantId
                               orderby pc.Ordre
                               select pc).ToListAsync();
            return liens.Where(l => combos.ContainsKey(l.ComboId)).GroupBy(l => l.ProduitId)
                .ToDictionary(g => g.Key, g => g.Select(l => combos[l.ComboId]).ToList());
        }

        // Composants choisis pour un combo, contrôlés : chaque groupe doit avoir exactement le nombre
        // d'articles prévu, parmi ses produits proposés. Renvoie les composants et le total des
        // suppléments, ou un message d'erreur.
        public static async Task<(List<Composant>? Composants, decimal Supplements, string? Erreur)> ControlerAsync(
            AppDbContext context, Produit combo, IEnumerable<Composant> saisis)
        {
            var groupes = (await SocieteAsync(context, combo.TenantId)).GetValueOrDefault(combo.Id) ?? new();
            if (!groupes.Any())
                return (null, 0, $"Le produit « {combo.Nom} » n'est plus composé d'aucun combo.");
            var liste = saisis.ToList();
            var composants = new List<Composant>();
            decimal supplements = 0;
            foreach (var g in groupes)
            {
                decimal total = 0;
                foreach (var s in liste.Where(s => s.GroupeId == g.Id))
                {
                    var qte = Math.Max(0, Math.Round(s.Qte, 2));
                    var choix = g.Choix.FirstOrDefault(c => c.ProduitId == s.ProduitId);
                    var p = qte > 0 && choix != null
                        ? await context.Produits.IgnoreQueryFilters().FirstOrDefaultAsync(x => x.Id == s.ProduitId && x.TenantId == combo.TenantId && x.Actif)
                        : null;
                    if (p == null || choix == null)
                        return (null, 0, $"Un article choisi pour « {combo.Nom} › {g.Nom} » n'est pas proposé ou n'est plus actif.");
                    composants.Add(new Composant { ProduitId = p.Id, GroupeId = g.Id, Nom = p.Nom, Qte = qte, Supplement = choix.Supplement, Groupe = g.Nom });
                    supplements += qte * choix.Supplement;
                    total += qte;
                }
                if (Math.Abs(total - g.Quantite) > 0.001m)
                    return (null, 0, $"Choisissez {g.Quantite} article(s) dans « {combo.Nom} › {g.Nom} ».");
            }
            return (composants, supplements, null);
        }

        public static string Ecrire(List<Composant> c) => JsonSerializer.Serialize(c, Restaurant.Json);

        public static List<Composant> Lire(string? json)
        {
            if (string.IsNullOrEmpty(json))
                return new();
            try { return JsonSerializer.Deserialize<List<Composant>>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new(); }
            catch (JsonException) { return new(); }
        }

        // Mouvement de stock d'une ligne vendue (dans le dépôt donné) : le produit, ou les composants d'un combo.
        public static async Task MouvementLigneAsync(this AppDbContext context, int produitId, string? composants, decimal quantite, string type,
            string? reference, int? commandeId, int? utilisateurId, string? commentaire = null, int? depotId = null)
        {
            var liste = Lire(composants);
            if (!liste.Any())
            {
                await context.MouvementAsync(produitId, quantite, type, reference, commandeId, utilisateurId, commentaire, depotId);
                return;
            }
            foreach (var c in liste)
                await context.MouvementAsync(c.ProduitId, quantite * c.Qte, type, reference, commandeId, utilisateurId, commentaire, depotId);
        }

        // Sortie de stock d'une ligne vendue, répartie entre les dépôts de la caisse : le produit, ou les composants d'un combo.
        public static async Task LigneSortieStockAsync(this AppDbContext context, int produitId, string? composants, decimal quantite,
            string? reference, int? commandeId, int? utilisateurId, List<int> depots)
        {
            var liste = Lire(composants);
            if (!liste.Any())
            {
                await context.SortieStockCaisseAsync(produitId, quantite, "Vente", reference, commandeId, utilisateurId, depots);
                return;
            }
            foreach (var c in liste)
                await context.SortieStockCaisseAsync(c.ProduitId, quantite * c.Qte, "Vente", reference, commandeId, utilisateurId, depots);
        }
    }
}
