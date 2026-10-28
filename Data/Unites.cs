using EasytransitCaisse.Models;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Data
{
    public static class Unites
    {
        // Unités de départ d'une nouvelle société (nom affiché sur le ticket, libellé).
        public static readonly (string Nom, string Libelle)[] Initiales =
        {
            ("Unité", "Article vendu à l'unité"), ("Pièce", "Pièce"), ("Kg", "Kilogramme"), ("g", "Gramme"), ("Litre", "Litre"),
            ("cl", "Centilitre"), ("Mètre", "Mètre"), ("Carton", "Carton"), ("Paquet", "Paquet"), ("Boîte", "Boîte"), ("Sac", "Sac"),
            ("Bouteille", "Bouteille"), ("Page", "Page (impression, photocopie)"), ("Heure", "Heure (service)")
        };

        public static void AjouterUnitesInitiales(this AppDbContext context, int tenantId)
        {
            foreach (var (nom, libelle) in Initiales)
                context.Unites.Add(new UniteVente { TenantId = tenantId, Nom = nom, Libelle = libelle });
        }

        // Noms des unités actives de la société consultée (« Unité » en premier).
        public static List<string> UnitesActives(this AppDbContext context) =>
            context.Unites.Where(u => u.Actif).Select(u => u.Nom).Distinct().AsEnumerable()
                .OrderBy(n => n == "Unité" ? 0 : 1).ThenBy(n => n, StringComparer.CurrentCultureIgnoreCase).ToList();

        // Ajoute l'unité à la liste de la société si elle n'y est pas (saisie par import Excel, par exemple).
        public static void AssurerUnite(this AppDbContext context, string? nom, int tenantId)
        {
            if (string.IsNullOrWhiteSpace(nom) || tenantId == 0)
                return;
            if (context.Unites.Local.Any(u => u.TenantId == tenantId && string.Equals(u.Nom, nom, StringComparison.OrdinalIgnoreCase))
                || context.Unites.IgnoreQueryFilters().Any(u => u.TenantId == tenantId && u.Nom == nom))
                return;
            context.Unites.Add(new UniteVente { TenantId = tenantId, Nom = nom });
        }
    }
}
