using System.ComponentModel.DataAnnotations;
using EasytransitCaisse.Data;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Models
{
    // Laverie : dépôt de linge payé au retrait. Au dépôt, la commande est enregistrée avec un numéro
    // (par société), le client, son téléphone, la date de retrait prévue et un acompte facultatif
    // (encaissé dans la journée du dépôt) ; un ticket « NON PAYÉ » est imprimé. Au retrait, le dépôt
    // est encaissé dans la journée du jour comme une vente (acompte déduit).
    // Statuts : En cours → Prêt → Retiré ; ou Annulé (acompte remboursé). Comme laverie.php en PHP.
    public class DepotLinge : ITenantScoped
    {
        public const string EnCours = "En cours", Pret = "Prêt", Retire = "Retiré", Annule = "Annulé";
        public static readonly string[] Actifs = { EnCours, Pret };

        public int Id { get; set; }

        public int TenantId { get; set; }

        public int CaisseId { get; set; }

        public int JourneeCaisseId { get; set; }

        public int Numero { get; set; }

        [StringLength(64)]
        public string? CleClient { get; set; }

        // Dépôt fait hors ligne : numéro provisoire de la souche imprimée sur le poste.
        [StringLength(30)]
        public string? NumeroHorsLigne { get; set; }

        public DateTime DateDepot { get; set; }

        public DateTime? DateRetraitPrevue { get; set; }

        [StringLength(100)]
        public string NomClient { get; set; } = "";

        [StringLength(30)]
        public string? TelephoneClient { get; set; }

        public int? ClientId { get; set; }

        public int? UtilisateurId { get; set; }

        // Ticket en JSON : lignes, client, remise globale.
        public string Contenu { get; set; } = "";

        [Precision(18, 2)]
        public decimal Total { get; set; }

        [Precision(18, 2)]
        public decimal NbArticles { get; set; }

        [Precision(18, 2)]
        public decimal Acompte { get; set; }

        public int? AcompteModePaiementId { get; set; }

        public int? AcompteOperationId { get; set; }

        [StringLength(20)]
        public string Statut { get; set; } = EnCours;

        public DateTime? DatePret { get; set; }

        public DateTime? DateRetrait { get; set; }

        public DateTime? DateAnnulation { get; set; }

        public int? CommandePosId { get; set; }
    }
}
