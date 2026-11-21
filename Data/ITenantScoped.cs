namespace GesCaisse.Data
{
    // TenantId == 0 signifie "aucun tenant" (réservé au SuperAdmin, portée globale).
    public interface ITenantScoped
    {
        int TenantId { get; set; }
    }
}
