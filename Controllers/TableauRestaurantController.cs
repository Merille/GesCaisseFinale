using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Models.ViewModels;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Tableau de bord du restaurant-bar (société qui a une caisse de type Restaurant ou Bar) : une page à
    // part, en tuiles, à côté du tableau de bord général (inchangé). Ventes, tables et couverts, bons en
    // cuisine et au bar, livraisons, meilleures ventes, stock, caisse du jour ; chiffre d'affaires des
    // 14 derniers jours ; tables occupées et bons en attente. Comme tableaurestaurant.php.
    [Authorize]
    public class TableauRestaurantController : Controller
    {
        private readonly AppDbContext _context;

        public TableauRestaurantController(AppDbContext context) => _context = context;

        public async Task<IActionResult> Index()
        {
            if (!Restaurant.Actif(_context))
                return RedirectToAction("Index", "Dashboard");
            var aujourdhui = DateTime.Today;
            var demain = aujourdhui.AddDays(1);
            var lundi = aujourdhui.AddDays(-(((int)aujourdhui.DayOfWeek + 6) % 7));
            var caisses = await _context.Caisses.Where(c => c.TypePointVente == "Restaurant" || c.TypePointVente == "Bar").Select(c => c.ID).ToListAsync();
            var journeesResto = _context.JourneesCaisses.Where(j => caisses.Contains(j.CaisseId)).Select(j => j.Id);
            var ventes = _context.CommandesPos.AsNoTracking().Where(v => v.Statut != "Annulée" && journeesResto.Contains(v.JourneeCaisseId));
            var vm = new TableauRestaurantVM();

            // Ventes : chiffre d'affaires net (ventes - retours), tickets, panier moyen, couverts, pourboires.
            var duJour = await ventes.Where(v => v.DateCommande >= aujourdhui && v.DateCommande < demain)
                .Select(v => new { v.Statut, v.TotalTTC, v.Couverts, v.Pourboire }).ToListAsync();
            var vraies = duJour.Where(v => v.Statut != "Retour").ToList();
            vm.CAJour = duJour.Sum(v => v.TotalTTC);
            vm.Tickets = vraies.Count;
            vm.VentesJour = vraies.Sum(v => v.TotalTTC);
            vm.CouvertsJour = vraies.Sum(v => v.Couverts ?? 0);
            vm.VentesCouverts = vraies.Where(v => v.Couverts > 0).Sum(v => v.TotalTTC);
            vm.Pourboires = duJour.Sum(v => v.Pourboire);
            var semaine = await ventes.Where(v => v.DateCommande >= lundi && v.DateCommande < demain)
                .Select(v => new { v.Statut, v.TotalTTC, v.Couverts }).ToListAsync();
            vm.CASemaine = semaine.Sum(v => v.TotalTTC);
            vm.CouvertsSemaine = semaine.Where(v => v.Statut != "Retour").Sum(v => v.Couverts ?? 0);

            // Tables : occupées / actives, couverts en salle, montant des commandes en cours (toutes commandes ouvertes).
            vm.Tables = await (from t in _context.TablesRestaurant join s in _context.Salles on t.SalleId equals s.Id
                               where t.Actif && caisses.Contains(s.CaisseId) select t.Id).CountAsync();
            var ouvertes = await (from o in _context.CommandesOuvertes.AsNoTracking()
                                  where caisses.Contains(o.CaisseId)
                                  join t in _context.TablesRestaurant on o.TableId equals t.Id into tt
                                  from t in tt.DefaultIfEmpty()
                                  join u in _context.Utilisateurs on o.UtilisateurId equals u.Id into uu
                                  from u in uu.DefaultIfEmpty()
                                  orderby o.DateOuverture, o.Id
                                  select new { o.TableId, o.Couverts, o.DateOuverture, o.Contenu, Table = t != null ? t.Nom : null,
                                               Serveur = u != null ? (u.NomComplet != "" ? u.NomComplet : u.NomUtilisateur) : null }).ToListAsync();
            var avecTotal = ouvertes.Select(o => new { o, Total = Restaurant.Total(Restaurant.Lire(o.Contenu)) }).ToList();
            vm.NbOuvertes = ouvertes.Count;
            vm.EnCours = avecTotal.Sum(x => x.Total);
            vm.Occupees = ouvertes.Count(o => o.TableId != null);
            vm.CouvertsSalle = ouvertes.Where(o => o.TableId != null).Sum(o => o.Couverts);
            vm.TablesOccupees = avecTotal.Where(x => x.o.TableId != null).Take(8)
                .Select(x => new TableauRestaurantVM.TableOccupee(x.o.Table ?? "?", x.o.Couverts, x.o.Serveur, x.o.DateOuverture, x.Total)).ToList();

            // Cuisine et bar : bons à préparer, par poste, le plus ancien.
            var bons = await _context.BonsPreparation.AsNoTracking().Where(b => b.Statut == "À préparer" && caisses.Contains(b.CaisseId))
                .OrderBy(b => b.DateEnvoi).ThenBy(b => b.Id)
                .Select(b => new { b.Numero, b.Poste, b.TableNom, b.DateEnvoi, Lignes = b.Lignes.Count }).ToListAsync();
            vm.NbBons = bons.Count;
            vm.BonsCuisine = bons.Count(b => b.Poste == "Cuisine");
            vm.BonsBar = bons.Count(b => b.Poste == "Bar");
            vm.Attente = bons.Count > 0 ? Math.Max(0, (int)Math.Floor((DateTime.Now - bons[0].DateEnvoi).TotalMinutes)) : 0;
            vm.Bons = bons.Take(8).Select(b => new TableauRestaurantVM.BonEnAttente(b.Numero, b.Poste, b.TableNom, b.Lignes, b.DateEnvoi)).ToList();

            // Livraisons : à livrer, à encaisser (commandes en attente confiées à un livreur, frais compris), livrées aujourd'hui.
            vm.ALivrer = await ventes.CountAsync(v => v.StatutLivraison == "À livrer");
            var attentes = await _context.CommandesAttente.Where(a => a.LivreurId != null && journeesResto.Contains(a.JourneeCaisseId))
                .Select(a => new { a.Total, a.Contenu }).ToListAsync();
            vm.AEncaisser = attentes.Count;
            vm.MontantAEncaisser = attentes.Sum(a => a.Total + Notifications.FraisLivraison(a.Contenu));
            vm.Livrees = await ventes.CountAsync(v => v.StatutLivraison == "Livrée" && v.DateLivraison >= aujourdhui && v.DateLivraison < demain);

            // Meilleures ventes du jour : article le plus vendu (quantité), catégorie (chiffre d'affaires), articles vendus.
            var lignes = await (from l in _context.LignesCommandePos
                                join v in ventes on l.CommandePosId equals v.Id
                                where v.DateCommande >= aujourdhui && v.DateCommande < demain
                                join p in _context.Produits on l.ProduitId equals p.Id into pp
                                from p in pp.DefaultIfEmpty()
                                join c in _context.Categories on p.CategorieId equals c.Id into cc
                                from c in cc.DefaultIfEmpty()
                                select new { l.ProduitId, l.Libelle, l.Quantite, l.TotalTTC, Nom = p != null ? p.Nom : null, CategorieId = c != null ? (int?)c.Id : null, Categorie = c != null ? c.Nom : null })
                               .ToListAsync();
            vm.ArticlesVendus = lignes.Sum(l => l.Quantite);
            vm.Top = lignes.GroupBy(l => l.ProduitId.HasValue ? l.ProduitId.ToString() : "#" + l.Libelle)
                .Select(g => (Nom: g.First().Nom ?? g.First().Libelle, Qte: g.Sum(l => l.Quantite)))
                .Where(x => x.Qte > 0).OrderByDescending(x => x.Qte).ThenBy(x => x.Nom, StringComparer.Ordinal).Cast<(string, decimal)?>().FirstOrDefault();
            vm.TopCategorie = lignes.GroupBy(l => l.CategorieId)
                .Select(g => (Nom: g.First().Categorie ?? "Sans catégorie", CA: g.Sum(l => l.TotalTTC)))
                .Where(x => x.CA > 0).OrderByDescending(x => x.CA).ThenBy(x => x.Nom, StringComparer.Ordinal).Cast<(string, decimal)?>().FirstOrDefault();

            // Stock : produits sous le seuil d'alerte (hors produits d'entretien), en rupture, suivis.
            var suivis = _context.Produits.Where(p => p.SuiviStock && p.Actif && !p.EstModele && !p.Consommable);
            vm.Suivis = await suivis.CountAsync();
            vm.StockBas = await suivis.CountAsync(p => p.SeuilAlerte != null && p.StockActuel <= p.SeuilAlerte);
            vm.Ruptures = await suivis.CountAsync(p => p.StockActuel <= 0);

            // Caisse : journées ouvertes des caisses Restaurant / Bar, encaissements du jour (hors rejetés).
            vm.Journees = (await _context.JourneesCaisses.Include(j => j.Caisse)
                    .Where(j => j.Statut == "Ouverte" && caisses.Contains(j.CaisseId)).OrderBy(j => j.Caisse.ChkCode).ToListAsync())
                .Select(j => (j.Id, j.Caisse.ChkCode ?? "")).ToList();
            vm.Encaissements = await _context.OperationsCaisses
                .Where(o => journeesResto.Contains(o.JourneeCaisseId) && o.TypeOperation == "Encaissement" && o.StatutValidation != "Rejeté"
                            && o.DateOperation >= aujourdhui && o.DateOperation < demain)
                .SumAsync(o => (decimal?)o.Montant) ?? 0;

            // 14 derniers jours : chiffre d'affaires net par jour.
            var debut = aujourdhui.AddDays(-13);
            var parJour = await ventes.Where(v => v.DateCommande >= debut).Select(v => new { v.DateCommande, v.TotalTTC }).ToListAsync();
            vm.Jours = Enumerable.Range(0, 14).Select(i => debut.AddDays(i))
                .Select(j => (j, parJour.Where(v => v.DateCommande.Date == j).Sum(v => v.TotalTTC))).ToList();
            return View(vm);
        }
    }
}
