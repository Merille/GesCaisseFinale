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

        // Règle unique de blocage, utilisée à la fois par le filtre d'accès et
        // par l'affichage — jamais recalculée différemment à deux endroits.
        [NotMapped]
        public bool EstBloque =>
            !Actif || (DateExpiration.HasValue && DateExpiration.Value.Date < DateTime.Today);
    }
}
