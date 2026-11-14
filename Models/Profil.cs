using System.ComponentModel.DataAnnotations;
using EasytransitCaisse.Data;

namespace EasytransitCaisse.Models
{
    // Profil d'utilisateurs d'une société (Caissier, Serveur, Gérant…) et ses droits d'accès :
    // codes séparés par des virgules (voir Services/Droits.cs). Les comptes Admin et SuperAdmin
    // ont toujours tous les droits. Comme la table Profils en PHP.
    public class Profil : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        [StringLength(50)]
        public string Nom { get; set; } = "";

        [StringLength(200)]
        public string? Description { get; set; }

        [StringLength(1000)]
        public string Droits { get; set; } = "";
    }
}
