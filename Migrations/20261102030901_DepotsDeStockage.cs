using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    // Dépôts de stockage : stock suivi par dépôt, caisse rattachée à un dépôt.
    public partial class DepotsDeStockage : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "DepotId",
                table: "MouvementsStock",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "DepotId",
                table: "Caisses",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Depots",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Nom = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Adresse = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    Responsable = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Actif = table.Column<bool>(type: "bit", nullable: false),
                    ParDefaut = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Depots", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "StocksDepots",
                columns: table => new
                {
                    DepotId = table.Column<int>(type: "int", nullable: false),
                    ProduitId = table.Column<int>(type: "int", nullable: false),
                    Quantite = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StocksDepots", x => new { x.DepotId, x.ProduitId });
                    table.ForeignKey(
                        name: "FK_StocksDepots_Depots_DepotId",
                        column: x => x.DepotId,
                        principalTable: "Depots",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StocksDepots_Produits_ProduitId",
                        column: x => x.ProduitId,
                        principalTable: "Produits",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_MouvementsStock_DepotId",
                table: "MouvementsStock",
                column: "DepotId");

            migrationBuilder.CreateIndex(
                name: "IX_Caisses_DepotId",
                table: "Caisses",
                column: "DepotId");

            migrationBuilder.CreateIndex(
                name: "IX_Depots_TenantId_Code",
                table: "Depots",
                columns: new[] { "TenantId", "Code" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_StocksDepots_ProduitId",
                table: "StocksDepots",
                column: "ProduitId");

            // Données existantes : un « Dépôt principal » par société, qui reçoit tout le stock actuel,
            // l'historique des mouvements et toutes les caisses.
            migrationBuilder.Sql(@"INSERT INTO Depots (TenantId, Code, Nom, Actif, ParDefaut)
                SELECT Id, 'DEP01', N'Dépôt principal', 1, 1 FROM Tenants");
            migrationBuilder.Sql(@"INSERT INTO StocksDepots (DepotId, ProduitId, Quantite)
                SELECT d.Id, p.Id, p.StockActuel FROM Produits p
                JOIN Depots d ON d.TenantId = p.TenantId AND d.ParDefaut = 1
                WHERE p.StockActuel <> 0");
            migrationBuilder.Sql(@"UPDATE c SET c.DepotId = d.Id FROM Caisses c
                JOIN Depots d ON d.TenantId = c.TenantId AND d.ParDefaut = 1");
            migrationBuilder.Sql(@"UPDATE m SET m.DepotId = d.Id FROM MouvementsStock m
                JOIN Depots d ON d.TenantId = m.TenantId AND d.ParDefaut = 1");

            migrationBuilder.AddForeignKey(
                name: "FK_Caisses_Depots_DepotId",
                table: "Caisses",
                column: "DepotId",
                principalTable: "Depots",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_MouvementsStock_Depots_DepotId",
                table: "MouvementsStock",
                column: "DepotId",
                principalTable: "Depots",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Caisses_Depots_DepotId",
                table: "Caisses");

            migrationBuilder.DropForeignKey(
                name: "FK_MouvementsStock_Depots_DepotId",
                table: "MouvementsStock");

            migrationBuilder.DropTable(
                name: "StocksDepots");

            migrationBuilder.DropTable(
                name: "Depots");

            migrationBuilder.DropIndex(
                name: "IX_MouvementsStock_DepotId",
                table: "MouvementsStock");

            migrationBuilder.DropIndex(
                name: "IX_Caisses_DepotId",
                table: "Caisses");

            migrationBuilder.DropColumn(
                name: "DepotId",
                table: "MouvementsStock");

            migrationBuilder.DropColumn(
                name: "DepotId",
                table: "Caisses");
        }
    }
}
