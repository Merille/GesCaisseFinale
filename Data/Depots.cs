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

        // Dépôt d'une caisse : celui choisi sur la caisse, sinon le dépôt par défaut de la société.
        public static async Task<int> DepotCaisseAsync(this AppDbContext context, int caisseId)
        {
            var c = await context.Caisses.IgnoreQueryFilters().AsNoTracking()
                .Where(x => x.ID == caisseId).Select(x => new { x.DepotId, x.TenantId }).FirstOrDefaultAsync();
            if (c?.DepotId != null)
                return c.DepotId.Value;
            return await context.DepotParDefautAsync(c?.TenantId ?? 0);
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
