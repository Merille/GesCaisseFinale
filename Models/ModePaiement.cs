using EasytransitCaisse.Data;

namespace EasytransitCaisse.Models
{
    public class ModePaiement : ITenantScoped
    {
        public int Id { get; set; }

        public string? Code { get; set; }

        public string? Libelle { get; set; }

        public bool Actif { get; set; } = true;

        public int TenantId { get; set; }
    }
}
