namespace GesCaisse.ViewModels
{
    public class RapportOperationVM
    {
        public DateTime DateOperation { get; set; }
        public string Caisse { get; set; }
        public string TypeOperation { get; set; }
        public decimal Montant { get; set; }
        public string Libelle { get; set; }
    }
}