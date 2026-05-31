# XCred — Credential Vault Application
## Requirements Document
**Version:** 1.0  
**Date:** 2026-05-31  
**Status:** Draft — Pending Review

---

## 1. Executive Summary

XCred is a web-based, zero-knowledge credential vault for organizations. It allows teams of up to ~15 users to securely store, organize, and share all types of credentials — from website logins and API keys to SSH keys, certificates, and secure notes. All encryption is performed client-side, meaning the server never has access to plaintext credential data. The application is built on ASP.NET Core and React, backed by SQL Server LocalDB (with a migration path to full SQL Server / Azure SQL), and deployed on IIS with HTTPS enforced in production.

---

## 2. System Overview

| Attribute         | Value                                      |
|-------------------|--------------------------------------------|
| Type              | Organizational credential vault            |
| Users             | ~10–15 internal users                      |
| Deployment        | IIS on Windows Server (hosted, centralized)|
| Encryption Model  | Zero-knowledge / client-side               |
| Access Model      | Self-registered users + admin role         |
| Protocol          | HTTPS (production); HTTP permitted in dev  |

---

## 3. User Management & Authentication

### 3.1 Registration
- Users self-register with: **full name, email address, username, login password, and master password**.
- New accounts are **pending approval by an admin** before first access (to prevent unauthorized self-registration in an org context).
- Admin can deactivate or delete accounts.

### 3.2 Roles
| Role  | Capabilities |
|-------|-------------|
| **Admin** | Manage users, approve registrations, view audit logs, manage organization-wide settings, manage groups |
| **User**  | Manage own credentials, share credentials, participate in groups |

### 3.3 Login
- Credentials: **username + login password**.
- Login password authenticates the user to the application.
- **Master password** is a separate passphrase used solely for deriving the client-side encryption key — it is never transmitted to or stored on the server.
- Failed login attempts are rate-limited (e.g., 5 attempts → 15-minute lockout).
- Unsuccessful login attempts are logged in the audit trail.

### 3.4 Session Management
- Sessions auto-expire after a configurable inactivity period (default: **15 minutes**; admin-configurable).
- Absolute maximum session duration: **8 hours** regardless of activity.
- Session tokens are HTTP-only, Secure, SameSite=Strict cookies (or short-lived JWTs with refresh token rotation).
- On logout or session expiry, the in-memory derived encryption key is cleared from the browser.

### 3.5 Master Password
- The master password is used client-side to derive an **encryption key** via Argon2id (see Section 6).
- It is never sent to the server in plaintext or stored anywhere.
- Users are warned: **if the master password is lost, vault data cannot be recovered** (by design — zero-knowledge).
- A master password change triggers a full re-encryption of the user's vault.

---

## 4. Credential Types & Data Model

### 4.1 Supported Credential Types

| Type              | Key Fields |
|-------------------|------------|
| Website Login     | URL, username, password, TOTP secret (optional) |
| Database          | Host, port, database name, username, password, connection type |
| API Key / Token   | Service name, key/token value, key ID, environment (prod/staging/dev) |
| SSH Key Pair      | Name, private key, public key, passphrase, host |
| Credit / Debit Card | Cardholder name, card number, expiry, CVV, billing address |
| Secure Note       | Title, free-form encrypted text body |
| Wi-Fi             | SSID, password, security type |
| Software License  | Product name, license key, license holder, seats, vendor |
| Certificate       | Name, certificate file (PEM/PFX), private key, expiry date, issuer |
| Environment Variables | Name, `.env` content block (multi-line key=value) |
| Other / Generic   | Name, username, password, notes — catch-all type |

### 4.2 Common Fields (All Types)
- **Name** (required) — display label
- **Type** (required) — from the list above
- **Folder** — optional organizational folder
- **Tags** — zero or more free-text tags
- **Notes** — encrypted additional notes
- **Expiry Date** — optional; triggers alert when reached/approaching
- **Custom Fields** — user-defined key/value pairs (text, hidden/password, URL, boolean)
- **File Attachments** — zero or more encrypted files
- **Created At / Updated At** timestamps
- **Created By / Last Modified By** user reference

### 4.3 Custom Fields
- Each credential can have user-defined fields: **Label**, **Value**, **Field Type** (text, password/hidden, URL).
- Custom fields are encrypted along with the credential body.

