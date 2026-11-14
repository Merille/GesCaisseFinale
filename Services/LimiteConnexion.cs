using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Services
{
    // Limite des tentatives de connexion : après 5 échecs en 15 minutes pour un même nom d'utilisateur
    // depuis une même adresse, ou 20 échecs depuis une même adresse, la connexion est refusée jusqu'à
    // 15 minutes après le premier de ces échecs (mot de passe non vérifié). Comme bootstrap.php en PHP.
    public static class LimiteConnexion
    {
        public const int Fenetre = 15, MaxCompte = 5, MaxAdresse = 20;

        // Minutes d'attente avant de pouvoir réessayer (0 : connexion permise).
        public static async Task<int> BloqueeAsync(AppDbContext context, string nom, string ip)
        {
            var maintenant = DateTime.Now;
            var depuis = maintenant.AddMinutes(-Fenetre);
            var fin = DateTime.MinValue;
            var tentatives = context.TentativesConnexion.AsNoTracking().Where(t => t.DateTentative >= depuis);
            foreach (var (requete, max) in new[] { (tentatives.Where(t => t.NomUtilisateur == nom && t.AdresseIp == ip), MaxCompte), (tentatives.Where(t => t.AdresseIp == ip), MaxAdresse) })
            {
                var dates = await requete.OrderByDescending(t => t.DateTentative).Take(max).Select(t => t.DateTentative).ToListAsync();
                if (dates.Count >= max && dates[^1].AddMinutes(Fenetre) > fin)
                    fin = dates[^1].AddMinutes(Fenetre);
            }
            return fin > maintenant ? (int)Math.Ceiling((fin - maintenant).TotalMinutes) : 0;
        }

        public static async Task EchecAsync(AppDbContext context, string nom, string ip)
        {
            var limite = DateTime.Now.AddDays(-1);
            await context.TentativesConnexion.Where(t => t.DateTentative < limite).ExecuteDeleteAsync();
            context.TentativesConnexion.Add(new TentativeConnexion { NomUtilisateur = nom.Length > 100 ? nom[..100] : nom, AdresseIp = ip, DateTentative = DateTime.Now });
            await context.SaveChangesAsync();
        }

        public static Task ReussieAsync(AppDbContext context, string nom)
            => context.TentativesConnexion.Where(t => t.NomUtilisateur == nom).ExecuteDeleteAsync();
    }
}
