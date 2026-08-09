# Offline SQL fallback (optional)

XCred Setup tries to download SQL Server Express automatically when no
reachable SQL Server is found. If the target machine has no internet access,
the download fails — as a fallback, the installer will offer to install
**SQL Server Express LocalDB** instead, but only if `SqlLocalDB.msi` is
present in this folder *when you compile the installer*.

This file is not checked into source control (see `.gitignore`) because it's
a large, versioned, third-party binary — each build machine should fetch its
own copy.

## How to get `SqlLocalDB.msi`

1. Download the SQL Server Express bootstrapper from the official page:
   <https://go.microsoft.com/fwlink/?linkid=2215160> (SQL Server 2022 Express —
   matches the version `Setup-XCred.ps1` installs on the online path).
2. Run it and choose **Download Media** (not Basic/Custom) — this downloads
   the full, extractable installation package instead of just installing.
3. In the extracted media, find:
   `<media_root>\<LCID>_ENU_LP\x64\Setup\x64\SqlLocalDB.msi`
   (LCID `1033` = en-US).
4. Copy that `SqlLocalDB.msi` into this folder (`installer\redist\`).
5. Recompile `installer\setup.iss` — the Inno Setup script includes the file
   automatically via `#ifexist` when present, and skips it silently when it
   isn't.

## Why LocalDB and not full SQL Express, offline

Full SQL Server Express doesn't have a small, standalone offline installer —
only the small online bootstrapper (which needs internet) or the multi-hundred-
MB full media. LocalDB is the one piece of the SQL Server family with a
single, bundleable `.msi` (~50 MB), which is why it's the offline fallback.

**Trade-off:** LocalDB runs as a per-user, on-demand instance rather than a
shared Windows service. It's the right tool for a disconnected single-server
install, but it's a weaker fit for a shared, always-on IIS-hosted app than
either a pre-existing SQL Server or a freshly downloaded SQL Express — use it
only when there's truly no internet access and no existing SQL Server to
point at.
