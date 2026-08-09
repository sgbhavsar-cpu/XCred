#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Called by the Inno Setup installer.
    Reads xcred-install.json from the temp dir, then:
      1. Provisions a local SQL engine if the wizard asked for one, and
         verifies SQL Server connectivity
      2. Enables required Windows/IIS features (Server or client OS)
      3. Installs the .NET Hosting Bundle if it's still missing
      4. Creates the IIS Application Pool and Website
      5. Opens the firewall for the chosen port
      6. Sets NTFS permissions on the install directory
      7. Grants the app pool identity access to SQL Server (new or existing database)
      8. Patches appsettings.json and appsettings.Production.json
      9. Applies the database schema (migrations) as its own explicit step
      10. Starts the website
#>
param(
    [Parameter(Mandatory)]
    [string]$ConfigFile
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ── Progress reporting to the Inno Setup wizard ──────────────────────────────
# Inno Setup runs this script via ExecAndLogOutput, which captures stdout
# line-by-line as it's written and streams it into a live log textbox in the
# wizard — so plain Write-Host here is all that's needed; no extra file-based
# signaling required.
function Log([string]$msg, [string]$color = 'Gray') { Write-Host $msg -ForegroundColor $color }
function Step([string]$msg) { Log '' 'Gray'; Log ">> $msg" 'Cyan' }
function OK   { Log '   Done.' 'Green' }
function Warn([string]$msg) { Log "   WARNING: $msg" 'Yellow' }

# A broken/changed download URL can return an HTML error page with a 200 OK
# instead of failing outright, silently producing a bogus "installer" that
# then crashes Start-Process with a cryptic "not a valid application for
# this OS platform" error. Check for the PE header ('MZ') before running
# anything we downloaded, so a bad download fails with a clear message here
# instead of that opaque one.
function Test-IsValidExe([string]$path) {
    if (-not (Test-Path $path)) { return $false }
    $stream = [System.IO.File]::OpenRead($path)
    try {
        $header = New-Object byte[] 2
        $read = $stream.Read($header, 0, 2)
        return ($read -eq 2) -and ($header[0] -eq 0x4D) -and ($header[1] -eq 0x5A)
    } finally {
        $stream.Dispose()
    }
}

# Where the ASP.NET Core Module V2 (aspnetcorev2.dll) actually lives has moved
# across Hosting Bundle versions — older ones placed it directly under
# System32\inetsrv; current ones install it under Program Files and register
# it with IIS as a global module pointing there instead. Checking only the old
# path reports "not installed" even when it demonstrably is, triggering a
# needless (and possibly failing) reinstall. Check the known locations, then
# fall back to asking IIS itself, which is authoritative regardless of path.
function Test-AncmInstalled {
    $knownPaths = @(
        "$env:SystemRoot\System32\inetsrv\aspnetcorev2.dll",
        "$env:ProgramFiles\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll",
        "${env:ProgramFiles(x86)}\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll"
    )
    foreach ($path in $knownPaths) {
        if (Test-Path $path) { return $true }
    }
    try {
        Import-Module WebAdministration -ErrorAction Stop
        $module = Get-WebGlobalModule -Name 'AspNetCoreModuleV2' -ErrorAction SilentlyContinue
        if ($module -and $module.Image) {
            # applicationHost.config stores this with an unexpanded %ProgramFiles%-style
            # token — Test-Path won't expand that on its own.
            $imagePath = [System.Environment]::ExpandEnvironmentVariables($module.Image)
            if (Test-Path $imagePath) { return $true }
        }
    } catch { }
    return $false
}

# ── Logging ─────────────────────────────────────────────────────────────────
# Inno Setup runs this script hidden, so a thrown error would otherwise be
# invisible. Log the whole run to a file and surface failures via a non-zero
# exit code (the installer checks it and shows this path on failure).
$LogFile = Join-Path $env:TEMP 'XCred-Install.log'
try { Start-Transcript -Path $LogFile -Force | Out-Null } catch { }
Log "Install log: $LogFile"

# Any terminating error lands here: log it clearly and exit non-zero.
trap {
    Log "`nINSTALL FAILED: $($_.Exception.Message)" 'Red'
    Log "$($_.ScriptStackTrace)" 'Red'
    try { Stop-Transcript | Out-Null } catch { }
    exit 1
}

# ── Load config ───────────────────────────────────────────────────────────────
Step 'Loading install configuration'
if (-not (Test-Path $ConfigFile)) { throw "Config file not found: $ConfigFile" }
$cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$InstallDir           = $cfg.InstallDir
$ConnectionStr        = $cfg.ConnectionString
$JwtSecret            = $cfg.JwtSecret
$SiteName             = $cfg.SiteName
$Port                 = [int]$cfg.Port
$AppBaseUrl           = $cfg.AppBaseUrl
$HostingBundlePath    = $cfg.HostingBundlePath
$SqlInstallMode       = $cfg.SqlInstallMode
$SqlBootstrapperPath  = $cfg.SqlBootstrapperPath
$SqlLocalDbMsiPath    = $cfg.SqlLocalDbMsiPath
$PoolName             = "${SiteName}Pool"
OK

# ── 1a. Provision a local SQL engine, if the wizard asked for one ───────────
if ($SqlInstallMode -eq 'express') {
    Step 'Installing SQL Server Express (this can take several minutes)'
    if (-not (Test-Path $SqlBootstrapperPath)) { throw "SQL Server Express installer not found at $SqlBootstrapperPath" }
    $p = Start-Process -FilePath $SqlBootstrapperPath -ArgumentList @(
            '/ACTION=Install', '/IACCEPTSQLSERVERLICENSETERMS', '/QUIET',
            '/INSTANCENAME=SQLEXPRESS', '/TCPENABLE=1',
            '/SQLSYSADMINACCOUNTS=BUILTIN\Administrators'
         ) -Wait -PassThru
    if ($p.ExitCode -notin 0, 3010) {
        throw "SQL Server Express setup failed (exit code $($p.ExitCode)). " +
              "See '%ProgramFiles%\Microsoft SQL Server\...\Setup Bootstrap\Log' for details."
    }
    Start-Service -Name 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
    OK
}
elseif ($SqlInstallMode -eq 'localdb') {
    Step 'Installing SQL Server Express LocalDB'
    if (-not (Test-Path $SqlLocalDbMsiPath)) { throw "SqlLocalDB.msi not found at $SqlLocalDbMsiPath" }
    $localDbLog = Join-Path $env:TEMP 'SqlLocalDB-Install.log'
    $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList @(
            '/i', "`"$SqlLocalDbMsiPath`"", '/qn', 'IACCEPTSQLLOCALDBLICENSETERMS=YES',
            '/log', "`"$localDbLog`""
         ) -Wait -PassThru
    if ($p.ExitCode -notin 0, 3010, 1641) {
        throw "SQL Server Express LocalDB setup failed (exit code $($p.ExitCode)). Log: $localDbLog"
    }
    OK
}

# ── 1b. Verify SQL Server connectivity before touching IIS ───────────────────
Step 'Verifying SQL Server connectivity'
$masterConnStr = $ConnectionStr -replace '(?i)Database=[^;]+;', 'Database=master;'
$maxAttempts = 10
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    try {
        $testConn = New-Object System.Data.SqlClient.SqlConnection($masterConnStr)
        $testConn.Open()
        $testConn.Close()
        break
    } catch {
        if ($attempt -eq $maxAttempts) {
            throw "Could not connect to SQL Server: $($_.Exception.Message)`n`n" +
                  "Check the connection details and make sure the SQL Server service is running, then re-run the installer."
        }
        Log "   Attempt $attempt/$maxAttempts failed, retrying..." 'DarkYellow'
        Start-Sleep -Seconds 3
    }
}
OK

