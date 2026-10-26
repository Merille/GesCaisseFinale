using EasytransitCaisse.Data;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Models
{
    // Mouvement de stock d'un produit suivi : quantité signée (+ entrée, − sortie)
    // et stock obtenu après le mouvement.
    public class MouvementStock : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        public int ProduitId { get; set; }

        public virtual Produit? Produit { get; set; }

        public DateTime DateMouvement { get; set; }

        // Stock initial, Entrée, Inventaire, Vente, Retour, Annulation
        public string TypeMouvement { get; set; } = "";

        [Precision(18, 2)]
        public decimal Quantite { get; set; }

        [Precision(18, 2)]
        public decimal StockApres { get; set; }

        public string? Reference { get; set; }

        public int? CommandePosId { get; set; }

        public int? UtilisateurId { get; set; }

        public string? Commentaire { get; set; }

        public static readonly string[] Types = { "Stock initial", "Entrée", "Inventaire", "Vente", "Retour", "Annulation" };
    }
}
