using System.ComponentModel.DataAnnotations;
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

        // Retour : vente d'origine ; motif du retour ou de l'annulation.
        public int? CommandeOrigineId { get; set; }

        public string? Motif { get; set; }

        // Remise globale du ticket (montant, et taux si saisie en %), répartie sur les lignes.
        [Precision(18, 2)]
        public decimal RemiseGlobale { get; set; }

        [Precision(5, 2)]
        public decimal? RemiseGlobaleTaux { get; set; }

        // Vente servie à table : table, couverts et pourboire (en plus du total TTC).
        public string? TableNom { get; set; }

        public int? Couverts { get; set; }

        [Precision(18, 2)]
        public decimal Pourboire { get; set; }

        // Frais de livraison : en plus du total TTC (hors taxes), recette de la société.
        [Precision(18, 2)]
        public decimal FraisLivraison { get; set; }

        // Vente faite hors ligne sur un poste, envoyée au retour de la connexion : numéro provisoire du
        // ticket imprimé, écarts constatés à l'arrivée (après clôture, prix, stock, plafond…) et date à
        // laquelle un administrateur les a vérifiés.
        [StringLength(30)]
        public string? NumeroHorsLigne { get; set; }

        [StringLength(500)]
        public string? AlerteHorsLigne { get; set; }

        public DateTime? AlerteHorsLigneVue { get; set; }

        // Commande livrée : livreur, destinataire et statut de la livraison (« À livrer » tant
        // qu'une vente payée à la commande n'est pas livrée, puis « Livrée »). Vide hors livraison.
        public int? LivreurId { get; set; }

        public string? NomLivraison { get; set; }

        public string? TelephoneLivraison { get; set; }

        public string? AdresseLivraison { get; set; }

        public string? StatutLivraison { get; set; }

        public DateTime? DateLivraison { get; set; }

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

        // Retour : ligne de la vente d'origine (quantités négatives).
        public int? LigneOrigineId { get; set; }

        // Part de la remise globale du ticket (TotalTTC est net de cette part).
        [Precision(18, 2)]
        public decimal RemiseGlobale { get; set; }

        // Note de l'article (« sans oignon », « bien cuit »).
        public string? Note { get; set; }

        // Combo vendu : composants choisis en JSON (produit, libellé, quantité par combo, supplément).
        public string? Composants { get; set; }

        public List<LigneCommandePosTaxe> Taxes { get; set; } = new();
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
