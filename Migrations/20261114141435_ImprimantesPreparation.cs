using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GesCaisse.Migrations
{
    /// <inheritdoc />
    public partial class ImprimantesPreparation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "CategorieId",
                table: "LignesBonPreparation",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ImprimantesPreparation",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    Nom = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Type = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false, defaultValue: "Epson"),
                    AdresseIp = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Port = table.Column<int>(type: "int", nullable: true),
                    Largeur = table.Column<int>(type: "int", nullable: false, defaultValue: 80),
                    Encodage = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false, defaultValue: "PC850"),
                    Bip = table.Column<bool>(type: "bit", nullable: false),
                    CaisseId = table.Column<int>(type: "int", nullable: true),
                    Actif = table.Column<bool>(type: "bit", nullable: false, defaultValue: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ImprimantesPreparation", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ImprimantesPreparation_Caisses_CaisseId",
                        column: x => x.CaisseId,
                        principalTable: "Caisses",
                        principalColumn: "ID",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "ImprimantesPreparationCategories",
                columns: table => new
                {
                    ImprimantePreparationId = table.Column<int>(type: "int", nullable: false),
                    CategorieId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ImprimantesPreparationCategories", x => new { x.ImprimantePreparationId, x.CategorieId });
                    table.ForeignKey(
                        name: "FK_ImprimantesPreparationCategories_Categories_CategorieId",
                        column: x => x.CategorieId,
                        principalTable: "Categories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ImprimantesPreparationCategories_ImprimantesPreparation_ImprimantePreparationId",
                        column: x => x.ImprimantePreparationId,
                        principalTable: "ImprimantesPreparation",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ImprimantesPreparation_CaisseId",
                table: "ImprimantesPreparation",
                column: "CaisseId");

            migrationBuilder.CreateIndex(
                name: "IX_ImprimantesPreparation_TenantId",
                table: "ImprimantesPreparation",
                column: "TenantId");

            migrationBuilder.CreateIndex(
                name: "IX_ImprimantesPreparationCategories_CategorieId",
                table: "ImprimantesPreparationCategories",
                column: "CategorieId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ImprimantesPreparationCategories");

            migrationBuilder.DropTable(
                name: "ImprimantesPreparation");

            migrationBuilder.DropColumn(
                name: "CategorieId",
                table: "LignesBonPreparation");
        }
    }
}
