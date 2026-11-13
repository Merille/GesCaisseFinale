using EasytransitCaisse.Models;

namespace EasytransitCaisse.Models.ViewModels
{
    // Page Synchronisation : filtres des ventes hors ligne, postes, ventes et dépôts de linge hors ligne.
    public class FiltresSynchro
    {
        // Valeur du filtre → libellé (« à vérifier » : toutes dates).
        public static readonly (string Valeur, string Libelle)[] Etats =
            { ("à vérifier", "À vérifier"), ("vérifiées", "Vérifiées"), ("sans écart", "Sans écart"), ("toutes", "Toutes") };

        public DateTime Du { get; set; }
        public DateTime Au { get; set; }
        public string Etat { get; set; } = "à vérifier";
    }

    public class ElementPoste
    {
        public string Numero { get; set; } = "";
        public string Type { get; set; } = "";
        public string Libelle { get; set; } = "";
        public decimal? Montant { get; set; }
        public DateTime? Cree { get; set; }
        public string Erreur { get; set; } = "";
    }

    public class LignePoste
    {
        public PosteHorsLigne Poste { get; set; } = null!;
        public string? Utilisateur { get; set; }
        public List<ElementPoste> Elements { get; set; } = new();
        public string Etat { get; set; } = "";
        public string Badge { get; set; } = "";
    }

    public class LigneVenteHorsLigne
    {
        public CommandePos Vente { get; set; } = null!;
        public string? Caisse { get; set; }
        public string? Vendeur { get; set; }
    }

    public class SynchroVM
    {
        public FiltresSynchro Filtres { get; set; } = new();
        public List<LignePoste> Postes { get; set; } = new();
        public List<LigneVenteHorsLigne> Ventes { get; set; } = new();
        public List<(DepotLinge Depot, string? Caisse)>? Depots { get; set; }
        public int NbVentes { get; set; }
        public decimal MontantVentes { get; set; }
        public int AVerifier { get; set; }
    }
}
