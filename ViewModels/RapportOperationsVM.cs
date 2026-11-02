namespace EasytransitCaisse.Models.ViewModels;

public class RapportOperationsVM
{
    public DateTime? DateDebut { get; set; }
    public DateTime? DateFin { get; set; }
    public int? CaisseId { get; set; }
    public string? TypeOperation { get; set; }
    public string? CaisseLibelle { get; set; }

    public List<OperationCaisse> Operations { get; set; } = new();

    public decimal TotalEntrees { get; set; }
    public decimal TotalSorties { get; set; }

    public decimal MontantInitialJournees { get; set; }
}