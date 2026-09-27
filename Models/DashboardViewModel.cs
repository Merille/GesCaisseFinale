using Microsoft.AspNetCore.Mvc.Rendering;

namespace EasytransitCaisse.Models.ViewModels
{
    public class DashboardViewModel
    {
        // Filtres

        // "jour", "semaine", "mois" ou "perso" (dates saisies)
        public string Periode { get; set; } = "jour";

        public DateTime? DateDebut { get; set; }

        public DateTime? DateFin { get; set; }

        public string? StatutJournee { get; set; }

        public int? CaisseId { get; set; }

        public List<SelectListItem> ListeCaisses { get; set; } = new();

        // Montants de la période

        // Fond de caisse au début de la période : solde initial de la première
        // journée de chaque caisse (et non la somme de toutes les journées).
        public decimal MontantInitial { get; set; }

        public decimal Entrees { get; set; }

        public decimal Sorties { get; set; }

        public decimal ResultatNet => Entrees - Sorties;

        public decimal Solde => MontantInitial + Entrees - Sorties;

        // Variation par rapport à la période précédente de même durée
        // (null quand la période précédente est vide).
        public decimal? VariationEntrees { get; set; }

        public decimal? VariationSorties { get; set; }

        // Statistiques

        public int NombreOperations { get; set; }

        public int NombreEncaissements { get; set; }

        public int NombreDecaissements { get; set; }

        public int NombreCaissesOuvertes { get; set; }

        // À traiter

        public int OperationsEnAttente { get; set; }

        public int? JourneeOperationEnAttenteId { get; set; }

        public int DecaissementsNonJustifies { get; set; }

        public int? JourneeNonJustifieId { get; set; }

        public int JourneesOuvertesAnciennes { get; set; }

        public int? JourneeOuverteAncienneId { get; set; }

        public bool RienATraiter =>
            OperationsEnAttente == 0 && DecaissementsNonJustifies == 0 && JourneesOuvertesAnciennes == 0;

        // Raccourci "Nouvelle opération" : la journée ouverte quand il n'y en a qu'une.
        public int? JourneeOuverteId { get; set; }

        // Blocs détaillés

        public string TitreFlux { get; set; } = "";

        public List<FluxPeriodeViewModel> Flux { get; set; } = new();

        public List<EtatCaisseViewModel> EtatCaisses { get; set; } = new();

        public List<RepartitionViewModel> EntreesParMode { get; set; } = new();

        public List<RepartitionViewModel> TopMotifsSortie { get; set; } = new();

        public List<OperationDashboardViewModel> DernieresOperations { get; set; } = new();
    }

    public class FluxPeriodeViewModel
    {
        public string Libelle { get; set; } = "";

        public decimal Entrees { get; set; }

        public decimal Sorties { get; set; }
    }

    public class EtatCaisseViewModel
    {
        public int CaisseId { get; set; }

        public string Nom { get; set; } = "";

        public int? JourneeId { get; set; }

        public string? Statut { get; set; }

        public DateTime? DateOuverture { get; set; }

        public DateTime? DateFermeture { get; set; }

        public string? Caissier { get; set; }

        public decimal Solde { get; set; }
    }

    public class RepartitionViewModel
    {
        public string Libelle { get; set; } = "";

        public decimal Montant { get; set; }

        public decimal Pourcentage { get; set; }
    }

    public class OperationDashboardViewModel
    {
        public int JourneeId { get; set; }

        public DateTime DateOperation { get; set; }

        public string Reference { get; set; }

        public string Libelle { get; set; }

        public string TypeOperation { get; set; }

        public decimal Montant { get; set; }

        public string Caissier { get; set; }

        public string? ModePaiement { get; set; }

        public string StatutValidation { get; set; }
    }
}
