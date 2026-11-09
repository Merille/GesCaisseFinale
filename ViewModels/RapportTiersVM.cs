namespace EasytransitCaisse.Models.ViewModels;

// Filtres du rapport des tiers (par défaut : du 1er du mois à aujourd'hui).
public class FiltresRapportTiers
{
    public DateTime Du { get; set; }
    public DateTime Au { get; set; }
    public string Type { get; set; } = "";
    public string Genre { get; set; } = "";
    public bool Tous { get; set; }

    public static readonly string[] Types = { "Client", "Fournisseur", "Salarié", "Autre" };

    // Paramètres d'URL des filtres (liens Imprimer, Excel, relevé).
    public Dictionary<string, string> Parametres()
    {
        var p = new Dictionary<string, string> { ["du"] = Du.ToString("yyyy-MM-dd"), ["au"] = Au.ToString("yyyy-MM-dd") };
        if (Type != "") p["type"] = Type;
        if (Genre != "") p["genre"] = Genre;
        if (Tous) p["tous"] = "1";
        return p;
    }

    public string Requete(int? id = null)
    {
        var p = Parametres();
        if (id.HasValue) p["id"] = id.Value.ToString();
        return string.Join("&", p.Select(x => x.Key + "=" + Uri.EscapeDataString(x.Value)));
    }
}

// Une ligne par tiers : ventes du point de vente, encaissements, décaissements, solde.
public class LigneRapportTiers
{
    public int Id { get; set; }
    public string Code { get; set; } = "";
    public string Nom { get; set; } = "";
    public string Genre { get; set; } = "";
    public string? Type { get; set; }
    public int NbVentes { get; set; }
    public decimal Ventes { get; set; }
    public decimal Encaissements { get; set; }
    public decimal Decaissements { get; set; }
    public decimal Solde => Encaissements - Decaissements;
    public DateTime? Dernier { get; set; }
    // Client en compte : solde dû à la fin de la période (null pour les autres tiers).
    public decimal? Du { get; set; }
}

public class RapportTiersVM
{
    public FiltresRapportTiers Filtres { get; set; } = new();
    public List<LigneRapportTiers> Lignes { get; set; } = new();
    public int NbVentes => Lignes.Sum(l => l.NbVentes);
    public decimal Ventes => Lignes.Sum(l => l.Ventes);
    public decimal Encaissements => Lignes.Sum(l => l.Encaissements);
    public decimal Decaissements => Lignes.Sum(l => l.Decaissements);
    public decimal Solde => Encaissements - Decaissements;
    public decimal Du => Lignes.Sum(l => l.Du ?? 0);
}

// Relevé d'un tiers sur la période : opérations de caisse et ventes du point de vente.
public class ReleveTiersVM
{
    public FiltresRapportTiers Filtres { get; set; } = new();
    public Client Tiers { get; set; } = null!;
    public List<OperationCaisse> Operations { get; set; } = new();
    public List<CommandePos> Ventes { get; set; } = new();
    public decimal Encaissements { get; set; }
    public decimal Decaissements { get; set; }
    public decimal VentesNettes { get; set; }
    // Libellés des paiements de chaque vente (Id de la vente → « Espèces, Compte client »).
    public Dictionary<int, string> Paiements { get; set; } = new();
    // Client en compte : solde dû au début et à la fin de la période, ventes par compte, règlements.
    public CompteReleve? Compte { get; set; }
}

public class CompteReleve
{
    public decimal Debut { get; set; }
    public decimal Fin { get; set; }
    public decimal Reglements { get; set; }
    public decimal Ventes => Fin - Debut + Reglements;
    public decimal? Plafond { get; set; }
}
