using EasytransitCaisse.Data;

namespace EasytransitCaisse.Models
{
    // Catégorie de produits du point de vente : regroupe les tuiles de l'écran
    // de vente (couleur) dans l'ordre choisi.
    public class Categorie : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        public string Nom { get; set; } = "";

        // Couleur des tuiles, au format #rrggbb.
        public string Couleur { get; set; } = "#195d84";

        public int Ordre { get; set; }
    }
}
