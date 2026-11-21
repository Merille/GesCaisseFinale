namespace GesCaisse.Models.ViewModels
{
    public class FacturePrintViewModel
    {
        public Facture Facture { get; set; }

        public List<LigneFacture> Lignes { get; set; } = new();
    }
}