### 4.4 File Attachments
- Attachments are encrypted client-side before upload.
- Supported: any file type; size limit per attachment (suggested: **10 MB**; admin-configurable).
- Attachment metadata (filename, size, MIME type) is also encrypted.

---

## 5. Organization & Folder Structure

### 5.1 Folders
- Users can create **nested folders** to organize credentials.
- Folder structure is per-user (personal) or per-group (shared).
- Drag-and-drop reordering and moving of credentials between folders.

### 5.2 Tags
- Tags are free-text labels applied to individual credentials.
- Multiple tags per credential; global tag list shown for quick filtering.
- Color-coded tags for visual organization.

### 5.3 Groups (Teams)
- Admins and users can create **groups** (e.g., "DevOps", "Finance", "HR").
- Groups have a group admin who manages membership.
- Groups can own **shared collections** of credentials.
- Members of a group automatically have access to the group's shared credentials.
- Group membership is managed by the group admin or the application admin.

---

## 6. Encryption & Security Architecture

### 6.1 Encryption Model: Zero-Knowledge, Client-Side

The server stores only encrypted ciphertext. It never has access to:
- The master password
- The derived encryption key
- Any plaintext credential data

### 6.2 Key Derivation
- **Algorithm:** Argon2id
- **Parameters (minimum):** memory=64MB, iterations=3, parallelism=4
- **Input:** master password + user-specific random salt (stored server-side)
- **Output:** 256-bit symmetric encryption key (held in memory only, cleared on logout)

### 6.3 Credential Encryption
- **Algorithm:** AES-256-GCM (authenticated encryption — provides both confidentiality and integrity)
- Each credential record is encrypted as a **single JSON blob** on the client before transmission.
- A unique random **IV/nonce** is generated per encryption operation.
- The encrypted blob, IV, and authentication tag are stored together in the database.

### 6.4 Key Hierarchy for Sharing
To enable sharing without exposing the master key:
- Each user has an **asymmetric RSA-4096 or X25519 key pair** (private key encrypted with the derived symmetric key).
- When a credential is shared, it is re-encrypted with a **shared credential key**, which is itself encrypted with each recipient's public key (envelope encryption).

### 6.5 Transport Security
- **TLS 1.2+ required** in production; TLS 1.3 preferred.
- HSTS header enabled in production.
- HTTP acceptable in development environment only.

### 6.6 Password Strength
- All password-type fields display a **real-time strength meter** (entropy-based, e.g., using zxcvbn library).
- Strength levels: Very Weak / Weak / Fair / Strong / Very Strong.
- Weak passwords are flagged with a warning (not blocked, to allow legacy credentials).

### 6.7 Clipboard Protection
- When a user copies a credential value, the clipboard is **automatically cleared after 30 seconds** (configurable by admin).
- A visible countdown timer is shown in the UI after copy.
- Copy actions are logged in the audit trail.

### 6.8 Database Protection
- The SQL Server connection string is stored in an encrypted configuration source (e.g., Windows DPAPI or ASP.NET Core Data Protection).
- Encrypted fields in the database: all credential data columns (stored as encrypted blobs).
- Plaintext in the database: user IDs, usernames, email addresses, salts, public keys, folder/group metadata, audit log entries.

### 6.9 Additional Security Measures
- **Content Security Policy (CSP)** headers on all pages.
- **CORS** restricted to the application's own origin.
- **Anti-CSRF** tokens on all state-changing requests.
- **Input validation** on all API endpoints (server-side).
- All dependencies audited; **no eval() or dynamic script execution** in frontend.
- Passwords hashed server-side with **BCrypt** (login password separate from master password).

---

## 7. Credential Sharing

### 7.1 Individual Sharing
- A user can share any credential they own with another specific user or a group.
- Share options:
  - **Permission:** Read-only (default); Edit (optional, for future)
  - **Duration:** Share indefinitely, or set an expiry date/time for the share
  - **Until Changed:** Share is automatically revoked if the credential is modified by the owner
- The recipient receives an in-app notification and email.

### 7.2 Revocation
- Owner can revoke any share at any time.
- Share automatically expires per the configured duration.
- If "Until Changed" is selected, modifying the credential removes access for all share recipients.

