using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class SocieteCoordonneesEtProduits : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Adresse",
                table: "Tenants",
                type: "nvarchar(250)",
                maxLength: 250,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Email",
                table: "Tenants",
                type: "nvarchar(150)",
                maxLength: 150,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LogoMaj",
                table: "Tenants",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "NIF",
                table: "Tenants",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Pays",
                table: "Tenants",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Telephone",
                table: "Tenants",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Ville",
                table: "Tenants",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "Cout",
                table: "Produits",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ImageMaj",
                table: "Produits",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Unite",
                table: "Produits",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Unité");

            migrationBuilder.CreateTable(
                name: "ProduitImages",
                columns: table => new
                {
                    ProduitId = table.Column<int>(type: "int", nullable: false),
                    TypeContenu = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    Donnees = table.Column<byte[]>(type: "varbinary(max)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProduitImages", x => x.ProduitId);
                    table.ForeignKey(
                        name: "FK_ProduitImages_Produits_ProduitId",
                        column: x => x.ProduitId,
                        principalTable: "Produits",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "TenantLogos",
                columns: table => new
                {
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    TypeContenu = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    Donnees = table.Column<byte[]>(type: "varbinary(max)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TenantLogos", x => x.TenantId);
                    table.ForeignKey(
                        name: "FK_TenantLogos_Tenants_TenantId",
                        column: x => x.TenantId,
                        principalTable: "Tenants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ProduitImages");

            migrationBuilder.DropTable(
                name: "TenantLogos");

            migrationBuilder.DropColumn(
                name: "Adresse",
                table: "Tenants");

            migrationBuilder.DropColumn(
                name: "Email",
                table: "Tenants");

            migrationBuilder.DropColumn(
                name: "LogoMaj",
                table: "Tenants");

            migrationBuilder.DropColumn(
                name: "NIF",
                table: "Tenants");

            migrationBuilder.DropColumn(
                name: "Pays",
                table: "Tenants");

            migrationBuilder.DropColumn(
                name: "Telephone",
                table: "Tenants");

            migrationBuilder.DropColumn(
                name: "Ville",
                table: "Tenants");

            migrationBuilder.DropColumn(
                name: "Cout",
                table: "Produits");

            migrationBuilder.DropColumn(
                name: "ImageMaj",
                table: "Produits");

            migrationBuilder.DropColumn(
                name: "Unite",
                table: "Produits");
        }
    }
}
