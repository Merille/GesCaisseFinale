using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class ModePaiementOperation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "ModePaiementId",
                table: "OperationsCaisses",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_OperationsCaisses_ModePaiementId",
                table: "OperationsCaisses",
                column: "ModePaiementId");

            migrationBuilder.AddForeignKey(
                name: "FK_OperationsCaisses_ModesPaiement_ModePaiementId",
                table: "OperationsCaisses",
                column: "ModePaiementId",
                principalTable: "ModesPaiement",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_OperationsCaisses_ModesPaiement_ModePaiementId",
                table: "OperationsCaisses");

            migrationBuilder.DropIndex(
                name: "IX_OperationsCaisses_ModePaiementId",
                table: "OperationsCaisses");

            migrationBuilder.DropColumn(
                name: "ModePaiementId",
                table: "OperationsCaisses");
        }
    }
}
