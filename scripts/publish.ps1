#Requires -Version 5.1
<#
.SYNOPSIS
    Builds the XCred frontend and backend into the publish/ folder,
    ready for the Inno Setup installer to package.

.PARAMETER Configuration
    Build configuration. Default: Release
#>
[CmdletBinding()]
param(
    [ValidateSet('Release', 'Debug')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$root    = Split-Path $PSScriptRoot
$pubDir  = Join-Path $root 'publish'

function Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function OK  { Write-Host '    OK' -ForegroundColor Green }

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
    & npm ci --silent
    if ($LASTEXITCODE -ne 0) { throw 'npm ci failed' }
} finally { Pop-Location }
OK

Step 'Building React frontend (npm run build)'
Push-Location (Join-Path $root 'src\XCred.Web')
try {
    & npm run build
    if ($LASTEXITCODE -ne 0) { throw 'npm run build failed' }
    # Vite outputs to src/XCred.Api/wwwroot — confirm
    $wwwroot = Join-Path $root 'src\XCred.Api\wwwroot'
    if (-not (Test-Path $wwwroot)) { throw "Expected wwwroot at $wwwroot but it was not created." }
} finally { Pop-Location }
OK

Step "Publishing ASP.NET Core API ($Configuration) → publish/"
if (Test-Path $pubDir) { Remove-Item $pubDir -Recurse -Force }
& dotnet publish (Join-Path $root 'src\XCred.Api\XCred.Api.csproj') `
      -c $Configuration `
      -o $pubDir `
      --nologo
if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed' }
OK

# Remove any leftover dev files from the publish output
Remove-Item "$pubDir\appsettings.Development.json" -ErrorAction SilentlyContinue

Write-Host ''
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Green
Write-Host " Published to: $pubDir" -ForegroundColor Green
Write-Host ' Next: open installer\setup.iss in Inno Setup' -ForegroundColor Green
Write-Host '        Compiler and click Build → Compile.'   -ForegroundColor Green
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Green
