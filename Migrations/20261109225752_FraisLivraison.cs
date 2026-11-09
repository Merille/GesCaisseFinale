using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    // Frais de livraison : montant par défaut de la société et frais de chaque vente livrée.
    /// <inheritdoc />
    public partial class FraisLivraison : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "FraisLivraisonDefaut",
                table: "Tenants",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "FraisLivraison",
                table: "CommandesPos",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "FraisLivraisonDefaut",
                table: "Tenants");

            migrationBuilder.DropColumn(
                name: "FraisLivraison",
                table: "CommandesPos");
        }
    }
}
