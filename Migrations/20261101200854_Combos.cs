using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class Combos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "EstCombo",
                table: "Produits",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "Composants",
                table: "LignesCommandePos",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ComboGroupes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    ProduitId = table.Column<int>(type: "int", nullable: false),
                    Nom = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Quantite = table.Column<int>(type: "int", nullable: false),
                    Ordre = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ComboGroupes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ComboGroupes_Produits_ProduitId",
                        column: x => x.ProduitId,
                        principalTable: "Produits",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ComboChoix",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    GroupeId = table.Column<int>(type: "int", nullable: false),
                    ProduitId = table.Column<int>(type: "int", nullable: false),
                    Supplement = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Ordre = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ComboChoix", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ComboChoix_ComboGroupes_GroupeId",
                        column: x => x.GroupeId,
                        principalTable: "ComboGroupes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ComboChoix_GroupeId",
                table: "ComboChoix",
                column: "GroupeId");

            migrationBuilder.CreateIndex(
                name: "IX_ComboChoix_ProduitId",
                table: "ComboChoix",
                column: "ProduitId");

            migrationBuilder.CreateIndex(
                name: "IX_ComboGroupes_ProduitId",
                table: "ComboGroupes",
                column: "ProduitId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ComboChoix");

            migrationBuilder.DropTable(
                name: "ComboGroupes");

            migrationBuilder.DropColumn(
                name: "EstCombo",
                table: "Produits");

            migrationBuilder.DropColumn(
                name: "Composants",
                table: "LignesCommandePos");
        }
    }
}
