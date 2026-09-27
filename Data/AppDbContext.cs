using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Data
{
    public class AppDbContext : DbContext
    {
        // Capturé à la construction du contexte (scoped par requête) : le tenant
        // de l'utilisateur connecté, ou 0 pour le SuperAdmin (portée globale).
        private readonly int _currentTenantId;

        public AppDbContext(DbContextOptions<AppDbContext> options, ITenantProvider tenantProvider)
            : base(options)
        {
            _currentTenantId = tenantProvider.TenantId;
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<OperationCaisse>()
            .HasOne(o => o.JourneeCaisse)
            .WithMany()
            .HasForeignKey(o => o.JourneeCaisseId)
            .OnDelete(DeleteBehavior.Restrict);

            // Cloisonnement multi-tenant : chaque requête ne voit que les
            // données de son propre tenant. _currentTenantId == 0 (SuperAdmin)
            // désactive le filtre et donne une vue globale.
            modelBuilder.Entity<Utilisateur>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<Caisse>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<Client>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<Motif>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<ModePaiement>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<JourneeCaisse>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<OperationCaisse>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<Facture>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<LigneFacture>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<ComptageCloture>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);
        }

        public override int SaveChanges(bool acceptAllChangesOnSuccess)
        {
            StamperTenantId();
            return base.SaveChanges(acceptAllChangesOnSuccess);
        }

        public override Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
        {
            StamperTenantId();
            return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
        }

        // Attribue automatiquement le tenant courant aux nouvelles entités qui
        // n'en ont pas encore (ex: création via un contrôleur qui ne s'en occupe pas).
        // Ne s'applique pas au SuperAdmin (_currentTenantId == 0) : dans ce cas,
        // le tenant doit être choisi explicitement (ex: création d'un tenant/utilisateur).
        private void StamperTenantId()
        {
            if (_currentTenantId == 0)
                return;

            foreach (var entry in ChangeTracker.Entries<ITenantScoped>())
            {
                if (entry.State == EntityState.Added && entry.Entity.TenantId == 0)
                {
                    entry.Entity.TenantId = _currentTenantId;
                }
            }
        }

        public DbSet<Tenant> Tenants { get; set; }

        public DbSet<Utilisateur> Utilisateurs { get; set; }
        public DbSet<Caisse> Caisses { get; set; }
        public DbSet<Client> Clients { get; set; }
        public DbSet<JourneeCaisse> JourneesCaisses { get; set; }
        public DbSet<OperationCaisse> OperationsCaisses { get; set; }
        public DbSet<Facture> Factures { get; set; }

        public DbSet<LigneFacture> LignesFactures { get; set; }

        public DbSet<Motif> Motifs { get; set; }

        public DbSet<ModePaiement> ModesPaiement { get; set; }

        public DbSet<ComptageCloture> ComptagesCloture { get; set; }
    }
}
