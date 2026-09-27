using EasytransitCaisse.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Services
{
    // Bloque toute action (pas seulement le login) dès qu'une société est
    // inactive ou que sa licence/abonnement a expiré — vérifié en base à
    // chaque requête, donc effectif immédiatement, même sur une session déjà
    // ouverte. Le SuperAdmin (TenantId = 0) n'est jamais concerné.
    public class TenantStatusFilter : IAsyncActionFilter
    {
        private readonly AppDbContext _context;

        public TenantStatusFilter(AppDbContext context)
        {
            _context = context;
        }

        public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
        {
            var user = context.HttpContext.User;

            var controllerName = context.RouteData.Values["controller"]?.ToString();

            // AuthController (login/logout/page de blocage) reste toujours accessible.
            if (user.Identity?.IsAuthenticated != true || controllerName == "Auth")
            {
                await next();
                return;
            }

            var tenantId = int.TryParse(
                user.FindFirst(AppClaimTypes.TenantId)?.Value, out var t) ? t : 0;

            if (tenantId == 0) // SuperAdmin : portée globale, jamais bloqué.
            {
                await next();
                return;
            }

            var tenant = await _context.Tenants.FirstOrDefaultAsync(x => x.Id == tenantId);

            if (tenant == null || tenant.EstBloque)
            {
                context.Result = new RedirectToActionResult("SocieteSuspendue", "Auth", null);
                return;
            }

            await next();
        }
    }
}
