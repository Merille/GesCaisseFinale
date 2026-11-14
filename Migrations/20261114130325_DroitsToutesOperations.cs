using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class DroitsToutesOperations : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Toutes les opérations proposées pour chaque droit : écran de vente (ajouter, modifier, supprimer),
            // rapports (exporter, imprimer), règlement des achats (modifier). Les profils existants gardent ce
            // qu'ils pouvaient faire. Comme 030_droits_toutes_operations.sql en PHP.
            migrationBuilder.Sql(@"UPDATE Profils SET Droits = TRIM(',' FROM REPLACE(CONCAT(',', Droits, ','), ',vendre,', ',vendre,vendre.a,vendre.m,vendre.s,'))
WHERE CONCAT(',', Droits, ',') LIKE '%,vendre,%' AND Droits NOT LIKE '%vendre.%';");
            migrationBuilder.Sql(@"UPDATE Profils SET Droits = TRIM(',' FROM REPLACE(CONCAT(',', Droits, ','), ',rapports,', ',rapports,rapports.a,rapports.m,'))
WHERE CONCAT(',', Droits, ',') LIKE '%,rapports,%' AND Droits NOT LIKE '%rapports.%';");
            migrationBuilder.Sql(@"UPDATE Profils SET Droits = TRIM(',' FROM REPLACE(CONCAT(',', Droits, ','), ',rapports_pdv,', ',rapports_pdv,rapports_pdv.a,rapports_pdv.m,'))
WHERE CONCAT(',', Droits, ',') LIKE '%,rapports_pdv,%' AND Droits NOT LIKE '%rapports_pdv.%';");
            migrationBuilder.Sql(@"UPDATE Profils SET Droits = TRIM(',' FROM REPLACE(CONCAT(',', Droits, ','), ',achats.a,', ',achats.a,achats.m,'))
WHERE CONCAT(',', Droits, ',') LIKE '%,achats.a,%' AND Droits NOT LIKE '%achats.m%';");


        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {

        }
    }
}
