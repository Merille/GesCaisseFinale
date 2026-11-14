using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    /// <inheritdoc />
    public partial class DroitsDetail : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Droits détaillés par opération (consulter, ajouter, modifier, supprimer) : les profils existants
            // gardent exactement ce qu'ils pouvaient faire. Comme 029_droits_detail.sql en PHP.
            migrationBuilder.Sql(@"UPDATE Profils SET Droits = TRIM(',' FROM
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CONCAT(',', Droits, ','),
        ',caisses,', ',caisses,journees,journees.a,journees.m,journees.s,'),
        ',caisses_gerer,', ',caisses,caisses.a,caisses.m,caisses.s,'),
        ',tiers,', ',tiers,tiers.a,tiers.m,tiers.s,'),
        ',ventes,', ',ventes,ventes.a,ventes.m,ventes.s,'),
        ',cuisine,', ',cuisine,cuisine.m,'),
        ',stock,', ',stock,stock.a,stock.m,'),
        ',achats,', ',achats,achats.a,achats.s,'),
        ',catalogue,', ',catalogue,catalogue.a,catalogue.m,catalogue.s,'),
        ',synchro,', ',synchro,synchro.m,'),
        ',parametres,', ',parametres,parametres.a,parametres.m,parametres.s,'),
        ',config_pdv,', ',config_pdv,config_pdv.a,config_pdv.m,config_pdv.s,'))
WHERE Droits NOT LIKE '%.%';");


        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {

        }
    }
}
