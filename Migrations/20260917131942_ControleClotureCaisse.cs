using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class ControleClotureCaisse : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "EcartCloture",
                table: "JourneesCaisses",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "NoteCloture",
                table: "JourneesCaisses",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ComptagesCloture",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    JourneeCaisseId = table.Column<int>(type: "int", nullable: false),
                    ModePaiementId = table.Column<int>(type: "int", nullable: true),
                    MontantTheorique = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    MontantCompte = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    TenantId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ComptagesCloture", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ComptagesCloture_JourneesCaisses_JourneeCaisseId",
                        column: x => x.JourneeCaisseId,
                        principalTable: "JourneesCaisses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ComptagesCloture_ModesPaiement_ModePaiementId",
                        column: x => x.ModePaiementId,
                        principalTable: "ModesPaiement",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_ComptagesCloture_JourneeCaisseId",
                table: "ComptagesCloture",
                column: "JourneeCaisseId");

            migrationBuilder.CreateIndex(
                name: "IX_ComptagesCloture_ModePaiementId",
                table: "ComptagesCloture",
                column: "ModePaiementId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ComptagesCloture");

            migrationBuilder.DropColumn(
                name: "EcartCloture",
                table: "JourneesCaisses");

            migrationBuilder.DropColumn(
                name: "NoteCloture",
                table: "JourneesCaisses");
        }
    }
}