# ── 2. Enable required Windows/IIS features (Server vs. client OS) ──────────
Step 'Detecting operating system type'
$IsServerOS = $false
try {
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $IsServerOS = $osInfo.ProductType -ne 1   # 1 = Workstation; 2/3 = Domain Controller/Server
} catch { }
Log "   $(if ($IsServerOS) { 'Windows Server' } else { 'Windows client (10/11)' }) detected."
OK

Step 'Enabling required IIS Windows Features'
$needsReboot = $false

if ($IsServerOS -and (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue)) {
    Import-Module ServerManager -ErrorAction SilentlyContinue
    $serverFeatures = @(
        'Web-Server', 'Web-WebServer', 'Web-Common-Http', 'Web-Default-Doc', 'Web-Dir-Browsing',
        'Web-Http-Errors', 'Web-Static-Content', 'Web-Http-Redirect',
        'Web-Health', 'Web-Http-Logging', 'Web-Request-Monitor',
        'Web-Performance', 'Web-Stat-Compression',
        'Web-Security', 'Web-Filtering',
        'Web-App-Dev', 'Web-Net-Ext45', 'Web-Asp-Net45', 'Web-ISAPI-Ext', 'Web-ISAPI-Filter',
        'Web-Mgmt-Tools', 'Web-Mgmt-Console', 'Web-Scripting-Tools',
        'NET-Framework-45-ASPNET',
        'WAS', 'WAS-Process-Model', 'WAS-NET-Environment', 'WAS-Config-APIs'
    )
    Log "   Installing Windows Server role: Web-Server + management tools..."
    $result = Install-WindowsFeature -Name $serverFeatures -ErrorAction Stop
    if ($result.RestartNeeded -ne 'No') { $needsReboot = $true }
}
else {
    $clientFeatures = @(
        'IIS-WebServerRole', 'IIS-WebServer',
        'IIS-CommonHttpFeatures', 'IIS-StaticContent', 'IIS-DefaultDocument',
        'IIS-HttpErrors', 'IIS-HttpRedirect',
        'IIS-ApplicationDevelopment', 'IIS-NetFxExtensibility45',
        'IIS-ISAPIExtensions', 'IIS-ISAPIFilter',
        'IIS-HttpLogging', 'IIS-RequestMonitor',
        'IIS-HttpCompressionStatic', 'IIS-Security', 'IIS-RequestFiltering',
        'IIS-ManagementConsole', 'IIS-WebServerManagementTools', 'IIS-ManagementScriptingTools',
        'NetFx4Extended-ASPNET45'
    )
    foreach ($f in $clientFeatures) {
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue).State
        if ($state -ne 'Enabled') {
            Log "   Enabling $f ..."
            $result = Enable-WindowsOptionalFeature -Online -FeatureName $f -All -NoRestart -ErrorAction SilentlyContinue
            if ($result -and $result.RestartNeeded) { $needsReboot = $true }
        }
    }
}
if ($needsReboot) { Warn 'A reboot may be required for some Windows features to fully activate.' }
OK

