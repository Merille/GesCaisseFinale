using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class UnitesDeVente : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Unites",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    Nom = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Libelle = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Actif = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Unites", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Unites_TenantId_Nom",
                table: "Unites",
                columns: new[] { "TenantId", "Nom" },
                unique: true);

            // Unités de départ de chaque société, puis celles déjà saisies sur des produits.
            migrationBuilder.Sql(@"
INSERT INTO Unites (TenantId, Nom, Libelle, Actif)
SELECT t.Id, u.Nom, u.Libelle, 1
FROM Tenants t
CROSS JOIN (VALUES
    (N'Unité', N'Article vendu à l''unité'), (N'Pièce', N'Pièce'), (N'Kg', N'Kilogramme'), (N'g', N'Gramme'),
    (N'Litre', N'Litre'), (N'cl', N'Centilitre'), (N'Mètre', N'Mètre'), (N'Carton', N'Carton'), (N'Paquet', N'Paquet'),
    (N'Boîte', N'Boîte'), (N'Sac', N'Sac'), (N'Bouteille', N'Bouteille'), (N'Page', N'Page (impression, photocopie)'),
    (N'Heure', N'Heure (service)')) AS u (Nom, Libelle);");
            migrationBuilder.Sql(@"
INSERT INTO Unites (TenantId, Nom, Actif)
SELECT DISTINCT p.TenantId, p.Unite, 1
FROM Produits p
WHERE LTRIM(RTRIM(p.Unite)) <> N''
  AND NOT EXISTS (SELECT 1 FROM Unites u WHERE u.TenantId = p.TenantId AND u.Nom = p.Unite);");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Unites");
        }
    }
}
