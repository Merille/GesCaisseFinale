using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class VariantesEtRemiseGlobale : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "EstModele",
                table: "Produits",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "LibelleVariante",
                table: "Produits",
                type: "nvarchar(150)",
                maxLength: 150,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ParentId",
                table: "Produits",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "Supplement",
                table: "Produits",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "RemiseGlobale",
                table: "LignesCommandePos",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "RemiseGlobale",
                table: "CommandesPos",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "RemiseGlobaleTaux",
                table: "CommandesPos",
                type: "decimal(5,2)",
                precision: 5,
                scale: 2,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ProduitAttributs",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ProduitId = table.Column<int>(type: "int", nullable: false),
                    Nom = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Ordre = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProduitAttributs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ProduitAttributs_Produits_ProduitId",
                        column: x => x.ProduitId,
                        principalTable: "Produits",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ProduitAttributValeurs",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ProduitAttributId = table.Column<int>(type: "int", nullable: false),
                    Valeur = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Ordre = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProduitAttributValeurs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ProduitAttributValeurs_ProduitAttributs_ProduitAttributId",
                        column: x => x.ProduitAttributId,
                        principalTable: "ProduitAttributs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "VarianteValeurs",
                columns: table => new
                {
                    VarianteId = table.Column<int>(type: "int", nullable: false),
                    ValeurId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VarianteValeurs", x => new { x.VarianteId, x.ValeurId });
                    table.ForeignKey(
                        name: "FK_VarianteValeurs_ProduitAttributValeurs_ValeurId",
                        column: x => x.ValeurId,
                        principalTable: "ProduitAttributValeurs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_VarianteValeurs_Produits_VarianteId",
                        column: x => x.VarianteId,
                        principalTable: "Produits",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Produits_ParentId",
                table: "Produits",
                column: "ParentId");

            migrationBuilder.CreateIndex(
                name: "IX_ProduitAttributs_ProduitId",
                table: "ProduitAttributs",
                column: "ProduitId");

            migrationBuilder.CreateIndex(
                name: "IX_ProduitAttributValeurs_ProduitAttributId",
                table: "ProduitAttributValeurs",
                column: "ProduitAttributId");

            migrationBuilder.CreateIndex(
                name: "IX_VarianteValeurs_ValeurId",
                table: "VarianteValeurs",
                column: "ValeurId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "VarianteValeurs");

            migrationBuilder.DropTable(
                name: "ProduitAttributValeurs");

            migrationBuilder.DropTable(
                name: "ProduitAttributs");

            migrationBuilder.DropIndex(
                name: "IX_Produits_ParentId",
                table: "Produits");

            migrationBuilder.DropColumn(
                name: "EstModele",
                table: "Produits");

            migrationBuilder.DropColumn(
                name: "LibelleVariante",
                table: "Produits");

            migrationBuilder.DropColumn(
                name: "ParentId",
                table: "Produits");

            migrationBuilder.DropColumn(
                name: "Supplement",
                table: "Produits");

            migrationBuilder.DropColumn(
                name: "RemiseGlobale",
                table: "LignesCommandePos");

            migrationBuilder.DropColumn(
                name: "RemiseGlobale",
                table: "CommandesPos");

            migrationBuilder.DropColumn(
                name: "RemiseGlobaleTaux",
                table: "CommandesPos");
        }
    }
}
