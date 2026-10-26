using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace EasytransitCaisse.Models
{
    public class Tenant
    {
        public int Id { get; set; }

        public string Nom { get; set; }

        public string Code { get; set; }

        public bool Actif { get; set; } = true;

        // Licence : DateExpiration = null (illimitée) le plus souvent.
        // Abonnement : DateExpiration = fin de la période payée, à renouveler.
        public string ModeAcces { get; set; } = "Licence";

        public DateTime? DateExpiration { get; set; }

        public DateTime DateCreation { get; set; } = DateTime.Now;

        // Point de vente : vente autorisée quand le stock est épuisé (avec avertissement).
        public bool PosVenteSansStock { get; set; } = true;

        // Coordonnées (en-tête des tickets, factures et impressions).
        [MaxLength(250)]
        public string? Adresse { get; set; }

        [MaxLength(100)]
        public string? Ville { get; set; }

        [MaxLength(100)]
        public string? Pays { get; set; }

        [MaxLength(150)]
        public string? Email { get; set; }

        [MaxLength(50)]
        public string? Telephone { get; set; }

        [MaxLength(50)]
        public string? NIF { get; set; }

        // Date du logo (table TenantLogos) : null = pas de logo ; sert aussi de version dans l'adresse.
        public DateTime? LogoMaj { get; set; }

        // Règle unique de blocage, utilisée à la fois par le filtre d'accès et
        // par l'affichage — jamais recalculée différemment à deux endroits.
        [NotMapped]
        public bool EstBloque =>
            !Actif || (DateExpiration.HasValue && DateExpiration.Value.Date < DateTime.Today);
    }
}
