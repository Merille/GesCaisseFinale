using System.Globalization;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    public class DashboardController : Controller
    {
        private readonly AppDbContext _context;

        private static readonly CultureInfo Fr = new CultureInfo("fr-FR");

        public DashboardController(AppDbContext context)
        {
            _context = context;
        }

        public IActionResult Index(
            string? periode,
            DateTime? dateDebut,
            DateTime? dateFin,
            string? statutJournee,
            int? caisseId)
        {
            // ==========================
            // PÉRIODE
            // ==========================

            var aujourdhui = DateTime.Today;

            if (string.IsNullOrWhiteSpace(periode))
            {
                periode = dateDebut.HasValue || dateFin.HasValue ? "perso" : "jour";
            }

            switch (periode)
            {
                case "semaine":
                    dateDebut = aujourdhui.AddDays(-6);
                    dateFin = aujourdhui;
                    break;
                case "mois":
                    dateDebut = new DateTime(aujourdhui.Year, aujourdhui.Month, 1);
                    dateFin = aujourdhui;
                    break;
                case "perso":
                    dateDebut ??= aujourdhui;
                    dateFin ??= aujourdhui;
                    break;
                default:
                    periode = "jour";
                    dateDebut = aujourdhui;
                    dateFin = aujourdhui;
                    break;
            }

            var debut = dateDebut.Value.Date;
            var fin = dateFin.Value.Date;

            if (fin < debut)
            {
                (debut, fin) = (fin, debut);
            }

            var model = new DashboardViewModel
            {
                Periode = periode,
                DateDebut = debut,
                DateFin = fin,
                StatutJournee = statutJournee,
                CaisseId = caisseId
            };

            // ==========================
            // LISTE DES CAISSES
            // ==========================

            model.ListeCaisses = _context.Caisses
                .OrderBy(c => c.ChkDescription)
                .Select(c => new SelectListItem
                {
                    Value = c.ID.ToString(),
                    Text = c.ChkCode + " - " + c.ChkDescription
                })
                .ToList();

            model.ListeCaisses.Insert(0, new SelectListItem
            {
                Value = "",
                Text = "-- Toutes les caisses --"
            });

            // ==========================
            // REQUÊTES DE BASE (filtres caisse + statut, sans les dates)
            // ==========================

            var journeesFiltrees = _context.JourneesCaisses.AsQueryable();
            var operationsFiltrees = _context.OperationsCaisses.AsQueryable();

            if (caisseId.HasValue)
            {
                journeesFiltrees = journeesFiltrees.Where(j => j.CaisseId == caisseId.Value);
                operationsFiltrees = operationsFiltrees.Where(o => o.JourneeCaisse.CaisseId == caisseId.Value);
            }

            if (!string.IsNullOrWhiteSpace(statutJournee))
            {
                journeesFiltrees = journeesFiltrees.Where(j => j.Statut == statutJournee);
                operationsFiltrees = operationsFiltrees.Where(o => o.JourneeCaisse.Statut == statutJournee);
            }

            var finExclue = fin.AddDays(1);

            var operations = operationsFiltrees.Where(o =>
                o.DateOperation >= debut && o.DateOperation < finExclue);

            // ==========================
            // MONTANTS ET COMPTEURS
            // ==========================

            var totaux = operations
                .GroupBy(o => o.TypeOperation)
                .Select(g => new { Type = g.Key, Nombre = g.Count(), Montant = g.Sum(o => o.Montant) })
                .ToList();

            var encaissements = totaux.FirstOrDefault(t => t.Type == "Encaissement");
            var decaissements = totaux.FirstOrDefault(t => t.Type == "Décaissement");

            model.Entrees = encaissements?.Montant ?? 0;
            model.Sorties = decaissements?.Montant ?? 0;
            model.NombreEncaissements = encaissements?.Nombre ?? 0;
            model.NombreDecaissements = decaissements?.Nombre ?? 0;
            model.NombreOperations = totaux.Sum(t => t.Nombre);

            // Fond de caisse : solde initial de la première journée de chaque
            // caisse sur la période (additionner toutes les journées compterait
            // plusieurs fois le même fond).
            model.MontantInitial = journeesFiltrees
                .Where(j => j.DateJournee >= debut && j.DateJournee < finExclue)
                .GroupBy(j => j.CaisseId)
                .Select(g => g
                    .OrderBy(j => j.DateJournee)
                    .ThenBy(j => j.DateOuverture)
                    .Select(j => j.SoldeInitial)
                    .First())
                .ToList()
                .Sum();

            // Période précédente de même durée, pour les tendances.
            var duree = (fin - debut).Days + 1;
            var debutPrecedent = debut.AddDays(-duree);

            var totauxPrecedents = operationsFiltrees
                .Where(o => o.DateOperation >= debutPrecedent && o.DateOperation < debut)
                .GroupBy(o => o.TypeOperation)
                .Select(g => new { Type = g.Key, Montant = g.Sum(o => o.Montant) })
                .ToList();

            model.VariationEntrees = Variation(
                model.Entrees,
                totauxPrecedents.FirstOrDefault(t => t.Type == "Encaissement")?.Montant ?? 0);

            model.VariationSorties = Variation(
                model.Sorties,
                totauxPrecedents.FirstOrDefault(t => t.Type == "Décaissement")?.Montant ?? 0);

            // ==========================
            // ÉTAT DES CAISSES
            // ==========================

            var caisses = _context.Caisses.AsQueryable();

            if (caisseId.HasValue)
            {
                caisses = caisses.Where(c => c.ID == caisseId.Value);
            }

            var listeCaisses = caisses
                .OrderBy(c => c.ChkCode)
                .Select(c => new
                {
                    c.ID,
                    Nom = c.ChkCode + " · " + c.ChkDescription,
                    Caissier = _context.Utilisateurs
                        .Where(u => u.Id == c.CashierDefault)
                        .Select(u => u.NomComplet)
                        .FirstOrDefault()
                })
                .ToList();

            var idsCaisses = listeCaisses.Select(c => c.ID).ToList();

            // Dernière journée de chaque caisse.
            var dernieresJournees = _context.JourneesCaisses
                .Where(j => idsCaisses.Contains(j.CaisseId))
                .GroupBy(j => j.CaisseId)
                .Select(g => g.OrderByDescending(j => j.DateOuverture).First())
                .ToList();

            var idsJournees = dernieresJournees.Select(j => j.Id).ToList();

            var totauxJournees = _context.OperationsCaisses
                .Where(o => idsJournees.Contains(o.JourneeCaisseId))
                .GroupBy(o => new { o.JourneeCaisseId, o.TypeOperation })
                .Select(g => new { g.Key.JourneeCaisseId, g.Key.TypeOperation, Montant = g.Sum(o => o.Montant) })
                .ToList();

            model.EtatCaisses = listeCaisses
                .Select(c =>
                {
                    var journee = dernieresJournees.FirstOrDefault(j => j.CaisseId == c.ID);
                    var etat = new EtatCaisseViewModel { CaisseId = c.ID, Nom = c.Nom, Caissier = c.Caissier };

                    if (journee != null)
                    {
                        var entrees = totauxJournees
                            .Where(t => t.JourneeCaisseId == journee.Id && t.TypeOperation == "Encaissement")
                            .Sum(t => t.Montant);
                        var sorties = totauxJournees
                            .Where(t => t.JourneeCaisseId == journee.Id && t.TypeOperation == "Décaissement")
                            .Sum(t => t.Montant);

                        etat.JourneeId = journee.Id;
                        etat.Statut = journee.Statut;
                        etat.DateOuverture = journee.DateOuverture;
                        etat.DateFermeture = journee.DateFermeture;
                        etat.Solde = journee.SoldeInitial + entrees - sorties;
                    }

                    return etat;
                })
                .ToList();

            var journeesOuvertes = model.EtatCaisses
                .Where(c => c.Statut == "Ouverte" && c.JourneeId.HasValue)
                .ToList();

            model.NombreCaissesOuvertes = journeesOuvertes.Count;

            if (journeesOuvertes.Count == 1)
            {
                model.JourneeOuverteId = journeesOuvertes[0].JourneeId;
            }

            // ==========================
            // À TRAITER (toutes dates : un retard reste à traiter)
            // ==========================

            var operationsATraiter = _context.OperationsCaisses.AsQueryable();
            var journeesATraiter = _context.JourneesCaisses.AsQueryable();

            if (caisseId.HasValue)
            {
                operationsATraiter = operationsATraiter.Where(o => o.JourneeCaisse.CaisseId == caisseId.Value);
                journeesATraiter = journeesATraiter.Where(j => j.CaisseId == caisseId.Value);
            }

            var enAttente = operationsATraiter.Where(o => o.StatutValidation == "En attente");
            model.OperationsEnAttente = enAttente.Count();
            model.JourneeOperationEnAttenteId = enAttente
                .OrderBy(o => o.DateOperation)
                .Select(o => (int?)o.JourneeCaisseId)
                .FirstOrDefault();

            var nonJustifies = operationsATraiter.Where(o =>
                o.TypeOperation == "Décaissement" && !o.EstJustifie);
            model.DecaissementsNonJustifies = nonJustifies.Count();
            model.JourneeNonJustifieId = nonJustifies
                .OrderBy(o => o.DateOperation)
                .Select(o => (int?)o.JourneeCaisseId)
                .FirstOrDefault();

            var limiteOuverture = DateTime.Now.AddHours(-24);
            var ouvertesAnciennes = journeesATraiter.Where(j =>
                j.Statut == "Ouverte" && j.DateOuverture < limiteOuverture);
            model.JourneesOuvertesAnciennes = ouvertesAnciennes.Count();
            model.JourneeOuverteAncienneId = ouvertesAnciennes
                .OrderBy(j => j.DateOuverture)
                .Select(j => (int?)j.Id)
                .FirstOrDefault();

            // ==========================
            // FLUX (graphique)
            // ==========================

            if (duree <= 31)
            {
                // Au moins 7 jours affichés pour que le graphique reste parlant.
                var debutFlux = duree < 7 ? fin.AddDays(-6) : debut;

                var parJour = operationsFiltrees
                    .Where(o => o.DateOperation >= debutFlux && o.DateOperation < finExclue)
                    .GroupBy(o => new { o.DateOperation.Date, o.TypeOperation })
                    .Select(g => new { g.Key.Date, g.Key.TypeOperation, Montant = g.Sum(o => o.Montant) })
                    .ToList();

                model.TitreFlux = duree < 7 ? "Flux des 7 derniers jours" : "Flux par jour";

                for (var jour = debutFlux; jour <= fin; jour = jour.AddDays(1))
                {
                    model.Flux.Add(new FluxPeriodeViewModel
                    {
                        Libelle = jour.ToString("ddd dd", Fr),
                        Entrees = parJour.Where(x => x.Date == jour && x.TypeOperation == "Encaissement").Sum(x => x.Montant),
                        Sorties = parJour.Where(x => x.Date == jour && x.TypeOperation == "Décaissement").Sum(x => x.Montant)
                    });
                }
            }
            else
            {
                var parMois = operations
                    .GroupBy(o => new { o.DateOperation.Year, o.DateOperation.Month, o.TypeOperation })
                    .Select(g => new { g.Key.Year, g.Key.Month, g.Key.TypeOperation, Montant = g.Sum(o => o.Montant) })
                    .ToList();

                model.TitreFlux = "Flux par mois";

                for (var mois = new DateTime(debut.Year, debut.Month, 1); mois <= fin; mois = mois.AddMonths(1))
                {
                    model.Flux.Add(new FluxPeriodeViewModel
                    {
                        Libelle = mois.ToString("MMM yy", Fr),
                        Entrees = parMois.Where(x => x.Year == mois.Year && x.Month == mois.Month && x.TypeOperation == "Encaissement").Sum(x => x.Montant),
                        Sorties = parMois.Where(x => x.Year == mois.Year && x.Month == mois.Month && x.TypeOperation == "Décaissement").Sum(x => x.Montant)
                    });
                }
            }

            // ==========================
            // RÉPARTITIONS
            // ==========================

            var parMode = operations
                .Where(o => o.TypeOperation == "Encaissement")
                .GroupBy(o => o.ModePaiement != null ? o.ModePaiement.Libelle : null)
                .Select(g => new { Libelle = g.Key, Montant = g.Sum(o => o.Montant) })
                .OrderByDescending(x => x.Montant)
                .ToList();

            model.EntreesParMode = parMode
                .Select(x => new RepartitionViewModel
                {
                    Libelle = x.Libelle ?? "Non renseigné",
                    Montant = x.Montant,
                    Pourcentage = model.Entrees > 0 ? Math.Round(x.Montant * 100 / model.Entrees) : 0
                })
                .ToList();

            model.TopMotifsSortie = operations
                .Where(o => o.TypeOperation == "Décaissement")
                .GroupBy(o => o.Motif != null ? o.Motif.LibelleMotif : null)
                .Select(g => new { Libelle = g.Key, Montant = g.Sum(o => o.Montant) })
                .OrderByDescending(x => x.Montant)
                .Take(3)
                .ToList()
                .Select(x => new RepartitionViewModel
                {
                    Libelle = x.Libelle ?? "Sans motif",
                    Montant = x.Montant,
                    Pourcentage = model.Sorties > 0 ? Math.Round(x.Montant * 100 / model.Sorties) : 0
                })
                .ToList();

            // ==========================
            // DERNIÈRES OPÉRATIONS
            // ==========================

            model.DernieresOperations = operations
                .OrderByDescending(o => o.DateOperation)
                .Take(10)
                .Select(o => new OperationDashboardViewModel
                {
                    JourneeId = o.JourneeCaisseId,
                    DateOperation = o.DateOperation,
                    Reference = "OP" + o.Id.ToString("000000"),
                    Libelle = o.Libelle,
                    TypeOperation = o.TypeOperation,
                    Montant = o.Montant,
                    Caissier = o.Utilisateur.NomComplet,
                    ModePaiement = o.ModePaiement != null ? o.ModePaiement.Libelle : null,
                    StatutValidation = o.StatutValidation
                })
                .ToList();

            return View(model);
        }

        private static decimal? Variation(decimal actuel, decimal precedent)
        {
            if (precedent == 0)
                return null;

            return Math.Round((actuel - precedent) * 100 / precedent);
        }
    }
}
