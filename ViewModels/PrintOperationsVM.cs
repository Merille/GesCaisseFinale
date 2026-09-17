namespace EasytransitCaisse.Models.ViewModels;

public class PrintOperationsVM
{
    public string NumeroJournee { get; set; } = "";
    public decimal SoldeInitial { get; set; }
    public decimal TotalEncaisse { get; set; }
    public decimal TotalDecaisse { get; set; }
    public decimal SoldeActuel { get; set; }

    public List<OperationCaisse> Operations { get; set; } = new();
    public List<TotalModePaiementVM> TotauxParModePaiement { get; set; } = new();
}
