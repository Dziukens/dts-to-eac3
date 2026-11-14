<#
.SYNOPSIS
    Instaluje narzędzia potrzebne do Convert-DtsToEac3.ps1: ffmpeg i MKVToolNix (przez winget).
    Bezpieczne do wielokrotnego uruchamiania - pomija to, co już jest zainstalowane.
#>
$ErrorActionPreference = 'Stop'

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
    if ($toInstall -notcontains $p) { Write-Host "$($p.Id): już zainstalowany" -ForegroundColor Green }
}
if (-not $toInstall) { return }

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host @'
Nie znaleziono winget. Zainstaluj "Instalator aplikacji" (App Installer) ze sklepu Microsoft Store
i uruchom setup ponownie, albo zainstaluj narzędzia ręcznie:
  ffmpeg:     https://www.gyan.dev/ffmpeg/builds/   (dodaj folder bin do PATH)
  MKVToolNix: https://mkvtoolnix.download/downloads.html#windows
'@ -ForegroundColor Red
    throw 'Brak winget.'
}

foreach ($p in $toInstall) {
    Write-Host "Instaluję $($p.Id)..." -ForegroundColor Cyan
    winget install --id $p.Id -e --source winget --accept-source-agreements --accept-package-agreements
    if (-not (& $p.Check)) { throw "Instalacja $($p.Id) nie powiodła się (kod winget: $LASTEXITCODE)." }
}
Write-Host "`nGotowe. Narzędzia są zainstalowane." -ForegroundColor Green
