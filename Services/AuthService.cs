using EasytransitCaisse.Data;
using Microsoft.EntityFrameworkCore;
using System.Security.Cryptography;
using System.Text;
using EasytransitCaisse.Models;

namespace EasytransitCaisse.Services
{
    public class AuthService
    {
        private readonly AppDbContext _context;

        public AuthService(AppDbContext context)
        {
            _context = context;
        }

        // LOGIN
        public async Task<Utilisateur?> Login(string username, string password)
        {
            var user = await _context.Utilisateurs.FirstOrDefaultAsync(u => u.NomUtilisateur == username);
            return user != null && MotsDePasse.Verifier(password, user.MotPasse) ? user : null;
        }

        // REGISTER
        public async Task<Utilisateur> Register(Utilisateur user)
        {
            user.MotPasse = EasytransitCaisse.Services.MotsDePasse.Hacher(user.MotPasse);

            _context.Utilisateurs.Add(user);
            await _context.SaveChangesAsync();

            return user;
        }
    }
}