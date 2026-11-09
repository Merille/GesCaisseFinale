namespace EasytransitCaisse.Models.ViewModels;

// Filtres du rapport des livraisons (par défaut : du 1er du mois à aujourd'hui).
public class FiltresRapportLivraison
{
    public DateTime Du { get; set; }
    public DateTime Au { get; set; }
    public int Livreur { get; set; }
    public string Statut { get; set; } = "";

    public static readonly string[] Statuts = { "Livrée", "À livrer", "À encaisser" };

    // Paramètres d'URL des filtres (liens Imprimer et Excel).
    public string Requete()
    {
        var p = new Dictionary<string, string> { ["du"] = Du.ToString("yyyy-MM-dd"), ["au"] = Au.ToString("yyyy-MM-dd") };
        if (Livreur > 0) p["livreur"] = Livreur.ToString();
        if (Statut != "") p["statut"] = Statut;
        return string.Join("&", p.Select(x => x.Key + "=" + Uri.EscapeDataString(x.Value)));
    }
}

// Une livraison : vente avec livreur (Vente = true) ou commande confiée au livreur, à encaisser.
public class LigneLivraison
{
    public int Id { get; set; }
    public bool Vente { get; set; }
    public string Numero { get; set; } = "";
    public DateTime Date { get; set; }
    public decimal Montant { get; set; }
    public decimal Frais { get; set; }
    public string Statut { get; set; } = "";
    public DateTime? DateLivraison { get; set; }
    public string? Destinataire { get; set; }
    public string? Telephone { get; set; }
    public string? Adresse { get; set; }
    public int LivreurId { get; set; }
    public string? Livreur { get; set; }
    public string? Moyen { get; set; }
    public string? Client { get; set; }
}

// Synthèse d'un livreur (ou total).
public class SyntheseLivreur
{
    public string? Livreur { get; set; }
    public string? Moyen { get; set; }
    public int Livraisons { get; set; }
    public int Livrees { get; set; }
    public int ALivrer { get; set; }
    public int AEncaisser { get; set; }
    public decimal Montant { get; set; }
    public decimal Frais { get; set; }

    public void Ajouter(LigneLivraison l)
    {
        Livraisons++;
        if (l.Statut == "Livrée") Livrees++;
        else if (l.Statut == "À encaisser") AEncaisser++;
        else ALivrer++;
        Montant += l.Montant;
        Frais += l.Frais;
    }
}

public class RapportLivraisonVM
{
    public FiltresRapportLivraison Filtres { get; set; } = new();
    public List<LigneLivraison> Lignes { get; set; } = new();
    public List<SyntheseLivreur> ParLivreur { get; set; } = new();
    public SyntheseLivreur Total { get; set; } = new();
    public List<Livreur> Livreurs { get; set; } = new();
}
