using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

namespace EasytransitCaisse.Controllers
{
    [AllowAnonymous]
    public class AuthController : Controller
    {
        private readonly AppDbContext _context;

        public AuthController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public IActionResult Login()
        {
            return View();
        }

        // HASH PASSWORD
        private string HashPassword(string password)
        {
            using var sha = SHA256.Create();
            var bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(password));
            return Convert.ToBase64String(bytes);
        }

        [HttpPost]
        public async Task<IActionResult> Login(LoginViewModel model)
        {
            if (!ModelState.IsValid)
                return View(model);

            var hash = HashPassword(model.Password);

            // Le username est global (pas de filtre tenant ici : on ne connaît
            // pas encore le tenant tant que l'utilisateur n'est pas identifié).
            var user = _context.Utilisateurs
                .IgnoreQueryFilters()
                .Include(u => u.Tenant)
                .FirstOrDefault(u =>
                    u.NomUtilisateur == model.Username &&
                    u.MotPasse == hash);

            if (user == null)
            {
                ViewBag.Error = "Utilisateur ou mot de passe incorrect";
                return View();
            }

            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(ClaimTypes.Name, user.NomUtilisateur),
                new Claim(AppClaimTypes.Profil, user.Profil),
                new Claim(AppClaimTypes.TenantId, (user.TenantId ?? 0).ToString()),
                new Claim(AppClaimTypes.TenantName, user.Tenant?.Nom ?? ""),
                new Claim(AppClaimTypes.NomComplet, user.NomComplet),
                new Claim(AppClaimTypes.PeutValiderOperations, user.PeutValiderOperations.ToString()),
            };

            var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);

            await HttpContext.SignInAsync(
                CookieAuthenticationDefaults.AuthenticationScheme,
                new ClaimsPrincipal(identity));

            return RedirectToAction("Index", "Dashboard");
        }

        public async Task<IActionResult> Logout()
        {
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            return RedirectToAction("Login");
        }

        // Page affichée à la place de toute action dès que la société de
        // l'utilisateur connecté est inactive ou que sa licence/son abonnement
        // a expiré (voir TenantStatusFilter).
        public IActionResult SocieteSuspendue()
        {
            return View();
        }
    }
}