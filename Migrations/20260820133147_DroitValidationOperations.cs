using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GesCaisse.Migrations
{
    /// <inheritdoc />
    public partial class DroitValidationOperations : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "PeutValiderOperations",
                table: "Utilisateurs",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PeutValiderOperations",
                table: "Utilisateurs");
        }
    }
}
