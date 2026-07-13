using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace XCred.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddCredentialGroups : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "CredentialGroupId",
                table: "Credentials",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "CredentialGroups",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Icon = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    OwnerId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    GroupId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CredentialGroups", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CredentialGroups_Groups_GroupId",
                        column: x => x.GroupId,
                        principalTable: "Groups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CredentialGroups_Users_OwnerId",
                        column: x => x.OwnerId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Credentials_CredentialGroupId",
                table: "Credentials",
                column: "CredentialGroupId");

            migrationBuilder.CreateIndex(
                name: "IX_CredentialGroups_GroupId",
                table: "CredentialGroups",
                column: "GroupId");

            migrationBuilder.CreateIndex(
                name: "IX_CredentialGroups_OwnerId",
                table: "CredentialGroups",
                column: "OwnerId");

            migrationBuilder.AddForeignKey(
                name: "FK_Credentials_CredentialGroups_CredentialGroupId",
                table: "Credentials",
                column: "CredentialGroupId",
                principalTable: "CredentialGroups",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Credentials_CredentialGroups_CredentialGroupId",
                table: "Credentials");

            migrationBuilder.DropTable(
                name: "CredentialGroups");

            migrationBuilder.DropIndex(
                name: "IX_Credentials_CredentialGroupId",
                table: "Credentials");

            migrationBuilder.DropColumn(
                name: "CredentialGroupId",
                table: "Credentials");
        }
    }
}
