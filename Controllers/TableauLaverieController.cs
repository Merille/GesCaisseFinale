using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Models.ViewModels;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Tableau de bord de la laverie (société qui a une caisse de type Laverie) : une page à part, en
    // tuiles, à côté du tableau de bord général (inchangé). Dépôts et retraits du jour et de la semaine,
    // linge à retirer et en retard, clients servis, articles, produits d'entretien, caisse du jour ;
    // graphique des 14 derniers jours ; linge prêt à remettre et en retard. Comme tableaulaverie.php.
    [Authorize]
    public class TableauLaverieController : Controller
    {
        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public TableauLaverieController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        public async Task<IActionResult> Index()
        {
            if (!await _context.Caisses.AnyAsync(c => c.TypePointVente == "Laverie"))
                return RedirectToAction("Index", "Dashboard");
            var aujourdhui = DateTime.Today;
            var demain = aujourdhui.AddDays(1);
            var lundi = aujourdhui.AddDays(-(((int)aujourdhui.DayOfWeek + 6) % 7));
            var mois = new DateTime(aujourdhui.Year, aujourdhui.Month, 1);
            var depots = _context.DepotsLinge.AsNoTracking();
            var nonAnnules = depots.Where(d => d.Statut != DepotLinge.Annule);
            var actifs = depots.Where(d => d.Statut == DepotLinge.EnCours || d.Statut == DepotLinge.Pret);
            var vm = new TableauLaverieVM();

            var jour = await nonAnnules.Where(d => d.DateDepot >= aujourdhui && d.DateDepot < demain)
                .Select(d => new { d.NbArticles, d.Total }).ToListAsync();
            vm.DepotsJour = jour.Count;
            vm.ArticlesJour = jour.Sum(d => d.NbArticles);
            vm.MontantJour = jour.Sum(d => d.Total);
            vm.DepotsSemaine = await nonAnnules.CountAsync(d => d.DateDepot >= lundi && d.DateDepot < demain);

            var retraits = await depots.Where(d => d.Statut == DepotLinge.Retire && d.DateRetrait >= lundi && d.DateRetrait < demain)
                .Select(d => new { d.DateRetrait, d.Total }).ToListAsync();
            vm.RetraitsSemaine = retraits.Count;
            vm.RetraitsJour = retraits.Count(d => d.DateRetrait >= aujourdhui);
            vm.MontantRetraitsJour = retraits.Where(d => d.DateRetrait >= aujourdhui).Sum(d => d.Total);

            var aRetirer = await actifs.Select(d => new { d.Statut, d.Total, d.Acompte, d.DateRetraitPrevue }).ToListAsync();
            vm.ARetirer = aRetirer.Count;
            vm.Prets = aRetirer.Count(d => d.Statut == DepotLinge.Pret);
            vm.Reste = aRetirer.Sum(d => Math.Max(0, d.Total - d.Acompte));
            var retard = aRetirer.Where(d => d.DateRetraitPrevue < aujourdhui).ToList();
            vm.Retard = retard.Count;
            vm.PlusAncienRetard = retard.Min(d => d.DateRetraitPrevue);
            vm.ResteRetard = retard.Sum(d => Math.Max(0, d.Total - d.Acompte));

            // Clients servis ce mois (dépôts) : par fiche client, sinon par téléphone ou nom.
            var duMois = await nonAnnules.Where(d => d.DateDepot >= mois).Select(d => new { d.ClientId, d.TelephoneClient, d.NomClient, d.Contenu }).ToListAsync();
            vm.ClientsMois = duMois.Select(d => d.ClientId.HasValue ? "c" + d.ClientId : !string.IsNullOrEmpty(d.TelephoneClient) ? "t" + d.TelephoneClient : "n" + d.NomClient).Distinct().Count();
            vm.ClientsTotal = await _context.Clients.CountAsync(c => c.Type == "Client");
            if (_tenant.TenantId != 0)
                vm.Du = (await _context.SoldesComptesAsync(_tenant.TenantId)).Values.Where(v => v > 0).Sum();

            // Articles : en vente, catégories ; les plus déposés ce mois (contenu des dépôts).
            vm.Articles = await _context.Produits.CountAsync(p => p.Actif && !p.Consommable && !p.EstModele);
            vm.Categories = await _context.Categories.CountAsync();
            var parArticle = new Dictionary<string, decimal>();
            foreach (var d in duMois)
                foreach (var l in Restaurant.Lire(d.Contenu).Lignes.Where(l => l.Nom != ""))
                    parArticle[l.Nom] = parArticle.GetValueOrDefault(l.Nom) + l.Qte;
            vm.TopArticles = parArticle.OrderByDescending(x => x.Value).Take(5).Select(x => (x.Key, x.Value)).ToList();

            // Produits d'entretien : à racheter, valeur du stock du dépôt des achats, achats du mois.
            vm.ARacheter = _context.EntretienEnAlerte().Count;
            vm.ValeurEntretien = await (from p in _context.Produits
                                        join dp in _context.Depots on p.TenantId equals dp.TenantId
                                        join s in _context.StocksDepots on new { P = p.Id, D = dp.Id } equals new { P = s.ProduitId, D = s.DepotId }
                                        where dp.DepotAchats && p.Consommable && p.Actif
                                        select (decimal?)(s.Quantite * (p.Cout ?? 0))).SumAsync() ?? 0;
            vm.AchatsMois = await _context.Achats.Where(a => a.Statut == "Validé" && a.DateAchat >= mois).SumAsync(a => (decimal?)a.Total) ?? 0;

            // Caisse : journées ouvertes des caisses Laverie, encaissements du jour (hors rejetés).
            vm.Journees = (await _context.JourneesCaisses.Include(j => j.Caisse)
                    .Where(j => j.Statut == "Ouverte" && j.Caisse.TypePointVente == "Laverie").OrderBy(j => j.Caisse.ChkCode).ToListAsync())
                .Select(j => (j.Id, j.Caisse.ChkCode ?? "")).ToList();
            vm.Encaissements = await _context.OperationsCaisses
                .Where(o => o.JourneeCaisse.Caisse.TypePointVente == "Laverie" && o.TypeOperation == "Encaissement" && o.StatutValidation != "Rejeté"
                            && o.DateOperation >= aujourdhui && o.DateOperation < demain)
                .SumAsync(o => (decimal?)o.Montant) ?? 0;

            // 14 derniers jours : dépôts et retraits par jour.
            var debut = aujourdhui.AddDays(-13);
            var dates = await nonAnnules.Where(d => d.DateDepot >= debut).Select(d => d.DateDepot).ToListAsync();
            var datesRetrait = await depots.Where(d => d.Statut == DepotLinge.Retire && d.DateRetrait >= debut).Select(d => d.DateRetrait!.Value).ToListAsync();
            vm.Jours = Enumerable.Range(0, 14).Select(i => debut.AddDays(i))
                .Select(j => (j, dates.Count(d => d.Date == j), datesRetrait.Count(d => d.Date == j))).ToList();

            vm.PretsListe = await depots.Where(d => d.Statut == DepotLinge.Pret).OrderBy(d => d.DatePret).ThenBy(d => d.Numero).Take(8).ToListAsync();
            vm.RetardsListe = await actifs.Where(d => d.DateRetraitPrevue < aujourdhui).OrderBy(d => d.DateRetraitPrevue).ThenBy(d => d.Numero).Take(8).ToListAsync();
            return View(vm);
        }
    }
}
