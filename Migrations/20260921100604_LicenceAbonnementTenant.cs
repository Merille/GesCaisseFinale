using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class LicenceAbonnementTenant : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "DateExpiration",
                table: "Tenants",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ModeAcces",
                table: "Tenants",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "Licence");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DateExpiration",
                table: "Tenants");

            migrationBuilder.DropColumn(
                name: "ModeAcces",
                table: "Tenants");
        }
    }
}
