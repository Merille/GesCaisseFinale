namespace EasytransitCaisse.Models.ViewModels;

public class PrintOperationsVM
{
    public List<OperationCaisse> Operations { get; set; } = new();
    public List<TotalModePaiementVM> TotauxParModePaiement { get; set; } = new();
}
