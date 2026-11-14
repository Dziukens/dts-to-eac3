<#
.SYNOPSIS
    Extracts a DTS / DTS-HD MA track from a video file and converts it to E-AC3 (Dolby Digital Plus).
    Wyciąga ścieżkę DTS / DTS-HD MA z pliku wideo i konwertuje ją do E-AC3 (Dolby Digital Plus).

.DESCRIPTION
    Step 1: lists the audio tracks (ffprobe).
    Step 2: extracts the selected track unchanged (mkvextract for MKV, ffmpeg otherwise) -> .dts
    Step 3: decodes DTS-HD MA (lossless) and encodes it to E-AC3 -> .eac3
    Remuxing is done separately (see README.md).

    Works in Windows PowerShell 5.1 and PowerShell 7+. Missing tools (ffmpeg, MKVToolNix)
    are installed automatically via winget (Setup.ps1).

    Console language: -Language en|pl, otherwise the DTS_TO_EAC3_LANG environment variable,
    otherwise the Windows display language (see Messages.ps1).

.EXAMPLE
    .\Convert-DtsToEac3.ps1 "D:\Movies\movie.mkv" -ListTracks
.EXAMPLE
    .\Convert-DtsToEac3.ps1 "D:\Movies\a.mkv" "D:\Movies\b.mkv" -Language en
.EXAMPLE
    .\Convert-DtsToEac3.ps1 -InputFile "D:\Movies\movie.mkv" -TrackIndex 2 -Bitrate 1536k -OutDir "D:\Movies\out"
