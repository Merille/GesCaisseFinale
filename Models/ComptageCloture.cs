using EasytransitCaisse.Data;
using System.ComponentModel.DataAnnotations.Schema;

namespace EasytransitCaisse.Models
{
    // Détail du contrôle physique/théorique par mode de paiement, saisi à la
    // clôture d'une journée (comparable à la fermeture de caisse d'un POS).
    public class ComptageCloture : ITenantScoped
    {
        public int Id { get; set; }

        public int JourneeCaisseId { get; set; }

        public int? ModePaiementId { get; set; }

        public decimal MontantTheorique { get; set; }

        public decimal MontantCompte { get; set; }

        [NotMapped]
        public decimal Ecart => MontantCompte - MontantTheorique;

        public int TenantId { get; set; }

        public virtual JourneeCaisse JourneeCaisse { get; set; }
        public virtual ModePaiement ModePaiement { get; set; }
    }
}
