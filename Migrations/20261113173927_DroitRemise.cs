using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class DroitRemise : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "PeutRemise",
                table: "Utilisateurs",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<decimal>(
                name: "RemiseMax",
                table: "Utilisateurs",
                type: "decimal(5,2)",
                precision: 5,
                scale: 2,
                nullable: true);

            // Les utilisateurs existants gardent le droit (ils pouvaient déjà faire des remises sur les
            // articles) ; un nouvel utilisateur ne l'a pas tant que l'administrateur ne le lui donne pas.
            migrationBuilder.Sql("UPDATE Utilisateurs SET PeutRemise = 1");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PeutRemise",
                table: "Utilisateurs");

            migrationBuilder.DropColumn(
                name: "RemiseMax",
                table: "Utilisateurs");
        }
    }
}
