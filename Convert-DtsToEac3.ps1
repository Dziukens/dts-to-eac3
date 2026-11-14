<#
.SYNOPSIS
    Wyciąga ścieżkę DTS / DTS-HD MA z pliku wideo i konwertuje ją do E-AC3 (Dolby Digital Plus).

.DESCRIPTION
    Krok 1: wypisuje ścieżki audio w pliku (ffprobe).
    Krok 2: wyciąga wybraną ścieżkę bez zmian (mkvextract dla MKV, ffmpeg dla innych kontenerów) -> .dts
    Krok 3: dekoduje DTS-HD MA (bezstratnie) i koduje do E-AC3 -> .eac3
    Remux robisz potem samodzielnie (przykład w README.md).

    Działa w Windows PowerShell 5.1 i PowerShell 7+. Brakujące narzędzia (ffmpeg, MKVToolNix)
    instaluje automatycznie przez winget (Setup.ps1).

.EXAMPLE
    .\Convert-DtsToEac3.ps1 -InputFile "D:\Filmy\film.mkv" -ListTracks
.EXAMPLE
    .\Convert-DtsToEac3.ps1 -InputFile "D:\Filmy\film.mkv"
.EXAMPLE
    .\Convert-DtsToEac3.ps1 -InputFile "D:\Filmy\film.mkv" -TrackIndex 2 -Bitrate 1536k -OutDir "D:\Filmy\out"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputFile,
    # Indeks strumienia (z -ListTracks). Domyślnie: pierwsza ścieżka DTS w pliku.
    [int]$TrackIndex = -1,
    # Bitrate E-AC3. 640k = jakość streamingowa, 1024k = bardzo dobra, 1536k = jak DD+ na Blu-ray.
    [ValidatePattern('^\d+k$')][string]$Bitrate = '1024k',
    [string]$OutDir,
    [switch]$ListTracks,
    # Pomija wyciąganie .dts i koduje E-AC3 bezpośrednio z pliku źródłowego.
    [switch]$SkipExtract
)

$ErrorActionPreference = 'Stop'

