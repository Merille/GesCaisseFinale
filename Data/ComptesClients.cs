using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Data
{
    // Clients en compte (vente à crédit). Même calcul que compte_soldes() de la version PHP.
    public static class ComptesClients
    {
        // Soldes dus des clients en compte : ClientId → montant. Solde = ventes payées « par compte »
        // (retours crédités au compte déduits, ventes annulées exclues) − règlements (hors rejetés).
        // tenantId : société (les filtres de société s'appliquent aussi) ; clientId : un seul client ;
        // au : solde à la fin de cette journée.
        public static async Task<Dictionary<int, decimal>> SoldesComptesAsync(this AppDbContext context, int tenantId,
            int? clientId = null, DateTime? au = null)
        {
            var fin = au?.Date.AddDays(1);
            var ventes = await (from p in context.PaiementsPos
                                join c in context.CommandesPos on p.CommandePosId equals c.Id
                                join m in context.ModesPaiement on p.ModePaiementId equals m.Id
                                where m.EstCompte && c.Statut != "Annulée" && c.ClientId != null && c.TenantId == tenantId
                                      && (clientId == null || c.ClientId == clientId) && (fin == null || c.DateCommande < fin)
                                group p by c.ClientId!.Value into g
                                select new { Id = g.Key, Montant = g.Sum(x => x.Montant) }).ToListAsync();
            var reglements = await context.OperationsCaisses
                .Where(o => o.ReglementCompte && o.StatutValidation != OperationCaisseQueries.StatutRejete && o.ClientId != null
                            && o.TenantId == tenantId && (clientId == null || o.ClientId == clientId) && (fin == null || o.DateOperation < fin))
                .GroupBy(o => o.ClientId!.Value)
                .Select(g => new { Id = g.Key, Montant = g.Sum(x => x.Montant) })
                .ToListAsync();
            var soldes = ventes.ToDictionary(v => v.Id, v => v.Montant);
            foreach (var r in reglements)
                soldes[r.Id] = soldes.GetValueOrDefault(r.Id) - r.Montant;
            return soldes;
        }

        // Profils proposés à une nouvelle société : Caissier et Vendeur (droits modifiables ensuite). Comme profils_initiaux() en PHP.
        public static void AjouterProfilsInitiaux(this AppDbContext context, int tenantId)
        {
            foreach (var nom in new[] { "Caissier", "Vendeur" })
                if (!context.Profils.IgnoreQueryFilters().Any(p => p.TenantId == tenantId && p.Nom == nom))
                    context.Profils.Add(new Models.Profil { TenantId = tenantId, Nom = nom, Description = "Caisse, ventes et tiers", Droits = string.Join(",", EasytransitCaisse.Services.Droits.ParDefaut) });
        }

        // Mode « Compte client » d'une nouvelle société (vente par compte des clients en compte).
        public static void AjouterModeCompte(this AppDbContext context, int tenantId) =>
            context.ModesPaiement.Add(new Models.ModePaiement { Code = "CPT", Libelle = "Compte client", Actif = true, EstCompte = true, TenantId = tenantId });

        // Solde dû d'un client en compte.
        public static async Task<decimal> SoldeCompteAsync(this AppDbContext context, int tenantId, int clientId, DateTime? au = null) =>
            (await context.SoldesComptesAsync(tenantId, clientId, au)).GetValueOrDefault(clientId);
    }
}
