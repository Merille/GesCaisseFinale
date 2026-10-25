using EasytransitCaisse.Data;
using EasytransitCaisse.Services;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.Authorization;
using Microsoft.EntityFrameworkCore;
using Rotativa.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddScoped<AuthService>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ITenantProvider, TenantProvider>();

builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Auth/Login";
        options.AccessDeniedPath = "/Auth/AccesRefuse";
        options.ExpireTimeSpan = TimeSpan.FromHours(8);
        options.SlidingExpiration = true;
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("SuperAdmin", policy =>
        policy.RequireClaim(AppClaimTypes.Profil, "SuperAdmin"));

    // Gestion des utilisateurs et des paramètres (motifs, modes de paiement).
    options.AddPolicy("Admin", policy =>
        policy.RequireClaim(AppClaimTypes.Profil, "Admin", "SuperAdmin"));
});

// MVC — connexion obligatoire par défaut sur tous les contrôleurs
// (AuthController est marqué [AllowAnonymous]), et blocage immédiat des
// sociétés inactives/expirées (licence ou abonnement), y compris en session
// déjà ouverte.
builder.Services.AddControllersWithViews(options =>
{
    options.Filters.Add(new AuthorizeFilter());
    options.Filters.Add<TenantStatusFilter>();
});

// Connexion SQL Server
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection")));

var app = builder.Build();


app.UseStaticFiles();

// wwwroot (CSS, images, wkhtmltopdf pour les PDF) doit se trouver dans le dossier
// de démarrage. Sinon, message clair plutôt qu'une ArgumentNullException de Rotativa.
if (string.IsNullOrEmpty(app.Environment.WebRootPath))
{
    throw new InvalidOperationException(
        $"Dossier wwwroot introuvable dans « {app.Environment.ContentRootPath} ». " +
        "Lancez l'application depuis le dossier du projet (profil « http » ou « https » dans Visual Studio).");
}

RotativaConfiguration.Setup(app.Environment.WebRootPath, "Rotativa");


// Seeder DB
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    DbSeeder.Seed(context);
}

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}


app.UseHttpsRedirection();

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapStaticAssets();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Auth}/{action=Login}/{id?}")
    .WithStaticAssets();

app.Run();