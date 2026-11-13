using EasytransitCaisse.Models;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Data
{
    // Notification de la cloche : nombre, texte, lien, icône et couleur.
    public record Notification(int N, string Texte, string Url, string Icone, string Couleur);

    // Notifications de la cloche (barre du haut) : ce qui attend une action, toutes caisses confondues.
    // Pour tous : opérations en attente de validation, décaissements sans justificatif, journées ouvertes
    // depuis plus de 24 h (lien vers la plus ancienne journée concernée) ; module Point de vente : livraisons
    // à livrer (ventes payées pas encore livrées) et à encaisser (commandes confiées à un livreur). Administrateurs, module Point de
    // vente : produits sous le seuil d'alerte (hors produits d'entretien), et en laverie, produits
    // d'entretien à racheter et dépôts de linge en retard. Comme notifications() en PHP.
    public static class Notifications
    {
        private static string Pluriel(int n, string mot) => $"{n} " + System.Text.RegularExpressions.Regex.Replace(mot, @"(\w+)%s", n > 1 ? "$1s" : "$1");

        // Frais de livraison lus dans le contenu d'une commande en attente (« livraison.frais »).
        private static decimal FraisLivraison(string? contenu)
        {
            try
            {
                using var json = System.Text.Json.JsonDocument.Parse(contenu ?? "{}");
                return json.RootElement.TryGetProperty("livraison", out var l) && l.ValueKind == System.Text.Json.JsonValueKind.Object
                    && l.TryGetProperty("frais", out var f) && f.TryGetDecimal(out var d) ? d : 0;
            }
            catch (System.Text.Json.JsonException) { return 0; }
        }

        public static List<Notification> Lister(AppDbContext context, bool admin, bool modulePointVente)
        {
            var liste = new List<Notification>();
            void Ajouter(int n, string texte, string url, string icone, string couleur)
            {
                if (n > 0)
                    liste.Add(new Notification(n, Pluriel(n, texte), url, icone, couleur));
            }
            var enAttente = context.OperationsCaisses.Where(o => o.StatutValidation == "En attente");
            var nonJustifies = context.OperationsCaisses.Where(o => o.TypeOperation == "Décaissement" && !o.EstJustifie && o.StatutValidation != OperationCaisseQueries.StatutRejete);
            foreach (var (requete, texte, icone, couleur) in new[]
            {
                (enAttente, "opération%s en attente de validation", "fa-hourglass-half", "#c2410c"),
                (nonJustifies, "décaissement%s sans justificatif", "fa-file-circle-exclamation", "#b45309")
            })
            {
                var n = requete.Count();
                if (n > 0)
                    Ajouter(n, texte, $"/JourneeCaisse/Details/{requete.OrderBy(o => o.DateOperation).Select(o => o.JourneeCaisseId).First()}", icone, couleur);
            }
            var limite = DateTime.Now.AddHours(-24);
            var anciennes = context.JourneesCaisses.Where(j => j.Statut == "Ouverte" && j.DateOuverture < limite);
            var nbAnciennes = anciennes.Count();
            if (nbAnciennes > 0)
                Ajouter(nbAnciennes, "journée%s ouverte%s depuis plus de 24 h", $"/JourneeCaisse/Details/{anciennes.OrderBy(j => j.DateOuverture).Select(j => j.Id).First()}", "fa-clock", "#7c2d12");
            // Livraisons à livrer : ventes payées confiées à un livreur, pas encore marquées « Livrée » (montant
            // frais compris). Administrateur : rapport des livraisons filtré ; sinon écran de vente de la journée
            // (Commandes en attente › Marquer livrée), ou la vente si sa journée est clôturée.
            if (modulePointVente)
            {
                var aLivrer = context.CommandesPos.Where(c => c.StatutLivraison == "À livrer" && c.Statut != "Annulée")
                    .OrderBy(c => c.DateCommande).ThenBy(c => c.Id)
                    .Select(c => new { c.Id, c.JourneeCaisseId, c.DateCommande, Montant = c.TotalTTC + c.FraisLivraison,
                        Ouverte = context.JourneesCaisses.Any(j => j.Id == c.JourneeCaisseId && j.Statut == "Ouverte") })
                    .ToList();
                if (aLivrer.Count > 0)
                {
                    var p = aLivrer[0];
                    var url = admin
                        ? $"/RapportLivraison/Index?statut={Uri.EscapeDataString("À livrer")}&du={p.DateCommande:yyyy-MM-dd}&au={DateTime.Today:yyyy-MM-dd}"
                        : p.Ouverte ? $"/Pos/Index?journee={p.JourneeCaisseId}" : $"/Vente/Details/{p.Id}";
                    Ajouter(aLivrer.Count, $"livraison%s à livrer ({aLivrer.Sum(x => x.Montant).ToString("N0", System.Globalization.CultureInfo.GetCultureInfo("fr-FR"))} FCFA)", url, "fa-route", "#0f766e");
                }
            }
            // Livraisons à encaisser : commandes confiées à un livreur, encaissées à son retour (montant attendu,
            // frais de livraison compris). Administrateur : rapport des livraisons filtré ; sinon écran de vente.
            if (modulePointVente)
            {
                var attentes = context.CommandesAttente.Where(a => a.LivreurId != null).OrderBy(a => a.DateCreation)
                    .Select(a => new { a.JourneeCaisseId, a.DateCreation, a.Total, a.Contenu, Ouverte = context.JourneesCaisses.Any(j => j.Id == a.JourneeCaisseId && j.Statut == "Ouverte") })
                    .ToList();
                if (attentes.Count > 0)
                {
                    var montant = attentes.Sum(a => a.Total + FraisLivraison(a.Contenu));
                    var premiere = attentes[0];
                    var url = admin
                        ? $"/RapportLivraison/Index?statut={Uri.EscapeDataString("À encaisser")}&du={premiere.DateCreation:yyyy-MM-dd}&au={DateTime.Today:yyyy-MM-dd}"
                        : premiere.Ouverte ? $"/Pos/Index?journee={premiere.JourneeCaisseId}" : "/Pos/Index";
                    Ajouter(attentes.Count, $"livraison%s à encaisser ({montant.ToString("N0", System.Globalization.CultureInfo.GetCultureInfo("fr-FR"))} FCFA)", url, "fa-truck-fast", "#0369a1");
                }
            }
            if (admin && modulePointVente)
            {
                // Ventes faites hors ligne avec des écarts (après clôture, prix, stock, plafond) à vérifier.
                var aVerifier = context.CommandesPos.Where(c => c.AlerteHorsLigne != null && c.AlerteHorsLigneVue == null);
                var nbAVerifier = aVerifier.Count();
                if (nbAVerifier > 0)
                    Ajouter(nbAVerifier, "vente%s hors ligne à vérifier", "/Synchro/Index", "fa-wifi", "#b45309");
                // Postes qui ont des opérations faites hors ligne pas encore envoyées (page Synchronisation).
                Ajouter(context.PostesHorsLigne.Count(p => p.EnAttente > 0), "poste%s avec des opérations hors ligne à envoyer", "/Synchro/Index", "fa-cloud-arrow-up", "#c2410c");
                Ajouter(context.Produits.Count(p => p.SuiviStock && p.Actif && !p.EstModele && !p.Consommable && p.SeuilAlerte != null && p.StockActuel <= p.SeuilAlerte),
                    "produit%s sous le seuil d'alerte", "/Stock/Index", "fa-boxes-stacked", "#dc2626");
                Ajouter(context.EntretienEnAlerte().Count, "produit%s d'entretien à racheter", "/Achat/Stock", "fa-bottle-droplet", "#dc2626");
                if (context.Caisses.Any(c => c.TypePointVente == "Laverie"))
                {
                    var aujourdHui = DateTime.Today;
                    Ajouter(context.DepotsLinge.Count(d => (d.Statut == DepotLinge.EnCours || d.Statut == DepotLinge.Pret) && d.DateRetraitPrevue < aujourdHui),
                        "dépôt%s de linge en retard", "/RapportLinge/Index?statut=En%20retard", "fa-shirt", "#7c3aed");
                }
            }
            return liste;
        }
    }
}
