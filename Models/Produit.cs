using EasytransitCaisse.Data;
using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Models
{
    // Produit (ou service) vendu au point de vente. Le prix de vente est saisi
    // TTC ; la TVA est calculée à partir du TTC.
    public class Produit : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        public string Code { get; set; } = "";

        public string? CodeBarres { get; set; }

        public string Nom { get; set; } = "";

        public int? CategorieId { get; set; }

        public virtual Categorie? Categorie { get; set; }

        [Precision(18, 2)]
        public decimal PrixVente { get; set; }

        [Precision(5, 2)]
        public decimal TauxTVA { get; set; } = 18;

        // Faux pour un service (photocopie, recharge...) : pas de stock.
        public bool SuiviStock { get; set; } = true;

        [Precision(18, 2)]
        public decimal StockActuel { get; set; }

        [Precision(18, 2)]
        public decimal? SeuilAlerte { get; set; }

        public bool Actif { get; set; } = true;

        // Coût d'achat HT (calcul de la marge).
        [Precision(18, 2)]
        public decimal? Cout { get; set; }

        // Unité de vente : le prix TTC s'entend pour une unité.
        [MaxLength(20)]
        public string Unite { get; set; } = "Unité";

        // Date de l'image (table ProduitImages) : null = pas d'image.
        public DateTime? ImageMaj { get; set; }

        // Variantes : le modèle (EstModele) porte les attributs ; chaque combinaison est un
        // produit variante (ParentId = modèle) avec son code, son stock et un supplément de prix.
        public int? ParentId { get; set; }

        public bool EstModele { get; set; }

        [Precision(18, 2)]
        public decimal Supplement { get; set; }

        [MaxLength(150)]
        public string? LibelleVariante { get; set; }

        public bool EnAlerteStock => SuiviStock && SeuilAlerte.HasValue && StockActuel <= SeuilAlerte.Value;
    }
}
