using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class RestaurantEtBar : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Note",
                table: "LignesCommandePos",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Couverts",
                table: "CommandesPos",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "Pourboire",
                table: "CommandesPos",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "TableNom",
                table: "CommandesPos",
                type: "nvarchar(60)",
                maxLength: 60,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Preparation",
                table: "Categories",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Cuisine");

            migrationBuilder.AddColumn<bool>(
                name: "ImprimerBons",
                table: "Caisses",
                type: "bit",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<string>(
                name: "TypePointVente",
                table: "Caisses",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Boutique");

            migrationBuilder.CreateTable(
                name: "BonsPreparation",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    CaisseId = table.Column<int>(type: "int", nullable: false),
                    JourneeCaisseId = table.Column<int>(type: "int", nullable: false),
                    CommandeOuverteId = table.Column<int>(type: "int", nullable: true),
                    Numero = table.Column<int>(type: "int", nullable: false),
                    Poste = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    TableNom = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: true),
                    Couverts = table.Column<int>(type: "int", nullable: true),
                    Serveur = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    DateEnvoi = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Statut = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    DatePret = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BonsPreparation", x => x.Id);
                    table.ForeignKey(
                        name: "FK_BonsPreparation_JourneesCaisses_JourneeCaisseId",
                        column: x => x.JourneeCaisseId,
                        principalTable: "JourneesCaisses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "CommandesOuvertes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    CaisseId = table.Column<int>(type: "int", nullable: false),
                    JourneeCaisseId = table.Column<int>(type: "int", nullable: false),
                    TableId = table.Column<int>(type: "int", nullable: true),
                    Couverts = table.Column<int>(type: "int", nullable: false),
                    UtilisateurId = table.Column<int>(type: "int", nullable: true),
                    DateOuverture = table.Column<DateTime>(type: "datetime2", nullable: false),
                    DateMaj = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Version = table.Column<int>(type: "int", nullable: false),
                    AdditionImprimee = table.Column<bool>(type: "bit", nullable: false),
                    Contenu = table.Column<string>(type: "nvarchar(max)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CommandesOuvertes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CommandesOuvertes_JourneesCaisses_JourneeCaisseId",
                        column: x => x.JourneeCaisseId,
                        principalTable: "JourneesCaisses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Salles",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    CaisseId = table.Column<int>(type: "int", nullable: false),
                    Nom = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Ordre = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Salles", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Salles_Caisses_CaisseId",
                        column: x => x.CaisseId,
                        principalTable: "Caisses",
                        principalColumn: "ID",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "LignesBonPreparation",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    BonPreparationId = table.Column<int>(type: "int", nullable: false),
                    Libelle = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Quantite = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Note = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LignesBonPreparation", x => x.Id);
                    table.ForeignKey(
                        name: "FK_LignesBonPreparation_BonsPreparation_BonPreparationId",
                        column: x => x.BonPreparationId,
                        principalTable: "BonsPreparation",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "TablesRestaurant",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    SalleId = table.Column<int>(type: "int", nullable: false),
                    Nom = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    Places = table.Column<int>(type: "int", nullable: false),
                    Forme = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    PosX = table.Column<int>(type: "int", nullable: false),
                    PosY = table.Column<int>(type: "int", nullable: false),
                    Largeur = table.Column<int>(type: "int", nullable: false),
                    Hauteur = table.Column<int>(type: "int", nullable: false),
                    Actif = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TablesRestaurant", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TablesRestaurant_Salles_SalleId",
                        column: x => x.SalleId,
                        principalTable: "Salles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_BonsPreparation_CaisseId_Statut",
                table: "BonsPreparation",
                columns: new[] { "CaisseId", "Statut" });

            migrationBuilder.CreateIndex(
                name: "IX_BonsPreparation_JourneeCaisseId",
                table: "BonsPreparation",
                column: "JourneeCaisseId");

            migrationBuilder.CreateIndex(
                name: "IX_CommandesOuvertes_JourneeCaisseId",
                table: "CommandesOuvertes",
                column: "JourneeCaisseId");

            migrationBuilder.CreateIndex(
                name: "IX_CommandesOuvertes_TableId",
                table: "CommandesOuvertes",
                column: "TableId",
                unique: true,
                filter: "[TableId] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_LignesBonPreparation_BonPreparationId",
                table: "LignesBonPreparation",
                column: "BonPreparationId");

            migrationBuilder.CreateIndex(
                name: "IX_Salles_CaisseId",
                table: "Salles",
                column: "CaisseId");

            migrationBuilder.CreateIndex(
                name: "IX_TablesRestaurant_SalleId",
                table: "TablesRestaurant",
                column: "SalleId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CommandesOuvertes");

            migrationBuilder.DropTable(
                name: "LignesBonPreparation");

            migrationBuilder.DropTable(
                name: "TablesRestaurant");

            migrationBuilder.DropTable(
                name: "BonsPreparation");

            migrationBuilder.DropTable(
                name: "Salles");

            migrationBuilder.DropColumn(
                name: "Note",
                table: "LignesCommandePos");

            migrationBuilder.DropColumn(
                name: "Couverts",
                table: "CommandesPos");

            migrationBuilder.DropColumn(
                name: "Pourboire",
                table: "CommandesPos");

            migrationBuilder.DropColumn(
                name: "TableNom",
                table: "CommandesPos");

            migrationBuilder.DropColumn(
                name: "Preparation",
                table: "Categories");

            migrationBuilder.DropColumn(
                name: "ImprimerBons",
                table: "Caisses");

            migrationBuilder.DropColumn(
                name: "TypePointVente",
                table: "Caisses");
        }
    }
}
