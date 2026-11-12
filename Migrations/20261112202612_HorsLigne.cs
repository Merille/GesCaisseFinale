using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class HorsLigne : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "NumeroHorsLigne",
                table: "DepotsLinge",
                type: "nvarchar(30)",
                maxLength: 30,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AlerteHorsLigne",
                table: "CommandesPos",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "AlerteHorsLigneVue",
                table: "CommandesPos",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "NumeroHorsLigne",
                table: "CommandesPos",
                type: "nvarchar(30)",
                maxLength: 30,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "NumeroHorsLigne",
                table: "DepotsLinge");

            migrationBuilder.DropColumn(
                name: "AlerteHorsLigne",
                table: "CommandesPos");

            migrationBuilder.DropColumn(
                name: "AlerteHorsLigneVue",
                table: "CommandesPos");

            migrationBuilder.DropColumn(
                name: "NumeroHorsLigne",
                table: "CommandesPos");
        }
    }
}
