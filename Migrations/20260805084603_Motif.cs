using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GesCaisse.Migrations
{
    /// <inheritdoc />
    public partial class Motif : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // NB: la colonne "Type" existait déjà en base (ajoutée manuellement avant
            // la génération de cette migration) — AddColumn retiré pour éviter un
            // doublon lors de l'application de cette migration en retard.

            migrationBuilder.CreateTable(
                name: "Motifs",
                columns: table => new
                {
                    ID = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    LibelleMotif = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    TypeModif = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    CG_Num = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Motifs", x => x.ID);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Motifs");
        }
    }
}
