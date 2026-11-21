namespace GesCaisse.Models.ViewModels;

public class RapportJourneesVM
{
    public DateTime? DateDebut { get; set; }
    public DateTime? DateFin { get; set; }
    public int? CaisseId { get; set; }
    public string? Statut { get; set; }

    public List<JourneeCaisse> Journees { get; set; } = new();
}