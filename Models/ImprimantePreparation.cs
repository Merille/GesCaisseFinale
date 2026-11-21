using System.ComponentModel.DataAnnotations;
using EasytransitCaisse.Data;

namespace EasytransitCaisse.Models
{
    // Imprimante de préparation (cuisine, bar) en réseau : la caisse lui envoie les bons des catégories
    // choisies. Epson : impression directe (ePOS) ; Réseau : imprimante ESC/POS par l'agent d'impression.
    public class ImprimantePreparation : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        [Required(ErrorMessage = "Le nom est obligatoire.")]
        [StringLength(100)]
        public string Nom { get; set; } = "";

        // Epson (ePOS, sans rien installer) ou Reseau (ESC/POS port 9100, par l'agent d'impression).
        [StringLength(20)]
        public string Type { get; set; } = "Epson";

        [Required(ErrorMessage = "L'adresse IP est obligatoire.")]
        [StringLength(100)]
        public string AdresseIp { get; set; } = "";

        // Vide : port par défaut (Epson : celui de la page, Réseau : 9100).
        public int? Port { get; set; }

        // Largeur du papier en mm : 80 (48 caractères) ou 58 (32 caractères).
        public int Largeur { get; set; } = 80;

        // PC850 (accents) ou SansAccents (imprimantes sans table de caractères française).
        [StringLength(20)]
        public string Encodage { get; set; } = "PC850";

        // Signal sonore à chaque bon (imprimantes équipées d'un buzzer).
        public bool Bip { get; set; }

        // Caisse concernée (vide : toutes les caisses restaurant / bar).
        public int? CaisseId { get; set; }

        public bool Actif { get; set; } = true;

        public List<ImprimantePreparationCategorie> Categories { get; set; } = new();

        public static readonly string[] Types = { "Epson", "Reseau" };
    }

    // Catégories de produits imprimées par une imprimante de préparation.
    public class ImprimantePreparationCategorie
    {
        public int ImprimantePreparationId { get; set; }

        public int CategorieId { get; set; }
    }
}
