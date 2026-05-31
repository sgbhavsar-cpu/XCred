# XCred — Windows / IIS Installation Guide

## Prerequisites (target server)

| Requirement | Notes |
|---|---|
| Windows Server 2019/2022 (or Windows 10/11 Pro) | 64-bit |
| IIS (any edition) | Installer enables the required features automatically |
| **.NET 10 ASP.NET Core Hosting Bundle** | **Must be installed before running XCred Setup** |
| SQL Server 2019+ or SQL Server Express | LocalDB is dev-only; use full SQL Server in production |

### Download the .NET 10 Hosting Bundle
Go to <https://dotnet.microsoft.com/download/dotnet/10.0> and click  
**Windows → Hosting Bundle** (not the SDK, not the Runtime).  
Install it, then reboot IIS: `iisreset`

---

## Step 1 — Build the installer (developer machine)

```powershell
# From the project root — requires Node 20+ and .NET 10 SDK
.\scripts\publish.ps1
```

This builds the React frontend (outputs to `src/XCred.Api/wwwroot`) then publishes
the .NET API to `publish/`.

Then open `installer/setup.iss` in **Inno Setup Compiler** and press **Build → Compile**
(or run `iscc installer\setup.iss`).

The output is `installer\XCred-Setup-1.0.0.exe` — a single self-contained installer.

---

## Step 2 — Run the installer (target server)

1. Copy `XCred-Setup-1.0.0.exe` to the server.
2. Right-click → **Run as Administrator**.
3. Follow the wizard:

| Wizard page | What to enter |
|---|---|
| **Destination folder** | Default `C:\Program Files\XCred` is fine; or choose any NTFS path |
| **Database** | SQL Server instance (e.g. `.\SQLEXPRESS`), database name, and credentials.<br>Leave username blank to use **Windows Authentication** (recommended). |
| **IIS Configuration** | Site name (e.g. `XCred`), port (`80`), and base URL for email links. |
| **JWT Secret** | Leave blank to auto-generate (recommended for new installs). |

4. Click **Install**. The installer will:
   - Enable required IIS Windows Features
   - Create an Application Pool (`XCredPool`, No Managed Code, Always Running)
   - Create the IIS Website
   - Grant the app pool identity Modify permissions on the install directory
   - Patch `appsettings.json` and `appsettings.Production.json` with your values
   - Start the site

5. On the final screen, tick **Open XCred in browser** and click **Finish**.

---

## Step 3 — First login

The database is created automatically on first startup (EF Core `MigrateAsync`).  
The **first registered user automatically becomes Admin** — register immediately after install.

---

## SQL Server permissions

If using **Windows Authentication**, grant the app pool identity access to SQL Server:

```sql
-- Run in SQL Server Management Studio
CREATE LOGIN [IIS APPPOOL\XCredPool] FROM WINDOWS;
-- Then on the XCredDb database:
CREATE USER [IIS APPPOOL\XCredPool] FOR LOGIN [IIS APPPOOL\XCredPool];
ALTER ROLE db_owner ADD MEMBER [IIS APPPOOL\XCredPool];
```

If using **SQL Authentication**, the connection string already contains credentials —
no additional SQL Server steps needed.

---

## HTTPS setup (recommended for production)

1. Obtain a certificate (IIS → Server Certificates → import, or use Let's Encrypt with win-acme).
2. In IIS Manager → Sites → XCred → Bindings → Add → HTTPS, port 443, select certificate.
3. Update the base URL in `appsettings.Production.json` → `AllowedOrigins` to `https://...`.
4. Run `iisreset`.

---

## Upgrading

Run `scripts\publish.ps1` and recompile the installer, then run the new `.exe` on the server.
Inno Setup detects the existing installation and upgrades in place.
The installer preserves `appsettings.Production.json` (your connection string and JWT secret stay intact).

---

## Uninstalling

Control Panel → Programs → XCred → Uninstall.  
This removes the IIS site and app pool, then deletes the install directory.  
**The database is not dropped** — delete it manually from SQL Server if desired.
