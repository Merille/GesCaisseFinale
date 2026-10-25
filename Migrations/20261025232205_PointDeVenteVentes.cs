using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class PointDeVenteVentes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "CommandesPos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    Numero = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    CleClient = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    JourneeCaisseId = table.Column<int>(type: "int", nullable: false),
                    ClientId = table.Column<int>(type: "int", nullable: true),
                    UtilisateurId = table.Column<int>(type: "int", nullable: false),
                    DateCommande = table.Column<DateTime>(type: "datetime2", nullable: false),
                    TotalHT = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    TotalTVA = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    TotalTTC = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    MontantRecu = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    MonnaieRendue = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Statut = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    FactureId = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CommandesPos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CommandesPos_JourneesCaisses_JourneeCaisseId",
                        column: x => x.JourneeCaisseId,
                        principalTable: "JourneesCaisses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "LignesCommandePos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    CommandePosId = table.Column<int>(type: "int", nullable: false),
                    ProduitId = table.Column<int>(type: "int", nullable: true),
                    Libelle = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Quantite = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    PrixUnitaire = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Remise = table.Column<decimal>(type: "decimal(5,2)", precision: 5, scale: 2, nullable: false),
                    TauxTVA = table.Column<decimal>(type: "decimal(5,2)", precision: 5, scale: 2, nullable: false),
                    TotalTTC = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LignesCommandePos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_LignesCommandePos_CommandesPos_CommandePosId",
                        column: x => x.CommandePosId,
                        principalTable: "CommandesPos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PaiementsPos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    CommandePosId = table.Column<int>(type: "int", nullable: false),
                    ModePaiementId = table.Column<int>(type: "int", nullable: true),
                    Libelle = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    MontantRecu = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Montant = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    OperationCaisseId = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PaiementsPos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PaiementsPos_CommandesPos_CommandePosId",
                        column: x => x.CommandePosId,
                        principalTable: "CommandesPos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CommandesPos_JourneeCaisseId",
                table: "CommandesPos",
                column: "JourneeCaisseId");

            migrationBuilder.CreateIndex(
                name: "IX_CommandesPos_TenantId_CleClient",
                table: "CommandesPos",
                columns: new[] { "TenantId", "CleClient" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_CommandesPos_TenantId_Numero",
                table: "CommandesPos",
                columns: new[] { "TenantId", "Numero" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_LignesCommandePos_CommandePosId",
                table: "LignesCommandePos",
                column: "CommandePosId");

            migrationBuilder.CreateIndex(
                name: "IX_PaiementsPos_CommandePosId",
                table: "PaiementsPos",
                column: "CommandePosId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "LignesCommandePos");

            migrationBuilder.DropTable(
                name: "PaiementsPos");

            migrationBuilder.DropTable(
                name: "CommandesPos");
        }
    }
}
