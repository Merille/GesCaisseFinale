using EasytransitCaisse.Models;

namespace EasytransitCaisse.Models.ViewModels
{
    // Rapport des achats et consommations (laverie) : filtres, synthèse par fournisseur et par produit,
    // détail des achats. Comme rapportachat.php en PHP.
    public class FiltresRapportAchat
    {
        public DateTime Du { get; set; }
        public DateTime Au { get; set; }
        public int Fournisseur { get; set; }
        public string NomFournisseur { get; set; } = "";

        public string Periode => $"Achats du {Du:dd/MM/yyyy} au {Au:dd/MM/yyyy}" + (NomFournisseur != "" ? $" — Fournisseur : {NomFournisseur}" : "");

        public string Requete => $"du={Du:yyyy-MM-dd}&au={Au:yyyy-MM-dd}" + (Fournisseur > 0 ? $"&fournisseur={Fournisseur}" : "");
    }

    public class SyntheseAchats
    {
        public int Nombre { get; set; }
        public decimal Montant { get; set; }
        public decimal Regle { get; set; }
        public decimal Reste { get; set; }

        public void Ajouter(LigneRapportAchat l)
        {
            Nombre++;
            Montant += l.Achat.Total;
            Regle += l.Regle;
            Reste += l.Reste;
        }
    }

    public class LigneRapportAchat
    {
        public Achat Achat { get; set; } = null!;
        public string? Fournisseur { get; set; }
        public string? Utilisateur { get; set; }
        public decimal Regle { get; set; }
        public decimal Reste { get; set; }
        public string Statut => Achat.Statut != Achat.Valide ? "Annulé" : Reste > 0 ? "Non soldé" : "Soldé";
    }

    public class ProduitRapportAchat
    {
        public string Code { get; set; } = "";
        public string Nom { get; set; } = "";
        public string Unite { get; set; } = "";
        public decimal QteAchetee { get; set; }
        public decimal MontantAchete { get; set; }
        public decimal QteConsommee { get; set; }
        public decimal ValeurConsommee { get; set; }
        public decimal Stock { get; set; }
        public decimal? PrixMoyen => QteAchetee > 0 ? MontantAchete / QteAchetee : null;
    }

    public class RapportAchatVM
    {
        public FiltresRapportAchat Filtres { get; set; } = new();
        public List<Client> Fournisseurs { get; set; } = new();
        public List<LigneRapportAchat> Achats { get; set; } = new();
        public SortedDictionary<string, SyntheseAchats> ParFournisseur { get; set; } = new(StringComparer.OrdinalIgnoreCase);
        public SyntheseAchats Total { get; set; } = new();
        public List<ProduitRapportAchat> Produits { get; set; } = new();
        public decimal MontantAchete => Produits.Sum(p => p.MontantAchete);
        public decimal ValeurConsommee => Produits.Sum(p => p.ValeurConsommee);

        public static string Qte(decimal n) => RapportLingeVM.Qte(n);
        public static string Fcfa(decimal n) => RapportLingeVM.Fcfa(n);
    }
}
