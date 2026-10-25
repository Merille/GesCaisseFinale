using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class PointDeVenteApresVente : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "LigneOrigineId",
                table: "LignesCommandePos",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "CommandeOrigineId",
                table: "CommandesPos",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Motif",
                table: "CommandesPos",
                type: "nvarchar(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_LignesCommandePos_LigneOrigineId",
                table: "LignesCommandePos",
                column: "LigneOrigineId");

            migrationBuilder.CreateIndex(
                name: "IX_CommandesPos_CommandeOrigineId",
                table: "CommandesPos",
                column: "CommandeOrigineId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_LignesCommandePos_LigneOrigineId",
                table: "LignesCommandePos");

            migrationBuilder.DropIndex(
                name: "IX_CommandesPos_CommandeOrigineId",
                table: "CommandesPos");

            migrationBuilder.DropColumn(
                name: "LigneOrigineId",
                table: "LignesCommandePos");

            migrationBuilder.DropColumn(
                name: "CommandeOrigineId",
                table: "CommandesPos");

            migrationBuilder.DropColumn(
                name: "Motif",
                table: "CommandesPos");
        }
    }
}
