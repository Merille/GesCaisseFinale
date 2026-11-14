using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class ProfilsDroits : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "Profil",
                table: "Utilisateurs",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AddColumn<int>(
                name: "ProfilId",
                table: "Utilisateurs",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Profils",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    Nom = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    Droits = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Profils", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Utilisateurs_ProfilId",
                table: "Utilisateurs",
                column: "ProfilId");

            migrationBuilder.CreateIndex(
                name: "IX_Profils_TenantId_Nom",
                table: "Profils",
                columns: new[] { "TenantId", "Nom" },
                unique: true);

            // Profils Caissier et Vendeur pour chaque société (droits qu'ils avaient déjà), puis
            // rattachement des utilisateurs existants à leur profil. Comme 028_profils.sql en PHP.
            migrationBuilder.Sql(@"INSERT INTO Profils (TenantId, Nom, Description, Droits)
SELECT t.Id, n.Nom, N'Caisse, ventes et tiers', N'tableau_bord,caisses,caisses_gerer,tiers,rapports,vendre,ventes,cuisine'
FROM Tenants t CROSS JOIN (VALUES (N'Caissier'), (N'Vendeur')) AS n(Nom)
WHERE NOT EXISTS (SELECT 1 FROM Profils p WHERE p.TenantId = t.Id AND p.Nom = n.Nom);");
            migrationBuilder.Sql(@"UPDATE u SET u.ProfilId = p.Id FROM Utilisateurs u
JOIN Profils p ON p.TenantId = u.TenantId AND p.Nom = u.Profil
WHERE u.Profil NOT IN (N'Admin', N'SuperAdmin') AND u.ProfilId IS NULL;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Profils");

            migrationBuilder.DropIndex(
                name: "IX_Utilisateurs_ProfilId",
                table: "Utilisateurs");

            migrationBuilder.DropColumn(
                name: "ProfilId",
                table: "Utilisateurs");

            migrationBuilder.AlterColumn<string>(
                name: "Profil",
                table: "Utilisateurs",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(50)",
                oldMaxLength: 50);
        }
    }
}
