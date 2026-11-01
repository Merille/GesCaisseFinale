namespace EasytransitCaisse.Models
{
    public class CaisseViewModel
    {
        public int ID { get; set; }
        public string ChkCode { get; set; }
        public string ChkDescription { get; set; }
        public string StCode { get; set; }

        public string CashierName { get; set; }

        public string TypePointVente { get; set; } = "Boutique";
    }
}