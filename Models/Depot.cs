using System.ComponentModel.DataAnnotations;
using EasytransitCaisse.Data;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Models
{
    // Dépôt de stockage (magasin, entrepôt, réserve…) : le stock de chaque produit est suivi par dépôt.
    // Chaque société a un dépôt par défaut, qui reçoit le stock initial des produits et
    // sert aux caisses sans dépôt choisi.
    public class Depot : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        [Required(ErrorMessage = "Le code est obligatoire.")]
        [StringLength(20)]
        public string Code { get; set; } = "";

        [Required(ErrorMessage = "Le nom est obligatoire.")]
        [StringLength(100)]
        public string Nom { get; set; } = "";

        [StringLength(200)]
        public string? Adresse { get; set; }

        [StringLength(100)]
        public string? Responsable { get; set; }

        public bool Actif { get; set; } = true;

        public bool ParDefaut { get; set; }

        // Dépôt des achats (laverie : « Magasin des produits d'entretien ») : reçoit les achats et fournit
        // les consommations ; il ne sert à aucune caisse. Un seul par société.
        public bool DepotAchats { get; set; }
    }

    // Quantité d'un produit dans un dépôt. Produit.StockActuel reste le total de tous les dépôts.
    [PrimaryKey(nameof(DepotId), nameof(ProduitId))]
    public class StockDepot
    {
        public int DepotId { get; set; }

        public int ProduitId { get; set; }

        [Precision(18, 2)]
        public decimal Quantite { get; set; }
    }
}
