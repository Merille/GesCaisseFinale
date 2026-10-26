using EasytransitCaisse.Models;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Data
{
    public static class StockMouvements
    {
        // Mouvement de stock d'un produit suivi : mise à jour atomique du stock en base
        // puis ajout du mouvement à l'historique (enregistré au prochain SaveChanges).
        // Sans effet pour un produit dont le stock n'est pas suivi. À appeler dans la
        // transaction de l'opération.
        public static async Task MouvementAsync(this AppDbContext context, int produitId, decimal quantite, string type,
            string? reference = null, int? commandeId = null, int? utilisateurId = null, string? commentaire = null)
        {
            if (Math.Abs(quantite) < 0.0001m)
                return;
            var p = await context.Produits.IgnoreQueryFilters().AsNoTracking()
                .Where(x => x.Id == produitId).Select(x => new { x.TenantId, x.SuiviStock }).FirstOrDefaultAsync();
            if (p == null || !p.SuiviStock)
                return;

            await context.Database.ExecuteSqlInterpolatedAsync(
                $"UPDATE Produits SET StockActuel = StockActuel + {quantite} WHERE Id = {produitId}");
            var stockApres = await context.Produits.IgnoreQueryFilters().AsNoTracking()
                .Where(x => x.Id == produitId).Select(x => x.StockActuel).FirstAsync();

            // Produit déjà chargé dans le contexte : on aligne sa valeur pour ne pas l'écraser.
            var suivi = context.ChangeTracker.Entries<Produit>().FirstOrDefault(e => e.Entity.Id == produitId);
            if (suivi != null)
            {
                suivi.Entity.StockActuel = stockApres;
                suivi.Property(x => x.StockActuel).OriginalValue = stockApres;
            }

            context.MouvementsStock.Add(new MouvementStock
            {
                TenantId = p.TenantId, ProduitId = produitId, DateMouvement = DateTime.Now, TypeMouvement = type,
                Quantite = quantite, StockApres = stockApres, Reference = reference, CommandePosId = commandeId,
                UtilisateurId = utilisateurId, Commentaire = commentaire
            });
        }
    }
}
