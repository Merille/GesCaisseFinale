using System.ComponentModel.DataAnnotations;
using EasytransitCaisse.Data;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Models
{
    // Page Synchronisation (administrateurs) : état de la file hors ligne d'un poste (navigateur), envoyé
    // par le poste quand il est connecté. Code : identifiant du poste (numéros provisoires H-code-n°).
    // EnAttente / Refusees / MontantEnAttente : opérations faites hors ligne pas encore envoyées (dont
    // refusées par le serveur) ; PlusAncien : date de la plus ancienne ; Detail : leur liste (JSON).
    // Comme la table PostesHorsLigne de la version PHP (migration 025).
    public class PosteHorsLigne : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        [StringLength(10)]
        public string Code { get; set; } = "";

        public int? UtilisateurId { get; set; }

        [StringLength(150)]
        public string? Navigateur { get; set; }

        public int EnAttente { get; set; }

        public int Refusees { get; set; }

        [Precision(18, 2)]
        public decimal MontantEnAttente { get; set; }

        public DateTime? PlusAncien { get; set; }

        public DateTime? DernierEnvoi { get; set; }

        public DateTime DernierRapport { get; set; }

        public string? Detail { get; set; }
    }
}
