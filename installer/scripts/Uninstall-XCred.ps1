#Requires -RunAsAdministrator
param(
    [Parameter(Mandatory)]
    [string]$SiteName
)

$ErrorActionPreference = 'SilentlyContinue'
Import-Module WebAdministration

$poolName = "${SiteName}Pool"

Write-Host "Stopping and removing IIS site '$SiteName'..." -NoNewline
Stop-Website -Name $SiteName
Remove-Website -Name $SiteName
Write-Host ' Done' -ForegroundColor Green

Write-Host "Removing app pool '$poolName'..." -NoNewline
Stop-WebAppPool -Name $poolName
Remove-WebAppPool -Name $poolName
Write-Host ' Done' -ForegroundColor Green
