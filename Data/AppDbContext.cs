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

            // Livraisons : livreurs, commandes en attente (partagées entre postes), livraison d'une vente.
            modelBuilder.Entity<Livreur>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);
            modelBuilder.Entity<CommandeAttente>().ToTable("CommandesAttente")
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);
            modelBuilder.Entity<CommandeAttente>()
                .HasOne<JourneeCaisse>().WithMany().HasForeignKey(c => c.JourneeCaisseId).OnDelete(DeleteBehavior.Cascade);
            modelBuilder.Entity<CommandeAttente>()
                .HasOne<Livreur>().WithMany().HasForeignKey(c => c.LivreurId).OnDelete(DeleteBehavior.Restrict);
            modelBuilder.Entity<CommandeAttente>().HasIndex(c => new { c.JourneeCaisseId, c.Numero });
            modelBuilder.Entity<CommandePos>()
                .HasOne<Livreur>().WithMany().HasForeignKey(c => c.LivreurId).OnDelete(DeleteBehavior.Restrict);
            modelBuilder.Entity<CommandePos>().Property(c => c.NomLivraison).HasMaxLength(100);
            modelBuilder.Entity<CommandePos>().Property(c => c.TelephoneLivraison).HasMaxLength(30);
            modelBuilder.Entity<CommandePos>().Property(c => c.AdresseLivraison).HasMaxLength(200);
            modelBuilder.Entity<CommandePos>().Property(c => c.StatutLivraison).HasMaxLength(20);

            // Dépôts de stockage : stock par dépôt (StocksDepots), caisse rattachée à un dépôt.
            modelBuilder.Entity<Depot>()
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);
            modelBuilder.Entity<Depot>()
                .HasIndex(d => new { d.TenantId, d.Code })
                .IsUnique();
            modelBuilder.Entity<StockDepot>().ToTable("StocksDepots");
            modelBuilder.Entity<StockDepot>()
                .HasOne<Depot>().WithMany().HasForeignKey(s => s.DepotId).OnDelete(DeleteBehavior.Restrict);
            modelBuilder.Entity<StockDepot>()
                .HasOne<Produit>().WithMany().HasForeignKey(s => s.ProduitId).OnDelete(DeleteBehavior.Cascade);
            modelBuilder.Entity<StockDepot>().HasIndex(s => s.ProduitId);
            modelBuilder.Entity<MouvementStock>()
                .HasOne(m => m.Depot).WithMany().HasForeignKey(m => m.DepotId).OnDelete(DeleteBehavior.Restrict);
            modelBuilder.Entity<Caisse>()
                .HasOne<Depot>().WithMany().HasForeignKey(c => c.DepotId).OnDelete(DeleteBehavior.Restrict);

            // Restaurant / bar : salles, tables, commandes ouvertes, bons de préparation.
            modelBuilder.Entity<Caisse>().Property(c => c.TypePointVente).HasMaxLength(20).HasDefaultValue("Boutique");
            modelBuilder.Entity<Categorie>().Property(c => c.Preparation).HasMaxLength(20).HasDefaultValue("Cuisine");
            modelBuilder.Entity<CommandePos>().Property(c => c.TableNom).HasMaxLength(60);
            modelBuilder.Entity<LigneCommandePos>().Property(l => l.Note).HasMaxLength(200);

            modelBuilder.Entity<Salle>().ToTable("Salles")
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);
            modelBuilder.Entity<Salle>()
                .HasOne<Caisse>().WithMany().HasForeignKey(s => s.CaisseId)
                .OnDelete(DeleteBehavior.Cascade);
            modelBuilder.Entity<Salle>()
                .HasMany(s => s.Tables).WithOne().HasForeignKey(t => t.SalleId)
                .OnDelete(DeleteBehavior.Cascade);
            modelBuilder.Entity<TableRestaurant>().ToTable("TablesRestaurant")
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);

            modelBuilder.Entity<CommandeOuverte>().ToTable("CommandesOuvertes")
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);
            modelBuilder.Entity<CommandeOuverte>()
                .HasOne<JourneeCaisse>().WithMany().HasForeignKey(c => c.JourneeCaisseId)
                .OnDelete(DeleteBehavior.Cascade);
            modelBuilder.Entity<CommandeOuverte>()
                .HasIndex(c => c.TableId).IsUnique().HasFilter("[TableId] IS NOT NULL");

            modelBuilder.Entity<BonPreparation>().ToTable("BonsPreparation")
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);
            modelBuilder.Entity<BonPreparation>()
                .HasOne<JourneeCaisse>().WithMany().HasForeignKey(b => b.JourneeCaisseId)
                .OnDelete(DeleteBehavior.Cascade);
            modelBuilder.Entity<BonPreparation>()
                .HasIndex(b => new { b.CaisseId, b.Statut });
            modelBuilder.Entity<BonPreparation>()
                .HasMany(b => b.Lignes).WithOne().HasForeignKey(l => l.BonPreparationId)
                .OnDelete(DeleteBehavior.Cascade);
            modelBuilder.Entity<LigneBonPreparation>().ToTable("LignesBonPreparation");

            // Combos (Configuration › Combos) et combos qui composent chaque produit combo. Pas de
            // cascade depuis le produit choisi (SQL Server refuse deux chemins de cascade depuis
            // Produits) : les choix sont retirés par le code à la suppression du produit.
            modelBuilder.Entity<Combo>().ToTable("Combos")
                .HasQueryFilter(e => _currentTenantId == 0 || e.TenantId == _currentTenantId);
            modelBuilder.Entity<Combo>()
                .HasMany(c => c.Choix).WithOne().HasForeignKey(c => c.ComboId)
                .OnDelete(DeleteBehavior.Cascade);
            modelBuilder.Entity<ComboChoix>().ToTable("ComboChoix").HasIndex(c => c.ProduitId);
            modelBuilder.Entity<ProduitCombo>().ToTable("ProduitCombos")
                .HasKey(pc => new { pc.ProduitId, pc.ComboId });
            modelBuilder.Entity<ProduitCombo>()
                .HasOne<Produit>().WithMany().HasForeignKey(pc => pc.ProduitId)
                .OnDelete(DeleteBehavior.Cascade);
            modelBuilder.Entity<ProduitCombo>()
                .HasOne<Combo>().WithMany().HasForeignKey(pc => pc.ComboId)
                .OnDelete(DeleteBehavior.Cascade);

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
        public DbSet<Depot> Depots { get; set; }
        public DbSet<StockDepot> StocksDepots { get; set; }
        public DbSet<Livreur> Livreurs { get; set; }
        public DbSet<CommandeAttente> CommandesAttente { get; set; }

        public DbSet<Taxe> Taxes { get; set; }

        public DbSet<UniteVente> Unites { get; set; }

        public DbSet<Combo> Combos { get; set; }

        public DbSet<ProduitCombo> ProduitCombos { get; set; }

        public DbSet<ComboChoix> ComboChoix { get; set; }

        public DbSet<Salle> Salles { get; set; }

        public DbSet<TableRestaurant> TablesRestaurant { get; set; }

        public DbSet<CommandeOuverte> CommandesOuvertes { get; set; }

        public DbSet<BonPreparation> BonsPreparation { get; set; }

        public DbSet<LigneBonPreparation> LignesBonPreparation { get; set; }

        public DbSet<ProduitTaxe> ProduitTaxes { get; set; }

        public DbSet<LigneCommandePosTaxe> LignesCommandePosTaxes { get; set; }

        public DbSet<TenantLogo> TenantLogos { get; set; }

        public DbSet<ProduitImage> ProduitImages { get; set; }

        public DbSet<ProduitAttribut> ProduitAttributs { get; set; }

        public DbSet<ProduitAttributValeur> ProduitAttributValeurs { get; set; }

        public DbSet<VarianteValeur> VarianteValeurs { get; set; }
    }
}
