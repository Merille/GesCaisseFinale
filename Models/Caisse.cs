using EasytransitCaisse.Data;

namespace EasytransitCaisse.Models
{
    public class Caisse : ITenantScoped
    {
        public int ID { get; set; } // Identity

        public string? ChkCode { get; set; }
        public string? ChkDescription { get; set; }

        public string? StCode { get; set; }

        public int? SalesPersonDefault { get; set; }

        public int? CashierDefault { get; set; }

        public string? CustomerDefaultCode { get; set; } = "C0001";

        public string? JournalDefaultCode { get; set; }= "J0001";

        // Compte comptable de la caisse elle-même (ex: 571000), utilisé comme
        // contrepartie caisse lors de l'export des écritures vers Sage.
        public string? CompteComptable { get; set; }

        // Dépôt d'où sortent les ventes de la caisse (dépôt par défaut de la société si vide).
        public int? DepotId { get; set; }

        public int TenantId { get; set; }

        // Boutique, Restaurant ou Bar : en restaurant / bar, l'écran de vente s'ouvre sur le
        // plan de salle et les commandes restent sur les tables jusqu'au paiement.
        public string TypePointVente { get; set; } = "Boutique";

        // Impression d'un bon de préparation à chaque envoi en cuisine / au bar.
        public bool ImprimerBons { get; set; } = true;

        public bool EstRestaurant => TypePointVente is "Restaurant" or "Bar";
    }
}