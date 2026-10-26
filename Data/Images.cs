using EasytransitCaisse.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Data
{
    // Logos de société et photos de produit, enregistrés dans la base.
    public static class Images
    {
        public const long TailleMax = 1024 * 1024;

        // Image envoyée par un formulaire : null si aucun fichier ; erreur si fichier refusé.
        // Le type est reconnu d'après le contenu (JPG, PNG, WEBP ou GIF), pas d'après le nom.
        public static (string Type, byte[] Donnees)? Lire(IFormFile? fichier, out string? erreur)
        {
            erreur = null;
            if (fichier == null || fichier.Length == 0)
                return null;
            if (fichier.Length > TailleMax)
            {
                erreur = "Image trop lourde : 1 Mo au plus.";
                return null;
            }
            using var flux = new MemoryStream();
            fichier.CopyTo(flux);
            var octets = flux.ToArray();
            var type = TypeImage(octets);
            if (type == null)
            {
                erreur = "Format d'image non reconnu : utilisez une image JPG, PNG, WEBP ou GIF.";
                return null;
            }
            return (type, octets);
        }

        private static string? TypeImage(byte[] o)
        {
            bool Commence(params byte[] signature) => o.Length >= signature.Length && signature.Select((b, i) => o[i] == b).All(x => x);
            if (Commence(0x89, 0x50, 0x4E, 0x47)) return "image/png";
            if (Commence(0xFF, 0xD8, 0xFF)) return "image/jpeg";
            if (Commence(0x47, 0x49, 0x46, 0x38)) return "image/gif";
            if (o.Length > 12 && Commence(0x52, 0x49, 0x46, 0x46) && o[8] == 0x57 && o[9] == 0x45 && o[10] == 0x42 && o[11] == 0x50) return "image/webp";
            return null;
        }

        // Enregistre ou retire la photo d'un produit (déjà enregistré).
        public static void EnregistrerImage(this AppDbContext context, Produit produit, (string Type, byte[] Donnees)? image, bool supprimer)
        {
            var existante = context.ProduitImages.FirstOrDefault(i => i.ProduitId == produit.Id);
            if (image.HasValue)
            {
                if (existante == null)
                    context.ProduitImages.Add(existante = new ProduitImage { ProduitId = produit.Id });
                existante.TypeContenu = image.Value.Type;
                existante.Donnees = image.Value.Donnees;
                produit.ImageMaj = DateTime.Now;
            }
            else if (supprimer)
            {
                if (existante != null)
                    context.ProduitImages.Remove(existante);
                produit.ImageMaj = null;
            }
        }

        // Enregistre ou retire le logo d'une société (déjà enregistrée).
        public static void EnregistrerLogo(this AppDbContext context, Tenant tenant, (string Type, byte[] Donnees)? logo, bool supprimer)
        {
            var existant = context.TenantLogos.FirstOrDefault(l => l.TenantId == tenant.Id);
            if (logo.HasValue)
            {
                if (existant == null)
                    context.TenantLogos.Add(existant = new TenantLogo { TenantId = tenant.Id });
                existant.TypeContenu = logo.Value.Type;
                existant.Donnees = logo.Value.Donnees;
                tenant.LogoMaj = DateTime.Now;
            }
            else if (supprimer)
            {
                if (existant != null)
                    context.TenantLogos.Remove(existant);
                tenant.LogoMaj = null;
            }
        }

        // Adresses des images ; la date sert de version (le navigateur peut les garder en cache).
        public static string? UrlImage(Produit p) => p.ImageMaj.HasValue ? $"/Image/Produit/{p.Id}?v={p.ImageMaj.Value.Ticks}" : null;

        public static string? UrlLogo(Tenant? t) => t?.LogoMaj.HasValue == true ? $"/Image/Societe/{t.Id}?v={t.LogoMaj!.Value.Ticks}" : null;

        // Logo intégré à la page (impressions PDF, où wkhtmltopdf n'a pas la session de l'utilisateur).
        public static string? LogoIntegre(this AppDbContext context, int tenantId)
        {
            var logo = context.TenantLogos.AsNoTracking().FirstOrDefault(l => l.TenantId == tenantId);
            return logo == null ? null : $"data:{logo.TypeContenu};base64,{Convert.ToBase64String(logo.Donnees)}";
        }

        // Lignes de coordonnées : adresse, « ville, pays », téléphone et e-mail, NIF.
        public static List<string> Coordonnees(Tenant? t)
        {
            if (t == null)
                return new List<string>();
            string Texte(string? v) => (v ?? "").Trim();
            var lignes = new List<string>
            {
                Texte(t.Adresse),
                string.Join(", ", new[] { Texte(t.Ville), Texte(t.Pays) }.Where(x => x != "")),
                string.Join(" · ", new[] { Texte(t.Telephone) != "" ? "Tél. " + Texte(t.Telephone) : "", Texte(t.Email) }.Where(x => x != "")),
                Texte(t.NIF) != "" ? "NIF : " + Texte(t.NIF) : ""
            };
            return lignes.Where(l => l != "").ToList();
        }
    }
}
