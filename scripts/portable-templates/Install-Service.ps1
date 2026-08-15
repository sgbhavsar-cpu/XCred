#Requires -Version 5.1
<#
.SYNOPSIS
    Registers XCred as a Windows Service, so it keeps running after you close the
    terminal or log out - the alternative to Start-XCred.bat's plain console-window mode.
    Run this once. Needs Administrator rights (it will prompt to relaunch elevated if
    you didn't already run it as Administrator).
#>
$ErrorActionPreference = 'Stop'
$serviceName = 'XCredVault'
$root = $PSScriptRoot
$exePath = Join-Path $root 'app\XCred.Api.exe'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'This needs Administrator rights - relaunching elevated...' -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

if (-not (Test-Path $exePath)) {
    throw "Couldn't find $exePath - run this script from inside the unzipped XCred folder."
}

if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
    Write-Host "A service named '$serviceName' already exists. Stopping and removing it first..." -ForegroundColor Yellow
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    & sc.exe delete $serviceName | Out-Null
    Start-Sleep -Seconds 1
}

Write-Host "Installing '$serviceName' service..." -ForegroundColor Cyan
New-Service -Name $serviceName `
    -BinaryPathName "`"$exePath`"" `
    -DisplayName 'XCred Credential Vault' `
    -Description 'Self-contained XCred credential vault (portable/SQLite mode).' `
    -StartupType Automatic | Out-Null

Start-Service -Name $serviceName
Write-Host "`nDone. XCred is now running in the background and will start automatically on boot." -ForegroundColor Green
Write-Host "Open http://localhost:1507 in your browser." -ForegroundColor Green
Write-Host "To stop/remove it later, run Uninstall-Service.ps1 as Administrator." -ForegroundColor Green
