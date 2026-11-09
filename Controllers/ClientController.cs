using ClosedXML.Excel;
using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using Microsoft.AspNetCore.Mvc;

using Microsoft.EntityFrameworkCore; // ← ICI
using System.Linq;
using System.Threading.Tasks;

namespace EasytransitCaisse.Controllers
{
    public class ClientController : Controller
    {
        private readonly AppDbContext _context;

        public ClientController(AppDbContext context)
        {
            _context = context;
        }

        // LISTE

        public async Task<IActionResult> Index(string search = "")
        {
            var query = _context.Clients.AsQueryable();

            if (!string.IsNullOrEmpty(search))
            {
                query = query.Where(c =>
                    c.CodeClient.Contains(search) ||
                    c.NomSociete.Contains(search) ||
                    c.NomContact.Contains(search) ||
                    c.Telephone.Contains(search) ||
                    c.Type.Contains(search));
            }

            var clients = await query
                .OrderBy(c => c.NomSociete)
                .ToListAsync();

            return View(clients); // ← List<Client> directement
        }

        // Champs saisis, nettoyés comme dans la version PHP (texte vide plutôt que null).
        private static void Copier(Client source, Client cible)
        {
            cible.CodeClient = (source.CodeClient ?? "").Trim();
            cible.NomSociete = (source.NomSociete ?? "").Trim();
            cible.Adresse = source.Adresse ?? "";
            cible.Telephone = source.Telephone ?? "";
            cible.Email = source.Email ?? "";
            cible.Type = source.Type ?? "";
            cible.Genre = Client.GenreValide(source.Genre);
            cible.CompteGeneral = source.CompteGeneral ?? "";
            cible.NomContact = source.NomContact ?? "";
            cible.FonctionContact = source.FonctionContact ?? "";
            cible.TelephoneContact = source.TelephoneContact ?? "";
            cible.EmailContact = source.EmailContact ?? "";
        }

        // CREATE GET
        public IActionResult Create()
        {
            return View(new Client());
        }

        // CREATE POST
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Create(Client saisie)
        {
            var client = new Client();
            Copier(saisie, client);
            if (client.CodeClient == "" || client.NomSociete == "")
                TempData["Error"] = "Le code et le nom de la société sont obligatoires.";
            else if (_context.Clients.Any(c => c.CodeClient == client.CodeClient))
                TempData["Error"] = $"Le code « {client.CodeClient} » existe déjà.";
            else
            {
                _context.Clients.Add(client);
                _context.SaveChanges();
                TempData["Success"] = "Tiers créé.";
                return RedirectToAction("Index");
            }
            return View(client);
        }

        // EDIT GET
        public IActionResult Edit(int id)
        {
            var client = _context.Clients.Find(id);
            if (client == null) return NotFound();

            return View(client);
        }

        // EDIT POST
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Edit(int id, Client saisie)
        {
            var client = _context.Clients.FirstOrDefault(c => c.Id == id);
            if (client == null)
                return NotFound();

            var verif = new Client();
            Copier(saisie, verif);
            if (verif.CodeClient == "" || verif.NomSociete == "")
            {
                TempData["Error"] = "Le code et le nom de la société sont obligatoires.";
                verif.Id = client.Id;
                return View(verif);
            }
            Copier(saisie, client);
            _context.SaveChanges();
            TempData["Success"] = "Tiers modifié.";
            return RedirectToAction("Index");
        }

        // DELETE : refusée si le tiers est utilisé (comme la version PHP).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Delete(int id)
        {
            var client = _context.Clients.Find(id);

            if (client != null)
            {
                var utilise = _context.OperationsCaisses.Count(o => o.ClientId == client.Id)
                            + _context.Factures.Count(f => f.ClientId == client.Id);
                if (utilise > 0)
                    TempData["Error"] = "Ce tiers est utilisé par des opérations ou des factures : il ne peut pas être supprimé.";
                else
                {
                    _context.Clients.Remove(client);
                    _context.SaveChanges();
                    TempData["Success"] = "Tiers supprimé.";
                }
            }

            return RedirectToAction("Index");
        }

