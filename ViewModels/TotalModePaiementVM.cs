namespace EasytransitCaisse.Models.ViewModels;

public class TotalModePaiementVM
{
    public int? ModePaiementId { get; set; }
    public string Libelle { get; set; } = "Non renseigné";
    public decimal Encaisse { get; set; }
    public decimal Decaisse { get; set; }
    public decimal Net => Encaisse - Decaisse;
}
