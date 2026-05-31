using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using XCred.Core.Constants;
using XCred.Core.DTOs.Common;
using XCred.Core.DTOs.Credentials;
using XCred.Core.Entities;
using XCred.Core.Interfaces;
using XCred.Infrastructure.Data;

namespace XCred.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/credentials/{credentialId:guid}/attachments")]
public class AttachmentsController(AppDbContext db, IAuditService audit, IAppSettingService settings) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<ApiResponse<AttachmentDto>>> Upload(Guid credentialId, [FromBody] UploadAttachmentRequest req)
    {
        var userId = GetUserId();
        var cred = await db.Credentials.FirstOrDefaultAsync(c => c.Id == credentialId && c.OwnerId == userId);
        if (cred == null) return NotFound(ApiResponse<AttachmentDto>.Fail("NOT_FOUND", "Credential not found."));

        var maxMb = await settings.GetAsync(AppSettingKeys.MaxAttachmentSizeMb, 10);
        if (req.FileSizeBytes > maxMb * 1024 * 1024)
            return BadRequest(ApiResponse<AttachmentDto>.Fail("FILE_TOO_LARGE", $"Maximum attachment size is {maxMb} MB."));

        var attachment = new CredentialAttachment
        {
            CredentialId = credentialId,
            EncryptedFileName = req.EncryptedFileName,
            FileNameIv = req.FileNameIv,
            EncryptedMimeType = req.EncryptedMimeType,
            MimeTypeIv = req.MimeTypeIv,
            EncryptedData = req.EncryptedData,
            DataIv = req.DataIv,
            FileSizeBytes = req.FileSizeBytes,
            UploadedById = userId
        };

        db.CredentialAttachments.Add(attachment);
        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.AttachmentUploaded, "Attachment", attachment.Id, credentialId.ToString(), GetIp());

        return Ok(ApiResponse<AttachmentDto>.Ok(new AttachmentDto
        {
            Id = attachment.Id,
            EncryptedFileName = attachment.EncryptedFileName,
            EncryptedMimeType = attachment.EncryptedMimeType,
            FileSizeBytes = attachment.FileSizeBytes,
            UploadedAt = attachment.UploadedAt
        }));
    }

    [HttpGet("{attachmentId:guid}")]
    public async Task<ActionResult<ApiResponse<AttachmentDataDto>>> Download(Guid credentialId, Guid attachmentId)
    {
        var userId = GetUserId();
        var cred = await db.Credentials.AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == credentialId && c.OwnerId == userId);
        if (cred == null) return NotFound();

        var attachment = await db.CredentialAttachments.AsNoTracking()
            .FirstOrDefaultAsync(a => a.Id == attachmentId && a.CredentialId == credentialId);
        if (attachment == null) return NotFound();

        await audit.LogAsync(userId, AuditActions.AttachmentDownloaded, "Attachment", attachmentId, credentialId.ToString(), GetIp());

        return Ok(ApiResponse<AttachmentDataDto>.Ok(new AttachmentDataDto
        {
            Id = attachment.Id,
            EncryptedFileName = attachment.EncryptedFileName,
            FileNameIv = attachment.FileNameIv,
            EncryptedMimeType = attachment.EncryptedMimeType,
            MimeTypeIv = attachment.MimeTypeIv,
            EncryptedData = attachment.EncryptedData,
            DataIv = attachment.DataIv,
            FileSizeBytes = attachment.FileSizeBytes
        }));
    }

    [HttpDelete("{attachmentId:guid}")]
    public async Task<ActionResult<ApiResponse<string>>> Delete(Guid credentialId, Guid attachmentId)
    {
        var userId = GetUserId();
        var cred = await db.Credentials.FirstOrDefaultAsync(c => c.Id == credentialId && c.OwnerId == userId);
        if (cred == null) return NotFound();

        var attachment = await db.CredentialAttachments
            .FirstOrDefaultAsync(a => a.Id == attachmentId && a.CredentialId == credentialId);
        if (attachment == null) return NotFound();

        db.CredentialAttachments.Remove(attachment);
        await db.SaveChangesAsync();
        await audit.LogAsync(userId, AuditActions.AttachmentDeleted, "Attachment", attachmentId, credentialId.ToString(), GetIp());

        return Ok(ApiResponse<string>.Ok("Attachment deleted."));
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? User.FindFirst("sub")!.Value);

    private string GetIp() => HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
}

public class UploadAttachmentRequest
{
    public string EncryptedFileName { get; set; } = string.Empty;
    public string FileNameIv { get; set; } = string.Empty;
    public string EncryptedMimeType { get; set; } = string.Empty;
    public string MimeTypeIv { get; set; } = string.Empty;
    public string EncryptedData { get; set; } = string.Empty;
    public string DataIv { get; set; } = string.Empty;
    public long FileSizeBytes { get; set; }
}

public class AttachmentDataDto
{
    public Guid Id { get; set; }
    public string EncryptedFileName { get; set; } = string.Empty;
    public string FileNameIv { get; set; } = string.Empty;
    public string EncryptedMimeType { get; set; } = string.Empty;
    public string MimeTypeIv { get; set; } = string.Empty;
    public string EncryptedData { get; set; } = string.Empty;
    public string DataIv { get; set; } = string.Empty;
    public long FileSizeBytes { get; set; }
}
