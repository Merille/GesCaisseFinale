namespace EasytransitCaisse.Services
{
    public class TenantProvider : ITenantProvider
    {
        public const string CookieConsultation = "TenantIdConsultation";

        public TenantProvider(IHttpContextAccessor httpContextAccessor)
        {
            var httpContext = httpContextAccessor.HttpContext;
            var user = httpContext?.User;

            // Le profil réel ne dépend jamais de la société consultée : le
            // SuperAdmin garde ses droits même en "regardant" une société.
            IsSuperAdmin = user?.FindFirst(AppClaimTypes.Profil)?.Value == "SuperAdmin";

            if (IsSuperAdmin)
            {
                // Société choisie via le sélecteur du menu (cookie) — vide/absent
                // = portée globale ("Toutes les sociétés").
                var cookie = httpContext?.Request.Cookies[CookieConsultation];
                TenantId = int.TryParse(cookie, out var idConsultation) ? idConsultation : 0;
            }
            else
            {
                var claim = user?.FindFirst(AppClaimTypes.TenantId)?.Value;
                TenantId = int.TryParse(claim, out var id) ? id : 0;
            }
        }

        public int TenantId { get; }

        public bool IsSuperAdmin { get; }
    }
}
