namespace EasytransitCaisse.Models.ViewModels
{
    // Rapports du point de vente. Chiffre d'affaires net TTC = ventes - retours ;
    // les ventes annulées sont exclues.
    public class PosRapportVM
    {
        public DateTime DateDebut { get; set; }
        public DateTime DateFin { get; set; }
        public int? CaisseId { get; set; }
        public string? CaisseLibelle { get; set; }

        // Rotativa ne transmet pas le ViewBag : la société et l'auteur voyagent dans le modèle.
        public string Societe { get; set; } = "";
        public string EditePar { get; set; } = "";

        public decimal ChiffreAffaires { get; set; }
        public decimal ChiffreAffairesHT { get; set; }
        public decimal Ventes { get; set; }
        public int Tickets { get; set; }
        public decimal PanierMoyen => Tickets > 0 ? Ventes / Tickets : 0;
        public decimal Articles { get; set; }
        public decimal Retours { get; set; }
        public int NbRetours { get; set; }
        public int Annulees { get; set; }

        public List<PosRapportPeriode> ParJour { get; set; } = new();
        public List<PosRapportPeriode> ParHeure { get; set; } = new();
        public List<PosRapportProduit> Produits { get; set; } = new();
        public List<PosRapportCategorie> Categories { get; set; } = new();
        public List<PosRapportVendeur> Vendeurs { get; set; } = new();
        public List<PosRapportMode> Modes { get; set; } = new();
        public List<PosRapportMode> Taxes { get; set; } = new();

        // Part du chiffre d'affaires net, en pourcentage.
        public decimal Part(decimal montant) => ChiffreAffaires != 0 ? montant * 100 / ChiffreAffaires : 0;
    }

    public class PosRapportPeriode
    {
        public DateTime Date { get; set; }
        public int Heure { get; set; }
        public int Tickets { get; set; }
        public decimal Montant { get; set; }
    }

    public class PosRapportProduit
    {
        public string? Code { get; set; }
        public string Nom { get; set; } = "";
        public string Categorie { get; set; } = "";
        public decimal Quantite { get; set; }
        public decimal Montant { get; set; }
    }

    public class PosRapportCategorie
    {
        public string Nom { get; set; } = "";
        public string? Couleur { get; set; }
        public decimal Quantite { get; set; }
        public decimal Montant { get; set; }
    }

    public class PosRapportVendeur
    {
        public string Nom { get; set; } = "";
        public int Tickets { get; set; }
        public decimal Ventes { get; set; }
        public decimal Retours { get; set; }
        public decimal Montant { get; set; }
        public decimal? PanierMoyen => Tickets > 0 ? Ventes / Tickets : null;
    }

    public class PosRapportMode
    {
        public string Nom { get; set; } = "";
        public int Tickets { get; set; }
        public decimal Montant { get; set; }
    }
}
