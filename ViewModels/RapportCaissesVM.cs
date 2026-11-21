namespace GesCaisse.Models.ViewModels;

public class RapportCaissesVM
{
    public string? Recherche { get; set; }

    public List<Caisse> Caisses { get; set; } = new();
}