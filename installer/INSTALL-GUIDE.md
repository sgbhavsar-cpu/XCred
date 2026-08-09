# XCred — Windows / IIS Installation Guide

## Prerequisites (target server)

| Requirement | Notes |
|---|---|
| Windows Server 2016+ (or Windows 10/11 Pro) | 64-bit. The installer detects which one it's on and enables IIS the right way for each. |
| IIS | The installer enables it automatically — nothing to pre-install. |
| **.NET 10 ASP.NET Core Hosting Bundle** | Auto-downloaded and installed if missing (needs internet on the target machine). Offline fallback: browse for a local copy. |
| SQL Server | Auto-detected. If unreachable, the installer offers to install SQL Server Express (downloaded) or, if there's no internet, a bundled LocalDB engine. See [SQL Server](#sql-server) below. |

Nothing above needs to be done by hand before running Setup — it's listed here so you know what the installer is going to do, and what to check first if a step fails.

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

The output is `installer\XCred-Setup-1.2.0.exe` — a single self-contained installer.

Optional: to make the installer work on servers with **no internet access at all**,
place a copy of `SqlLocalDB.msi` in `installer\redist\` before compiling — see
[`installer/redist/README.md`](redist/README.md) for how to obtain it. Without it,
offline machines with no reachable SQL Server will need one installed manually.

---

## Step 2 — Run the installer (target server)

1. Copy `XCred-Setup-1.2.0.exe` to the server.
2. Right-click → **Run as Administrator**.
3. Follow the wizard:

| Wizard page | What happens |
|---|---|
| **Destination folder** | Default `C:\Program Files\XCred` is fine; or choose any NTFS path |
| **Database** | Enter a SQL Server instance, database name, and credentials (blank username = Windows Authentication). Clicking **Next** tests the connection — if it fails, the wizard offers to install SQL Server Express for you (see [SQL Server](#sql-server)) — then checks whether that database name **already exists**. If it does, you're shown its current schema state (e.g. the last applied migration) and asked whether to reuse it as-is (XCred updates its schema automatically) or go back and pick a different name for a fresh database. |
| **IIS Configuration** | Site name, port, and base URL for email links. Clicking **Next** checks whether the port is already in use — by another IIS site, or by any other process — and blocks you from proceeding with a conflicting port. |
| **JWT Secret** | Leave blank to auto-generate (recommended for new installs). |
| **Ready to Install** | If the .NET Hosting Bundle isn't already on this machine, the installer downloads it here (or lets you browse for a local copy if there's no internet) — with a real progress bar. |

4. Click **Install**. A live, scrolling log of each configuration step (SQL Server, IIS, firewall, etc.) appears as it runs, so you can see exactly what's happening and why, if something fails. The installer will:
   - Install SQL Server Express or LocalDB, if you asked it to on the Database page
   - Enable the required Windows/IIS features (using the right method for Server vs. client Windows)
   - Install the .NET Hosting Bundle, if needed
   - Create an Application Pool (`<SiteName>Pool`, No Managed Code, Always Running)
   - Create the IIS Website, freeing the port from IIS's default site if that's what was using it
   - Open the Windows Firewall for the chosen port
   - Grant the app pool identity Modify permissions on the install directory
   - Grant the app pool identity a SQL Server login (see [SQL Server permissions](#sql-server-permissions))
   - Patch `appsettings.json` and `appsettings.Production.json` with your values
   - Apply the database schema (create the database if it's new, or bring an existing one
     up to date) — as its own explicit, logged step, so a schema problem is caught and
     reported here instead of surfacing later as a crash on someone's first visit to the site
   - Start the site

5. On the final screen, tick **Open XCred in browser** and click **Finish**.

If any of these steps fails, the installer shows the exact cause and automatically opens
the log file (`%TEMP%\XCred-Install.log`) in Notepad instead of silently leaving a
half-configured site — fix the underlying issue (see [Troubleshooting](#troubleshooting))
and re-run.

---

## Step 3 — First login

The database schema is created/updated during install (see above), not deferred to first
startup — so by the time the site is running, it's ready. The **first registered user
automatically becomes Admin** — register immediately after install.

---

## SQL Server

You can point the installer at any SQL Server you already have (local, named instance,
or a remote/domain server) — just fill in the Database page. If that connection fails,
you're offered a local install instead:

1. **SQL Server Express (default fallback)** — downloaded from Microsoft and installed
   silently as instance `.\SQLEXPRESS`, with the current admin account (`BUILTIN\Administrators`)
   as sysadmin. Requires internet access on the target machine.
2. **SQL Server Express LocalDB (offline fallback)** — only available if the installer was
   built with `SqlLocalDB.msi` bundled (see [Step 1](#step-1--build-the-installer-developer-machine)).
   LocalDB runs per-user rather than as a shared Windows service, so it's meant for a
   single, disconnected server, not a large shared deployment.

Either way, the installer also grants the IIS app pool identity access automatically —
see below.

### Pointing at a database that already exists

If the database name you enter already exists (a previous install, a restore, a
dev/test database, etc.), the wizard tells you so — including the last migration
it finds applied — and asks whether to:

- **Reuse it** — the installer grants the app pool identity access to it and applies
  any migrations newer than what's already there during install, same as a fresh
  database. Nothing is dropped or reset; existing data stays.
- **Use a different name instead** — go back and change the database name on the
  same page to start with a brand-new, empty database.

## SQL Server permissions

XCred creates its own database on first start (EF Core `MigrateAsync` issues
`CREATE DATABASE`), which needs the **dbcreator** server role — `db_owner` alone
isn't enough, and can't be granted yet anyway since the database doesn't exist
until that first run.

When using **Windows Authentication**, the installer automatically creates a SQL
login for the app pool identity (`IIS AppPool\<SiteName>Pool`) and grants it
`dbcreator` — this applies whether SQL Server was already there or the installer
provisioned it. SQL Server automatically makes the login that creates a database
its owner, so this one grant covers first-run creation *and* every migration
after it — no separate `db_owner` step needed, **provided the database doesn't
already exist**.

If the database name you chose already exists (a leftover from a previous
install, a restore, a dev/test machine, etc.), `dbcreator`'s auto-ownership
doesn't apply — that only kicks in for a database the login creates itself. The
installer detects this and grants `db_owner` inside the existing database
directly instead. If that's what happened and the automatic grant still failed
for some reason (or your login can't reach the SQL Server as an administrator
at all), run whichever of these applies, before starting XCred:

```sql
-- Run in SQL Server Management Studio, against the SQL Server instance
-- Always needed:
CREATE LOGIN [IIS APPPOOL\<SiteName>Pool] FROM WINDOWS;

