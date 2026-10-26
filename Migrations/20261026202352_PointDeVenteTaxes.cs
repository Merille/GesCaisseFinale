using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class PointDeVenteTaxes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "LignesCommandePosTaxes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    LigneCommandePosId = table.Column<int>(type: "int", nullable: false),
                    TaxeId = table.Column<int>(type: "int", nullable: true),
                    Code = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Taux = table.Column<decimal>(type: "decimal(5,2)", precision: 5, scale: 2, nullable: false),
                    Montant = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LignesCommandePosTaxes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_LignesCommandePosTaxes_LignesCommandePos_LigneCommandePosId",
                        column: x => x.LigneCommandePosId,
                        principalTable: "LignesCommandePos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Taxes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TenantId = table.Column<int>(type: "int", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Libelle = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Taux = table.Column<decimal>(type: "decimal(5,2)", precision: 5, scale: 2, nullable: false),
                    ParDefaut = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Taxes", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ProduitTaxes",
                columns: table => new
                {
                    ProduitId = table.Column<int>(type: "int", nullable: false),
                    TaxeId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProduitTaxes", x => new { x.ProduitId, x.TaxeId });
                    table.ForeignKey(
                        name: "FK_ProduitTaxes_Produits_ProduitId",
                        column: x => x.ProduitId,
                        principalTable: "Produits",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ProduitTaxes_Taxes_TaxeId",
                        column: x => x.TaxeId,
                        principalTable: "Taxes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_LignesCommandePosTaxes_LigneCommandePosId",
                table: "LignesCommandePosTaxes",
                column: "LigneCommandePosId");

            migrationBuilder.CreateIndex(
                name: "IX_ProduitTaxes_TaxeId",
                table: "ProduitTaxes",
                column: "TaxeId");

            // Taxes de départ de chaque société : TVA 18 % (proposée par défaut) et CSS 1 %.
            migrationBuilder.Sql(@"
INSERT INTO Taxes (TenantId, Code, Libelle, Taux, ParDefaut)
SELECT Id, 'TVA', N'Taxe sur la valeur ajoutée', 18, 1 FROM Tenants;
INSERT INTO Taxes (TenantId, Code, Libelle, Taux, ParDefaut)
SELECT Id, 'CSS', N'Contribution spéciale de solidarité', 1, 0 FROM Tenants;");

            // Autres taux de TVA déjà utilisés par des produits (ex. TVA10 pour 10 %).
            migrationBuilder.Sql(@"
INSERT INTO Taxes (TenantId, Code, Libelle, Taux, ParDefaut)
SELECT DISTINCT p.TenantId, 'TVA' + FORMAT(p.TauxTVA, '0.##', 'fr-FR'), N'Taxe sur la valeur ajoutée', p.TauxTVA, 0
FROM Produits p
WHERE p.TauxTVA > 0 AND p.TauxTVA <> 18;");

            // Chaque produit reçoit la TVA correspondant à son taux actuel.
            migrationBuilder.Sql(@"
INSERT INTO ProduitTaxes (ProduitId, TaxeId)
SELECT p.Id, MIN(t.Id)
FROM Produits p
JOIN Taxes t ON t.TenantId = p.TenantId AND t.Taux = p.TauxTVA AND t.Code LIKE 'TVA%'
WHERE p.TauxTVA > 0
GROUP BY p.Id;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "LignesCommandePosTaxes");

            migrationBuilder.DropTable(
                name: "ProduitTaxes");

            migrationBuilder.DropTable(
                name: "Taxes");
        }
    }
}
