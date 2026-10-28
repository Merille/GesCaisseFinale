using EasytransitCaisse.Data;
using System.ComponentModel.DataAnnotations;

namespace EasytransitCaisse.Models
{
    // Unité de vente des produits (Kg, Litre, Carton…). Produits.Unite garde le nom de l'unité :
    // renommer une unité met à jour ses produits ; une unité désactivée n'est plus proposée
    // sur la fiche produit mais reste sur les produits qui l'utilisent.
    public class UniteVente : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        [MaxLength(20)]
        public string Nom { get; set; } = "";

        [MaxLength(100)]
        public string? Libelle { get; set; }

        public bool Actif { get; set; } = true;
    }
}
