using EasytransitCaisse.Models;

namespace EasytransitCaisse.Models.ViewModels
{
    // Tableau de bord de la laverie (tuiles), à côté du tableau de bord général.
    public class TableauLaverieVM
    {
        public int DepotsJour { get; set; }
        public decimal ArticlesJour { get; set; }
        public decimal MontantJour { get; set; }
        public int DepotsSemaine { get; set; }
        public int RetraitsJour { get; set; }
        public decimal MontantRetraitsJour { get; set; }
        public int RetraitsSemaine { get; set; }
        public int ARetirer { get; set; }
        public int Prets { get; set; }
        public decimal Reste { get; set; }
        public int Retard { get; set; }
        public DateTime? PlusAncienRetard { get; set; }
        public decimal ResteRetard { get; set; }
        public int ClientsMois { get; set; }
        public int ClientsTotal { get; set; }
        public decimal Du { get; set; }
        public int Articles { get; set; }
        public int Categories { get; set; }
        public List<(string Nom, decimal Qte)> TopArticles { get; set; } = new();
        public int ARacheter { get; set; }
        public decimal ValeurEntretien { get; set; }
        public decimal AchatsMois { get; set; }
        public List<(int Id, string Code)> Journees { get; set; } = new();
        public decimal Encaissements { get; set; }
        public List<(DateTime Jour, int Depots, int Retraits)> Jours { get; set; } = new();
        public List<DepotLinge> PretsListe { get; set; } = new();
        public List<DepotLinge> RetardsListe { get; set; } = new();
    }
}
