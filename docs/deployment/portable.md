# XCred — Portable Edition (Self-Contained, No IIS/SQL Server)

This is XCred's second distribution mode, alongside the [hosted IIS/SQL-Server
installer](../../installer/INSTALL-GUIDE.md). It trades centralized/multi-server hosting
for zero-setup simplicity: unzip a folder, run a batch file, and it's ready to use — no
IIS, no SQL Server, no separately-installed .NET runtime. It's built for a single
workstation, a USB drive, or an offline demo, not for replacing the hosted deployment at
team scale (see [`docs/requirements.md` §17.0 / §18.2](../requirements.md)).

---

## Step 1 — Build the portable distribution (developer machine)

```powershell
# From the project root — requires Node 20+ and .NET 10 SDK
.\scripts\publish-portable.ps1
```

This builds the React frontend, publishes the API as a self-contained single-file
executable (`win-x64`, bundles the .NET runtime — nothing else needs to be installed on
the target machine), and assembles everything into `publish-portable/`:

```
publish-portable/
├── Start-XCred.bat        <- double-click this to run
├── Install-Service.ps1    <- optional: run permanently in the background
├── Uninstall-Service.ps1
├── README.txt
└── app/
    ├── XCred.Api.exe       <- self-contained, ~60MB, bundles the .NET runtime
    ├── wwwroot/            <- the React SPA
    ├── appsettings.json    <- SQLite provider, port 1507, pre-configured
    └── data/                <- the SQLite database lives here once the app has run
```

Zip the whole `publish-portable/` folder to distribute it.

---

## Step 2 — Run it (target machine)

1. Unzip the folder anywhere — a Desktop, a USB drive, wherever.
2. Double-click `Start-XCred.bat`.
3. A console window opens and starts XCred; your browser opens automatically to
   `http://localhost:1507` once it's ready.
4. Register the first account — it automatically becomes the Admin account, same as the
   hosted deployment.

That's it. Data lives in `app\data\xcred.db`, a single SQLite file next to the app.
Closing the console window stops XCred; run `Start-XCred.bat` again to resume — your data
is untouched (it lives in the file, not the process).

---

## Running in the background (optional)

`Start-XCred.bat` runs XCred in the foreground — the console window itself is the
"is it running" indicator, and closing it stops the app. If you'd rather XCred kept
running permanently (survives closing the window, logging out, or rebooting):

1. Right-click `Install-Service.ps1` → **Run with PowerShell** (or run it from an
   elevated PowerShell prompt).
2. It prompts for Administrator rights once, registers XCred as a Windows Service named
   `XCredVault` (Automatic startup), and starts it.
3. Confirm with `Get-Service XCredVault` — it should show `Running`.

To undo this, run `Uninstall-Service.ps1` the same way. It stops and removes the service
but leaves `app\data\xcred.db` untouched — you can still use `Start-XCred.bat` afterward.

---

## Moving to a different machine / migrating from the hosted deployment

Portable XCred includes the same **System Backup** feature as the hosted deployment
(Admin Panel → System Backup) — it's engine-agnostic, so it works in either direction:

- **Portable → Portable**: export from the old machine, unzip a fresh copy on the new
  one, start it, register a throwaway first account to get into the Admin Panel, then
  restore the exported zip (`force=true` when prompted) — it replaces the throwaway
  account and any other data with the full contents of the backup.
- **Hosted (SQL Server) → Portable (SQLite)**: export from the hosted deployment's Admin
  Panel, restore onto a fresh portable instance. This is a genuine cross-engine data
  migration — every user, credential, folder, tag, group, share, and audit log
  transfers, including original login-password hashes and RSA key material, so existing
  users can log in with their original master password unchanged.
- **Portable (SQLite) → Hosted (SQL Server)**: works the same way in reverse.

This is different from **Settings → Backup & Restore**, which covers only the signed-in
user's own vault. System Backup is admin-only and covers the whole instance — treat the
exported zip with the same care as a database backup: it contains every user's
login-password hash and (still individually encrypted) RSA private key, not just one
person's credentials.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| "Port 1507 already in use" | Something else is already listening on 1507 | Edit `app\appsettings.json` → `Urls`, change the port (e.g. `http://localhost:1508`), then restart |
| Browser doesn't open automatically | Default browser association issue | Open `http://localhost:1507` manually |
| Data seems to have disappeared after moving the folder | The `app\data` folder wasn't included in the copy/zip | Always move or zip the whole `publish-portable` folder together, including `app\data` |
| Service won't start (`Install-Service.ps1`) | Something already listening on 1507, or the service account can't reach the `app` folder | Check `logs\` next to `XCred.Api.exe`; confirm the folder wasn't moved after installing the service (the service points at the path it was installed from) |
| Want to inspect/back up the raw database directly | — | `app\data\xcred.db` is a complete, single-file SQLite database — copy it directly as an alternative to the System Backup zip |

Logs are written to `logs\` next to `XCred.Api.exe`.

---

## Relationship to the hosted (IIS/SQL Server) deployment

Both modes share the same codebase, API, and zero-knowledge encryption model — only the
database engine and hosting method differ. Neither replaces the other:

| | Hosted (IIS / SQL Server) | Portable (SQLite) |
|---|---|---|
| Setup | Inno Setup installer, provisions IIS + SQL Server | Unzip and run a batch file |
| Scale | Designed for ~10-50 concurrent users | Single workstation / light use |
| Database | SQL Server (Express, LocalDB, or full) | SQLite (single file) |
| Background operation | IIS Application Pool | Optional Windows Service (`Install-Service.ps1`) |
| Moving/cloning an instance | System Backup (Admin Panel) | System Backup (Admin Panel) — same feature, works across both |

See [`installer/INSTALL-GUIDE.md`](../../installer/INSTALL-GUIDE.md) for the hosted
deployment guide.
