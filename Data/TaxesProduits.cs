using System.Globalization;
using EasytransitCaisse.Models;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Data
{
    // Taxes des produits : un produit peut en porter plusieurs (ex. TVA 18 % + CSS 1 %),
    // qui s'additionnent sur le HT ; Produits.TauxTVA garde le taux total.
    public static class TaxesProduits
    {
        private static readonly CultureInfo Fr = new("fr-FR");

        // Taxes de départ d'une nouvelle société : TVA 18 % (par défaut) et CSS 1 %.
        public static void AjouterTaxesInitiales(this AppDbContext context, int tenantId)
        {
            context.Taxes.Add(new Taxe { TenantId = tenantId, Code = "TVA", Libelle = "Taxe sur la valeur ajoutée", Taux = 18, ParDefaut = true });
            context.Taxes.Add(new Taxe { TenantId = tenantId, Code = "CSS", Libelle = "Contribution spéciale de solidarité", Taux = 1 });
        }

        // Taxes de la société consultée, la TVA en premier.
        public static List<Taxe> ListeTaxes(this AppDbContext context, int? tenantId = null) =>
            context.Taxes
                .Where(t => tenantId == null || t.TenantId == tenantId)
                .OrderByDescending(t => t.ParDefaut).ThenByDescending(t => t.Taux).ThenBy(t => t.Code)
                .ToList();

        // Taxes de chaque produit demandé.
        public static Dictionary<int, List<Taxe>> TaxesDesProduits(this AppDbContext context, IEnumerable<int> produitIds)
        {
            var ids = produitIds.Distinct().ToList();
            return (from pt in context.ProduitTaxes
                    join t in context.Taxes on pt.TaxeId equals t.Id
                    where ids.Contains(pt.ProduitId)
                    select new { pt.ProduitId, Taxe = t })
                .AsEnumerable()
                .GroupBy(x => x.ProduitId)
                .ToDictionary(g => g.Key, g => g.Select(x => x.Taxe)
                    .OrderByDescending(t => t.ParDefaut).ThenByDescending(t => t.Taux).ThenBy(t => t.Code).ToList());
        }

        // Codes affichés dans les listes : « TVA + CSS ».
        public static string Codes(IEnumerable<Taxe>? taxes) => string.Join(" + ", (taxes ?? Enumerable.Empty<Taxe>()).Select(t => t.Code));

        // Remplace les taxes d'un produit (déjà enregistré) et met à jour son taux total.
        public static void EnregistrerTaxes(this AppDbContext context, Produit produit, IEnumerable<int> taxeIds)
        {
            var valides = context.Taxes.IgnoreQueryFilters()
                .Where(t => t.TenantId == produit.TenantId && taxeIds.Contains(t.Id))
                .ToList();
            context.ProduitTaxes.RemoveRange(context.ProduitTaxes.Where(pt => pt.ProduitId == produit.Id));
            foreach (var t in valides)
                context.ProduitTaxes.Add(new ProduitTaxe { ProduitId = produit.Id, TaxeId = t.Id });
            produit.TauxTVA = valides.Sum(t => t.Taux);
        }

        // Taux total des produits qui portent cette taxe (après modification de son taux).
        public static void RecalculerTauxProduits(this AppDbContext context, int taxeId)
        {
            var produitIds = context.ProduitTaxes.Where(pt => pt.TaxeId == taxeId).Select(pt => pt.ProduitId).ToList();
            var taux = (from pt in context.ProduitTaxes
                        join t in context.Taxes.IgnoreQueryFilters() on pt.TaxeId equals t.Id
                        where produitIds.Contains(pt.ProduitId)
                        group t.Taux by pt.ProduitId into g
                        select new { ProduitId = g.Key, Total = g.Sum() })
                .ToDictionary(x => x.ProduitId, x => x.Total);
            foreach (var p in context.Produits.IgnoreQueryFilters().Where(p => produitIds.Contains(p.Id)))
                p.TauxTVA = taux.TryGetValue(p.Id, out var total) ? total : 0;
        }

        // Détail des taxes d'une ligne vendue : chaque taxe calculée sur le HT de la ligne.
        public static List<LigneCommandePosTaxe> TaxesLigne(int tenantId, IEnumerable<(int? TaxeId, string Code, decimal Taux)> taxes, decimal totalTtc)
        {
            var liste = taxes.ToList();
            var total = liste.Sum(t => t.Taux);
            if (total <= 0)
                return new List<LigneCommandePosTaxe>();
            var ht = totalTtc / (1 + total / 100);
            return liste.Select(t => new LigneCommandePosTaxe
            {
                TenantId = tenantId,
                TaxeId = t.TaxeId,
                Code = t.Code,
                Taux = t.Taux,
                Montant = Math.Round(ht * t.Taux / 100, 2, MidpointRounding.AwayFromZero)
            }).ToList();
        }

        public static string Libelle(string code, decimal taux)
        {
            var t = taux == Math.Floor(taux) ? taux.ToString("N0", Fr) : taux.ToString("N2", Fr);
            return $"{code} {t} %";
        }

        // Taxes d'une vente regroupées (« TVA 18 % » => montant). Les lignes vendues avant le
        // détail des taxes sont comptées en TVA à leur taux total.
        public static Dictionary<string, decimal> TaxesVente(this AppDbContext context, int commandeId)
        {
            var lignes = context.LignesCommandePos.Where(l => l.CommandePosId == commandeId).Include(l => l.Taxes).ToList();
            return Regrouper(lignes);
        }

        public static Dictionary<string, decimal> Regrouper(IEnumerable<LigneCommandePos> lignes)
        {
            var resultat = new Dictionary<string, decimal>();
            foreach (var l in lignes)
            {
                var detail = l.Taxes.Count > 0
                    ? l.Taxes.Select(t => (Libelle(t.Code, t.Taux), t.Montant))
                    : l.TauxTVA > 0
                        ? new[] { (Libelle("TVA", l.TauxTVA), l.TotalTTC - l.TotalTTC / (1 + l.TauxTVA / 100)) }
                        : Enumerable.Empty<(string, decimal)>();
                foreach (var (libelle, montant) in detail)
                    resultat[libelle] = (resultat.TryGetValue(libelle, out var m) ? m : 0) + montant;
            }
            return resultat;
        }
    }
}
