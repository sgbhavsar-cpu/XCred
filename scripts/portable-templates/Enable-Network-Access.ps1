#Requires -Version 5.1
<#
.SYNOPSIS
    Lets other devices on your network (a phone running the XCred app, another PC's browser)
    reach this portable XCred. Out of the box XCred only listens on localhost, so nothing but
    this computer can connect.

    What it does:
      1. Changes "Urls" in app\appsettings.json from http://localhost:PORT to http://0.0.0.0:PORT
      2. Adds a Windows Firewall rule allowing inbound TCP PORT
      3. Restarts the XCredVault service if you installed it (otherwise: close and re-run Start-XCred.bat)
      4. Prints the address(es) to type into the phone app

    Run with -Off to go back to localhost-only and remove the firewall rule.
    Needs Administrator rights (it relaunches itself elevated if you didn't run it as admin).

.PARAMETER Off
    Turn network access back off.
.PARAMETER Port
    Port XCred listens on. Default 1507.
.PARAMETER ConfigOnly
    Only edit appsettings.json (no firewall rule, no service restart, no admin needed).
#>
[CmdletBinding()]
param(
    [switch]$Off,
    [int]$Port = 1507,
    [switch]$ConfigOnly
)

$ErrorActionPreference = 'Stop'
$serviceName = 'XCredVault'
$ruleName = "XCred Portable (TCP $Port)"
$cfgPath = Join-Path $PSScriptRoot 'app\appsettings.json'

if (-not (Test-Path $cfgPath)) {
    throw "Couldn't find $cfgPath - run this script from inside the unzipped XCred folder."
}

if (-not $ConfigOnly) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host 'This needs Administrator rights - relaunching elevated...' -ForegroundColor Yellow
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Port $Port"
        if ($Off) { $argList += ' -Off' }
        Start-Process powershell -Verb RunAs -ArgumentList $argList
        exit
    }
}

# --- 1. appsettings.json ------------------------------------------------------------------
$newUrl = if ($Off) { "http://localhost:$Port" } else { "http://0.0.0.0:$Port" }
$json = [IO.File]::ReadAllText($cfgPath)
if ($json -notmatch '"Urls"\s*:\s*"[^"]*"') { throw 'No "Urls" setting found in appsettings.json.' }
$updated = [regex]::Replace($json, '"Urls"\s*:\s*"[^"]*"', "`"Urls`": `"$newUrl`"")
[IO.File]::WriteAllText($cfgPath, $updated, (New-Object Text.UTF8Encoding($false)))
Write-Host "appsettings.json: Urls = $newUrl" -ForegroundColor Cyan

if ($ConfigOnly) {
    Write-Host 'Config only: restart XCred for it to take effect (no firewall rule was changed).' -ForegroundColor Yellow
    return
}

# --- 2. Firewall --------------------------------------------------------------------------
Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
if (-not $Off) {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port `
        -Profile Any -Description 'Allows phones/other PCs on the network to reach XCred Portable.' | Out-Null
    Write-Host "Firewall: inbound TCP $Port allowed." -ForegroundColor Cyan
} else {
    Write-Host 'Firewall: XCred rule removed.' -ForegroundColor Cyan
}

# --- 3. Restart ---------------------------------------------------------------------------
$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($svc) {
    Restart-Service -Name $serviceName -Force
    Write-Host "Service '$serviceName' restarted." -ForegroundColor Cyan
} else {
    Write-Host 'If XCred is running (Start-XCred.bat window), close it and start it again for this to take effect.' -ForegroundColor Yellow
}

# --- 4. Tell the user where to connect ----------------------------------------------------
if ($Off) {
    Write-Host "`nDone. XCred is reachable from this computer only (http://localhost:$Port)." -ForegroundColor Green
    return
}
$ips = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1' -and $_.PrefixOrigin -ne 'WellKnown' } |
    Select-Object -ExpandProperty IPAddress
Write-Host "`nDone. From a phone on the same network, use one of:" -ForegroundColor Green
foreach ($ip in $ips) { Write-Host "    http://${ip}:$Port" -ForegroundColor Green }
Write-Host @"

Notes:
 - This is plain HTTP. Your vault data is end-to-end encrypted, but your login password travels in
   clear text, so only do this on a network you trust (home/office), never on public Wi-Fi.
 - Your PC's address can change (DHCP). If the phone stops connecting, re-run this script to see the
   current address, or ask your network admin for a fixed address for this PC.
 - Run  .\Enable-Network-Access.ps1 -Off  to switch back to localhost-only.
"@ -ForegroundColor Gray
