using EasytransitCaisse.Data;

namespace EasytransitCaisse.Models
{
    public class OperationCaisse : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        public int JourneeCaisseId { get; set; }

        public DateTime DateOperation { get; set; }

        public string TypeOperation { get; set; } // Encaissement / Décaissement

        public decimal Montant { get; set; }

        public string Libelle { get; set; }

        public int? ClientId { get; set; }
        public int? MotifId { get; set; }
        public int? ModePaiementId { get; set; }

        public int UtilisateurId { get; set; }

        // Validations
        public bool EstJustifie { get; set; }

        public string StatutValidation { get; set; } = "En attente"; // En attente / Validé / Rejeté

        public string? Valideur { get; set; }

        public string? Observation { get; set; }

        public virtual JourneeCaisse JourneeCaisse { get; set; }
        public virtual Motif Motif { get; set; }

        public virtual ModePaiement ModePaiement { get; set; }

        public virtual Client Client { get; set; }

        public virtual Utilisateur Utilisateur { get; set; }

    }
}