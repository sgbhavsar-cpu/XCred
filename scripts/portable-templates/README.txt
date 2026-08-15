XCred - Portable Edition
=========================

No installation needed. This folder is the whole app.

QUICK START
-----------
1. Unzip this folder anywhere (a USB drive, Desktop, wherever).
2. Double-click Start-XCred.bat.
3. Your browser opens automatically to http://localhost:1507.
4. Register your first account - it automatically becomes the admin account.

That's it. Your data is stored in the app\data folder, right next to the app.

KEEP IT RUNNING IN THE BACKGROUND (optional)
---------------------------------------------
Start-XCred.bat runs XCred in a console window - closing that window stops the app.
If you'd rather it kept running permanently in the background (survives closing the
window, logging out, or rebooting), right-click Install-Service.ps1 and choose
"Run with PowerShell" (or run it from an elevated PowerShell prompt). It'll ask for
Administrator rights once, register XCred as a Windows Service named "XCredVault", and
start it. To undo this later, run Uninstall-Service.ps1 the same way.

MOVING TO A DIFFERENT MACHINE
------------------------------
Log in as an admin, go to Admin Panel -> System Backup, and click "Export Full System
Backup" - this downloads a zip with every user, credential, and setting on this instance
(not just your own vault). Unzip a fresh copy of XCred Portable on the new machine, start
it, register a throwaway first account just to get into the Admin Panel, then use
"Restore Full System Backup" with the zip you exported - it will replace that throwaway
account (and anything else on the new instance) with the real data from your backup.

This also works the other way: if you're currently running the full IIS/SQL-Server
installer version of XCred, its own Admin Panel has the same System Backup feature -
export from there and restore it here to move onto this portable edition instead.

BACKING UP YOUR OWN DATA
-------------------------
Settings -> Backup & Restore covers your own personal vault (just your credentials, still
encrypted, restorable onto your account elsewhere). Admin Panel -> System Backup covers
the WHOLE instance (every user) and is meant for admins moving/cloning the entire app.

TROUBLESHOOTING
----------------
- "Port 1507 already in use": edit app\appsettings.json's Kestrel/Urls setting to a
  different port (e.g. http://localhost:1508), or stop whatever else is using 1507.
- Logs are written to the logs\ folder next to XCred.Api.exe.
- Your database is app\data\xcred.db - back that file up directly if you'd rather not use
  the System Backup zip feature (it's a complete, single-file copy of everything).
