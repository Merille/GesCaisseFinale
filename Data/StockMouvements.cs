using EasytransitCaisse.Models;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Data
{
    public static class StockMouvements
    {
        // Mouvement de stock d'un produit suivi dans un dépôt (dépôt par défaut de la société si non
        // précisé) : mise à jour atomique du stock du dépôt et du stock total du produit, puis ajout
        // du mouvement à l'historique (enregistré au prochain SaveChanges ; « stock après » = stock du
        // dépôt). Sans effet pour un produit dont le stock n'est pas suivi. À appeler dans la
        // transaction de l'opération.
        public static async Task MouvementAsync(this AppDbContext context, int produitId, decimal quantite, string type,
            string? reference = null, int? commandeId = null, int? utilisateurId = null, string? commentaire = null,
            int? depotId = null)
        {
            if (Math.Abs(quantite) < 0.0001m)
                return;
            var p = await context.Produits.IgnoreQueryFilters().AsNoTracking()
                .Where(x => x.Id == produitId).Select(x => new { x.TenantId, x.SuiviStock }).FirstOrDefaultAsync();
            if (p == null || !p.SuiviStock)
                return;

            var depot = depotId ?? await context.DepotParDefautAsync(p.TenantId);
            await context.Database.ExecuteSqlInterpolatedAsync(
                $"UPDATE Produits SET StockActuel = StockActuel + {quantite} WHERE Id = {produitId}");
            await context.Database.ExecuteSqlInterpolatedAsync($@"
                UPDATE StocksDepots SET Quantite = Quantite + {quantite} WHERE DepotId = {depot} AND ProduitId = {produitId};
                IF @@ROWCOUNT = 0 INSERT INTO StocksDepots (DepotId, ProduitId, Quantite) VALUES ({depot}, {produitId}, {quantite});");
            var total = await context.Produits.IgnoreQueryFilters().AsNoTracking()
                .Where(x => x.Id == produitId).Select(x => x.StockActuel).FirstAsync();
            var stockApres = await context.StockDepotAsync(produitId, depot);

            // Produit déjà chargé dans le contexte : on aligne sa valeur pour ne pas l'écraser.
            var suivi = context.ChangeTracker.Entries<Produit>().FirstOrDefault(e => e.Entity.Id == produitId);
            if (suivi != null)
            {
                suivi.Entity.StockActuel = total;
                suivi.Property(x => x.StockActuel).OriginalValue = total;
            }

            context.MouvementsStock.Add(new MouvementStock
            {
                TenantId = p.TenantId, ProduitId = produitId, DepotId = depot, DateMouvement = DateTime.Now, TypeMouvement = type,
                Quantite = quantite, StockApres = stockApres, Reference = reference, CommandePosId = commandeId,
                UtilisateurId = utilisateurId, Commentaire = commentaire
            });
        }
    }
}
