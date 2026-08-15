#Requires -Version 5.1
<#
.SYNOPSIS
    Builds XCred into a self-contained, portable Windows distribution — no IIS, no SQL
    Server, no separately-installed .NET runtime. Unzip the output folder anywhere and run
    Start-XCred.bat.

.PARAMETER OutputDir
    Where to write the portable distribution. Default: publish-portable/ at the repo root.
#>
[CmdletBinding()]
param(
    [string]$OutputDir = (Join-Path (Split-Path $PSScriptRoot) 'publish-portable')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$appDir = Join-Path $OutputDir 'app'
$templatesDir = Join-Path $PSScriptRoot 'portable-templates'

function Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function OK { Write-Host '    OK' -ForegroundColor Green }

# See scripts/publish.ps1 for why $ErrorActionPreference is relaxed around native calls —
# same PowerShell 5.1 stderr-as-terminating-error quirk applies here.
function Invoke-Native {
    param([Parameter(Mandatory)][scriptblock]$Command, [Parameter(Mandatory)][string]$FailMessage)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Command } finally { $ErrorActionPreference = $prev }
    if ($LASTEXITCODE -ne 0) { throw $FailMessage }
}

Step 'Checking tools'
foreach ($cmd in 'node', 'npm', 'dotnet') {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "$cmd is not on PATH. Please install it and retry."
    }
}
OK

Step 'Installing frontend dependencies (npm ci)'
Push-Location (Join-Path $root 'src\XCred.Web')
try {
    Invoke-Native { & npm ci --silent } 'npm ci failed'
} finally { Pop-Location }
OK

Step 'Building React frontend (npm run build)'
Push-Location (Join-Path $root 'src\XCred.Web')
try {
    Invoke-Native { & npm run build } 'npm run build failed'
    $wwwroot = Join-Path $root 'src\XCred.Api\wwwroot'
    if (-not (Test-Path $wwwroot)) { throw "Expected wwwroot at $wwwroot but it was not created." }
} finally { Pop-Location }
OK

Step "Publishing self-contained single-file API -> $appDir"
if (Test-Path $OutputDir) { Remove-Item $OutputDir -Recurse -Force }
Invoke-Native {
    & dotnet publish (Join-Path $root 'src\XCred.Api\XCred.Api.csproj') `
          -c Release `
          -p:PublishProfile=Portable `
          -o $appDir `
          --nologo
} 'dotnet publish failed'
OK

Step 'Wiring up portable config (SQLite, no IIS/env-vars required)'
$portableSettings = Join-Path $root 'src\XCred.Api\appsettings.Portable.json'
Copy-Item $portableSettings (Join-Path $appDir 'appsettings.json') -Force
# Avoid ambiguity with any environment-specific file the publish step also copied —
# appsettings.json alone (just overwritten above) is now the complete, self-sufficient
# config regardless of how the exe is launched (batch file or Windows Service — see
# Program.cs's comments on why this matters for New-Service specifically). Also drop
# web.config (an IIS/ANCM artifact the SDK emits by default on every publish — inert here,
# but confusing clutter in a distribution whose whole point is "no IIS involved").
Remove-Item (Join-Path $appDir 'appsettings.Production.json') -ErrorAction SilentlyContinue
Remove-Item (Join-Path $appDir 'appsettings.Portable.json') -ErrorAction SilentlyContinue
Remove-Item (Join-Path $appDir 'web.config') -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Join-Path $appDir 'data') | Out-Null
OK

Step 'Adding launcher scripts'
Copy-Item (Join-Path $templatesDir 'Start-XCred.bat') $OutputDir -Force
Copy-Item (Join-Path $templatesDir 'Install-Service.ps1') $OutputDir -Force
Copy-Item (Join-Path $templatesDir 'Uninstall-Service.ps1') $OutputDir -Force
Copy-Item (Join-Path $templatesDir 'README.txt') $OutputDir -Force
OK

Write-Host ''
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Green
Write-Host " Portable build ready at: $OutputDir" -ForegroundColor Green
Write-Host ' Zip that whole folder to distribute it, or' -ForegroundColor Green
Write-Host ' run Start-XCred.bat directly to try it now.' -ForegroundColor Green
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Green
