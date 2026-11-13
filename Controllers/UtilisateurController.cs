using System.Security.Claims;
﻿using EasytransitCaisse.Data;
using EasytransitCaisse.Models;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Controllers
{
    // Réservé aux profils Admin et SuperAdmin.
    [Authorize(Policy = "Admin")]
    public class UtilisateurController : Controller
    {
        private readonly AppDbContext _context;
        private readonly ITenantProvider _tenantProvider;

        public UtilisateurController(AppDbContext context, ITenantProvider tenantProvider)
        {
            _context = context;
            _tenantProvider = tenantProvider;
        }

        // Seul le SuperAdmin choisit le tenant explicitement (les autres profils
        // sont automatiquement rattachés à leur propre tenant à l'enregistrement).
        private void ChargerTenantsSiSuperAdmin()
        {
            ViewBag.IsSuperAdmin = _tenantProvider.IsSuperAdmin;

            if (_tenantProvider.IsSuperAdmin)
            {
                ViewBag.Tenants = _context.Tenants
                    .OrderBy(t => t.Nom)
                    .Select(t => new SelectListItem
                    {
                        Value = t.Id.ToString(),
                        Text = t.Nom
                    })
                    .ToList();
            }
        }

        // Profils qu'on peut attribuer : SuperAdmin seulement par un SuperAdmin.
        private bool ProfilAutorise(string? profil) =>
            profil is "Admin" or "Caissier" or "Vendeur"
            || (profil == "SuperAdmin" && _tenantProvider.IsSuperAdmin);

        // LISTE

        public async Task<IActionResult> Index()
        {
            ViewBag.IsSuperAdmin = _tenantProvider.IsSuperAdmin;

            var users = await _context.Utilisateurs
                .Include(u => u.Tenant)
                .OrderBy(c => c.NomUtilisateur)
                .ToListAsync();

            return View(users);
        }
        //public IActionResult Index()
        //{
        //    var users = _context.Utilisateurs.ToList();
        //    return View(users);
        //}

        // Contrôles communs, identiques à la version PHP. Renvoie un message d'erreur ou null.
        private string? Erreur(Utilisateur u, int idExclu, bool creation)
        {
            if (string.IsNullOrWhiteSpace(u.NomUtilisateur) || string.IsNullOrWhiteSpace(u.NomComplet))
                return "Le nom d'utilisateur et le nom complet sont obligatoires.";
            if (creation && (u.MotPasse ?? "").Length < 3)
                return "Le mot de passe doit contenir au moins 3 caractères.";
            if (remiseMaxInvalide || u.RemiseMax.HasValue && (u.RemiseMax <= 0 || u.RemiseMax > 100))
                return "La remise maximale doit être comprise entre 0 et 100 % (laissez vide pour ne pas limiter).";
            if (u.Profil != "SuperAdmin" && (u.TenantId ?? 0) == 0)
                return "Choisissez la société de cet utilisateur.";
            var nom = u.NomUtilisateur.Trim();
            if (_context.Utilisateurs.IgnoreQueryFilters().Any(x => x.NomUtilisateur == nom && x.Id != idExclu))
                return $"Le nom d'utilisateur « {nom} » est déjà pris.";
            return null;
        }

        // Profil et société retenus : la société est choisie par le SuperAdmin, sinon celle de l'utilisateur.
        private void Normaliser(Utilisateur saisie, int? tenantExistant)
        {
            if (!ProfilAutorise(saisie.Profil))
                saisie.Profil = "Caissier";
            if (_tenantProvider.IsSuperAdmin)
                saisie.TenantId = saisie.Profil == "SuperAdmin" ? null : (saisie.TenantId > 0 ? saisie.TenantId : null);
            else
                saisie.TenantId = tenantExistant ?? _tenantProvider.TenantId;
            saisie.NomUtilisateur = (saisie.NomUtilisateur ?? "").Trim();
            saisie.NomComplet = (saisie.NomComplet ?? "").Trim();
            // Remise maximale : « 10 » ou « 12,5 » ; vide = sans limite (et sans objet sans le droit).
            var max = (Request.Form["RemiseMax"].ToString() ?? "").Trim().Replace(',', '.');
            saisie.RemiseMax = saisie.PeutRemise && max != "" && decimal.TryParse(max, System.Globalization.NumberStyles.Number, System.Globalization.CultureInfo.InvariantCulture, out var m) ? m : null;
            remiseMaxInvalide = saisie.PeutRemise && max != "" && saisie.RemiseMax == null;
        }
        private bool remiseMaxInvalide;

        // CREATE GET
        public IActionResult Create()
        {
            ChargerTenantsSiSuperAdmin();
            return View(new Utilisateur { Profil = "Caissier" });
        }

        // CREATE POST
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Create(Utilisateur user)
        {
            ModelState.Clear();
            Normaliser(user, null);
            var erreur = Erreur(user, 0, true);
            if (erreur != null)
            {
                TempData["Error"] = erreur;
                user.MotPasse = "";
                ChargerTenantsSiSuperAdmin();
                return View(user);
            }

            user.MotPasse = HashPassword(user.MotPasse);
            _context.Utilisateurs.Add(user);
            _context.SaveChanges();
            TempData["Success"] = "Utilisateur créé.";

            return RedirectToAction("Index");
        }

        // EDIT GET
        public IActionResult Edit(int id)
        {
            var user = _context.Utilisateurs.Find(id);

            if (user == null)
                return NotFound();

            user.MotPasse = ""; // ne pas afficher le hash

            ChargerTenantsSiSuperAdmin();

            return View(user);
        }

        // EDIT POST
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Edit(int id, Utilisateur user)
        {
            var existing = _context.Utilisateurs.Find(id);

            if (existing == null)
                return NotFound();

            ModelState.Clear();
            user.Id = existing.Id;
            Normaliser(user, existing.TenantId);
            var erreur = Erreur(user, existing.Id, false);
            if (erreur != null)
            {
                TempData["Error"] = erreur;
                user.MotPasse = "";
                ChargerTenantsSiSuperAdmin();
                return View(user);
            }

            existing.NomUtilisateur = user.NomUtilisateur;
            existing.NomComplet = user.NomComplet;
            existing.Profil = user.Profil;
            existing.PeutValiderOperations = user.PeutValiderOperations;
            existing.PeutRemise = user.PeutRemise;
            existing.RemiseMax = user.RemiseMax;
            existing.TenantId = user.TenantId;
            // Mot de passe changé seulement s'il est saisi.
            if (!string.IsNullOrEmpty(user.MotPasse))
                existing.MotPasse = HashPassword(user.MotPasse);

            _context.SaveChanges();
            TempData["Success"] = "Utilisateur modifié.";

            return RedirectToAction("Index");
        }

        // DELETE : pas son propre compte, ni un utilisateur qui a saisi des opérations (comme la version PHP).
        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Delete(int id)
        {
            var user = _context.Utilisateurs.Find(id);

            if (user != null)
            {
                var moi = int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var m) ? m : 0;
                if (user.Id == moi)
                    TempData["Error"] = "Vous ne pouvez pas supprimer votre propre compte.";
                else if (_context.OperationsCaisses.IgnoreQueryFilters().Any(o => o.UtilisateurId == user.Id))
                    TempData["Error"] = "Cet utilisateur a saisi des opérations : il ne peut pas être supprimé.";
                else
                {
                    _context.Utilisateurs.Remove(user);
                    _context.SaveChanges();
                    TempData["Success"] = "Utilisateur supprimé.";
                }
            }

            return RedirectToAction("Index");
        }

        // HASH PASSWORD
        private string HashPassword(string password)
        {
            using var sha = SHA256.Create();
            var bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(password));
            return Convert.ToBase64String(bytes);
        }
    }
}