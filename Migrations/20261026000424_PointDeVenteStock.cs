using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class PointDeVenteStock : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "PosVenteSansStock",
                table: "Tenants",
                type: "bit",
                nullable: false,
                defaultValue: true);

            migrationBuilder.CreateTable(
                name: "MouvementsStock",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    ProduitId = table.Column<int>(type: "int", nullable: false),
                    DateMouvement = table.Column<DateTime>(type: "datetime2", nullable: false),
                    TypeMouvement = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Quantite = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    StockApres = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Reference = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    CommandePosId = table.Column<int>(type: "int", nullable: true),
                    UtilisateurId = table.Column<int>(type: "int", nullable: true),
                    Commentaire = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MouvementsStock", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MouvementsStock_Produits_ProduitId",
                        column: x => x.ProduitId,
                        principalTable: "Produits",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_MouvementsStock_ProduitId_DateMouvement",
                table: "MouvementsStock",
                columns: new[] { "ProduitId", "DateMouvement" });

            migrationBuilder.CreateIndex(
                name: "IX_MouvementsStock_TenantId_DateMouvement",
                table: "MouvementsStock",
                columns: new[] { "TenantId", "DateMouvement" });

            // Point de départ de l'historique : stock actuel des produits suivis.
            migrationBuilder.Sql(@"INSERT INTO MouvementsStock (TenantId, ProduitId, DateMouvement, TypeMouvement, Quantite, StockApres, Commentaire)
SELECT TenantId, Id, GETDATE(), N'Stock initial', StockActuel, StockActuel, N'Stock au démarrage de l''historique'
FROM Produits WHERE SuiviStock = 1;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "MouvementsStock");

            migrationBuilder.DropColumn(
                name: "PosVenteSansStock",
                table: "Tenants");
        }
    }
}
