using GesCaisse.Data;

namespace GesCaisse.Models
{
    public class Facture : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        public string Numero { get; set; }

        public DateTime DateFacture { get; set; }

        public int ClientId { get; set; }

        public decimal MontantHT { get; set; }

        public decimal TauxTVA { get; set; }

        public decimal MontantTVA { get; set; }

        public decimal MontantTTC { get; set; }

        public decimal MontantPaye { get; set; }

        public string Statut { get; set; } = "Brouillon";

        public virtual Client Client { get; set; }
    }
}