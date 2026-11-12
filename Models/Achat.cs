using System.ComponentModel.DataAnnotations;
using EasytransitCaisse.Data;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Models
{
    // Achat chez un fournisseur (laverie : lessive, javel, assouplissant…). Les lignes entrent en stock
    // dans le dépôt (mouvement « Achat ») et mettent à jour le coût des produits (coût moyen pondéré).
    // Règlements : par la caisse (décaissement dans une journée ouverte), hors caisse, ou plus tard
    // (achat à crédit). Statuts : Validé, Annulé. Comme achat.php en PHP.
    public class Achat : ITenantScoped
    {
        public const string Valide = "Validé", Annule = "Annulé";

        public int Id { get; set; }

        public int TenantId { get; set; }

        public int Numero { get; set; }

        public DateTime DateAchat { get; set; }

        // Tiers de type « Fournisseur » (facultatif).
        public int? FournisseurId { get; set; }

        public int DepotId { get; set; }

        [StringLength(100)]
        public string? Reference { get; set; }

        [StringLength(300)]
        public string? Commentaire { get; set; }

        [Precision(18, 2)]
        public decimal Total { get; set; }

        [StringLength(20)]
        public string Statut { get; set; } = Valide;

        public int? UtilisateurId { get; set; }

        public DateTime DateCreation { get; set; }

        public DateTime? DateAnnulation { get; set; }

        public List<LigneAchat> Lignes { get; set; } = new();

        public List<ReglementAchat> Reglements { get; set; } = new();
    }

    public class LigneAchat
    {
        public int Id { get; set; }

        public int AchatId { get; set; }

        public int ProduitId { get; set; }

        [Precision(18, 2)]
        public decimal Quantite { get; set; }

        [Precision(18, 2)]
        public decimal PrixUnitaire { get; set; }

        [Precision(18, 2)]
        public decimal Montant { get; set; }
    }

    // Règlement d'un achat ; OperationCaisseId : décaissement correspondant (payé par la caisse).
    public class ReglementAchat
    {
        public int Id { get; set; }

        public int AchatId { get; set; }

        public DateTime DateReglement { get; set; }

        [Precision(18, 2)]
        public decimal Montant { get; set; }

        public int? ModePaiementId { get; set; }

        public int? OperationCaisseId { get; set; }

        public int? UtilisateurId { get; set; }
    }
}
