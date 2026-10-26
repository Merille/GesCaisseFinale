using EasytransitCaisse.Data;
using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Models
{
    // Taxe applicable aux produits (TVA, CSS…). Un produit peut en porter plusieurs :
    // elles s'additionnent sur le HT et sont comprises dans le prix de vente TTC.
    public class Taxe : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        [MaxLength(20)]
        public string Code { get; set; } = "";

        [MaxLength(100)]
        public string Libelle { get; set; } = "";

        [Precision(5, 2)]
        public decimal Taux { get; set; }

        // Cochée par défaut sur un nouveau produit.
        public bool ParDefaut { get; set; }
    }

    // Taxes d'un produit (Produits.TauxTVA garde le taux total).
    public class ProduitTaxe
    {
        public int ProduitId { get; set; }

        public int TaxeId { get; set; }
    }

    // Détail des taxes d'une ligne vendue (code et taux figés au moment de la vente).
    public class LigneCommandePosTaxe : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        public int LigneCommandePosId { get; set; }

        public int? TaxeId { get; set; }

        [MaxLength(20)]
        public string Code { get; set; } = "";

        [Precision(5, 2)]
        public decimal Taux { get; set; }

        [Precision(18, 2)]
        public decimal Montant { get; set; }
    }
}
