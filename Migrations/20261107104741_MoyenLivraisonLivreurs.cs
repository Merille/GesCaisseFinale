using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    // Moyen de livraison des livreurs (Moto, Voiture, Vélo, Autre) ; les livreurs existants passent « Moto ».
    public partial class MoyenLivraisonLivreurs : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "MoyenLivraison",
                table: "Livreurs",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Moto");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "MoyenLivraison",
                table: "Livreurs");
        }
    }
}
