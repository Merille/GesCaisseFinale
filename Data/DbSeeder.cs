using EasytransitCaisse.Models;
using Microsoft.EntityFrameworkCore;
using System.Security.Cryptography;
using System.Text;

namespace EasytransitCaisse.Data
{
    public static class DbSeeder
    {
        public static void Seed(AppDbContext context)
        {
            // SuperAdmin : portée globale (TenantId = 0), gère les tenants.
            if (!context.Utilisateurs.IgnoreQueryFilters().Any(u => u.NomUtilisateur == "superadmin"))
            {
                context.Utilisateurs.Add(new Utilisateur
                {
                    NomUtilisateur = "superadmin",
                    NomComplet = "Super Administrateur",
                    Profil = "SuperAdmin",
                    TenantId = null,
                    MotPasse = HashPassword("123")
                });

                context.SaveChanges();
            }

            if (!context.Tenants.Any())
            {
                var tenant = new Tenant
                {
                    Nom = "Société de démonstration",
                    Code = "DEMO",
                    Actif = true
                };

                context.Tenants.Add(tenant);
                context.SaveChanges();
                context.AjouterTaxesInitiales(tenant.Id);

                context.Utilisateurs.Add(new Utilisateur
                {
                    NomUtilisateur = "admin",
                    NomComplet = "Administrateur",
                    Profil = "Admin",
                    TenantId = tenant.Id,
                    MotPasse = HashPassword("123")
                });

                context.Caisses.Add(new Caisse
                {
                    ChkCode = "CASH1",
                    ChkDescription = "Caisse principale",
                    StCode = "ST01",
                    SalesPersonDefault = 1,
                    CashierDefault = 1,
                    CustomerDefaultCode = "CUST001",
                    JournalDefaultCode = "JRN01",
                    TenantId = tenant.Id
                });

                context.SaveChanges();
            }
        }

        private static string HashPassword(string password)
        {
            using var sha = SHA256.Create();
            var bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(password));
            return Convert.ToBase64String(bytes);
        }
    }
}