### 7.3 Group Sharing
- Credentials added to a group collection are accessible to all group members.
- Group admins control which credentials are in the group collection.

---

## 8. Audit Log

### 8.1 Events Tracked
All the following events are logged with: **timestamp, user, IP address, credential/resource ID, and action detail**.

| Category | Events |
|----------|--------|
| Authentication | Login success, login failure, logout, session expiry |
| Credential Access | View credential, copy password, copy field, view attachment |
| Credential Changes | Create, edit, delete credential; add/remove attachment; add/remove custom field |
| Sharing | Share created, share revoked, share accessed by recipient, share expired |
| Group Management | Group created/deleted, member added/removed |
| User Management | Registration, approval, deactivation, password change, master password change |
| Admin Actions | Settings changes, user role changes |
| Backup | Export backup created, import performed |

### 8.2 Audit Log Access
- Admins have access to the full organization-wide audit log.
- Users can view their own activity log.
- Audit log is **append-only** — cannot be modified or deleted through the UI.
- Filterable by: user, date range, credential, event type.
- Exportable to CSV by admins.

---

## 9. Expiry & Alerts

### 9.1 Credential Expiry
- Any credential can have an optional **expiry date**.
- Certificate type automatically parses the expiry from the uploaded certificate file.

### 9.2 Alert Display
- The **home/dashboard page** shows two alert sections:
  - **Expired:** Credentials where expiry date has passed (shown in red).
  - **Expiring Soon:** Credentials expiring within the next **30 days** (shown in amber; threshold configurable by admin).
- Alerts show: credential name, type, folder, expiry date, and quick-action buttons.

### 9.3 Email Notifications for Expiry
- Email sent to the credential owner at: **30 days, 14 days, 7 days, 1 day** before expiry.
- Additional email on the day of expiry.
- Admin receives a daily digest of all expiring/expired credentials across the organization.

---

## 10. Password Generator

- Accessible from any password field and as a standalone tool in the app.
- Configurable options:
  - **Length:** 8–128 characters (default: 20)
  - **Character sets:** Uppercase, lowercase, numbers, symbols (each toggleable)
  - **Exclude ambiguous characters** (e.g., `0`, `O`, `l`, `1`)
  - **Exclude specific characters** (user-defined exclusion list)
  - **Passphrase mode:** Generate word-based passphrase (e.g., `correct-horse-battery-staple`) with configurable word count and separator
- Generated password is shown with strength meter.
- One-click copy with clipboard auto-clear.
- Generated password can be directly applied to the current credential field.

---

## 11. Search & Discovery

- **Global search bar** accessible from all pages (keyboard shortcut: `Ctrl+K` / `Cmd+K`).
- Searches across: credential name, username, URL, tags, folder name, notes, custom field labels.
- Encrypted values (passwords, keys) are **not searchable** by design (zero-knowledge).
- Search results show: name, type icon, folder, last modified date.
- Filters: by type, by tag, by folder, by group, by expiry status, by owner.
- Results update in real-time as the user types.

---

## 12. Backup & Restore

### 12.1 Export (Backup)
- Admin or user can export an **encrypted backup file** (`.xcred` format, a structured JSON bundle encrypted with AES-256-GCM).
- The backup is encrypted with the user's master password (or an admin-defined backup passphrase).
- Export includes: credentials, folders, tags, custom fields, attachment metadata (optionally attachment files).
- Audit log entry is created for every export.

### 12.2 Import (Restore)
- Import from a `.xcred` backup file.
- Passphrase-protected import; decryption happens client-side.
- Import preview shows what will be restored before confirming.
- Duplicate detection: user can choose to skip, overwrite, or create new on conflict.

---

## 13. Email Notifications

### 13.1 Notification Events
| Event | Recipient |
|-------|-----------|
| New share received | Share recipient |
| Share revoked | Share recipient |
| Share expired | Share recipient + owner |
| Credential expiring (30/14/7/1 day) | Credential owner |
| Credential expired | Credential owner |
| Daily expiry digest | Admin |
| Account approved | New user |
| Account deactivated | Affected user |
| Login from new IP address | Account owner |
| Multiple failed login attempts | Account owner + admin |

