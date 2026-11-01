using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class CombosOdoo : Migration
    {
        /// <inheritdoc />
        // Les groupes créés sur les produits (migration Combos) deviennent des combos réutilisables
        // (Configuration › Combos), reliés à leur produit par ProduitCombos : données conservées.
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(name: "FK_ComboChoix_ComboGroupes_GroupeId", table: "ComboChoix");
            migrationBuilder.DropForeignKey(name: "FK_ComboGroupes_Produits_ProduitId", table: "ComboGroupes");
            migrationBuilder.DropPrimaryKey(name: "PK_ComboGroupes", table: "ComboGroupes");
            migrationBuilder.RenameTable(name: "ComboGroupes", newName: "Combos");
            migrationBuilder.AddPrimaryKey(name: "PK_Combos", table: "Combos", column: "Id");

            migrationBuilder.CreateTable(
                name: "ProduitCombos",
                columns: table => new
                {
                    ProduitId = table.Column<int>(type: "int", nullable: false),
                    ComboId = table.Column<int>(type: "int", nullable: false),
                    Ordre = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProduitCombos", x => new { x.ProduitId, x.ComboId });
                    table.ForeignKey(
                        name: "FK_ProduitCombos_Combos_ComboId",
                        column: x => x.ComboId,
                        principalTable: "Combos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ProduitCombos_Produits_ProduitId",
                        column: x => x.ProduitId,
                        principalTable: "Produits",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });
            migrationBuilder.CreateIndex(name: "IX_ProduitCombos_ComboId", table: "ProduitCombos", column: "ComboId");
            migrationBuilder.Sql("INSERT INTO ProduitCombos (ProduitId, ComboId, Ordre) SELECT ProduitId, Id, Ordre FROM Combos;");

            migrationBuilder.DropIndex(name: "IX_ComboGroupes_ProduitId", table: "Combos");
            migrationBuilder.DropColumn(name: "ProduitId", table: "Combos");

            migrationBuilder.RenameColumn(name: "GroupeId", table: "ComboChoix", newName: "ComboId");
            migrationBuilder.RenameIndex(name: "IX_ComboChoix_GroupeId", table: "ComboChoix", newName: "IX_ComboChoix_ComboId");
            migrationBuilder.AddForeignKey(
                name: "FK_ComboChoix_Combos_ComboId",
                table: "ComboChoix",
                column: "ComboId",
                principalTable: "Combos",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        // Retour arrière : chaque combo est rattaché au premier produit qui l'utilise (les combos
        // inutilisés sont supprimés).
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(name: "FK_ComboChoix_Combos_ComboId", table: "ComboChoix");
            migrationBuilder.RenameIndex(name: "IX_ComboChoix_ComboId", table: "ComboChoix", newName: "IX_ComboChoix_GroupeId");
            migrationBuilder.RenameColumn(name: "ComboId", table: "ComboChoix", newName: "GroupeId");

            migrationBuilder.AddColumn<int>(name: "ProduitId", table: "Combos", type: "int", nullable: true);
            migrationBuilder.Sql("UPDATE c SET ProduitId = (SELECT MIN(pc.ProduitId) FROM ProduitCombos pc WHERE pc.ComboId = c.Id) FROM Combos c;");
            migrationBuilder.Sql("DELETE FROM Combos WHERE ProduitId IS NULL;");
            migrationBuilder.AlterColumn<int>(name: "ProduitId", table: "Combos", type: "int", nullable: false, oldClrType: typeof(int), oldType: "int", oldNullable: true);
            migrationBuilder.DropTable(name: "ProduitCombos");

            migrationBuilder.DropPrimaryKey(name: "PK_Combos", table: "Combos");
            migrationBuilder.RenameTable(name: "Combos", newName: "ComboGroupes");
            migrationBuilder.AddPrimaryKey(name: "PK_ComboGroupes", table: "ComboGroupes", column: "Id");
            migrationBuilder.CreateIndex(name: "IX_ComboGroupes_ProduitId", table: "ComboGroupes", column: "ProduitId");
            migrationBuilder.AddForeignKey(
                name: "FK_ComboGroupes_Produits_ProduitId",
                table: "ComboGroupes",
                column: "ProduitId",
                principalTable: "Produits",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
            migrationBuilder.AddForeignKey(
                name: "FK_ComboChoix_ComboGroupes_GroupeId",
                table: "ComboChoix",
                column: "GroupeId",
                principalTable: "ComboGroupes",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
