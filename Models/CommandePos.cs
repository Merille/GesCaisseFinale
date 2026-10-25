using EasytransitCaisse.Data;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Models
{
    // Vente du point de vente (ticket payé).
    public class CommandePos : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        // POS-<caisse>-<aaaammjj>-<rang dans la journée>
        public string Numero { get; set; } = "";

        // Identifiant du ticket côté navigateur : un second envoi du même ticket est ignoré.
        public string CleClient { get; set; } = "";

        public int JourneeCaisseId { get; set; }

        public virtual JourneeCaisse? JourneeCaisse { get; set; }

        public int? ClientId { get; set; }

        public int UtilisateurId { get; set; }

        public DateTime DateCommande { get; set; }

        [Precision(18, 2)]
        public decimal TotalHT { get; set; }

        [Precision(18, 2)]
        public decimal TotalTVA { get; set; }

        [Precision(18, 2)]
        public decimal TotalTTC { get; set; }

        [Precision(18, 2)]
        public decimal MontantRecu { get; set; }

        [Precision(18, 2)]
        public decimal MonnaieRendue { get; set; }

        public string Statut { get; set; } = "Payée";

        public int? FactureId { get; set; }

        public List<LigneCommandePos> Lignes { get; set; } = new();

        public List<PaiementPos> Paiements { get; set; } = new();
    }

    public class LigneCommandePos : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        public int CommandePosId { get; set; }

        public int? ProduitId { get; set; }

        public string Libelle { get; set; } = "";

        [Precision(18, 2)]
        public decimal Quantite { get; set; }

        [Precision(18, 2)]
        public decimal PrixUnitaire { get; set; }

        [Precision(5, 2)]
        public decimal Remise { get; set; }

        [Precision(5, 2)]
        public decimal TauxTVA { get; set; }

        [Precision(18, 2)]
        public decimal TotalTTC { get; set; }
    }

    // Règlement d'une vente. Montant = part encaissée (monnaie déduite) ;
    // MontantRecu = somme remise par le client.
    public class PaiementPos : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        public int CommandePosId { get; set; }

        public int? ModePaiementId { get; set; }

        public string Libelle { get; set; } = "";

        [Precision(18, 2)]
        public decimal MontantRecu { get; set; }

        [Precision(18, 2)]
        public decimal Montant { get; set; }

        public int? OperationCaisseId { get; set; }
    }
}