### 13.2 Email Configuration
- SMTP configuration managed by admin in application settings.
- Email templates are HTML with plain-text fallback.
- Users can opt out of non-critical notifications (expiry reminders) from their profile.
- All security alerts (failed logins, new IP) are mandatory and cannot be opted out.

---

## 14. Home / Dashboard

The home page shows:
- **Expiry Alerts panel:** expired and expiring-soon credentials (Section 9.2)
- **Recent Activity:** last 10 actions by the logged-in user
- **Quick Stats:** total credentials, shared with me, groups I belong to
- **Recently Accessed Credentials:** quick re-access
- **Pending Shares:** shares awaiting acceptance (if applicable)
- **Search bar** prominent at top

---

## 15. Frontend Architecture

| Attribute | Decision |
|-----------|----------|
| Framework | **React** (latest stable) with **TypeScript** |
| Build Tool | **Vite** |
| UI Component Library | **shadcn/ui** (Tailwind CSS-based; accessible, customizable) |
| State Management | **Zustand** (lightweight, suitable for 10–15 user app) |
| Routing | **React Router v7** |
| HTTP Client | **Axios** with interceptors for auth token handling |
| Crypto | **Web Crypto API** (native browser; no third-party crypto lib) |
| Password Strength | **zxcvbn** library |
| Form Handling | **React Hook Form** + **Zod** validation |
| Icons | **Lucide React** |
| Notifications | **React Hot Toast** |

### 15.1 Key UI Screens
1. Login / Register
2. Dashboard / Home (expiry alerts, recent activity)
3. Credential List (browse, filter, search)
4. Credential Detail / View
5. Credential Create / Edit
6. Password Generator (modal + standalone page)
7. Folder Management
8. Groups Management
9. Sharing Management
10. Profile & Settings (session, notifications, master password change)
11. Admin Panel (users, audit log, org settings, SMTP config)
12. Audit Log Viewer
13. Backup & Restore

---

## 16. Backend Architecture

| Attribute | Decision |
|-----------|----------|
| Framework | **ASP.NET Core 9** (latest LTS) |
| API Style | **REST** (JSON) |
| Authentication | **JWT** (access token, short-lived) + **Refresh Token** (HTTP-only cookie) |
| ORM | **Entity Framework Core 9** |
| Validation | **FluentValidation** |
| Email | **MailKit** (SMTP) |
| Logging | **Serilog** (structured logging to file + optional DB sink) |
| API Docs | **Scalar** (OpenAPI/Swagger) |

### 16.1 API Design Principles
- All endpoints require authentication except `/auth/login` and `/auth/register`.
- Credentials returned from the API are always in **encrypted ciphertext** — the server never decrypts them.
- Pagination on all list endpoints (cursor-based for audit log, offset for credentials).
- Consistent error response format: `{ "error": { "code": "...", "message": "..." } }`.

---

## 17. Database Architecture

| Attribute | Decision |
|-----------|----------|
| Database | **SQL Server LocalDB** (development/initial) |
| Migration Path | Designed for **full SQL Server** or **Azure SQL** with no code changes |
| ORM | EF Core 9 with code-first migrations |
| Sensitive Columns | All credential data stored as **encrypted NVARCHAR(MAX)** blobs |

### 17.1 Core Tables (Logical)
- `Users` — id, username, email, password_hash, salt, public_key, encrypted_private_key, created_at, is_active, role
- `Credentials` — id, owner_user_id, type, name_encrypted, data_encrypted, iv, auth_tag, folder_id, expiry_date, created_at, updated_at
- `Folders` — id, user_id/group_id, name, parent_folder_id
- `Tags` — id, name, color, user_id
- `CredentialTags` — credential_id, tag_id
- `CredentialAttachments` — id, credential_id, filename_encrypted, data_encrypted, iv, size, mime_type_encrypted
- `CredentialCustomFields` — id, credential_id, label_encrypted, value_encrypted, field_type
- `Groups` — id, name, description, created_by
- `GroupMembers` — group_id, user_id, role (admin/member)
- `SharedCredentials` — id, credential_id, shared_by, shared_with_user_id/group_id, permission, expires_at, until_changed, encrypted_key_for_recipient
- `AuditLogs` — id, timestamp, user_id, ip_address, action, resource_type, resource_id, detail
- `Sessions` — id, user_id, refresh_token_hash, expires_at, ip_address, user_agent
- `NotificationSettings` — user_id, preferences (JSON)
- `AppSettings` — key, value (org-level config: SMTP, session timeout, clipboard timeout, expiry warning days)

