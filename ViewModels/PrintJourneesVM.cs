namespace EasytransitCaisse.Models.ViewModels;

public class JourneeLigneVM
{
    public DateTime DateJournee { get; set; }
    public decimal SoldeInitial { get; set; }
    public decimal Encaisse { get; set; }
    public decimal Decaisse { get; set; }
    public decimal Solde { get; set; }
    public string Statut { get; set; } = "";
}

public class PrintJourneesVM
{
    public string CaisseName { get; set; } = "";
    public List<JourneeLigneVM> Journees { get; set; } = new();
}
