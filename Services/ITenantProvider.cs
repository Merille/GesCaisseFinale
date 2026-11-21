namespace GesCaisse.Services
{
    public interface ITenantProvider
    {
        // 0 = aucun tenant (portée globale, réservé au SuperAdmin)
        int TenantId { get; }

        bool IsSuperAdmin { get; }
    }
}