        // Exportation des clients Excel
        public async Task<IActionResult> Export(string search = "")
        {
            var query = _context.Clients.AsQueryable();

            if (!string.IsNullOrEmpty(search))
            {
                query = query.Where(c =>
                    c.CodeClient.Contains(search) ||
                    c.NomSociete.Contains(search) ||
                    c.NomContact.Contains(search) ||
                    c.Telephone.Contains(search) ||
                    c.EmailContact.Contains(search) ||
                    c.Adresse.Contains(search) ||
                    c.Email.Contains(search) ||
                    c.Type.Contains(search) ||
                    c.FonctionContact.Contains(search) ||
                    c.TelephoneContact.Contains(search));
            }

            var clients = await query.OrderBy(c => c.NomSociete).ToListAsync();

            using var workbook = new XLWorkbook();
            var sheet = workbook.Worksheets.Add("Clients");

            // En-têtes
            sheet.Cell(1, 1).Value = "Code";
            sheet.Cell(1, 2).Value = "Société";
            sheet.Cell(1, 3).Value = "Contact";
            sheet.Cell(1, 4).Value = "Téléphone";
            sheet.Cell(1, 5).Value = "EmailContact";
            sheet.Cell(1, 6).Value = "Adresse";
            sheet.Cell(1, 7).Value = "Email";
            sheet.Cell(1, 8).Value = "Type";
            sheet.Cell(1, 9).Value = "FonctionContact";
            sheet.Cell(1, 10).Value = "TelephoneContact";
            sheet.Cell(1, 11).Value = "CompteGeneral";
            sheet.Cell(1, 12).Value = "Genre";

            // Style en-têtes
            var headerRow = sheet.Range("A1:D1");
            headerRow.Style.Font.Bold = true;
            headerRow.Style.Fill.BackgroundColor = XLColor.DarkBlue;
            headerRow.Style.Font.FontColor = XLColor.White;

            // Données
            for (int i = 0; i < clients.Count; i++)
            {
                var c = clients[i];
                sheet.Cell(i + 2, 1).Value = c.CodeClient;
                sheet.Cell(i + 2, 2).Value = c.NomSociete;
                sheet.Cell(i + 2, 3).Value = c.NomContact;
                sheet.Cell(i + 2, 4).Value = c.Telephone;
                sheet.Cell(i + 2, 5).Value = c.EmailContact;
                sheet.Cell(i + 2, 6).Value = c.Adresse;
                sheet.Cell(i + 2, 7).Value = c.Email;
                sheet.Cell(i + 2, 8).Value = c.Type;
                sheet.Cell(i + 2, 9).Value = c.FonctionContact;
                sheet.Cell(i + 2, 10).Value = c.TelephoneContact;
                sheet.Cell(i + 2, 11).Value = c.CompteGeneral;
                sheet.Cell(i + 2, 12).Value = c.Genre;
            }

            // Ajuster largeur des colonnes automatiquement
            sheet.Columns().AdjustToContents();

            // Retourner le fichier
            using var stream = new MemoryStream();
            workbook.SaveAs(stream);
            stream.Position = 0;

            var fileName = $"Clients_{DateTime.Now:yyyyMMdd_HHmm}.xlsx";
            return File(stream.ToArray(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
        }

        // GET — afficher le formulaire d'import
        public IActionResult Import()
        {
            return View();
        }

        // POST — traiter le fichier uploadé
        [HttpPost]
        public async Task<IActionResult> Import(IFormFile file)
        {
            if (file == null || file.Length == 0)
            {
                TempData["Error"] = "Veuillez sélectionner un fichier Excel.";
                return RedirectToAction("Index");
            }

            if (!file.FileName.EndsWith(".xlsx"))
            {
                TempData["Error"] = "Le fichier doit être au format .xlsx";
                return RedirectToAction("Index");
            }

            var clients = new List<Client>();
            var erreurs = new List<string>();

            using var stream = new MemoryStream();
            await file.CopyToAsync(stream);
            stream.Position = 0;

            using var workbook = new XLWorkbook(stream);
            var sheet = workbook.Worksheet(1);
            var rows = sheet.RowsUsed().Skip(1); // Skip l'en-tête

            foreach (var row in rows)
            {
                try
                {
                    var client = new Client
                    {
                        CodeClient = row.Cell(1).GetString(),
                        NomSociete = row.Cell(2).GetString(),
                        NomContact = row.Cell(3).GetString(),
                        Telephone = row.Cell(4).GetString(),
                        EmailContact = row.Cell(5).GetString() ?? "",
                        Adresse = row.Cell(6).GetString() ?? "",
                        Email = row.Cell(7).GetString() ?? "",
                        Type = row.Cell(8).GetString() ?? "",
                        FonctionContact = row.Cell(9).GetString() ?? "",
                        TelephoneContact = row.Cell(10).GetString() ?? "",
                        CompteGeneral = row.Cell(11).GetString() ?? "",
                        // Colonne Genre absente (fichier d'une version précédente) : Entreprise.
                        Genre = Client.GenreValide(row.Cell(12).GetString().Trim()),
                    };

                    // Validation basique
                    if (string.IsNullOrEmpty(client.CodeClient) || string.IsNullOrEmpty(client.NomSociete))
                    {
                        erreurs.Add($"Ligne {row.RowNumber()} : Code ou Société manquant.");
                        continue;
                    }

                    // Vérifier si le client existe déjà
                    var existe = await _context.Clients
                        .AnyAsync(c => c.CodeClient == client.CodeClient);

                    if (existe)
                    {
                        erreurs.Add($"Ligne {row.RowNumber()} : Code '{client.CodeClient}' déjà existant.");
                        continue;
                    }

                    clients.Add(client);
                }
                catch (Exception ex)
                {
                    erreurs.Add($"Ligne {row.RowNumber()} : Erreur — {ex.Message}");
                }
            }

            if (clients.Any())
            {
                _context.Clients.AddRange(clients);
                await _context.SaveChangesAsync();
            }

            TempData["Success"] = $"{clients.Count} tiers importé(s) avec succès.";
            if (erreurs.Any())
                TempData["Erreurs"] = string.Join("|", erreurs);

            return RedirectToAction("Index");
        }
    }
}