using EasytransitCaisse.Data;
using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Models
{
    // Restaurant et bar (comme le point de vente restaurant d'Odoo) : salles et tables d'une
    // caisse de type Restaurant ou Bar, commande ouverte sur la table jusqu'au paiement,
    // bons de préparation envoyés en cuisine ou au bar.
    public class Salle : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        public int CaisseId { get; set; }

        [MaxLength(50)]
        public string Nom { get; set; } = "";

        public int Ordre { get; set; }

        public List<TableRestaurant> Tables { get; set; } = new();
    }

    // Position et taille en points sur un plan de 1000 × 600.
    public class TableRestaurant : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        public int SalleId { get; set; }

        [MaxLength(30)]
        public string Nom { get; set; } = "";

        public int Places { get; set; } = 4;

        // carree ou ronde
        [MaxLength(10)]
        public string Forme { get; set; } = "carree";

        public int PosX { get; set; } = 20;

        public int PosY { get; set; } = 20;

        public int Largeur { get; set; } = 100;

        public int Hauteur { get; set; } = 100;

        public bool Actif { get; set; } = true;
    }

    // Commande en cours sur une table. Contenu : lignes, client et remise en JSON (même format
    // que les tickets de l'écran de vente). Version : contrôle des modifications simultanées.
    public class CommandeOuverte : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        public int CaisseId { get; set; }

        public int JourneeCaisseId { get; set; }

        public int? TableId { get; set; }

        public int Couverts { get; set; } = 1;

        public int? UtilisateurId { get; set; }

        public DateTime DateOuverture { get; set; }

        public DateTime DateMaj { get; set; }

        public int Version { get; set; } = 1;

        public bool AdditionImprimee { get; set; }

        public string Contenu { get; set; } = "{}";
    }

    // Bon de préparation (Cuisine ou Bar) : imprimé et affiché sur l'écran cuisine / bar.
    public class BonPreparation : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        public int CaisseId { get; set; }

        public int JourneeCaisseId { get; set; }

        public int? CommandeOuverteId { get; set; }

        public int Numero { get; set; }

        [MaxLength(20)]
        public string Poste { get; set; } = "Cuisine";

        [MaxLength(60)]
        public string? TableNom { get; set; }

        public int? Couverts { get; set; }

        [MaxLength(100)]
        public string? Serveur { get; set; }

        public DateTime DateEnvoi { get; set; }

        [MaxLength(20)]
        public string Statut { get; set; } = "À préparer";

        public DateTime? DatePret { get; set; }

        public List<LigneBonPreparation> Lignes { get; set; } = new();
    }

    // Quantité négative : article annulé après l'envoi.
    public class LigneBonPreparation
    {
        public int Id { get; set; }

        public int BonPreparationId { get; set; }

        [MaxLength(200)]
        public string Libelle { get; set; } = "";

        [Precision(18, 2)]
        public decimal Quantite { get; set; }

        [MaxLength(200)]
        public string? Note { get; set; }
    }
}