-- If the database does NOT exist yet (XCred will create it on first start):
ALTER SERVER ROLE dbcreator ADD MEMBER [IIS APPPOOL\<SiteName>Pool];

-- If the database already exists:
USE [<YourDatabaseName>];
CREATE USER [IIS APPPOOL\<SiteName>Pool] FOR LOGIN [IIS APPPOOL\<SiteName>Pool];
ALTER ROLE db_owner ADD MEMBER [IIS APPPOOL\<SiteName>Pool];
```

If using **SQL Authentication**, the connection string already contains credentials —
no additional SQL Server steps needed.

---

## HTTPS setup (recommended for production)

1. Obtain a certificate (IIS → Server Certificates → import, or use Let's Encrypt with win-acme).
2. In IIS Manager → Sites → XCred → Bindings → Add → HTTPS, port 443, select certificate.
3. Update the base URL in `appsettings.Production.json` → `AllowedOrigins` to `https://...`.
4. Re-run the installer (or manually add a firewall rule for 443) since the automatic
   firewall rule only opens the port chosen during setup.
5. Run `iisreset`.

---

## Upgrading

Run `scripts\publish.ps1` and recompile the installer, then run the new `.exe` on the server.

The installer detects an existing XCred install (via the registry key it wrote and the
config files already in place) and treats this as an upgrade automatically — **the
Destination Folder, Database, IIS Configuration, and JWT Secret pages are skipped
entirely**, pre-filled from the current install's own `appsettings.json` /
`appsettings.Production.json` and IIS site, so you aren't re-asked questions you already
answered. It goes straight to the Ready-to-Install page. Everything downstream (SQL
permissions, IIS site/pool, firewall rule, schema migrations) re-runs exactly as it does
for a fresh install — safely, since all of that is already idempotent.

If detection can't confidently read back a usable connection string or site name (for
example, a hand-edited config), it falls back to a normal install and asks the usual
questions instead of risking a broken silent upgrade.

---

## Uninstalling

Control Panel → Programs → XCred → Uninstall.
This removes the IIS site, app pool, and the firewall rule, then deletes the install directory.
**The database and any SQL Server/LocalDB engine the installer provisioned are not removed** —
delete them manually if desired.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Installer says a reboot may be required, then IIS setup fails | Windows just enabled IIS features and hasn't finished activating them | Reboot the server, then re-run the installer — it's idempotent. |
| ".NET Hosting Bundle... not found" even after install | Bundle was installed **before** IIS was enabled | Per Microsoft's own docs this requires a repair — re-run the XCred installer (it re-checks and reinstalls the bundle if still missing) or manually re-run the Hosting Bundle installer, then `iisreset`. |
| Wizard blocks you at the IIS page with a port conflict | Another site or process (not IIS's Default Web Site) already owns that port | Pick a different port, or stop/uninstall whatever is using it, then retry. |
| SQL connection test keeps failing even though the server is reachable | Firewall on the *SQL* box blocking 1433, or SQL Browser not running for a named instance | Confirm `Test-NetConnection <server> -Port 1433` succeeds from the web server, and that SQL Server Browser is running if you're using a named instance. |
| App pool identity can't reach SQL Server after install | You pointed the installer at your own SQL Server (not one it provisioned) | Run the manual grant SQL under [SQL Server permissions](#sql-server-permissions). |
| "Applying database schema (migrations)" step fails during install | Permission grant didn't fully take effect, or the database is in a state EF Core's migrations can't reconcile (e.g. manually edited outside EF) | Check the log output shown for that step; for permission errors, re-check [SQL Server permissions](#sql-server-permissions); for schema conflicts, restore from backup or point at a different database name. |
| Full install log | `%TEMP%\XCred-Install.log` (opens automatically in Notepad on failure) | |
