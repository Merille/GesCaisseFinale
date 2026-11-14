using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

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

        [HttpPost]
        public async Task<IActionResult> Login(LoginViewModel model)
        {
            if (!ModelState.IsValid)
                return View(model);

            var nom = model.Username ?? "";
            var ip = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "";
            if (ip.Length > 45) ip = ip[..45];
            var attente = await LimiteConnexion.BloqueeAsync(_context, nom, ip);
            if (attente > 0)
            {
                ViewBag.Error = $"Trop de tentatives de connexion. Réessayez dans {attente} minute{(attente > 1 ? "s" : "")}.";
                model.Password = "";
                return View(model);
            }

            // Le username est global (pas de filtre tenant ici : on ne connaît
            // pas encore le tenant tant que l'utilisateur n'est pas identifié).
            var user = await _context.Utilisateurs
                .IgnoreQueryFilters()
                .Include(u => u.Tenant)
                .FirstOrDefaultAsync(u => u.NomUtilisateur == nom);
            // Utilisateur inconnu : même calcul, pour ne pas révéler par le temps de réponse si le compte existe.
            var ok = MotsDePasse.Verifier(model.Password ?? "", user?.MotPasse ?? MotsDePasse.Factice);

            if (user == null || !ok)
            {
                await LimiteConnexion.EchecAsync(_context, nom, ip);
                ViewBag.Error = "Utilisateur ou mot de passe incorrect";
                model.Password = "";
                return View(model);
            }

            await LimiteConnexion.ReussieAsync(_context, nom);
            // Ancien format de mot de passe : remplacé par le format actuel.
            if (MotsDePasse.AMettreANiveau(user.MotPasse))
            {
                user.MotPasse = MotsDePasse.Hacher(model.Password ?? "");
                await _context.SaveChangesAsync();
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

            return Redirect("/Auth/Accueil");
        }

        public async Task<IActionResult> Logout()
        {
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            return RedirectToAction("Login");
        }

        // Page affichée quand un utilisateur connecté ouvre une page réservée
        // à un autre profil (ex. un caissier sur la gestion des utilisateurs).
        public IActionResult AccesRefuse()
        {
            if (User.Identity?.IsAuthenticated != true)
                return RedirectToAction("Login");

            return View();
        }

        // Première page permise par les droits de l'utilisateur, après la connexion.
        public async Task<IActionResult> Accueil([FromServices] DroitsUtilisateur droits)
        {
            if (User.Identity?.IsAuthenticated != true)
                return RedirectToAction("Login");
            await droits.ChargerAsync();
            return Redirect(droits.Accueil());
        }

        // Profil sans aucun droit : page d'information (avec lien de déconnexion).
        public IActionResult AucunAcces()
        {
            if (User.Identity?.IsAuthenticated != true)
                return RedirectToAction("Login");
            return View();
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