### 17.2 Migration Strategy
- EF Core migrations are environment-aware.
- Connection string is configurable via environment variable or encrypted config.
- Moving from LocalDB to SQL Server: change connection string only — no schema changes required.

---

## 18. Deployment

| Attribute | Value |
|-----------|-------|
| Web Server | **IIS on Windows Server** |
| App Model | ASP.NET Core hosted as IIS site (in-process hosting) |
| Frontend | React SPA served as static files from `wwwroot` (or separate IIS site) |
| HTTPS | Enforced in production via IIS + SSL certificate (Let's Encrypt or org cert) |
| Development | HTTP permitted; optional self-signed cert suggestion via `dotnet dev-certs` |
| Environment Config | `appsettings.Production.json` + environment variables; secrets via Windows DPAPI or IIS app pool identity |

### 18.1 Development HTTPS (Optional Suggestion)
Run once to trust a self-signed cert in development:
```bash
dotnet dev-certs https --trust
```
This enables HTTPS in dev without any manual certificate management.

---

## 19. Future Considerations (Out of Scope — v1)

The following are **not in scope for v1** but should be kept in mind during architecture decisions:

| Feature | Notes |
|---------|-------|
| MS Teams Integration | Notifications/alerts via Teams webhook or Teams bot; design notification system to be provider-agnostic |
| Browser Extension | Auto-fill support; keep API auth stateless to support extension clients |
| Mobile App | REST API design supports future mobile clients |
| Full SQL Server / Azure SQL | Already accounted for in DB design |
| TOTP / MFA | Authentication layer should allow adding a second factor later |
| LDAP / AD Integration | User provisioning; auth layer should be abstractable |
| Slack / Webhook Notifications | Notification service should be pluggable |

---

## 20. Non-Functional Requirements

| Requirement | Target |
|-------------|--------|
| Response Time | API responses < 300ms (p95) for non-crypto operations |
| Availability | 99.5% uptime (IIS on Windows Server, no HA required for v1) |
| Scalability | Support 10–15 concurrent users comfortably; architecture allows horizontal scale later |
| Security | OWASP Top 10 compliance; zero-knowledge by design |
| Accessibility | WCAG 2.1 AA — keyboard navigable, screen-reader friendly |
| Browser Support | Latest 2 versions of Chrome, Firefox, Edge, Safari |
| Audit Retention | Audit logs retained for minimum 1 year |
| Backup | Organization-level encrypted backup exportable on demand |
| Data Loss | No plaintext credential data recoverable from DB, logs, or server memory |

---

## 21. Assumptions & Constraints

- Users are responsible for remembering their master password — there is no recovery mechanism (zero-knowledge by design).
- The application assumes a trusted internal network for IIS deployment; network-level controls (firewall, VPN) are managed externally.
- Email delivery requires a reachable SMTP server configured by the admin.
- SQL Server LocalDB is suitable for the initial user count; scaling beyond ~50 users or high-frequency access should prompt migration to full SQL Server.
- File attachment storage is in the database as encrypted blobs for v1 (simplicity); a file system or blob storage backend may be preferable at higher volumes.

---

## 22. Open Items (To Confirm Before Development)

| # | Item | Default Assumed |
|---|------|-----------------|
| 1 | Session inactivity timeout value | 15 minutes |
| 2 | Clipboard auto-clear timeout | 30 seconds |
| 3 | Expiry warning window | 10 days |
| 4 | Max file attachment size | 10 MB |
| 5 | Admin-approved registration vs. fully open self-register | Admin approval required |
| 6 | Whether users must accept a share or it is granted immediately | Granted immediately, with notification |
| 7 | Whether edit-permission shares are in scope for v1 | Read-only only for v1 |
| 8 | Color/branding preferences for the UI | dark themed colors with violate as primary colour |
| 9 | Application name / logo | XCred (confirm) |

---

*End of Requirements Document v1.0*
