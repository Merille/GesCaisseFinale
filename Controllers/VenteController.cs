using System.Globalization;
using System.Security.Claims;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Ventes du point de vente : liste, détail, facture depuis une vente, retour /
    // remboursement et annulation. Retours et annulations : administrateurs et
    // utilisateurs autorisés à valider les opérations.
    public class VenteController : Controller
    {
        private readonly AppDbContext _context;

        public VenteController(AppDbContext context)
        {
            _context = context;
        }

        private bool PeutRembourser =>
            User.FindFirst(AppClaimTypes.Profil)?.Value is "Admin" or "SuperAdmin"
            || (bool.TryParse(User.FindFirst(AppClaimTypes.PeutValiderOperations)?.Value, out var pv) && pv);

        private int UtilisateurId => int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id) ? id : 0;

        private string NomUtilisateur => User.FindFirst(AppClaimTypes.NomComplet)?.Value ?? User.Identity?.Name ?? "";

        // Quantité déjà retournée par ligne (retours non annulés).
        private async Task<Dictionary<int, decimal>> QuantitesRetournees(int commandeId)
        {
            var ids = await _context.LignesCommandePos.Where(l => l.CommandePosId == commandeId).Select(l => l.Id).ToListAsync();
            return await (from r in _context.LignesCommandePos
                          join c in _context.CommandesPos on r.CommandePosId equals c.Id
                          where r.LigneOrigineId != null && ids.Contains(r.LigneOrigineId.Value) && c.Statut != "Annulée"
                          group r by r.LigneOrigineId!.Value into g
                          select new { g.Key, Qte = -g.Sum(x => x.Quantite) })
                .ToDictionaryAsync(x => x.Key, x => x.Qte);
        }

        public async Task<IActionResult> Index(int journee = 0, string search = "")
        {
            var query = _context.CommandesPos.Include(c => c.JourneeCaisse).ThenInclude(j => j!.Caisse).AsQueryable();
            if (journee > 0)
                query = query.Where(c => c.JourneeCaisseId == journee);
            if (!string.IsNullOrWhiteSpace(search))
                query = query.Where(c => c.Numero.Contains(search));
            var ventes = await query.OrderByDescending(c => c.DateCommande).ThenByDescending(c => c.Id).ToListAsync();

            var clientIds = ventes.Where(v => v.ClientId != null).Select(v => v.ClientId!.Value).Distinct().ToList();
            var userIds = ventes.Select(v => v.UtilisateurId).Distinct().ToList();
            ViewBag.Clients = await _context.Clients.Where(c => clientIds.Contains(c.Id)).ToDictionaryAsync(c => c.Id, c => c.NomSociete);
            ViewBag.Vendeurs = await _context.Utilisateurs.IgnoreQueryFilters().Where(u => userIds.Contains(u.Id)).ToDictionaryAsync(u => u.Id, u => u.NomComplet);
            ViewBag.Journee = journee > 0 ? await _context.JourneesCaisses.Include(j => j.Caisse).FirstOrDefaultAsync(j => j.Id == journee) : null;
            ViewBag.Search = search;
            return View(ventes);
        }

        public async Task<IActionResult> Details(int id)
        {
            var vente = await _context.CommandesPos
                .Include(c => c.Lignes).Include(c => c.Paiements)
                .Include(c => c.JourneeCaisse).ThenInclude(j => j!.Caisse)
                .FirstOrDefaultAsync(c => c.Id == id);
            if (vente == null)
                return NotFound();

            var retournees = await QuantitesRetournees(vente.Id);
            ViewBag.Retournees = retournees;
            ViewBag.Restant = vente.Lignes.Sum(l => l.Quantite - retournees.GetValueOrDefault(l.Id));
            ViewBag.Retours = await _context.CommandesPos.Where(c => c.CommandeOrigineId == vente.Id && c.Statut != "Annulée").OrderBy(c => c.Id).ToListAsync();
            ViewBag.Origine = vente.CommandeOrigineId.HasValue ? await _context.CommandesPos.FirstOrDefaultAsync(c => c.Id == vente.CommandeOrigineId) : null;
            ViewBag.Facture = vente.FactureId.HasValue ? await _context.Factures.FirstOrDefaultAsync(f => f.Id == vente.FactureId) : null;
            ViewBag.Client = vente.ClientId.HasValue ? (await _context.Clients.FirstOrDefaultAsync(c => c.Id == vente.ClientId))?.NomSociete : null;
            ViewBag.Vendeur = (await _context.Utilisateurs.IgnoreQueryFilters().FirstOrDefaultAsync(u => u.Id == vente.UtilisateurId))?.NomComplet ?? "";
            ViewBag.Clients = vente.ClientId.HasValue ? new List<Client>()
                : await _context.Clients.Where(c => c.TenantId == vente.TenantId).OrderBy(c => c.NomSociete).ToListAsync();
            var caisseId = vente.JourneeCaisse?.CaisseId ?? 0;
            ViewBag.JourneesOuvertes = await _context.JourneesCaisses.Include(j => j.Caisse)
                .Where(j => j.Statut == "Ouverte" && j.TenantId == vente.TenantId)
                .OrderByDescending(j => j.CaisseId == caisseId).ThenByDescending(j => j.DateJournee)
                .ToListAsync();
            ViewBag.Modes = await _context.ModesPaiement.Where(m => m.Actif && m.TenantId == vente.TenantId).OrderBy(m => m.Libelle).ToListAsync();
            ViewBag.PeutRembourser = PeutRembourser;
            return View(vente);
        }

        private IActionResult VersDetails(int id, string? erreur = null, string? succes = null)
        {
            if (erreur != null) TempData["Error"] = erreur;
            if (succes != null) TempData["Success"] = succes;
            return RedirectToAction("Details", new { id });
        }

        // Facture validée créée depuis une vente (un seul taux de TVA par facture).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Facture(int id, int? clientId)
        {
            var vente = await _context.CommandesPos.Include(c => c.Lignes).FirstOrDefaultAsync(c => c.Id == id);
            if (vente == null)
                return NotFound();
            if (vente.CommandeOrigineId.HasValue || vente.Statut != "Payée")
                return VersDetails(id, "Seule une vente payée, sans retour, peut être facturée.");
            if (vente.FactureId.HasValue)
                return VersDetails(id, "Cette vente est déjà facturée.");
            var client = vente.ClientId ?? clientId;
            if (client == null || !await _context.Clients.AnyAsync(c => c.Id == client && c.TenantId == vente.TenantId))
                return VersDetails(id, "Choisissez le client à facturer.");
            var taux = vente.Lignes.Select(l => l.TauxTVA).Distinct().ToList();
            if (taux.Count > 1)
                return VersDetails(id, "Les articles ont des taux de TVA différents : une facture GesCaisse ne porte qu'un seul taux.");
            var t = taux.FirstOrDefault();

            await using var transaction = await _context.Database.BeginTransactionAsync();
            var n = await _context.Factures.CountAsync(f => f.DateFacture.Year == DateTime.Now.Year && f.TenantId == vente.TenantId) + 1;
            var facture = new Facture
            {
                TenantId = vente.TenantId, Numero = $"FAC-{DateTime.Now.Year}-{n:0000}", DateFacture = DateTime.Now,
                ClientId = client.Value, TauxTVA = t, Statut = "Validée"
            };
            _context.Factures.Add(facture);
            await _context.SaveChangesAsync();
            // Prix HT déduits du TTC payé (remise comprise).
            decimal ht = 0;
            foreach (var l in vente.Lignes.OrderBy(x => x.Id))
            {
                var totalHt = Math.Round(l.TotalTTC / (1 + t / 100), 2);
                ht += totalHt;
                _context.LignesFactures.Add(new LigneFacture
                {
                    TenantId = vente.TenantId, FactureId = facture.Id,
                    Designation = l.Libelle + (l.Remise > 0 ? $" (remise {l.Remise.ToString("0.##", CultureInfo.GetCultureInfo("fr-FR"))} %)" : ""),
                    Quantite = l.Quantite, PrixUnitaire = Math.Round(totalHt / l.Quantite, 2), TotalLigne = totalHt
                });
            }
            facture.MontantHT = ht;
            facture.MontantTVA = Math.Round(ht * t / 100, 2);
            facture.MontantTTC = facture.MontantHT + facture.MontantTVA;
            facture.MontantPaye = facture.MontantTTC;
            vente.FactureId = facture.Id;
            vente.ClientId = client;
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            TempData["Success"] = $"Facture {facture.Numero} créée et validée.";
            return Redirect($"/Facture/Edit/{facture.Id}");
        }

        // Retour / remboursement : quantités retournées par ligne, montant remboursé au
        // prorata de la ligne (remise comprise), décaissement validé dans une journée
        // ouverte, remise en stock.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Retour(int id, string? cle, int journeeId, int modeId, string? motif)
        {
            var vente = await _context.CommandesPos.Include(c => c.Lignes).FirstOrDefaultAsync(c => c.Id == id);
            if (vente == null)
                return NotFound();
            if (!PeutRembourser)
                return VersDetails(id, "Vous n'avez pas le droit d'enregistrer un retour.");
            if (vente.CommandeOrigineId.HasValue || (vente.Statut != "Payée" && vente.Statut != "Remboursée en partie"))
                return VersDetails(id, "Cette vente ne peut pas faire l'objet d'un retour.");
            var cleRetour = "R-" + new string((cle ?? "").Where(c => char.IsAsciiLetterOrDigit(c) || c == '-').Take(60).ToArray());
            if (await _context.CommandesPos.AnyAsync(c => c.TenantId == vente.TenantId && c.CleClient == cleRetour))
                return VersDetails(id);   // formulaire envoyé deux fois

            var journee = await _context.JourneesCaisses.Include(j => j.Caisse)
                .FirstOrDefaultAsync(j => j.Id == journeeId && j.TenantId == vente.TenantId && j.Statut == "Ouverte");
            if (journee == null)
                return VersDetails(id, "Choisissez une journée de caisse ouverte pour enregistrer le remboursement.");
            var mode = await _context.ModesPaiement.FirstOrDefaultAsync(m => m.Id == modeId && m.TenantId == vente.TenantId && m.Actif);
            if (mode == null)
                return VersDetails(id, "Choisissez le mode de remboursement.");

            var retournees = await QuantitesRetournees(vente.Id);
            var lignesRetour = new List<(LigneCommandePos Origine, decimal Qte, decimal Total)>();
            decimal ttc = 0, tva = 0;
            foreach (var l in vente.Lignes.OrderBy(x => x.Id))
            {
                var texte = Request.Form[$"qte[{l.Id}]"].ToString().Replace(" ", "").Replace(',', '.');
                if (!decimal.TryParse(texte, NumberStyles.Number, CultureInfo.InvariantCulture, out var q) || q <= 0)
                    continue;
                q = Math.Round(q, 2);
                var reste = l.Quantite - retournees.GetValueOrDefault(l.Id);
                if (q > reste + 0.001m)
                    return VersDetails(id, $"Quantité retournée trop élevée pour « {l.Libelle} » ({reste.ToString("0.##", CultureInfo.GetCultureInfo("fr-FR"))} au plus).");
                var total = Math.Round(l.TotalTTC * q / l.Quantite, 0, MidpointRounding.AwayFromZero);
                ttc += total;
                tva += total - total / (1 + l.TauxTVA / 100);
                lignesRetour.Add((l, q, total));
            }
            if (!lignesRetour.Any())
                return VersDetails(id, "Indiquez au moins une quantité à retourner.");
            tva = Math.Round(tva, 0, MidpointRounding.AwayFromZero);
            motif = string.IsNullOrWhiteSpace(motif) ? null : motif.Trim();

            await using var transaction = await _context.Database.BeginTransactionAsync();
            await _context.Database.ExecuteSqlInterpolatedAsync($"SELECT Id FROM JourneesCaisses WITH (UPDLOCK, HOLDLOCK) WHERE Id = {journee.Id}");
            var rang = await _context.CommandesPos.CountAsync(c => c.JourneeCaisseId == journee.Id) + 1;
            var numero = $"RET-{journee.Caisse?.ChkCode}-{journee.DateJournee:yyyyMMdd}-{rang:0000}";
            var retour = new CommandePos
            {
                TenantId = vente.TenantId, Numero = numero, CleClient = cleRetour, JourneeCaisseId = journee.Id,
                ClientId = vente.ClientId, UtilisateurId = UtilisateurId, DateCommande = DateTime.Now,
                TotalHT = -(ttc - tva), TotalTVA = -tva, TotalTTC = -ttc, MontantRecu = -ttc, MonnaieRendue = 0,
                Statut = "Retour", CommandeOrigineId = vente.Id, Motif = motif,
                Lignes = lignesRetour.Select(r => new LigneCommandePos
                {
                    TenantId = vente.TenantId, ProduitId = r.Origine.ProduitId, Libelle = r.Origine.Libelle,
                    Quantite = -r.Qte, PrixUnitaire = r.Origine.PrixUnitaire, Remise = r.Origine.Remise,
                    TauxTVA = r.Origine.TauxTVA, TotalTTC = -r.Total, LigneOrigineId = r.Origine.Id
                }).ToList()
            };
            _context.CommandesPos.Add(retour);
            var motifRetour = await _context.Motifs.FirstOrDefaultAsync(m => m.LibelleMotif == "Retour POS" && m.TenantId == vente.TenantId);
            if (motifRetour == null)
            {
                motifRetour = new Motif { LibelleMotif = "Retour POS", TypeModif = "Client", TenantId = vente.TenantId };
                _context.Motifs.Add(motifRetour);
            }
            await _context.SaveChangesAsync();

            var operation = new OperationCaisse
            {
                TenantId = vente.TenantId, JourneeCaisseId = journee.Id, DateOperation = DateTime.Now,
                TypeOperation = "Décaissement", Montant = ttc, Libelle = $"Retour POS {numero} (vente {vente.Numero})",
                ClientId = vente.ClientId, MotifId = motifRetour.ID, ModePaiementId = mode.Id, UtilisateurId = UtilisateurId,
                EstJustifie = true, StatutValidation = "Validé", Valideur = "Point de vente", Observation = motif
            };
            _context.OperationsCaisses.Add(operation);
            await _context.SaveChangesAsync();
            foreach (var r in lignesRetour.Where(r => r.Origine.ProduitId.HasValue))
                await _context.MouvementAsync(r.Origine.ProduitId!.Value, r.Qte, "Retour", numero, retour.Id, UtilisateurId, motif);
            _context.PaiementsPos.Add(new PaiementPos
            {
                TenantId = vente.TenantId, CommandePosId = retour.Id, ModePaiementId = mode.Id, Libelle = mode.Libelle ?? "",
                MontantRecu = -ttc, Montant = -ttc, OperationCaisseId = operation.Id
            });
            // Statut de la vente d'origine : remboursée en totalité ou en partie.
            var restant = vente.Lignes.Sum(l => l.Quantite - retournees.GetValueOrDefault(l.Id))
                          - lignesRetour.Sum(r => r.Qte);
            vente.Statut = restant > 0.001m ? "Remboursée en partie" : "Remboursée";
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            return VersDetails(retour.Id, succes: $"Retour {numero} enregistré : {ttc.ToString("N0", CultureInfo.GetCultureInfo("fr-FR"))} FCFA à rembourser ({mode.Libelle}).");
        }

        // Annulation d'une vente du jour : ses encaissements passent « Rejeté » (donc
        // hors des totaux) et le stock est remis. Journée ouverte, sans retour ni facture.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Annuler(int id, string? motif)
        {
            var vente = await _context.CommandesPos.Include(c => c.Lignes).Include(c => c.Paiements).Include(c => c.JourneeCaisse)
                .FirstOrDefaultAsync(c => c.Id == id);
            if (vente == null)
                return NotFound();
            if (!PeutRembourser)
                return VersDetails(id, "Vous n'avez pas le droit d'annuler une vente.");
            if (vente.CommandeOrigineId.HasValue || vente.Statut != "Payée" || vente.FactureId.HasValue)
                return VersDetails(id, "Seule une vente payée, sans retour ni facture, peut être annulée.");
            if (vente.JourneeCaisse?.Statut != "Ouverte")
                return VersDetails(id, "La journée de cette vente est clôturée : faites plutôt un retour.");

            motif = string.IsNullOrWhiteSpace(motif) ? null : motif.Trim();
            vente.Statut = "Annulée";
            vente.Motif = motif;
            var operationIds = vente.Paiements.Where(p => p.OperationCaisseId.HasValue).Select(p => p.OperationCaisseId!.Value).ToList();
            foreach (var op in await _context.OperationsCaisses.Where(o => operationIds.Contains(o.Id)).ToListAsync())
            {
                op.StatutValidation = "Rejeté";
                op.Valideur = NomUtilisateur;
                op.Observation = "Vente annulée" + (motif != null ? " : " + motif : "");
            }
            await using var transaction = await _context.Database.BeginTransactionAsync();
            foreach (var l in vente.Lignes.Where(l => l.ProduitId.HasValue))
                await _context.MouvementAsync(l.ProduitId!.Value, l.Quantite, "Annulation", vente.Numero, vente.Id, UtilisateurId, motif);
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
            return VersDetails(id, succes: $"Vente {vente.Numero} annulée : ses encaissements sont rejetés et le stock est remis.");
        }
    }
}
