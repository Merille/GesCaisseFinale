using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasytransitCaisse.Migrations
{
    // Clients en compte : vente par compte (à crédit), plafond, mode « Compte client » et règlements.
    /// <inheritdoc />
    public partial class ClientsEnCompte : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "ReglementCompte",
                table: "OperationsCaisses",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "EstCompte",
                table: "ModesPaiement",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "EnCompte",
                table: "Clients",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<decimal>(
                name: "PlafondCredit",
                table: "Clients",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            // Mode « Compte client » : un mode existant nommé « compte » est repris, sinon il est
            // créé pour chaque société (même traitement que 017_clients_en_compte.sql en PHP).
            migrationBuilder.Sql(@"UPDATE ModesPaiement SET EstCompte = 1
    WHERE Code IN ('CPT', 'COMPTE') OR Libelle LIKE N'%compte%';");
            migrationBuilder.Sql(@"INSERT INTO ModesPaiement (Code, Libelle, Actif, TenantId, EstCompte)
    SELECT 'CPT', N'Compte client', 1, t.Id, 1 FROM Tenants t
    WHERE NOT EXISTS (SELECT 1 FROM ModesPaiement m WHERE m.TenantId = t.Id AND m.EstCompte = 1);");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ReglementCompte",
                table: "OperationsCaisses");

            migrationBuilder.DropColumn(
                name: "EstCompte",
                table: "ModesPaiement");

            migrationBuilder.DropColumn(
                name: "EnCompte",
                table: "Clients");

            migrationBuilder.DropColumn(
                name: "PlafondCredit",
                table: "Clients");
        }
    }
}
