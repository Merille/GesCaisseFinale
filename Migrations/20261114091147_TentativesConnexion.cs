using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class TentativesConnexion : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "TentativesConnexion",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    NomUtilisateur = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    AdresseIp = table.Column<string>(type: "nvarchar(45)", maxLength: 45, nullable: false),
                    DateTentative = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TentativesConnexion", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_TentativesConnexion_AdresseIp_DateTentative",
                table: "TentativesConnexion",
                columns: new[] { "AdresseIp", "DateTentative" });

            migrationBuilder.CreateIndex(
                name: "IX_TentativesConnexion_NomUtilisateur_DateTentative",
                table: "TentativesConnexion",
                columns: new[] { "NomUtilisateur", "DateTentative" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TentativesConnexion");
        }
    }
}
