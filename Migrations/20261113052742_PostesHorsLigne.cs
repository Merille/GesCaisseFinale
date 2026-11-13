using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class PostesHorsLigne : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PostesHorsLigne",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    UtilisateurId = table.Column<int>(type: "int", nullable: true),
                    Navigateur = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: true),
                    EnAttente = table.Column<int>(type: "int", nullable: false),
                    Refusees = table.Column<int>(type: "int", nullable: false),
                    MontantEnAttente = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    PlusAncien = table.Column<DateTime>(type: "datetime2", nullable: true),
                    DernierEnvoi = table.Column<DateTime>(type: "datetime2", nullable: true),
                    DernierRapport = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Detail = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PostesHorsLigne", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PostesHorsLigne_TenantId_Code",
                table: "PostesHorsLigne",
                columns: new[] { "TenantId", "Code" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PostesHorsLigne");
        }
    }
}
