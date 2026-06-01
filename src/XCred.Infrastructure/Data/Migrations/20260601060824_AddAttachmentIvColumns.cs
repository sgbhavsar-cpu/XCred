using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace XCred.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddAttachmentIvColumns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "FileNameIv",
                table: "CredentialAttachments",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "MimeTypeIv",
                table: "CredentialAttachments",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "FileNameIv",
                table: "CredentialAttachments");

            migrationBuilder.DropColumn(
                name: "MimeTypeIv",
                table: "CredentialAttachments");
        }
    }
}
