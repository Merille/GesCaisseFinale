using EasytransitCaisse.Data;
using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Models
{
    // Combos comme dans le point de vente Odoo : un combo regroupe les produits proposés au choix
    // (ex. « Plats » : Poulet, Poisson + 500) et le nombre d'articles à choisir. Géré dans
    // Configuration › Combos ; un produit combo (ex. « Menu midi ») se compose d'une liste de combos.
    public class Combo : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        [MaxLength(50)]
        public string Nom { get; set; } = "";

        // Nombre d'articles à choisir dans le combo.
        public int Quantite { get; set; } = 1;

        public int Ordre { get; set; }

        public List<ComboChoix> Choix { get; set; } = new();
    }

    // Produit proposé dans un combo (supplément ajouté au prix du produit combo).
    public class ComboChoix
    {
        public int Id { get; set; }

        public int ComboId { get; set; }

        public int ProduitId { get; set; }

        [Precision(18, 2)]
        public decimal Supplement { get; set; }

        public int Ordre { get; set; }
    }

    // Combos qui composent un produit combo, dans l'ordre.
    public class ProduitCombo
    {
        public int ProduitId { get; set; }

        public int ComboId { get; set; }

        public int Ordre { get; set; }
    }
}
