using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    // Livraisons : livreurs, commandes en attente partagées entre postes, livraison d'une vente.
    public partial class LivraisonsEtCommandesEnAttente : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AdresseLivraison",
                table: "CommandesPos",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "DateLivraison",
                table: "CommandesPos",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "LivreurId",
                table: "CommandesPos",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "NomLivraison",
                table: "CommandesPos",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "StatutLivraison",
                table: "CommandesPos",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TelephoneLivraison",
                table: "CommandesPos",
                type: "nvarchar(30)",
                maxLength: 30,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Livreurs",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    Nom = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Telephone = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: true),
                    Actif = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Livreurs", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "CommandesAttente",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    JourneeCaisseId = table.Column<int>(type: "int", nullable: false),
                    Numero = table.Column<int>(type: "int", nullable: false),
                    DateCreation = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UtilisateurId = table.Column<int>(type: "int", nullable: false),
                    ClientId = table.Column<int>(type: "int", nullable: true),
                    Contenu = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Total = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    NbArticles = table.Column<int>(type: "int", nullable: false),
                    LivreurId = table.Column<int>(type: "int", nullable: true),
                    NomLivraison = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    TelephoneLivraison = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: true),
                    AdresseLivraison = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CommandesAttente", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CommandesAttente_JourneesCaisses_JourneeCaisseId",
                        column: x => x.JourneeCaisseId,
                        principalTable: "JourneesCaisses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_CommandesAttente_Livreurs_LivreurId",
                        column: x => x.LivreurId,
                        principalTable: "Livreurs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CommandesPos_LivreurId",
                table: "CommandesPos",
                column: "LivreurId");

            migrationBuilder.CreateIndex(
                name: "IX_CommandesAttente_JourneeCaisseId_Numero",
                table: "CommandesAttente",
                columns: new[] { "JourneeCaisseId", "Numero" });

            migrationBuilder.CreateIndex(
                name: "IX_CommandesAttente_LivreurId",
                table: "CommandesAttente",
                column: "LivreurId");

            migrationBuilder.AddForeignKey(
                name: "FK_CommandesPos_Livreurs_LivreurId",
                table: "CommandesPos",
                column: "LivreurId",
                principalTable: "Livreurs",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_CommandesPos_Livreurs_LivreurId",
                table: "CommandesPos");

            migrationBuilder.DropTable(
                name: "CommandesAttente");

            migrationBuilder.DropTable(
                name: "Livreurs");

            migrationBuilder.DropIndex(
                name: "IX_CommandesPos_LivreurId",
                table: "CommandesPos");

            migrationBuilder.DropColumn(
                name: "AdresseLivraison",
                table: "CommandesPos");

            migrationBuilder.DropColumn(
                name: "DateLivraison",
                table: "CommandesPos");

            migrationBuilder.DropColumn(
                name: "LivreurId",
                table: "CommandesPos");

            migrationBuilder.DropColumn(
                name: "NomLivraison",
                table: "CommandesPos");

            migrationBuilder.DropColumn(
                name: "StatutLivraison",
                table: "CommandesPos");

            migrationBuilder.DropColumn(
                name: "TelephoneLivraison",
                table: "CommandesPos");
        }
    }
}