#>
[CmdletBinding()]
param(
    # One or more movie files. Without it, the script asks for a path.
    [Parameter(Position = 0, ValueFromRemainingArguments)][string[]]$InputFile,
    # Stream index (from -ListTracks). Default: the first DTS track in the file.
    [int]$TrackIndex = -1,
    # E-AC3 bitrate. 640k = streaming quality, 1024k = very good, 1536k = like DD+ on Blu-ray.
    [ValidatePattern('^\d+k$')][string]$Bitrate = '1024k',
    [string]$OutDir,
    [switch]$ListTracks,
    # Skips saving the .dts and encodes E-AC3 straight from the source file.
    [switch]$SkipExtract,
    # Console language: auto (DTS_TO_EAC3_LANG / Windows language), en, pl.
    [ValidateSet('auto', 'en', 'pl')][string]$Language = 'auto'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Messages.ps1')
Set-Language (Resolve-Language $Language)

$inv = [Globalization.CultureInfo]::InvariantCulture

# --- Tools --------------------------------------------------------------------
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

function Get-Probe([string]$Path) {
    $json = & $ffprobe -v error -show_streams -show_format -of json -i $Path
    if ($LASTEXITCODE -ne 0) { throw (T 'ProbeFailed' $Path) }
    ($json -join "`n") | ConvertFrom-Json
}

# --- Converting one file ------------------------------------------------------
function Convert-One([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw (T 'FileNotFound' $Path) }
    $Path     = (Resolve-Path -LiteralPath $Path).Path
    $baseName = [IO.Path]::GetFileNameWithoutExtension($Path)
    $outDir   = if ($OutDir) { $OutDir } else { Join-Path (Split-Path $Path) 'eac3_out' }

    # Step 1: track analysis
    $probe = Get-Probe $Path
    $audio = @($probe.streams | Where-Object { $_.codec_type -eq 'audio' })
    if (-not $audio) { throw (T 'NoAudio') }

    Write-Host ("`n" + (T 'AudioTracksIn' $Path)) -ForegroundColor Cyan
    $audio | ForEach-Object {
        $row = [ordered]@{}
        $row['Index']             = $_.index
        $row[(T 'ColCodec')]      = $_.codec_name
        $row[(T 'ColProfile')]    = $_.profile
        $row[(T 'ColChannels')]   = $_.channels
        $row[(T 'ColLayout')]     = $_.channel_layout
        $row['Hz']                = $_.sample_rate
        $row[(T 'ColLanguage')]   = $_.tags.language
        $row[(T 'ColTitle')]      = $_.tags.title
        $row['Start_s']           = $_.start_time
        [pscustomobject]$row
    } | Format-Table -AutoSize | Out-Host

    if ($ListTracks) { return }

    if ($TrackIndex -ge 0) {
        $track = $audio | Where-Object { $_.index -eq $TrackIndex } | Select-Object -First 1
        if (-not $track) { throw (T 'TrackNotFound' $TrackIndex) }
    } else {
        $track = $audio | Where-Object { $_.codec_name -eq 'dts' } | Select-Object -First 1
        if (-not $track) { throw (T 'NoDts') }
    }
    $idx  = [int]$track.index
    $lang = if ($track.tags.language) { $track.tags.language } else { 'und' }
    Write-Host (T 'Selected' $idx $track.codec_name $track.profile $track.channels $track.channel_layout $track.sample_rate $lang) -ForegroundColor Green

    # Track delay relative to the video - raw .dts/.eac3 files don't store it.
    $video = $probe.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1
    if ($video -and $track.start_time -and $video.start_time) {
        $delayMs = [math]::Round(([double]::Parse($track.start_time, $inv) - [double]::Parse($video.start_time, $inv)) * 1000)
        if ($delayMs -ne 0) { Write-Warn (T 'Delay' $delayMs) }
    }

    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    # Step 2: extract the track unchanged
    $source = $Path
    $mapArg = "0:$idx"
    if (-not $SkipExtract -and $track.codec_name -eq 'dts') {
        $dtsFile = Join-Path $outDir "$baseName.$idx.$lang.dts"
        Write-Host ("`n" + (T 'Extracting' $dtsFile)) -ForegroundColor Cyan
        if (@('.mkv', '.mka', '.webm') -contains [IO.Path]::GetExtension($Path).ToLower()) {
            # In MKV, the mkvmerge/mkvextract track ID equals the ffprobe stream index.
            & $mkvextract --ui-language $script:Lang $Path tracks "${idx}:$dtsFile"
        } else {
            & $ffmpeg -hide_banner -loglevel warning -stats -y -i $Path -map $mapArg -c:a copy -f dts $dtsFile
        }
        if ($LASTEXITCODE -ne 0) { throw (T 'ExtractFailed' $LASTEXITCODE) }
        $source = $dtsFile
        $mapArg = '0:a:0'
    } elseif (-not $SkipExtract) {
        Write-Host ("`n" + (T 'NotDts')) -ForegroundColor Yellow
    }

    # Step 3: convert to E-AC3 (the ffmpeg encoder supports up to 5.1 and 32/44.1/48 kHz)
    $filters = @()
    $channels = [int]$track.channels
    if ($channels -gt 6) {
        if ($track.channel_layout -like '7.1*') {
            # 7.1 -> 5.1: back channels mixed into the sides (-3 dB), front unchanged.
            $filters += 'pan=5.1(side)|FL=FL|FR=FR|FC=FC|LFE=LFE|SL=0.707*SL+0.707*BL|SR=0.707*SR+0.707*BR'
        } else {
            $filters += 'aresample=ochl=5.1(side)'
        }
        Write-Warn (T 'Downmix' $channels $track.channel_layout)
    }
    $filters += if ($hasSoxr) { 'aresample=48000:resampler=soxr:precision=28' } else { 'aresample=48000' }

    $eac3File = Join-Path $outDir "$baseName.$idx.$lang.eac3"
    Write-Host ("`n" + (T 'Converting' $Bitrate $eac3File)) -ForegroundColor Cyan
    & $ffmpeg -hide_banner -loglevel warning -stats -y -i $source -map $mapArg -vn -sn -dn `
        -af ($filters -join ',') -c:a eac3 -b:a $Bitrate -f eac3 $eac3File
    if ($LASTEXITCODE -ne 0) { throw (T 'ConvertFailed' $LASTEXITCODE) }

    # Verification
    $out = Get-Probe $eac3File
    $s = $out.streams[0]
    $srcDurStr = if ($track.duration) { $track.duration } else { $probe.format.duration }
    $srcDur = if ($srcDurStr) { [double]::Parse($srcDurStr, $inv) } else { 0 }
    $outDur = [double]::Parse($out.format.duration, $inv)
    Write-Host ("`n" + (T 'Done' $s.codec_name $s.channels $s.channel_layout $s.sample_rate ([double]$out.format.bit_rate / 1000) $outDur $srcDur)) -ForegroundColor Green
    if ($srcDur -gt 0 -and [math]::Abs($srcDur - $outDur) -gt 1) { Write-Warn (T 'DurationMismatch') }
    Write-Host (T 'OutputFile' $eac3File)
}

# --- Main -----------------------------------------------------------------------
$tools = Get-Tools
if ($tools.Values -contains $null) {
    Write-Host (T 'MissingTools') -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot 'Setup.ps1') -Language $script:Lang
    $tools = Get-Tools
    $missing = @($tools.Keys | Where-Object { -not $tools[$_] })
    if ($missing) { throw (T 'StillMissing' ($missing -join ', ')) }
}
$ffmpeg, $ffprobe, $mkvextract = $tools.ffmpeg, $tools.ffprobe, $tools.mkvextract
# Use the higher-quality soxr resampler only if this ffmpeg build has it.
$hasSoxr = (& $ffmpeg -hide_banner -buildconf | Out-String) -match 'enable-libsoxr'

$files = @($InputFile | Where-Object { $_ })
if (-not $files) {
    Write-Host (T 'Prompt')
    $answer = "$(Read-Host (T 'PromptLabel'))".Trim().Trim('"')
    if (-not $answer) { exit 0 }
    $files = @($answer)
}

$failed = 0
foreach ($file in $files) {
    if ($files.Count -gt 1) { Write-Host "`n==== $(Split-Path $file -Leaf) ====" -ForegroundColor Magenta }
    try {
        Convert-One $file
    } catch {
        $failed++
        Write-Host ((T 'ErrorPrefix') + $_.Exception.Message) -ForegroundColor Red
    }
}

if (-not $ListTracks -and ($files.Count -gt 1 -or $failed)) {
    Write-Host ''
    if ($failed) { Write-Host (T 'SummaryFailed' $failed $files.Count) -ForegroundColor Red }
    else         { Write-Host (T 'SummaryOk' $files.Count) -ForegroundColor Green }
}
exit $failed
