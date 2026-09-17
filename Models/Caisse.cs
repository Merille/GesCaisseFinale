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

        public int TenantId { get; set; }
    }
}