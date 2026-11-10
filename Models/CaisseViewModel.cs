namespace EasytransitCaisse.Models
{
    public class CaisseViewModel
    {
        public int ID { get; set; }
        public string ChkCode { get; set; }
        public string ChkDescription { get; set; }
        public string StCode { get; set; }

        public string CashierName { get; set; }

        public string? CompteComptable { get; set; }

        public string TypePointVente { get; set; } = "Boutique";

        // Dépôt de la caisse (sinon dépôt par défaut de la société) et ses dépôts secondaires, dans l'ordre.
        public string? DepotCode { get; set; }
        public bool DepotParDefaut { get; set; }
        public List<string> Secondaires { get; set; } = new();
    }
}