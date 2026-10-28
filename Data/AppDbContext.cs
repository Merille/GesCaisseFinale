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

            // Point de vente : catalogue.
            modelBuilder.Entity<Categorie>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<Produit>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<Produit>()
                .HasIndex(p => new { p.TenantId, p.Code })
                .IsUnique();

            modelBuilder.Entity<Produit>()
                .HasIndex(p => p.CodeBarres);

            // Point de vente : ventes.
            modelBuilder.Entity<CommandePos>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<LigneCommandePos>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<PaiementPos>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<CommandePos>()
                .HasIndex(c => new { c.TenantId, c.Numero })
                .IsUnique();

            modelBuilder.Entity<CommandePos>()
                .HasIndex(c => new { c.TenantId, c.CleClient })
                .IsUnique();

            modelBuilder.Entity<CommandePos>()
                .HasOne(c => c.JourneeCaisse)
                .WithMany()
                .HasForeignKey(c => c.JourneeCaisseId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<CommandePos>()
                .HasMany(c => c.Lignes)
                .WithOne()
                .HasForeignKey(l => l.CommandePosId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<CommandePos>()
                .HasMany(c => c.Paiements)
                .WithOne()
                .HasForeignKey(p => p.CommandePosId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<CommandePos>().Property(c => c.Numero).HasMaxLength(50);
            modelBuilder.Entity<CommandePos>().Property(c => c.CleClient).HasMaxLength(64);
            modelBuilder.Entity<CommandePos>().Property(c => c.Motif).HasMaxLength(300);
            modelBuilder.Entity<CommandePos>().HasIndex(c => c.CommandeOrigineId);
            modelBuilder.Entity<LigneCommandePos>().HasIndex(l => l.LigneOrigineId);

            // Point de vente : stock.
            modelBuilder.Entity<MouvementStock>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<MouvementStock>()
                .HasIndex(m => new { m.ProduitId, m.DateMouvement });

            modelBuilder.Entity<MouvementStock>()
                .HasIndex(m => new { m.TenantId, m.DateMouvement });

            modelBuilder.Entity<MouvementStock>().Property(m => m.TypeMouvement).HasMaxLength(20);
            modelBuilder.Entity<MouvementStock>().Property(m => m.Reference).HasMaxLength(100);
            modelBuilder.Entity<MouvementStock>().Property(m => m.Commentaire).HasMaxLength(300);

            // Point de vente : unités de vente.
            modelBuilder.Entity<UniteVente>().ToTable("Unites")
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);
            modelBuilder.Entity<UniteVente>()
                .HasIndex(u => new { u.TenantId, u.Nom }).IsUnique();

            // Point de vente : taxes (plusieurs par produit).
            modelBuilder.Entity<Taxe>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<ProduitTaxe>()
                .HasKey(pt => new { pt.ProduitId, pt.TaxeId });

            modelBuilder.Entity<ProduitTaxe>()
                .HasOne<Produit>().WithMany().HasForeignKey(pt => pt.ProduitId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ProduitTaxe>()
                .HasOne<Taxe>().WithMany().HasForeignKey(pt => pt.TaxeId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<LigneCommandePosTaxe>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<LigneCommandePos>()
                .HasMany(l => l.Taxes)
                .WithOne()
                .HasForeignKey(t => t.LigneCommandePosId)
                .OnDelete(DeleteBehavior.Cascade);

            // Images (logo de société, photo de produit).
            modelBuilder.Entity<TenantLogo>()
                .HasOne<Tenant>().WithOne().HasForeignKey<TenantLogo>(l => l.TenantId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ProduitImage>()
                .HasOne<Produit>().WithOne().HasForeignKey<ProduitImage>(i => i.ProduitId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<Produit>()
                .Property(p => p.Unite)
                .HasDefaultValue("Unité");

            // Variantes : attributs du modèle, valeurs, combinaison de chaque variante.
            modelBuilder.Entity<Produit>().HasIndex(p => p.ParentId);

            modelBuilder.Entity<ProduitAttribut>()
                .HasOne<Produit>().WithMany().HasForeignKey(a => a.ProduitId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<ProduitAttribut>()
                .HasMany(a => a.Valeurs).WithOne().HasForeignKey(v => v.ProduitAttributId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<VarianteValeur>()
                .HasKey(vv => new { vv.VarianteId, vv.ValeurId });

            modelBuilder.Entity<VarianteValeur>()
                .HasOne<Produit>().WithMany().HasForeignKey(vv => vv.VarianteId)
                .OnDelete(DeleteBehavior.Cascade);

            // Pas de suppression en cascade depuis la valeur (SQL Server refuse deux chemins
            // de cascade depuis Produits) : les liens sont retirés par le code avant la valeur.
            modelBuilder.Entity<VarianteValeur>()
                .HasOne<ProduitAttributValeur>().WithMany().HasForeignKey(vv => vv.ValeurId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Tenant>()
                .Property(t => t.PosVenteSansStock)
                .HasDefaultValue(true);

            modelBuilder.Entity<Produit>()
                .HasOne(p => p.Categorie)
                .WithMany()
                .HasForeignKey(p => p.CategorieId)
                .OnDelete(DeleteBehavior.SetNull);
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

        public DbSet<Categorie> Categories { get; set; }

        public DbSet<Produit> Produits { get; set; }

        public DbSet<CommandePos> CommandesPos { get; set; }

        public DbSet<LigneCommandePos> LignesCommandePos { get; set; }

        public DbSet<PaiementPos> PaiementsPos { get; set; }

        public DbSet<MouvementStock> MouvementsStock { get; set; }

        public DbSet<Taxe> Taxes { get; set; }

        public DbSet<UniteVente> Unites { get; set; }

        public DbSet<ProduitTaxe> ProduitTaxes { get; set; }

        public DbSet<LigneCommandePosTaxe> LignesCommandePosTaxes { get; set; }

        public DbSet<TenantLogo> TenantLogos { get; set; }

        public DbSet<ProduitImage> ProduitImages { get; set; }

        public DbSet<ProduitAttribut> ProduitAttributs { get; set; }

        public DbSet<ProduitAttributValeur> ProduitAttributValeurs { get; set; }

        public DbSet<VarianteValeur> VarianteValeurs { get; set; }
    }
}
