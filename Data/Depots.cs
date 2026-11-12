using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Data
{
    // Dépôts de stockage : dépôt par défaut d'une société, dépôt d'une caisse, stock d'un produit dans un dépôt.
    // Même fonctionnement que la version PHP (depot_par_defaut, depot_caisse, stock_depot).
    public static class Depots
    {
        // Dépôt par défaut de la société : reçoit le stock initial des produits et sert aux caisses sans
        // dépôt choisi. Créé (« Dépôt principal ») s'il n'existe pas encore, par exemple pour une nouvelle société.
        public static async Task<int> DepotParDefautAsync(this AppDbContext context, int tenantId)
        {
            var depot = await context.Depots.IgnoreQueryFilters().AsNoTracking()
                .Where(d => d.TenantId == tenantId)
                .OrderByDescending(d => d.ParDefaut).ThenBy(d => d.Id)
                .Select(d => new { d.Id, d.ParDefaut }).FirstOrDefaultAsync();
            if (depot != null)
            {
                if (!depot.ParDefaut)
                    await context.Database.ExecuteSqlInterpolatedAsync($"UPDATE Depots SET ParDefaut = 1 WHERE Id = {depot.Id}");
                return depot.Id;
            }
            // Requête directe : n'enregistre pas les autres modifications en attente du contexte.
            var ids = await context.Database.SqlQuery<int>($@"INSERT INTO Depots (TenantId, Code, Nom, Actif, ParDefaut)
                OUTPUT INSERTED.Id AS Value VALUES ({tenantId}, 'DEP01', N'Dépôt principal', 1, 1)").ToListAsync();
            return ids.First();
        }

        // Dépôt des achats de la société (laverie : « Magasin des produits d'entretien ») : les achats y
        // entrent et les consommations en sortent ; il ne sert à aucune caisse. Créé (ACH01…) au besoin,
        // réactivé s'il avait été désactivé. Comme depot_des_achats() en PHP.
        public static async Task<Models.Depot> DepotDesAchatsAsync(this AppDbContext context, int tenantId)
        {
            var depot = await context.Depots.IgnoreQueryFilters().AsNoTracking()
                .Where(d => d.TenantId == tenantId && d.DepotAchats).OrderBy(d => d.Id).FirstOrDefaultAsync();
            if (depot != null)
            {
                if (!depot.Actif)
                {
                    await context.Database.ExecuteSqlInterpolatedAsync($"UPDATE Depots SET Actif = 1 WHERE Id = {depot.Id}");
                    depot.Actif = true;
                }
                return depot;
            }
            await context.DepotParDefautAsync(tenantId);
            var codes = await context.Depots.IgnoreQueryFilters().Where(d => d.TenantId == tenantId).Select(d => d.Code).ToListAsync();
            var n = 1;
            while (codes.Contains($"ACH{n:D2}"))
                n++;
            var code = $"ACH{n:D2}";
            var ids = await context.Database.SqlQuery<int>($@"INSERT INTO Depots (TenantId, Code, Nom, Actif, ParDefaut, DepotAchats)
                OUTPUT INSERTED.Id AS Value VALUES ({tenantId}, {code}, N'Magasin des produits d''entretien', 1, 0, 1)").ToListAsync();
            return await context.Depots.IgnoreQueryFilters().AsNoTracking().FirstAsync(d => d.Id == ids.First());
        }

        // Dépôt d'une caisse : celui choisi sur la caisse, sinon le dépôt par défaut de la société.
        public static async Task<int> DepotCaisseAsync(this AppDbContext context, int caisseId)
        {
            var c = await context.Caisses.IgnoreQueryFilters().AsNoTracking()
                .Where(x => x.ID == caisseId).Select(x => new { x.DepotId, x.TenantId }).FirstOrDefaultAsync();
            if (c?.DepotId != null)
                return c.DepotId.Value;
            return await context.DepotParDefautAsync(c?.TenantId ?? 0);
        }

        // Dépôts où vend une caisse : son dépôt principal, puis ses dépôts secondaires actifs dans l'ordre
        // choisi (complément quand le stock du principal ne suffit pas). Comme depots_caisse() en PHP.
        public static async Task<List<int>> DepotsCaisseAsync(this AppDbContext context, int caisseId)
        {
            var principal = await context.DepotCaisseAsync(caisseId);
            var secondaires = await (from cd in context.CaissesDepots
                                     join d in context.Depots.IgnoreQueryFilters() on cd.DepotId equals d.Id
                                     where cd.CaisseId == caisseId && d.Actif && cd.DepotId != principal
                                     orderby cd.Ordre, cd.DepotId
                                     select cd.DepotId).ToListAsync();
            return new List<int> { principal }.Concat(secondaires).ToList();
        }

        // Stock disponible d'un produit pour une caisse : total de ses dépôts (principal et secondaires).
        public static async Task<decimal> StockCaisseAsync(this AppDbContext context, int produitId, List<int> depots)
        {
            return await context.StocksDepots.AsNoTracking()
                .Where(s => s.ProduitId == produitId && depots.Contains(s.DepotId))
                .SumAsync(s => (decimal?)s.Quantite) ?? 0;
        }

        // Sortie de stock d'une vente (quantité positive) répartie entre les dépôts de la caisse : le dépôt
        // principal d'abord, puis les secondaires dans l'ordre, chacun à hauteur de son stock ; ce qui manque
        // encore (vente sans stock autorisée) sort du principal. Un mouvement par dépôt utilisé.
        public static async Task SortieStockCaisseAsync(this AppDbContext context, int produitId, decimal quantite, string type,
            string? reference, int? commandeId, int? utilisateurId, List<int> depots)
        {
            var suivi = await context.Produits.IgnoreQueryFilters().AsNoTracking()
                .Where(p => p.Id == produitId).Select(p => (bool?)p.SuiviStock).FirstOrDefaultAsync();
            if (suivi != true || quantite < 0.0001m)
                return;
            var parts = new Dictionary<int, decimal>();
            var reste = quantite;
            foreach (var depot in depots)
            {
                if (reste < 0.0001m)
                    break;
                var prend = Math.Min(reste, Math.Max(0, await context.StockDepotAsync(produitId, depot)));
                if (prend >= 0.0001m)
                {
                    parts[depot] = prend;
                    reste -= prend;
                }
            }
            if (reste >= 0.0001m)
                parts[depots[0]] = parts.GetValueOrDefault(depots[0]) + reste;
            foreach (var (depot, q) in parts)
                await context.MouvementAsync(produitId, -q, type, reference, commandeId, utilisateurId, null, depot);
        }

        // Annulation d'une vente : chaque quantité sortie revient dans le dépôt d'où elle est sortie
        // (d'après les mouvements « Vente » de la vente).
        public static async Task RemiseStockAnnulationAsync(this AppDbContext context, int commandeId, string reference,
            int? utilisateurId, string? commentaire)
        {
            var sorties = await context.MouvementsStock.IgnoreQueryFilters().AsNoTracking()
                .Where(m => m.CommandePosId == commandeId && m.TypeMouvement == "Vente")
                .GroupBy(m => new { m.ProduitId, m.DepotId })
                .Select(g => new { g.Key.ProduitId, g.Key.DepotId, Q = g.Sum(m => m.Quantite) })
                .ToListAsync();
            foreach (var m in sorties.OrderBy(m => m.ProduitId).ThenBy(m => m.DepotId))
                await context.MouvementAsync(m.ProduitId, -m.Q, "Annulation", reference, commandeId, utilisateurId, commentaire, m.DepotId);
        }

        // Quantité d'un produit dans un dépôt.
        public static async Task<decimal> StockDepotAsync(this AppDbContext context, int produitId, int depotId)
        {
            return await context.StocksDepots.AsNoTracking()
                .Where(s => s.DepotId == depotId && s.ProduitId == produitId)
                .Select(s => (decimal?)s.Quantite).FirstOrDefaultAsync() ?? 0;
        }
    }
}
