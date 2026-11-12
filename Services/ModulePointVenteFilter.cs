using EasytransitCaisse.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.ViewFeatures;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Services
{
    // Module Point de vente optionnel par société : sans lui, les pages du point de vente (vente,
    // catalogue, stock, restaurant, taxes, unités) restent inaccessibles, même par leur adresse.
    // « Toutes les sociétés » (SuperAdmin, TenantId = 0) n'est jamais concerné.
    public class ModulePointVenteFilter : IAsyncActionFilter
    {
        public static readonly HashSet<string> Controleurs = new(StringComparer.OrdinalIgnoreCase)
        {
            "Pos", "Vente", "Stock", "PosRapport", "RapportLivraison", "RapportLinge", "Achat", "Produit", "Categorie", "Combo", "Salle", "Cuisine", "Taxe", "Unite", "Depot", "Livreur"
        };

        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenant;
        private readonly ITempDataDictionaryFactory _tempData;

        public ModulePointVenteFilter(AppDbContext context, ITenantProvider tenant, ITempDataDictionaryFactory tempData)
        {
            _context = context;
            _tenant = tenant;
            _tempData = tempData;
        }

        public static async Task<bool> ActifAsync(AppDbContext context, int tenantId) =>
            tenantId == 0 || (await context.Tenants.AsNoTracking().Where(t => t.Id == tenantId).Select(t => (bool?)t.ModulePointVente).FirstOrDefaultAsync() ?? true);

        public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
        {
            var controleur = context.RouteData.Values["controller"]?.ToString() ?? "";
            if (context.HttpContext.User.Identity?.IsAuthenticated == true && Controleurs.Contains(controleur)
                && !await ActifAsync(_context, _tenant.TenantId))
            {
                _tempData.GetTempData(context.HttpContext)["Error"] = "Le module Point de vente n'est pas activé pour cette société.";
                context.Result = new RedirectToActionResult("Index", "Dashboard", null);
                return;
            }
            await next();
        }
    }
}
