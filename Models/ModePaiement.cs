using EasytransitCaisse.Data;

namespace EasytransitCaisse.Models
{
    public class ModePaiement : ITenantScoped
    {
        public int Id { get; set; }

        public string? Code { get; set; }

        public string? Libelle { get; set; }

        public bool Actif { get; set; } = true;

        // Paiement par compte client (vente à crédit) : pas d'encaissement en caisse, le montant
        // s'ajoute au solde dû du client.
        public bool EstCompte { get; set; }

        public int TenantId { get; set; }
    }
}
