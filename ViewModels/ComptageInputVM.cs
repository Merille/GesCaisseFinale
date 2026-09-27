using EasytransitCaisse.Services;

namespace EasytransitCaisse.Models.ViewModels;

public class ComptageInputVM
{
    public int? ModePaiementId { get; set; }

    // Liée en string (et non decimal) : voir MontantHelper.Parse.
    public string? MontantCompte { get; set; }

    public decimal MontantCompteDecimal => MontantHelper.Parse(MontantCompte);
}
