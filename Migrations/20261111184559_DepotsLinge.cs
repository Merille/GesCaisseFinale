using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class DepotsLinge : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "DepotsLinge",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    CaisseId = table.Column<int>(type: "int", nullable: false),
                    JourneeCaisseId = table.Column<int>(type: "int", nullable: false),
                    Numero = table.Column<int>(type: "int", nullable: false),
                    CleClient = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    DateDepot = table.Column<DateTime>(type: "datetime2", nullable: false),
                    DateRetraitPrevue = table.Column<DateTime>(type: "date", nullable: true),
                    NomClient = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    TelephoneClient = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: true),
                    ClientId = table.Column<int>(type: "int", nullable: true),
                    UtilisateurId = table.Column<int>(type: "int", nullable: true),
                    Contenu = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Total = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false, defaultValue: 0m),
                    NbArticles = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false, defaultValue: 0m),
                    Acompte = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false, defaultValue: 0m),
                    AcompteModePaiementId = table.Column<int>(type: "int", nullable: true),
                    AcompteOperationId = table.Column<int>(type: "int", nullable: true),
                    Statut = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false, defaultValue: "En cours"),
                    DatePret = table.Column<DateTime>(type: "datetime2", nullable: true),
                    DateRetrait = table.Column<DateTime>(type: "datetime2", nullable: true),
                    DateAnnulation = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CommandePosId = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DepotsLinge", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_DepotsLinge_TenantId_Numero",
                table: "DepotsLinge",
                columns: new[] { "TenantId", "Numero" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DepotsLinge_TenantId_Statut",
                table: "DepotsLinge",
                columns: new[] { "TenantId", "Statut" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DepotsLinge");
        }
    }
}
