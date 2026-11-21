using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GesCaisse.Migrations
{
    /// <inheritdoc />
    public partial class MultiTenant : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "TenantId",
                table: "Utilisateurs",
                type: "int",
                nullable: true);

            // NB: la colonne "MotifId" existait déjà en base (ajoutée manuellement
            // en même temps que la table Motifs) — AddColumn retiré pour éviter un doublon.

            migrationBuilder.AddColumn<int>(
                name: "TenantId",
                table: "OperationsCaisses",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "TenantId",
                table: "Motifs",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "TenantId",
                table: "LignesFactures",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "TenantId",
                table: "JourneesCaisses",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "TenantId",
                table: "Factures",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "TenantId",
                table: "Clients",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "TenantId",
                table: "Caisses",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "Tenants",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Nom = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Actif = table.Column<bool>(type: "bit", nullable: false),
                    DateCreation = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Tenants", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Utilisateurs_TenantId",
                table: "Utilisateurs",
                column: "TenantId");

            migrationBuilder.CreateIndex(
                name: "IX_OperationsCaisses_MotifId",
                table: "OperationsCaisses",
                column: "MotifId");

            migrationBuilder.AddForeignKey(
                name: "FK_OperationsCaisses_Motifs_MotifId",
                table: "OperationsCaisses",
                column: "MotifId",
                principalTable: "Motifs",
                principalColumn: "ID");

            migrationBuilder.AddForeignKey(
                name: "FK_Utilisateurs_Tenants_TenantId",
                table: "Utilisateurs",
                column: "TenantId",
                principalTable: "Tenants",
                principalColumn: "Id");

            // Rattache toutes les données existantes (créées avant le multi-tenant)
            // à un tenant "LEGACY" plutôt que de les laisser orphelines (TenantId = 0,
            // visible seulement du SuperAdmin).
            migrationBuilder.Sql(@"
                DECLARE @LegacyTenantId INT;

                INSERT INTO Tenants (Nom, Code, Actif, DateCreation)
                VALUES (N'Société par défaut', N'LEGACY', 1, GETDATE());

                SET @LegacyTenantId = SCOPE_IDENTITY();

                UPDATE Caisses SET TenantId = @LegacyTenantId;
                UPDATE Clients SET TenantId = @LegacyTenantId;
                UPDATE Motifs SET TenantId = @LegacyTenantId;
                UPDATE JourneesCaisses SET TenantId = @LegacyTenantId;
                UPDATE OperationsCaisses SET TenantId = @LegacyTenantId;
                UPDATE Factures SET TenantId = @LegacyTenantId;
                UPDATE LignesFactures SET TenantId = @LegacyTenantId;
                UPDATE Utilisateurs SET TenantId = @LegacyTenantId WHERE NomUtilisateur <> N'superadmin';
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_OperationsCaisses_Motifs_MotifId",
                table: "OperationsCaisses");

            migrationBuilder.DropForeignKey(
                name: "FK_Utilisateurs_Tenants_TenantId",
                table: "Utilisateurs");

            migrationBuilder.DropTable(
                name: "Tenants");

            migrationBuilder.DropIndex(
                name: "IX_Utilisateurs_TenantId",
                table: "Utilisateurs");

            migrationBuilder.DropIndex(
                name: "IX_OperationsCaisses_MotifId",
                table: "OperationsCaisses");

            migrationBuilder.DropColumn(
                name: "TenantId",
                table: "Utilisateurs");

            migrationBuilder.DropColumn(
                name: "TenantId",
                table: "OperationsCaisses");

            migrationBuilder.DropColumn(
                name: "TenantId",
                table: "Motifs");

            migrationBuilder.DropColumn(
                name: "TenantId",
                table: "LignesFactures");

            migrationBuilder.DropColumn(
                name: "TenantId",
                table: "JourneesCaisses");

            migrationBuilder.DropColumn(
                name: "TenantId",
                table: "Factures");

            migrationBuilder.DropColumn(
                name: "TenantId",
                table: "Clients");

            migrationBuilder.DropColumn(
                name: "TenantId",
                table: "Caisses");
        }
    }
}
