using EasytransitCaisse.Models;

namespace EasytransitCaisse.Models.ViewModels
{
    // Tableau de bord du restaurant-bar (tuiles), à côté du tableau de bord général.
    public class TableauRestaurantVM
    {
        public decimal CAJour { get; set; }
        public int Tickets { get; set; }
        public decimal VentesJour { get; set; }
        public int CouvertsJour { get; set; }
        public decimal VentesCouverts { get; set; }
        public decimal Pourboires { get; set; }
        public decimal CASemaine { get; set; }
        public int CouvertsSemaine { get; set; }
        public int Tables { get; set; }
        public int Occupees { get; set; }
        public int CouvertsSalle { get; set; }
        public decimal EnCours { get; set; }
        public int NbOuvertes { get; set; }
        public int BonsCuisine { get; set; }
        public int BonsBar { get; set; }
        public int NbBons { get; set; }
        public int Attente { get; set; }
        public int ALivrer { get; set; }
        public int AEncaisser { get; set; }
        public decimal MontantAEncaisser { get; set; }
        public int Livrees { get; set; }
        public (string Nom, decimal Qte)? Top { get; set; }
        public (string Nom, decimal CA)? TopCategorie { get; set; }
        public decimal ArticlesVendus { get; set; }
        public int StockBas { get; set; }
        public int Suivis { get; set; }
        public int Ruptures { get; set; }
        public List<(int Id, string Code)> Journees { get; set; } = new();
        public decimal Encaissements { get; set; }
        public List<(DateTime Jour, decimal CA)> Jours { get; set; } = new();
        public List<TableOccupee> TablesOccupees { get; set; } = new();
        public List<BonEnAttente> Bons { get; set; } = new();

        public record TableOccupee(string Table, int Couverts, string? Serveur, DateTime Depuis, decimal Total);
        public record BonEnAttente(int Numero, string Poste, string? Table, int Lignes, DateTime DateEnvoi);
    }
}
