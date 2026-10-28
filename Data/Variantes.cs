using EasytransitCaisse.Models;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Data
{
    // Variantes de produits : le modèle porte les attributs (Taille : S, M, L ; Couleur : Rouge,
    // Bleu) ; chaque combinaison est un produit (ParentId = modèle). Stock, ventes, retours,
    // taxes et rapports traitent une variante comme n'importe quel produit.
    public static class Variantes
    {
        public const int MaxVariantes = 200;

        public record AttributSaisi(string Nom, List<string> Valeurs);

        // Attributs saisis sur la fiche : attribut[i][nom] et attribut[i][valeurs] (« S, M, L »).
        public static List<AttributSaisi> Lire(Microsoft.AspNetCore.Http.IFormCollection form)
        {
            var parIndice = new SortedDictionary<string, (string Nom, string Valeurs)>();
            foreach (var cle in form.Keys)
            {
                var m = System.Text.RegularExpressions.Regex.Match(cle, @"^attribut\[([^\]]+)\]\[(nom|valeurs)\]$");
                if (!m.Success) continue;
                parIndice.TryGetValue(m.Groups[1].Value, out var a);
                if (m.Groups[2].Value == "nom") a.Nom = form[cle].ToString(); else a.Valeurs = form[cle].ToString();
                parIndice[m.Groups[1].Value] = a;
            }
            var resultat = new List<AttributSaisi>();
            foreach (var (nom, valeurs) in parIndice.Values)
            {
                var n = Couper((nom ?? "").Trim(), 50);
                var liste = new List<string>();
                foreach (var brut in (valeurs ?? "").Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
                {
                    var v = Couper(brut, 50);
                    if (v != "" && !liste.Any(x => string.Equals(x, v, StringComparison.OrdinalIgnoreCase)))
                        liste.Add(v);
                }
                if (n != "" && liste.Count > 0 && !resultat.Any(x => string.Equals(x.Nom, n, StringComparison.OrdinalIgnoreCase)))
                    resultat.Add(new AttributSaisi(n, liste));
            }
            return resultat;
        }

        private static string Couper(string s, int max) => s.Length > max ? s[..max] : s;

        // Enregistre les attributs puis crée les combinaisons manquantes. Une valeur ou un attribut
        // retiré désactive les variantes qui l'utilisaient (l'historique des ventes est gardé).
        public static async Task<(int Creees, string? Erreur)> GenererAsync(AppDbContext context, Produit modele, List<AttributSaisi> saisis)
        {
            if (modele.ParentId.HasValue)
                return (0, "Une variante ne peut pas avoir ses propres variantes.");
            if (!modele.EstModele && saisis.Count > 0 && modele.SuiviStock && Math.Abs(modele.StockActuel) > 0.0001m)
                return (0, $"Ce produit a encore {modele.StockActuel:0.##} en stock : ramenez son stock à 0 (inventaire) avant de créer des variantes, puis faites l'entrée de stock sur chaque variante.");
            var combinaisons = saisis.Aggregate(1, (n, a) => n * a.Valeurs.Count);
            if (saisis.Count > 0 && combinaisons > MaxVariantes)
                return (0, $"Trop de combinaisons ({combinaisons}) : {MaxVariantes} variantes au plus par produit.");

            await using var transaction = await context.Database.BeginTransactionAsync();
            var existants = await context.ProduitAttributs.Include(a => a.Valeurs).Where(a => a.ProduitId == modele.Id).ToListAsync();
            var variantesIds = await context.Produits.IgnoreQueryFilters().Where(p => p.ParentId == modele.Id).Select(p => p.Id).ToListAsync();

            async Task DesactiverEtRetirer(IEnumerable<int> valeurIds)
            {
                var ids = valeurIds.ToList();
                if (ids.Count == 0) return;
                var liens = await context.VarianteValeurs.Where(vv => ids.Contains(vv.ValeurId)).ToListAsync();
                var aDesactiver = liens.Select(l => l.VarianteId).Distinct().ToList();
                foreach (var v in await context.Produits.IgnoreQueryFilters().Where(p => aDesactiver.Contains(p.Id)).ToListAsync())
                    v.Actif = false;
                context.VarianteValeurs.RemoveRange(liens);
            }

            // 1. Attributs et valeurs (identifiés par leur nom, sans tenir compte des majuscules).
            var retenues = new List<List<ProduitAttributValeur>>();
            var gardes = new List<ProduitAttribut>();
            for (var ordre = 0; ordre < saisis.Count; ordre++)
            {
                var a = saisis[ordre];
                var attr = existants.FirstOrDefault(e => string.Equals(e.Nom, a.Nom, StringComparison.OrdinalIgnoreCase));
                if (attr == null)
                {
                    attr = new ProduitAttribut { ProduitId = modele.Id };
                    context.ProduitAttributs.Add(attr);
                }
                attr.Nom = a.Nom;
                attr.Ordre = ordre;
                gardes.Add(attr);
                var valeurs = new List<ProduitAttributValeur>();
                for (var o = 0; o < a.Valeurs.Count; o++)
                {
                    var val = attr.Valeurs.FirstOrDefault(v => string.Equals(v.Valeur, a.Valeurs[o], StringComparison.OrdinalIgnoreCase));
                    if (val == null)
                        attr.Valeurs.Add(val = new ProduitAttributValeur());
                    val.Valeur = a.Valeurs[o];
                    val.Ordre = o;
                    valeurs.Add(val);
                }
                var retirees = attr.Valeurs.Where(v => v.Id != 0 && !valeurs.Contains(v)).ToList();
                await DesactiverEtRetirer(retirees.Select(v => v.Id));
                context.ProduitAttributValeurs.RemoveRange(retirees);
                retenues.Add(valeurs);
            }
            foreach (var e in existants.Where(e => !gardes.Contains(e)))
            {
                await DesactiverEtRetirer(e.Valeurs.Select(v => v.Id));
                context.ProduitAttributValeurs.RemoveRange(e.Valeurs);
                context.ProduitAttributs.Remove(e);
            }
            await context.SaveChangesAsync();

            // 2. Combinaisons manquantes : une variante par combinaison de valeurs.
            var creees = 0;
            if (retenues.Count > 0)
            {
                var liens = await context.VarianteValeurs.Where(vv => variantesIds.Contains(vv.VarianteId)).ToListAsync();
                var connues = liens.GroupBy(l => l.VarianteId)
                    .ToDictionary(g => string.Join(",", g.Select(x => x.ValeurId).OrderBy(x => x)), g => g.Key);
                IEnumerable<List<ProduitAttributValeur>> combis = new[] { new List<ProduitAttributValeur>() };
                foreach (var valeurs in retenues)
                    combis = combis.SelectMany(c => valeurs.Select(v => c.Append(v).ToList())).ToList();
                var taxes = await context.ProduitTaxes.Where(pt => pt.ProduitId == modele.Id).Select(pt => pt.TaxeId).ToListAsync();
                var codes = await context.Produits.IgnoreQueryFilters().Where(p => p.TenantId == modele.TenantId).Select(p => p.Code).ToListAsync();
                foreach (var c in combis)
                {
                    var cle = string.Join(",", c.Select(v => v.Id).OrderBy(x => x));
                    var libelle = Couper(string.Join(" ", c.Select(v => v.Valeur)), 150);
                    if (connues.TryGetValue(cle, out var existante))
                    {
                        var v = await context.Produits.IgnoreQueryFilters().FirstAsync(p => p.Id == existante);
                        v.LibelleVariante = libelle;
                        continue;
                    }
                    var code = "";
                    for (var n = 1; ; n++)
                    {
                        code = $"{Couper(modele.Code, 44)}-{n:00}";
                        if (!codes.Contains(code, StringComparer.OrdinalIgnoreCase)) break;
                    }
                    codes.Add(code);
                    var variante = new Produit
                    {
                        TenantId = modele.TenantId,
                        Code = code,
                        Nom = Couper(modele.Nom + " " + libelle, 200),
                        CategorieId = modele.CategorieId,
                        PrixVente = modele.PrixVente,
                        TauxTVA = modele.TauxTVA,
                        SuiviStock = modele.SuiviStock,
                        SeuilAlerte = modele.SeuilAlerte,
                        Actif = true,
                        Cout = modele.Cout,
                        Unite = modele.Unite,
                        ParentId = modele.Id,
                        LibelleVariante = libelle
                    };
                    context.Produits.Add(variante);
                    await context.SaveChangesAsync();
                    foreach (var val in c)
                        context.VarianteValeurs.Add(new VarianteValeur { VarianteId = variante.Id, ValeurId = val.Id });
                    foreach (var t in taxes)
                        context.ProduitTaxes.Add(new ProduitTaxe { ProduitId = variante.Id, TaxeId = t });
                    creees++;
                }
                await context.SaveChangesAsync();
            }

            // 3. Le produit est un modèle tant qu'il a des variantes.
            modele.EstModele = await context.Produits.IgnoreQueryFilters().AnyAsync(p => p.ParentId == modele.Id);
            await context.SaveChangesAsync();
            await PropagerAsync(context, modele);
            await context.SaveChangesAsync();
            await transaction.CommitAsync();
            return (creees, null);
        }

        // Recopie sur les variantes ce qui vient du modèle : nom (+ valeurs), catégorie, prix
        // (+ supplément), coût, unité, suivi du stock, seuil et taxes.
        public static async Task PropagerAsync(AppDbContext context, Produit modele)
        {
            if (!modele.EstModele)
                return;
            var variantes = await context.Produits.IgnoreQueryFilters().Where(p => p.ParentId == modele.Id).ToListAsync();
            var ids = variantes.Select(v => v.Id).ToList();
            var taxes = await context.ProduitTaxes.Where(pt => pt.ProduitId == modele.Id).Select(pt => pt.TaxeId).ToListAsync();
            context.ProduitTaxes.RemoveRange(await context.ProduitTaxes.Where(pt => ids.Contains(pt.ProduitId)).ToListAsync());
            foreach (var v in variantes)
            {
                v.Nom = Couper((modele.Nom + " " + (v.LibelleVariante ?? "")).Trim(), 200);
                v.CategorieId = modele.CategorieId;
                v.PrixVente = modele.PrixVente + v.Supplement;
                v.Cout = modele.Cout;
                v.Unite = modele.Unite;
                v.SuiviStock = modele.SuiviStock;
                v.SeuilAlerte = modele.SeuilAlerte;
                v.TauxTVA = modele.TauxTVA;
                foreach (var t in taxes)
                    context.ProduitTaxes.Add(new ProduitTaxe { ProduitId = v.Id, TaxeId = t });
            }
        }
    }
}
