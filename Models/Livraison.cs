using System.ComponentModel.DataAnnotations;
using EasytransitCaisse.Data;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Models
{
    // Livreur (sans compte de connexion) : choisi sur une commande à livrer.
    public class Livreur : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        [Required(ErrorMessage = "Le nom est obligatoire.")]
        [StringLength(100)]
        public string Nom { get; set; } = "";

        [StringLength(30)]
        public string? Telephone { get; set; }

        // Moyen de livraison : Moto, Voiture, Vélo ou Autre.
        [StringLength(20)]
        public string MoyenLivraison { get; set; } = "Moto";

        public bool Actif { get; set; } = true;

        public static readonly string[] Moyens = { "Moto", "Voiture", "Vélo", "Autre" };

        // Pictogramme Font Awesome du moyen de livraison.
        public static string Icone(string? moyen) => moyen switch
        {
            "Voiture" => "fa-car",
            "Vélo" => "fa-bicycle",
            "Autre" => "fa-truck-fast",
            _ => "fa-motorcycle"
        };
    }

    // Commande mise en attente au point de vente, gardée sur le serveur et visible depuis tous les
    // postes de la journée. Contenu : le ticket en JSON (lignes, client, remise globale, livraison).
    // Une commande à livrer « à encaisser à la livraison » attend ici le retour du livreur.
    public class CommandeAttente : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        public int JourneeCaisseId { get; set; }

        // Rang dans la journée (A-001, A-002…).
        public int Numero { get; set; }

        public DateTime DateCreation { get; set; }

        public int UtilisateurId { get; set; }

        public int? ClientId { get; set; }

        public string Contenu { get; set; } = "";

        [Precision(18, 2)]
        public decimal Total { get; set; }

        public int NbArticles { get; set; }

        public int? LivreurId { get; set; }

        [StringLength(100)]
        public string? NomLivraison { get; set; }

        [StringLength(30)]
        public string? TelephoneLivraison { get; set; }

        [StringLength(200)]
        public string? AdresseLivraison { get; set; }

        // Clé du poste : un envoi refait (coupure réseau, commande mise en attente hors ligne) ne crée
        // pas une seconde commande.
        [StringLength(64)]
        public string? CleClient { get; set; }
    }
}