function Find-Tool([string]$Name, [string[]]$Fallbacks) {
    $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    foreach ($p in $Fallbacks) {
        $hit = Get-ChildItem -Path $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Get-Tools {
    $wingetPkgs = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\Gyan.FFmpeg*\*\bin'
    $mkvDir     = Join-Path $env:ProgramFiles 'MKVToolNix'
    @{
        ffmpeg     = Find-Tool 'ffmpeg'     @("$wingetPkgs\ffmpeg.exe")
        ffprobe    = Find-Tool 'ffprobe'    @("$wingetPkgs\ffprobe.exe")
        mkvextract = Find-Tool 'mkvextract' @("$mkvDir\mkvextract.exe")
    }
}

$tools = Get-Tools
if ($tools.Values -contains $null) {
    Write-Host 'Brakuje ffmpeg lub MKVToolNix - uruchamiam instalację (Setup.ps1)...' -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot 'Setup.ps1')
    $tools = Get-Tools
    $missing = @($tools.Keys | Where-Object { -not $tools[$_] })
    if ($missing) { throw "Nadal brakuje: $($missing -join ', '). Zainstaluj je ręcznie (patrz README.md)." }
}
$ffmpeg, $ffprobe, $mkvextract = $tools.ffmpeg, $tools.ffprobe, $tools.mkvextract

function Get-Probe([string]$Path) {
    $json = & $ffprobe -v error -show_streams -show_format -of json -i $Path
    if ($LASTEXITCODE -ne 0) { throw "ffprobe nie może odczytać pliku: $Path" }
    ($json -join "`n") | ConvertFrom-Json
}

if (-not (Test-Path -LiteralPath $InputFile -PathType Leaf)) { throw "Plik nie istnieje: $InputFile" }
$InputFile = (Resolve-Path -LiteralPath $InputFile).Path
$baseName  = [IO.Path]::GetFileNameWithoutExtension($InputFile)
if (-not $OutDir) { $OutDir = Join-Path (Split-Path $InputFile) 'eac3_out' }

# --- Krok 1: analiza ścieżek -------------------------------------------------
$probe = Get-Probe $InputFile
$audio = @($probe.streams | Where-Object { $_.codec_type -eq 'audio' })
if (-not $audio) { throw 'Plik nie zawiera żadnych ścieżek audio.' }

Write-Host "`nŚcieżki audio w: $InputFile" -ForegroundColor Cyan
$audio | ForEach-Object {
    [pscustomobject]@{
        Index   = $_.index
        Kodek   = $_.codec_name
        Profil  = $_.profile
        Kanaly  = $_.channels
        Uklad   = $_.channel_layout
        Hz      = $_.sample_rate
        Jezyk   = $_.tags.language
        Tytul   = $_.tags.title
        Start_s = $_.start_time
    }
} | Format-Table -AutoSize | Out-Host

if ($ListTracks) { return }

if ($TrackIndex -ge 0) {
    $track = $audio | Where-Object { $_.index -eq $TrackIndex } | Select-Object -First 1
    if (-not $track) { throw "Strumień $TrackIndex nie istnieje lub nie jest ścieżką audio." }
} else {
    $track = $audio | Where-Object { $_.codec_name -eq 'dts' } | Select-Object -First 1
    if (-not $track) { throw 'Brak ścieżki DTS. Wskaż ścieżkę ręcznie przez -TrackIndex.' }
}
$idx  = [int]$track.index
$lang = if ($track.tags.language) { $track.tags.language } else { 'und' }
Write-Host ("Wybrano strumień {0}: {1} {2}, {3} kan. ({4}), {5} Hz, język: {6}" -f `
    $idx, $track.codec_name, $track.profile, $track.channels, $track.channel_layout, $track.sample_rate, $lang) -ForegroundColor Green

# Opóźnienie ścieżki względem obrazu - surowy plik .dts/.eac3 go nie przechowuje.
$video = $probe.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1
if ($video -and $track.start_time -and $video.start_time) {
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $delayMs = [math]::Round(([double]::Parse($track.start_time, $inv) - [double]::Parse($video.start_time, $inv)) * 1000)
    if ($delayMs -ne 0) {
        Write-Warning "Ścieżka ma przesunięcie $delayMs ms względem obrazu. Przy remuxie użyj: mkvmerge --sync 0:$delayMs"
    }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# --- Krok 2: wyciągnięcie ścieżki bez zmian ----------------------------------
$source = $InputFile
$mapArg = "0:$idx"
if (-not $SkipExtract -and $track.codec_name -eq 'dts') {
    $dtsFile = Join-Path $OutDir "$baseName.$idx.$lang.dts"
    Write-Host "`n[1/2] Wyciąganie ścieżki -> $dtsFile" -ForegroundColor Cyan
    if (@('.mkv', '.mka', '.webm') -contains [IO.Path]::GetExtension($InputFile).ToLower()) {
        # W MKV numer ścieżki mkvmerge/mkvextract = indeks strumienia ffprobe.
        & $mkvextract $InputFile tracks "${idx}:$dtsFile"
    } else {
        & $ffmpeg -hide_banner -loglevel warning -stats -y -i $InputFile -map $mapArg -c:a copy -f dts $dtsFile
    }
    if ($LASTEXITCODE -ne 0) { throw "Wyciąganie ścieżki nie powiodło się (kod $LASTEXITCODE)." }
    $source = $dtsFile
    $mapArg = '0:a:0'
} elseif (-not $SkipExtract) {
    Write-Host "`n[1/2] Ścieżka nie jest DTS - koduję bezpośrednio ze źródła." -ForegroundColor Yellow
}

# --- Krok 3: konwersja do E-AC3 ----------------------------------------------
# Enkoder E-AC3 w ffmpeg obsługuje max 5.1 i 32/44.1/48 kHz.
$filters = @()
$channels = [int]$track.channels
if ($channels -gt 6) {
    if ($track.channel_layout -like '7.1*') {
        # 7.1 -> 5.1: tylne kanały wmieszane w boczne (-3 dB), przód bez zmian.
        $filters += 'pan=5.1(side)|FL=FL|FR=FR|FC=FC|LFE=LFE|SL=0.707*SL+0.707*BL|SR=0.707*SR+0.707*BR'
    } else {
        $filters += 'aresample=ochl=5.1(side)'
    }
    Write-Warning "Źródło ma $channels kanałów ($($track.channel_layout)) - E-AC3 w ffmpeg obsługuje maks. 5.1, robię downmix do 5.1."
}
# Resampler soxr (lepsza jakość) tylko jeśli dana kompilacja ffmpeg go ma.
$hasSoxr = (& $ffmpeg -hide_banner -buildconf | Out-String) -match 'enable-libsoxr'
$filters += if ($hasSoxr) { 'aresample=48000:resampler=soxr:precision=28' } else { 'aresample=48000' }

$eac3File = Join-Path $OutDir "$baseName.$idx.$lang.eac3"
Write-Host "`n[2/2] Konwersja do E-AC3 ($Bitrate) -> $eac3File" -ForegroundColor Cyan
& $ffmpeg -hide_banner -loglevel warning -stats -y -i $source -map $mapArg -vn -sn -dn `
    -af ($filters -join ',') -c:a eac3 -b:a $Bitrate -f eac3 $eac3File
if ($LASTEXITCODE -ne 0) { throw "Konwersja nie powiodła się (kod $LASTEXITCODE)." }

# --- Weryfikacja --------------------------------------------------------------
$inv = [Globalization.CultureInfo]::InvariantCulture
$out = Get-Probe $eac3File
$s = $out.streams[0]
$srcDurStr = if ($track.duration) { $track.duration } else { $probe.format.duration }
$srcDur = if ($srcDurStr) { [double]::Parse($srcDurStr, $inv) } else { 0 }
$outDur = [double]::Parse($out.format.duration, $inv)
Write-Host ("`nGotowe: {0}, {1} kan. ({2}), {3} Hz, {4:N0} kb/s, czas {5:N1} s (źródło {6:N1} s)" -f `
    $s.codec_name, $s.channels, $s.channel_layout, $s.sample_rate, ([double]$out.format.bit_rate / 1000), $outDur, $srcDur) -ForegroundColor Green
if ($srcDur -gt 0 -and [math]::Abs($srcDur - $outDur) -gt 1) {
    Write-Warning 'Czas trwania wyniku różni się od źródła o ponad 1 s - sprawdź plik przed remuxem.'
}
Write-Host "Plik E-AC3: $eac3File"
