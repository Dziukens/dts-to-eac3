<#
.SYNOPSIS
    Installs the tools needed by Convert-DtsToEac3.ps1: ffmpeg and MKVToolNix (via winget).
    Instaluje narzędzia potrzebne do Convert-DtsToEac3.ps1: ffmpeg i MKVToolNix (przez winget).
    Safe to run repeatedly - skips whatever is already installed. Exit code 1 on failure.
#>
param(
    # Console language: auto (DTS_TO_EAC3_LANG / Windows language), en, pl.
    [ValidateSet('auto', 'en', 'pl')][string]$Language = 'auto'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Messages.ps1')
Set-Language (Resolve-Language $Language)

# ProgramW6432 = the 64-bit Program Files, also when running in 32-bit PowerShell.
$mkvPaths = @($env:ProgramW6432, $env:ProgramFiles) | Where-Object { $_ } |
    ForEach-Object { Join-Path $_ 'MKVToolNix\mkvextract.exe' }

$packages = @(
    @{
        Id    = 'Gyan.FFmpeg'
        Check = { [bool](Get-Command ffmpeg -CommandType Application -ErrorAction SilentlyContinue) -or
                  (Test-Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg*\*\bin\ffmpeg.exe") }
    }
    @{
        Id    = 'MKVToolNix.MKVToolNix'
        Check = { [bool](Get-Command mkvextract -CommandType Application -ErrorAction SilentlyContinue) -or
                  [bool]($mkvPaths | Where-Object { Test-Path $_ }) }
    }
)

try {
    $toInstall = @($packages | Where-Object { -not (& $_.Check) })
    foreach ($p in $packages) {
        if ($toInstall -notcontains $p) { Write-Host (T 'AlreadyInstalled' $p.Id) -ForegroundColor Green }
    }
    if (-not $toInstall) { exit 0 }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host (T 'NoWinget') -ForegroundColor Red
        throw (T 'NoWingetShort')
    }

    foreach ($p in $toInstall) {
        Write-Host (T 'Installing' $p.Id) -ForegroundColor Cyan
        # 'Continue': winget output on stderr must not stop the script in Windows PowerShell 5.1.
        & { $ErrorActionPreference = 'Continue'
            winget install --id $p.Id -e --source winget --accept-source-agreements --accept-package-agreements }
        if (-not (& $p.Check)) { throw (T 'InstallFailed' $p.Id $LASTEXITCODE) }
    }
    Write-Host ("`n" + (T 'SetupDone')) -ForegroundColor Green
    exit 0
} catch {
    Write-Host ((T 'ErrorPrefix') + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
