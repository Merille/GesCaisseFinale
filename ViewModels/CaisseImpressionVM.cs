namespace EasytransitCaisse.Models.ViewModels;

// Ligne de la liste imprimée des caisses : la caisse et le nom de son caissier par défaut.
public class CaisseImpressionVM
{
    public Caisse Caisse { get; set; } = null!;
    public string? Caissier { get; set; }
}
