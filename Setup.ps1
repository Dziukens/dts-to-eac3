<#
.SYNOPSIS
    Installs the tools needed by Convert-DtsToEac3.ps1: ffmpeg and MKVToolNix (via winget).
    Instaluje narzędzia potrzebne do Convert-DtsToEac3.ps1: ffmpeg i MKVToolNix (przez winget).
    Safe to run repeatedly - skips whatever is already installed.
#>
param(
    # Console language: auto (DTS_TO_EAC3_LANG / Windows language), en, pl.
    [ValidateSet('auto', 'en', 'pl')][string]$Language = 'auto'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Messages.ps1')
Set-Language (Resolve-Language $Language)

$packages = @(
    @{
        Id    = 'Gyan.FFmpeg'
        Check = { [bool](Get-Command ffmpeg -CommandType Application -ErrorAction SilentlyContinue) -or
                  (Test-Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg*\*\bin\ffmpeg.exe") }
    }
    @{
        Id    = 'MKVToolNix.MKVToolNix'
        Check = { [bool](Get-Command mkvextract -CommandType Application -ErrorAction SilentlyContinue) -or
                  (Test-Path "$env:ProgramFiles\MKVToolNix\mkvextract.exe") }
    }
)

$toInstall = @($packages | Where-Object { -not (& $_.Check) })
foreach ($p in $packages) {
    if ($toInstall -notcontains $p) { Write-Host (T 'AlreadyInstalled' $p.Id) -ForegroundColor Green }
}
if (-not $toInstall) { return }

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host (T 'NoWinget') -ForegroundColor Red
    throw (T 'NoWingetShort')
}

foreach ($p in $toInstall) {
    Write-Host (T 'Installing' $p.Id) -ForegroundColor Cyan
    winget install --id $p.Id -e --source winget --accept-source-agreements --accept-package-agreements
    if (-not (& $p.Check)) { throw (T 'InstallFailed' $p.Id $LASTEXITCODE) }
}
Write-Host ("`n" + (T 'SetupDone')) -ForegroundColor Green