# Make sure the IIS service itself is running before anything else touches it.
Step 'Ensuring the IIS service (W3SVC) is running'
if (-not (Get-Service -Name W3SVC -ErrorAction SilentlyContinue)) {
    throw "IIS did not install correctly (the W3SVC service was not found). " +
          "A reboot may be required to finish enabling Windows features — reboot the server and re-run this installer."
}
Set-Service   -Name W3SVC -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service -Name W3SVC -ErrorAction SilentlyContinue
OK

# ── 3. Install the .NET Hosting Bundle if the ASP.NET Core Module is missing ─
Step 'Checking .NET Hosting Bundle (ASP.NET Core Module)'
if (-not (Test-AncmInstalled)) {
    if ($HostingBundlePath -and (Test-Path $HostingBundlePath)) {
        if (-not (Test-IsValidExe $HostingBundlePath)) {
            throw "The downloaded Hosting Bundle installer at '$HostingBundlePath' isn't a valid executable " +
                  "(likely an interrupted or failed download). Delete it and re-run XCred Setup so it can be re-downloaded."
        }
        Log "   Installing $HostingBundlePath ..."
        $p = Start-Process -FilePath $HostingBundlePath -ArgumentList '/quiet', '/norestart' -Wait -PassThru
        if ($p.ExitCode -notin 0, 3010) {
            throw "The .NET Hosting Bundle installer failed (exit code $($p.ExitCode))."
        }
        # Per Microsoft docs: restart WAS/W3SVC (or the whole box) to pick up the new module.
        Stop-Service  -Name WAS   -Force -ErrorAction SilentlyContinue
        Start-Service -Name W3SVC -ErrorAction SilentlyContinue
        if (-not (Test-AncmInstalled)) {
            throw "The .NET Hosting Bundle was installed but the ASP.NET Core Module still isn't present. A reboot may be required."
        }
    }
    else {
        throw "The ASP.NET Core Module (ANCM) was not found and no Hosting Bundle installer was available.`n`n" +
              "Download it from https://dotnet.microsoft.com/download/dotnet/10.0 (Hosting Bundle), install it, then re-run XCred Setup."
    }
}
OK

