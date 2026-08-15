#Requires -Version 5.1
<#
.SYNOPSIS
    Stops and removes the XCred Windows Service installed by Install-Service.ps1.
    Needs Administrator rights (it will prompt to relaunch elevated if needed).
    Does NOT delete your data - the app/data folder (and your SQLite database in it) is
    left untouched; you can still run Start-XCred.bat afterward.
#>
$ErrorActionPreference = 'Stop'
$serviceName = 'XCredVault'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'This needs Administrator rights - relaunching elevated...' -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

if (-not (Get-Service -Name $serviceName -ErrorAction SilentlyContinue)) {
    Write-Host "No '$serviceName' service found - nothing to do." -ForegroundColor Yellow
    exit
}

Write-Host "Stopping '$serviceName'..." -ForegroundColor Cyan
Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue

Write-Host "Removing '$serviceName'..." -ForegroundColor Cyan
& sc.exe delete $serviceName | Out-Null

Write-Host "`nDone. The service has been removed. Your data in the app\data folder is untouched." -ForegroundColor Green
Write-Host "You can still run Start-XCred.bat to use XCred in a console window." -ForegroundColor Green
