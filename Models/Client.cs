using EasytransitCaisse.Data;

namespace EasytransitCaisse.Models
{
    public class Client : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        // Société
        public string CodeClient { get; set; }
        public string NomSociete { get; set; }
        public string? Adresse { get; set; }
        public string? Telephone { get; set; }
        public string? Email { get; set; }
        public string? Type { get; set; }

        // Genre du tiers : Entreprise (personne morale) ou Particulier (personne physique).
        public string Genre { get; set; } = "Entreprise";

        public static readonly string[] Genres = { "Entreprise", "Particulier" };

        public static string GenreValide(string? genre) => genre == "Particulier" ? "Particulier" : "Entreprise";

        // Client en compte : peut payer « par compte » au point de vente (vente à crédit),
        // dans la limite du plafond de crédit (vide = sans plafond).
        public bool EnCompte { get; set; }
        public decimal? PlafondCredit { get; set; }

        // Compte général comptable de ce tiers (ex: 411000), utilisé comme
        // contrepartie lors de l'export des écritures vers Sage quand le
        // motif de l'opération n'en précise pas.
        public string? CompteGeneral { get; set; }

        // Interlocuteur principal
        public string? NomContact { get; set; }
        public string? FonctionContact { get; set; }
        public string? TelephoneContact { get; set; }
        public string? EmailContact { get; set; }
    }
}