# ── 4. Create IIS Application Pool ───────────────────────────────────────────
Import-Module WebAdministration -ErrorAction Stop

Step "Creating IIS Application Pool '$PoolName'"
if (Test-Path "IIS:\AppPools\$PoolName") {
    Log "   Pool already exists — reconfiguring."
    Stop-WebAppPool -Name $PoolName -ErrorAction SilentlyContinue
    Remove-WebAppPool -Name $PoolName
}
New-WebAppPool -Name $PoolName | Out-Null
# No managed code — required for ASP.NET Core
Set-ItemProperty "IIS:\AppPools\$PoolName" managedRuntimeVersion ''
# Keep the pool alive (no cold-start delay)
Set-ItemProperty "IIS:\AppPools\$PoolName" startMode 'AlwaysRunning'
Set-ItemProperty "IIS:\AppPools\$PoolName" autoStart $true
Set-ItemProperty "IIS:\AppPools\$PoolName" processModel.idleTimeout ([TimeSpan]::Zero)
if ($SqlInstallMode -eq 'localdb') {
    # LocalDB instances are created per-user-profile — the app pool identity needs
    # a loadable profile for LocalDB to work at all under it. Still best-effort:
    # LocalDB is not intended for shared/production hosting (see install guide).
    Set-ItemProperty "IIS:\AppPools\$PoolName" processModel.loadUserProfile $true
}
OK

# ── 5. Create IIS Website ─────────────────────────────────────────────────────
Step "Creating IIS Website '$SiteName' (port $Port)"

# Remove a previous XCred site of the same name (re-install / upgrade).
if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
    Log "   Site '$SiteName' already exists — removing."
    Stop-Website -Name $SiteName -ErrorAction SilentlyContinue
    Remove-Website -Name $SiteName
}

# Resolve port conflicts. A fresh IIS install binds 'Default Web Site' to *:80,
# so New-Website on the same port fails with a binding clash — the #1 reason the
# site silently fails to appear. Free the port first. (The wizard already warned
# the user about this and about any other conflicting site/process before Install
# began — this is the enforcement/safety-net side of that check.)
$portConflicts = Get-Website | Where-Object {
    $_.Name -ne $SiteName -and
    ($_.Bindings.Collection | Where-Object { $_.bindingInformation -like "*:$($Port):*" })
}
foreach ($c in $portConflicts) {
    if ($c.Name -eq 'Default Web Site') {
        Log "   Port $Port is used by 'Default Web Site' — stopping and removing it." 'Yellow'
        Stop-Website  -Name $c.Name -ErrorAction SilentlyContinue
        Remove-Website -Name $c.Name
    }
    else {
        throw "Port $Port is already in use by IIS site '$($c.Name)'. " +
              "Choose a different port in the installer, or free that port, then re-run."
    }
}

