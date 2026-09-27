using EasytransitCaisse.Data;

namespace EasytransitCaisse.Models
{
    public class JourneeCaisse : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        public int CaisseId { get; set; }

        public string NumeroJournee { get; set; }

        // Date de gestion
        public DateTime DateJournee { get; set; }

        public DateTime DateOuverture { get; set; }

        public DateTime? DateFermeture { get; set; }

        public decimal SoldeInitial { get; set; }

        // Total physiquement compté à la clôture (SoldeInitial + comptages par
        // mode de paiement) — sert de solde initial suggéré à la journée suivante.
        public decimal SoldeFinal { get; set; }

        // Écart entre le compté et le théorique à la clôture (compté - théorique).
        public decimal? EcartCloture { get; set; }

        public string? NoteCloture { get; set; }

        public string Statut { get; set; }= "Ouverte";

        public virtual Caisse Caisse { get; set; }
    }
}