#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Called by the Inno Setup installer.
    Reads xcred-install.json from the temp dir, then:
      1. Checks the .NET 10 ASP.NET Core Hosting Bundle
      2. Enables required IIS Windows Features
      3. Creates the IIS Application Pool and Website
      4. Sets NTFS permissions on the install directory
      5. Patches appsettings.json and appsettings.Production.json
      6. Starts the website
#>
param(
    [Parameter(Mandatory)]
    [string]$ConfigFile
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Step([string]$msg) { Write-Host "`n>> $msg" -ForegroundColor Cyan }
function OK   { Write-Host '   Done.' -ForegroundColor Green }
function Warn([string]$msg) { Write-Host "   WARNING: $msg" -ForegroundColor Yellow }

# ── Logging ─────────────────────────────────────────────────────────────────
# Inno Setup runs this script hidden, so a thrown error would otherwise be
# invisible. Log the whole run to a file and surface failures via a non-zero
# exit code (the installer checks it and shows this path on failure).
$LogFile = Join-Path $env:TEMP 'XCred-Install.log'
try { Start-Transcript -Path $LogFile -Force | Out-Null } catch { }
Write-Host "Install log: $LogFile"

# Any terminating error lands here: log it clearly and exit non-zero.
trap {
    Write-Host "`nINSTALL FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    try { Stop-Transcript | Out-Null } catch { }
    exit 1
}

# ── Load config ───────────────────────────────────────────────────────────────
Step 'Loading install configuration'
if (-not (Test-Path $ConfigFile)) { throw "Config file not found: $ConfigFile" }
$cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$InstallDir      = $cfg.InstallDir
$ConnectionStr   = $cfg.ConnectionString
$JwtSecret       = $cfg.JwtSecret
$SiteName        = $cfg.SiteName
$Port            = [int]$cfg.Port
$AppBaseUrl      = $cfg.AppBaseUrl
$PoolName        = "${SiteName}Pool"
OK

# ── 1. Check .NET 10 Hosting Bundle ──────────────────────────────────────────
Step 'Checking .NET 10 ASP.NET Core Hosting Bundle'
$ancm = "$env:SystemRoot\System32\inetsrv\aspnetcorev2.dll"
if (-not (Test-Path $ancm)) {
    Write-Host @'

  ERROR: The ASP.NET Core Module (ANCM) was not found.
  The .NET 10 Hosting Bundle must be installed before running this installer.

  Download it from:
  https://dotnet.microsoft.com/download/dotnet/10.0
  (look for "Hosting Bundle" under Windows)

  Install it, then re-run the XCred installer.

'@ -ForegroundColor Red
    exit 1
}

$runtimes = & dotnet --list-runtimes 2>$null
$hasRuntime = $runtimes | Where-Object { $_ -match '^Microsoft\.AspNetCore\.App 10\.' }
if (-not $hasRuntime) {
    Warn 'ASP.NET Core 10 runtime not detected via dotnet CLI. The app may fail to start if the hosting bundle is not correctly installed.'
}
OK

# ── 2. Enable IIS Windows Features ───────────────────────────────────────────
Step 'Enabling required IIS Windows Features'
$features = @(
    'IIS-WebServerRole', 'IIS-WebServer',
    'IIS-CommonHttpFeatures', 'IIS-StaticContent', 'IIS-DefaultDocument',
    'IIS-HttpErrors', 'IIS-HttpRedirect',
    'IIS-ApplicationDevelopment', 'IIS-NetFxExtensibility45',
    'IIS-ISAPIExtensions', 'IIS-ISAPIFilter',
    'IIS-HttpLogging', 'IIS-RequestMonitor',
    'IIS-HttpCompressionStatic', 'IIS-Security', 'IIS-RequestFiltering',
    'IIS-ManagementConsole', 'NetFx4Extended-ASPNET45'
)

$needsReboot = $false
foreach ($f in $features) {
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue).State
    if ($state -ne 'Enabled') {
        Write-Host "   Enabling $f ..." -NoNewline
        $result = Enable-WindowsOptionalFeature -Online -FeatureName $f -All -NoRestart -ErrorAction SilentlyContinue
        if ($result.RestartNeeded) { $needsReboot = $true }
        Write-Host ' OK' -ForegroundColor Green
    }
}
if ($needsReboot) { Warn 'A reboot may be required for some IIS features to fully activate.' }
OK

# ── 3. Create IIS Application Pool ───────────────────────────────────────────
Import-Module WebAdministration -ErrorAction Stop

# Make sure the IIS service itself is running — on a server where IIS was just
# enabled it can be stopped/disabled, which would make site creation fail.
Step 'Ensuring the IIS service (W3SVC) is running'
Set-Service  -Name W3SVC -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service -Name W3SVC -ErrorAction SilentlyContinue
OK

Step "Creating IIS Application Pool '$PoolName'"
if (Test-Path "IIS:\AppPools\$PoolName") {
    Write-Host "   Pool already exists — reconfiguring."
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
OK

# ── 4. Create IIS Website ─────────────────────────────────────────────────────
Step "Creating IIS Website '$SiteName' (port $Port)"

# Remove a previous XCred site of the same name (re-install / upgrade).
if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
    Write-Host "   Site '$SiteName' already exists — removing."
    Stop-Website -Name $SiteName -ErrorAction SilentlyContinue
    Remove-Website -Name $SiteName
}

# Resolve port conflicts. A fresh IIS install binds 'Default Web Site' to *:80,
# so New-Website on the same port fails with a binding clash — the #1 reason the
# site silently fails to appear. Free the port first.
$portConflicts = Get-Website | Where-Object {
    $_.Name -ne $SiteName -and
    ($_.Bindings.Collection | Where-Object { $_.bindingInformation -like "*:$($Port):*" })
}
foreach ($c in $portConflicts) {
    if ($c.Name -eq 'Default Web Site') {
        Write-Host "   Port $Port is used by 'Default Web Site' — stopping and removing it." -ForegroundColor Yellow
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

# ── 5. NTFS permissions ───────────────────────────────────────────────────────
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

# ── 6. Patch appsettings files ────────────────────────────────────────────────
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
$prodConfig | ConvertTo-Json -Depth 10 | Set-Content $prodConfigPath -Encoding UTF8
OK

# ── 7. Start the website ──────────────────────────────────────────────────────
Step "Starting website '$SiteName'"
Start-WebAppPool -Name $PoolName
Start-Website    -Name $SiteName
OK

Write-Host ''
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Green
Write-Host " XCred is installed and running on port $Port." -ForegroundColor Green
Write-Host " Open a browser and navigate to: $AppBaseUrl"   -ForegroundColor Green
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Green

try { Stop-Transcript | Out-Null } catch { }
exit 0