New-Website -Name $SiteName `
            -PhysicalPath $InstallDir `
            -Port $Port `
            -ApplicationPool $PoolName | Out-Null
Set-ItemProperty "IIS:\Sites\$SiteName" serverAutoStart $true
OK

# ── 6. Open the firewall ──────────────────────────────────────────────────────
Step "Opening firewall for port $Port"
$fwRuleName = "XCred - $SiteName"
try {
    Remove-NetFirewallRule -DisplayName $fwRuleName -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName $fwRuleName -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow | Out-Null
    OK
} catch {
    Warn "Could not create a firewall rule automatically: $($_.Exception.Message). You may need to open port $Port manually."
}

# ── 7. NTFS permissions ───────────────────────────────────────────────────────
Step 'Setting NTFS permissions for IIS app pool identity'
$acl      = Get-Acl $InstallDir
$identity = "IIS AppPool\$PoolName"
$rule     = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $identity, 'Modify',
                'ContainerInherit,ObjectInherit', 'None', 'Allow')
$acl.AddAccessRule($rule)
Set-Acl $InstallDir $acl

# Ensure logs directory exists and is writable
$logsDir = Join-Path $InstallDir 'logs'
New-Item -ItemType Directory -Force $logsDir | Out-Null
$acl2 = Get-Acl $logsDir
$acl2.AddAccessRule($rule)
Set-Acl $logsDir $acl2
OK

# ── 8. Grant the app pool identity access to SQL Server (Windows Auth only) ──
# Two distinct cases, both handled here:
#  - Database doesn't exist yet: XCred creates it on first start (EF Core
#    MigrateAsync issues CREATE DATABASE), which needs the dbcreator server
#    role. SQL Server automatically makes the creating login the owner of a
#    database it creates, which covers every later migration too.
#  - Database already exists (leftover from a previous install, a restore,
#    a dev/test machine, etc.): dbcreator's auto-ownership only applies to
#    databases this login creates itself, so an existing one needs an
#    explicit user + db_owner grant inside it, or the identity has no access
#    to it at all (EF's "does it exist" probe then misreads that access
#    failure as "doesn't exist" and retries CREATE DATABASE, which fails a
#    second way: "database already exists").
if ($ConnectionStr -match '(?i)Trusted_Connection=True') {
    Step "Granting SQL Server access to '$identity'"
    try {
        $dbNameMatch = [regex]::Match($ConnectionStr, '(?i)Database=([^;]+);')
        $dbName = $dbNameMatch.Groups[1].Value

        $grantConn = New-Object System.Data.SqlClient.SqlConnection($masterConnStr)
        $grantConn.Open()
        $cmd = $grantConn.CreateCommand()

        $cmd.CommandText = "IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$identity') CREATE LOGIN [$identity] FROM WINDOWS;"
        $cmd.ExecuteNonQuery() | Out-Null
        $cmd.CommandText = "IF NOT EXISTS (SELECT 1 FROM sys.server_role_members rm JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id WHERE r.name = 'dbcreator' AND m.name = N'$identity') ALTER SERVER ROLE dbcreator ADD MEMBER [$identity];"
        $cmd.ExecuteNonQuery() | Out-Null

        $cmd.CommandText = "SELECT DB_ID(N'$dbName')"
        $dbId = $cmd.ExecuteScalar()
        if ($null -ne $dbId -and $dbId -ne [DBNull]::Value) {
            Log "   Database '$dbName' already exists — granting db_owner inside it directly."
            $cmd.CommandText = "USE [$dbName]; IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$identity') CREATE USER [$identity] FOR LOGIN [$identity]; ALTER ROLE db_owner ADD MEMBER [$identity];"
            $cmd.ExecuteNonQuery() | Out-Null
        }

        $grantConn.Close()
        OK
    } catch {
        Warn ("Could not automatically grant '$identity' rights on SQL Server: $($_.Exception.Message). " +
              "XCred won't be able to start until this login has the dbcreator server role and, if the database " +
              "already exists, db_owner membership inside it — see the install guide for the exact SQL to run.")
    }
}

# ── 9. Patch appsettings files ────────────────────────────────────────────────
Step 'Patching appsettings.json (JWT secret)'
$baseConfig = Get-Content (Join-Path $InstallDir 'appsettings.json') -Raw | ConvertFrom-Json
$baseConfig.Jwt.Secret = $JwtSecret
$baseConfig | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $InstallDir 'appsettings.json') -Encoding UTF8
OK

Step 'Patching appsettings.Production.json (connection string + base URL)'
$prodConfigPath = Join-Path $InstallDir 'appsettings.Production.json'
$prodConfig = Get-Content $prodConfigPath -Raw | ConvertFrom-Json
$prodConfig.ConnectionStrings.DefaultConnection = $ConnectionStr
$prodConfig.AllowedOrigins = $AppBaseUrl
# HTTPS redirection only makes sense once a real certificate is bound to the site
# (a manual, documented post-install step — see INSTALL-GUIDE.md's "HTTPS setup"
# section). The default install is plain HTTP with no HTTPS binding at all, so
# leaving redirection on would issue redirects to a port nothing is listening on.
# Mirror it to the scheme of the base URL the admin just gave us: they've already
# told us whether HTTPS is set up by whether they typed http:// or https://.
$prodConfig.DisableHttpsRedirection = -not ($AppBaseUrl -match '(?i)^https://')
$prodConfig | ConvertTo-Json -Depth 10 | Set-Content $prodConfigPath -Encoding UTF8
OK

# ── 9b. Apply the database schema now, as its own explicit step ──────────────
# Runs XCred.Api.exe directly (bypassing IIS) with a flag that makes it run
# EF Core's MigrateAsync and exit — the exact same call the app makes on its
# own at startup, just surfaced here with full output, so a migration failure
# is caught during install instead of silently crashing the site on the first
# real request (which is what happens if this is left to the app alone: IIS
# just shows a generic 500.30, and the real error is buried in Event Viewer).
Step 'Applying database schema (migrations)'
$exePath = Join-Path $InstallDir 'XCred.Api.exe'
$migrateOut = Join-Path $env:TEMP 'XCred-Migrate.log'
Remove-Item $migrateOut -ErrorAction SilentlyContinue
$prevEnv = $env:ASPNETCORE_ENVIRONMENT
$env:ASPNETCORE_ENVIRONMENT = 'Production'
try {
    $p = Start-Process -FilePath $exePath -ArgumentList '--migrate-only' -WorkingDirectory $InstallDir `
            -Wait -PassThru -NoNewWindow -RedirectStandardOutput $migrateOut -RedirectStandardError "$migrateOut.err"
} finally {
    $env:ASPNETCORE_ENVIRONMENT = $prevEnv
}
foreach ($f in @($migrateOut, "$migrateOut.err")) {
    if (Test-Path $f) { Get-Content $f | Where-Object { $_ -ne '' } | ForEach-Object { Log "   $_" } }
}
if ($p.ExitCode -ne 0) {
    throw "Applying the database schema failed (exit code $($p.ExitCode)). See the output above, " +
          "and $InstallDir\logs, for details."
}
OK

# ── 10. Start the website ─────────────────────────────────────────────────────
Step "Starting website '$SiteName'"
Start-WebAppPool -Name $PoolName
Start-Website    -Name $SiteName
OK

Log ''
Log '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' 'Green'
Log " XCred is installed and running on port $Port." 'Green'
Log " Open a browser and navigate to: $AppBaseUrl"   'Green'
Log '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' 'Green'

try { Stop-Transcript | Out-Null } catch { }
exit 0
