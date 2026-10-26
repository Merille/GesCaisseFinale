using System.ComponentModel.DataAnnotations;

namespace EasytransitCaisse.Models
{
    // Images enregistrées dans la base : aucun dossier à copier lors d'une mise à jour du site.
    public class TenantLogo
    {
        [Key]
        public int TenantId { get; set; }

        [MaxLength(30)]
        public string TypeContenu { get; set; } = "";

        public byte[] Donnees { get; set; } = Array.Empty<byte>();
    }

    public class ProduitImage
    {
        [Key]
        public int ProduitId { get; set; }

        [MaxLength(30)]
        public string TypeContenu { get; set; } = "";

        public byte[] Donnees { get; set; } = Array.Empty<byte>();
    }
}
