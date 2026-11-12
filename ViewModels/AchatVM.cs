using EasytransitCaisse.Models;

namespace EasytransitCaisse.Models.ViewModels
{
    // Achats (laverie) : filtres, liste avec montant réglé / reste, totaux ; synthèse des consommations.
    public class FiltresAchats
    {
        public static readonly string[] Choix = { "Validé", "Non soldé", "Annulé" };

        public DateTime Du { get; set; }
        public DateTime Au { get; set; }
        public int Fournisseur { get; set; }
        public string Statut { get; set; } = "";
    }

    public class LigneListeAchat
    {
        public Achat Achat { get; set; } = null!;
        public string? Fournisseur { get; set; }
        public string? Depot { get; set; }
        public decimal Regle { get; set; }
        public decimal Reste { get; set; }
    }

    public class AchatsVM
    {
        public FiltresAchats Filtres { get; set; } = new();
        public List<LigneListeAchat> Achats { get; set; } = new();
        public List<Client> Fournisseurs { get; set; } = new();
        public int Nombre { get; set; }
        public decimal Montant { get; set; }
        public decimal Regle { get; set; }
        public decimal Reste { get; set; }
        // Reste à payer de tous les achats validés, quelle que soit leur date.
        public decimal Dette { get; set; }
    }

    public class SyntheseConsommation
    {
        public string Code { get; set; } = "";
        public string Nom { get; set; } = "";
        public string Unite { get; set; } = "";
        public decimal Quantite { get; set; }
        public decimal Valeur { get; set; }
    }
}
