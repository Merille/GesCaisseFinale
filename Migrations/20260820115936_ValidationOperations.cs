using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GesCaisse.Migrations
{
    /// <inheritdoc />
    public partial class ValidationOperations : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "EstJustifie",
                table: "OperationsCaisses",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "Observation",
                table: "OperationsCaisses",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "StatutValidation",
                table: "OperationsCaisses",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "En attente");

            migrationBuilder.AddColumn<string>(
                name: "Valideur",
                table: "OperationsCaisses",
                type: "nvarchar(max)",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "EstJustifie",
                table: "OperationsCaisses");

            migrationBuilder.DropColumn(
                name: "Observation",
                table: "OperationsCaisses");

            migrationBuilder.DropColumn(
                name: "StatutValidation",
                table: "OperationsCaisses");

            migrationBuilder.DropColumn(
                name: "Valideur",
                table: "OperationsCaisses");
        }
    }
}
