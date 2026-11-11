using EasytransitCaisse.Models;

namespace EasytransitCaisse.Models.ViewModels
{
    // Rapport des dépôts de linge (laverie) : filtres, synthèse par statut et détail.
    public class FiltresRapportLinge
    {
        public static readonly string[] Statuts = { "En cours", "Prêt", "Retiré", "Annulé" };
        // « À retirer » et « En retard » : tous les dépôts non retirés, quelle que soit leur date.
        public static readonly string[] Choix = { "À retirer", "En retard", "En cours", "Prêt", "Retiré", "Annulé" };

        public DateTime Du { get; set; }
        public DateTime Au { get; set; }
        public string Statut { get; set; } = "";
        public bool SansPeriode => Statut is "À retirer" or "En retard";

        public string Periode => SansPeriode
            ? "Tous les dépôts non retirés" + (Statut == "En retard" ? " dont la date de retrait est passée" : "")
            : $"Dépôts du {Du:dd/MM/yyyy} au {Au:dd/MM/yyyy}" + (Statut != "" ? " — Statut : " + Statut : "");
    }

    public class LigneDepotLinge
    {
        public DepotLinge Depot { get; set; } = new();
        public string? Caisse { get; set; }
        public string? Utilisateur { get; set; }
        public string? NumeroVente { get; set; }
        // Reste à encaisser (dépôt en cours ou prêt) et retard du retrait prévu.
        public decimal Reste { get; set; }
        public bool EnRetard { get; set; }
        public DateTime? Fin => Depot.DateRetrait ?? Depot.DateAnnulation;
    }

    public class SyntheseLinge
    {
        public int Nombre { get; set; }
        public decimal Articles { get; set; }
        public decimal Montant { get; set; }
        public decimal Acomptes { get; set; }
        public decimal Reste { get; set; }
        public int EnRetard { get; set; }

        public void Ajouter(LigneDepotLinge l)
        {
            Nombre++;
            Articles += l.Depot.NbArticles;
            Montant += l.Depot.Total;
            Acomptes += l.Depot.Acompte;
            Reste += l.Reste;
            EnRetard += l.EnRetard ? 1 : 0;
        }
    }

    public class RapportLingeVM
    {
        public FiltresRapportLinge Filtres { get; set; } = new();
        public List<LigneDepotLinge> Lignes { get; set; } = new();
        public Dictionary<string, SyntheseLinge> ParStatut { get; set; } = new();
        // Total hors dépôts annulés.
        public SyntheseLinge Total { get; set; } = new();

        // Quantité au format de la version PHP (quantite_fr) : entier, sinon deux décimales.
        public static string Qte(decimal n) => n.ToString(n == Math.Round(n) ? "N0" : "N2", System.Globalization.CultureInfo.GetCultureInfo("fr-FR"));
        public static string Fcfa(decimal n) => n.ToString("N0", System.Globalization.CultureInfo.GetCultureInfo("fr-FR"));
    }
}
