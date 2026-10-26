using System.Globalization;
using ClosedXML.Excel;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Produits du point de vente : liste, fiche, suppression, export / import Excel.
    // Réservé aux profils Admin et SuperAdmin. Le prix de vente est saisi TTC ; un produit
    // peut porter plusieurs taxes (TVA, CSS…) qui s'additionnent sur le HT.
    [Authorize(Policy = "Admin")]
    public class ProduitController : Controller
    {
        // Colonnes du fichier Excel (export et import), dans cet ordre.
        public static readonly string[] ColonnesExcel =
        {
            "Code", "Nom", "Catégorie", "Code-barres", "Prix TTC", "Taxes", "Suivi stock", "Stock", "Seuil alerte", "Actif"
        };

        private const string MessageSociete = "Choisissez d'abord la société concernée dans le menu « Société consultée », puis recommencez.";

        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public ProduitController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        private IQueryable<Produit> Filtrer(string search, int categorie)
        {
            var query = _context.Produits.Include(p => p.Categorie).AsQueryable();
            if (!string.IsNullOrWhiteSpace(search))
            {
                query = query.Where(p => p.Nom.Contains(search) || p.Code.Contains(search)
                                         || (p.CodeBarres != null && p.CodeBarres.Contains(search)));
            }
            if (categorie > 0)
                query = query.Where(p => p.CategorieId == categorie);
            return query;
        }

        private void ChargerCategories()
        {
            ViewBag.Categories = _context.Categories.OrderBy(c => c.Ordre).ThenBy(c => c.Nom).ToList();
            ViewBag.Taxes = _context.ListeTaxes();
        }

        // Taxes cochées par défaut sur un nouveau produit.
        private int[] TaxesParDefaut() => _context.ListeTaxes().Where(t => t.ParDefaut).Select(t => t.Id).ToArray();

        public async Task<IActionResult> Index(string search = "", int categorie = 0)
        {
            ChargerCategories();
            ViewBag.Search = search;
            ViewBag.Categorie = categorie;
            ViewBag.NbAlertes = await _context.Produits.CountAsync(p =>
                p.SuiviStock && p.Actif && p.SeuilAlerte != null && p.StockActuel <= p.SeuilAlerte);
            var produits = await Filtrer(search, categorie).OrderBy(p => p.Nom).ToListAsync();
            ViewBag.TaxesProduits = _context.TaxesDesProduits(produits.Select(p => p.Id));
            ViewBag.TaxesCochees = TaxesParDefaut();
            return View(produits);
        }

        // Message d'erreur, ou null si le produit peut être enregistré.
        private string? Erreur(Produit p, int idExclu = 0)
        {
            if (string.IsNullOrWhiteSpace(p.Code) || string.IsNullOrWhiteSpace(p.Nom))
                return "Le code et le nom du produit sont obligatoires.";
            if (p.PrixVente < 0)
                return "Le prix doit être positif.";
            if (_context.Produits.Any(x => x.Code == p.Code && x.Id != idExclu))
                return $"Le code « {p.Code} » est déjà utilisé par un autre produit.";
            if (!string.IsNullOrEmpty(p.CodeBarres) && _context.Produits.Any(x => x.CodeBarres == p.CodeBarres && x.Id != idExclu))
                return $"Le code-barres « {p.CodeBarres} » est déjà utilisé par un autre produit.";
            return null;
        }

        // Les montants sont relus depuis le formulaire, quelle que soit la culture du serveur
        // (« 1 800 », « 1800,5 » ou « 1800.5 »).
        private void LireNombres(Produit p)
        {
            string Champ(string nom) => Request.Form[nom].ToString();
            p.PrixVente = Nombre(Champ("PrixVente")) ?? 0;
            p.StockActuel = Nombre(Champ("StockActuel")) ?? 0;
            p.SeuilAlerte = Nombre(Champ("SeuilAlerte"));
        }

        private void Nettoyer(Produit p)
        {
            p.Code = (p.Code ?? "").Trim();
            p.Nom = (p.Nom ?? "").Trim();
            p.CodeBarres = string.IsNullOrWhiteSpace(p.CodeBarres) ? null : p.CodeBarres.Trim();
            if (p.CategorieId != null && !_context.Categories.Any(c => c.Id == p.CategorieId))
                p.CategorieId = null;
        }

        public IActionResult Create()
        {
            ChargerCategories();
            ViewBag.TaxesCochees = TaxesParDefaut();
            return View(new Produit());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(Produit produit, int[] taxes)
        {
            LireNombres(produit);
            Nettoyer(produit);
            var erreur = _tenant.TenantId == 0 ? MessageSociete : Erreur(produit);
            if (erreur != null)
            {
                ViewBag.Erreur = erreur;
                ChargerCategories();
                ViewBag.TaxesCochees = taxes;
                return View(produit);
            }

            await CreerAvecStockInitial(produit, taxes);
            TempData["Success"] = "Produit créé.";
            return RedirectToAction("Index");
        }

        // Crée le produit et ses taxes, puis enregistre son stock initial comme premier mouvement.
        // Le stock ne change ensuite que par des mouvements (entrées, inventaires, ventes, retours).
        private async Task CreerAvecStockInitial(Produit produit, IEnumerable<int> taxes)
        {
            var initial = produit.StockActuel;
            produit.Id = 0;
            produit.StockActuel = 0;
            await using var transaction = await _context.Database.BeginTransactionAsync();
            _context.Produits.Add(produit);
            await _context.SaveChangesAsync();
            _context.EnregistrerTaxes(produit, taxes);
            int.TryParse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value, out var utilisateurId);
            await _context.MouvementAsync(produit.Id, initial, "Stock initial", utilisateurId: utilisateurId);
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
        }

        public IActionResult Edit(int id)
        {
            var produit = _context.Produits.FirstOrDefault(p => p.Id == id);
            if (produit == null)
                return NotFound();
            ChargerCategories();
            ViewBag.TaxesCochees = _context.ProduitTaxes.Where(pt => pt.ProduitId == id).Select(pt => pt.TaxeId).ToArray();
            return View(produit);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Edit(int id, Produit saisi, int[] taxes)
        {
            var produit = _context.Produits.FirstOrDefault(p => p.Id == id);
            if (produit == null)
                return NotFound();

            LireNombres(saisi);
            Nettoyer(saisi);
            var erreur = Erreur(saisi, id);
            if (erreur != null)
            {
                saisi.Id = id;
                ViewBag.Erreur = erreur;
                ChargerCategories();
                ViewBag.TaxesCochees = taxes;
                return View(saisi);
            }

            produit.Code = saisi.Code;
            produit.CodeBarres = saisi.CodeBarres;
            produit.Nom = saisi.Nom;
            produit.CategorieId = saisi.CategorieId;
            produit.PrixVente = saisi.PrixVente;
            produit.SuiviStock = saisi.SuiviStock;
            produit.SeuilAlerte = saisi.SeuilAlerte;
            produit.Actif = saisi.Actif;
            _context.EnregistrerTaxes(produit, taxes);
            _context.SaveChanges();
            TempData["Success"] = "Produit modifié.";
            return RedirectToAction("Index");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Delete(int id)
        {
            // Étapes suivantes : refuser la suppression d'un produit déjà vendu (le désactiver à la place).
            var produit = _context.Produits.FirstOrDefault(p => p.Id == id);
            if (produit != null)
            {
                _context.Produits.Remove(produit);
                _context.SaveChanges();
                TempData["Success"] = "Produit supprimé.";
            }
            return RedirectToAction("Index");
        }

        public async Task<IActionResult> Export(string search = "", int categorie = 0)
        {
            var produits = await Filtrer(search, categorie).OrderBy(p => p.Nom).ToListAsync();
            var taxesProduits = _context.TaxesDesProduits(produits.Select(p => p.Id));

            using var workbook = new XLWorkbook();
            var sheet = workbook.Worksheets.Add("Produits");
            for (int c = 0; c < ColonnesExcel.Length; c++)
                sheet.Cell(1, c + 1).Value = ColonnesExcel[c];
            var entete = sheet.Range(1, 1, 1, ColonnesExcel.Length);
            entete.Style.Font.Bold = true;
            entete.Style.Fill.BackgroundColor = XLColor.FromHtml("#195d84");
            entete.Style.Font.FontColor = XLColor.White;

            for (int i = 0; i < produits.Count; i++)
            {
                var p = produits[i];
                var r = i + 2;
                sheet.Cell(r, 1).Value = p.Code;
                sheet.Cell(r, 2).Value = p.Nom;
                sheet.Cell(r, 3).Value = p.Categorie?.Nom ?? "";
                sheet.Cell(r, 4).Value = p.CodeBarres ?? "";
                sheet.Cell(r, 4).Style.NumberFormat.Format = "@";
                sheet.Cell(r, 5).Value = p.PrixVente;
                sheet.Cell(r, 6).Value = TaxesProduits.Codes(taxesProduits.GetValueOrDefault(p.Id));
                sheet.Cell(r, 7).Value = p.SuiviStock ? "Oui" : "Non";
                sheet.Cell(r, 8).Value = p.StockActuel;
                if (p.SeuilAlerte.HasValue)
                    sheet.Cell(r, 9).Value = p.SeuilAlerte.Value;
                sheet.Cell(r, 10).Value = p.Actif ? "Oui" : "Non";
            }
            sheet.Columns().AdjustToContents();

            using var stream = new MemoryStream();
            workbook.SaveAs(stream);
            return File(stream.ToArray(),
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"Produits_{DateTime.Now:yyyyMMdd_HHmm}.xlsx");
        }

        // « 1 500 », « 1500,5 » ou « 1500.5 » ; vide → valeur par défaut.
        private static decimal? Nombre(string texte)
        {
            var t = texte.Replace(" ", "").Replace(" ", "").Replace(" ", "").Replace(',', '.');
            return decimal.TryParse(t, NumberStyles.Number, CultureInfo.InvariantCulture, out var n) ? n : null;
        }

        // Taxes d'une ligne importée : codes séparés par « + », « , » ou « ; » (ex. « TVA + CSS »),
        // ou un taux seul (ancien format « TVA % », ex. 18). Null si la cellule est vide.
        private static int[]? TaxesDepuisTexte(string texte, List<Taxe> taxes, out string? erreur)
        {
            erreur = null;
            texte = texte.Trim();
            if (texte == "")
                return null;
            if (System.Text.RegularExpressions.Regex.IsMatch(texte, @"^\d+([.,]\d+)?\s*%?$"))
            {
                var taux = Nombre(texte.TrimEnd('%', ' ')) ?? 0;
                if (taux == 0)
                    return Array.Empty<int>();
                var taxe = taxes.FirstOrDefault(t => t.Taux == taux);
                if (taxe == null)
                    erreur = $"aucune taxe de {taux.ToString("0.##", new CultureInfo("fr-FR"))} % (créez-la dans Paramètres > Taxes).";
                return taxe == null ? null : new[] { taxe.Id };
            }
            var ids = new List<int>();
            foreach (var code in texte.Split(new[] { '+', ',', ';' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                var taxe = taxes.FirstOrDefault(t => string.Equals(t.Code, code, StringComparison.OrdinalIgnoreCase));
                if (taxe == null)
                {
                    erreur = $"taxe « {code} » inconnue (voir Paramètres > Taxes).";
                    return null;
                }
                ids.Add(taxe.Id);
            }
            return ids.ToArray();
        }

        private static bool Booleen(string texte, bool defaut)
        {
            var t = texte.Trim().ToLowerInvariant();
            if (t == "") return defaut;
            return t is "oui" or "o" or "1" or "vrai" or "x" or "yes" or "true";
        }

        // Import : un produit dont le code existe déjà est mis à jour, sinon il est créé.
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Import(IFormFile file)
        {
            if (file == null || file.Length == 0)
            {
                TempData["Error"] = "Veuillez sélectionner un fichier Excel.";
                return RedirectToAction("Index");
            }
            if (!file.FileName.EndsWith(".xlsx", StringComparison.OrdinalIgnoreCase))
            {
                TempData["Error"] = "Le fichier doit être au format .xlsx";
                return RedirectToAction("Index");
            }
            if (_tenant.TenantId == 0)
            {
                TempData["Error"] = MessageSociete;
                return RedirectToAction("Index");
            }

            using var stream = new MemoryStream();
            await file.CopyToAsync(stream);
            stream.Position = 0;

            XLWorkbook workbook;
            try
            {
                workbook = new XLWorkbook(stream);
            }
            catch (Exception ex)
            {
                TempData["Error"] = "Fichier Excel illisible : " + ex.Message;
                return RedirectToAction("Index");
            }

            using (workbook)
            {
                var categories = await _context.Categories.ToListAsync();
                var taxesSociete = _context.ListeTaxes();
                var taxesDefaut = TaxesParDefaut();
                var erreurs = new List<string>();
                int crees = 0, maj = 0;

                foreach (var row in workbook.Worksheet(1).RowsUsed().Skip(1))
                {
                    string Col(int i) => row.Cell(i).GetFormattedString().Trim();
                    if (Enumerable.Range(1, ColonnesExcel.Length).All(i => Col(i) == ""))
                        continue;

                    Categorie? categorie = null;
                    var nomCategorie = Col(3);
                    if (nomCategorie != "")
                    {
                        categorie = categories.FirstOrDefault(c => string.Equals(c.Nom, nomCategorie, StringComparison.OrdinalIgnoreCase));
                        if (categorie == null)
                        {
                            categorie = new Categorie { Nom = nomCategorie };
                            _context.Categories.Add(categorie);
                            await _context.SaveChangesAsync();
                            categories.Add(categorie);
                        }
                    }

                    var taxes = TaxesDepuisTexte(Col(6), taxesSociete, out var erreurTaxes);
                    if (erreurTaxes != null)
                    {
                        erreurs.Add($"Ligne {row.RowNumber()} : {erreurTaxes}");
                        continue;
                    }

                    var saisi = new Produit
                    {
                        Code = Col(1),
                        Nom = Col(2),
                        CategorieId = categorie?.Id,
                        CodeBarres = Col(4),
                        PrixVente = Nombre(Col(5)) ?? 0,
                        SuiviStock = Booleen(Col(7), true),
                        StockActuel = Nombre(Col(8)) ?? 0,
                        SeuilAlerte = Nombre(Col(9)),
                        Actif = Booleen(Col(10), true),
                    };
                    Nettoyer(saisi);

                    var existant = saisi.Code == "" ? null : await _context.Produits.FirstOrDefaultAsync(p => p.Code == saisi.Code);
                    var erreur = Erreur(saisi, existant?.Id ?? 0);
                    if (erreur != null)
                    {
                        erreurs.Add($"Ligne {row.RowNumber()} : {erreur}");
                        continue;
                    }

                    if (existant != null)
                    {
                        existant.Nom = saisi.Nom;
                        existant.CategorieId = saisi.CategorieId;
                        existant.CodeBarres = saisi.CodeBarres;
                        existant.PrixVente = saisi.PrixVente;
                        existant.SuiviStock = saisi.SuiviStock;
                        existant.SeuilAlerte = saisi.SeuilAlerte;
                        existant.Actif = saisi.Actif;
                        // Colonne Taxes vide : taxes inchangées.
                        if (taxes != null)
                            _context.EnregistrerTaxes(existant, taxes);
                        maj++;
                    }
                    else
                    {
                        // Produit existant : le stock du fichier est ignoré (il change par entrées et inventaires).
                        await CreerAvecStockInitial(saisi, taxes ?? taxesDefaut);
                        crees++;
                    }
                    // Enregistré ligne par ligne : les contrôles de doublon voient les lignes précédentes.
                    await _context.SaveChangesAsync();
                }

                TempData["Success"] = $"Import terminé : {crees} produit(s) créé(s), {maj} mis à jour.";
                if (erreurs.Any())
                    TempData["Erreurs"] = string.Join("|", erreurs);
            }
            return RedirectToAction("Index");
        }
    }
}
