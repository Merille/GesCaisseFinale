using EasytransitCaisse.Data;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Images enregistrées dans la base : photos des produits et logos des sociétés.
    // L'adresse porte la date de mise à jour (?v=…) : le navigateur peut les garder en cache.
    public class ImageController : Controller
    {
        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;

        public ImageController(AppDbContext context, ITenantProvider tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        private IActionResult Envoyer(string? type, byte[]? donnees)
        {
            if (type == null || donnees == null)
                return NotFound();
            Response.Headers.CacheControl = "private, max-age=31536000";
            Response.Headers["X-Content-Type-Options"] = "nosniff";
            return File(donnees, type);
        }

        public IActionResult Produit(int id)
        {
            // Le filtre de société des produits s'applique : seulement les produits de sa société.
            var image = (from i in _context.ProduitImages
                         join p in _context.Produits on i.ProduitId equals p.Id
                         where i.ProduitId == id
                         select new { i.TypeContenu, i.Donnees }).AsNoTracking().FirstOrDefault();
            return Envoyer(image?.TypeContenu, image?.Donnees);
        }

        public IActionResult Societe(int id)
        {
            // Son propre logo ; le SuperAdmin voit ceux de toutes les sociétés.
            if (!_tenant.IsSuperAdmin && id != _tenant.TenantId)
                return NotFound();
            var logo = _context.TenantLogos.AsNoTracking().FirstOrDefault(l => l.TenantId == id);
            return Envoyer(logo?.TypeContenu, logo?.Donnees);
        }
    }
}
