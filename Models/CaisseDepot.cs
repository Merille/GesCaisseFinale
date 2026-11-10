using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Models
{
    // Dépôt secondaire d'une caisse : en plus de son dépôt principal (Caisse.DepotId), la caisse puise
    // dans ces dépôts, dans l'ordre indiqué, quand le stock du principal ne suffit pas.
    // Un même dépôt peut être secondaire de plusieurs caisses.
    [PrimaryKey(nameof(CaisseId), nameof(DepotId))]
    public class CaisseDepot
    {
        public int CaisseId { get; set; }

        public int DepotId { get; set; }

        public int Ordre { get; set; } = 1;
    }
}
