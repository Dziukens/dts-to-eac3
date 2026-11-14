<#
.SYNOPSIS
    End-to-end tests for Convert-DtsToEac3.ps1.

.DESCRIPTION
    Generates a short synthetic movie (video + DTS 5.1 delayed by 200 ms + FLAC 7.1 96 kHz)
    and an audio-only file without DTS, then runs the converter the way users do:
    in Windows PowerShell 5.1 and, if installed, PowerShell 7 (pwsh).

    Needs ffmpeg and MKVToolNix (run setup.cmd first). Prints PASS/FAIL per case;
    the exit code is the number of failed cases.

.EXAMPLE
    .\tests\Test-Convert.ps1
.EXAMPLE
    .\tests\Test-Convert.ps1 -KeepFiles     # keep the temporary folder for inspection
#>
param([switch]$KeepFiles)

# 'Continue': the child processes write progress to stderr, which must not stop this script.
$ErrorActionPreference = 'Continue'
$repo   = Split-Path $PSScriptRoot -Parent
$script = Join-Path $repo 'Convert-DtsToEac3.ps1'

# --- Tools ----------------------------------------------------------------------
function Find-Exe([string]$Name, [string[]]$Fallbacks) {
    $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    $Fallbacks | ForEach-Object { Get-ChildItem -Path $_ -ErrorAction SilentlyContinue } |
        Select-Object -First 1 -ExpandProperty FullName
}
$wingetBin = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\Gyan.FFmpeg*\*\bin'
$mkvDirs   = @($env:ProgramW6432, $env:ProgramFiles) | Where-Object { $_ } | ForEach-Object { Join-Path $_ 'MKVToolNix' }
$ffmpeg    = Find-Exe 'ffmpeg'   @("$wingetBin\ffmpeg.exe")
$ffprobe   = Find-Exe 'ffprobe'  @("$wingetBin\ffprobe.exe")
$mkvmerge  = Find-Exe 'mkvmerge' ($mkvDirs | ForEach-Object { "$_\mkvmerge.exe" })
if (-not ($ffmpeg -and $ffprobe -and $mkvmerge)) { Write-Host 'ffmpeg / MKVToolNix not found - run setup.cmd first.' -ForegroundColor Red; exit 1 }

$hosts = @(@{ Name = 'PS 5.1'; Exe = 'powershell.exe' })
$pwsh  = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($pwsh) { $hosts += @{ Name = 'PS 7'; Exe = $pwsh.Source } }

# --- Test data --------------------------------------------------------------------
$work = Join-Path ([IO.Path]::GetTempPath()) ("dts-to-eac3-tests-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $work | Out-Null
$raw    = Join-Path $work 'raw.mkv'
$sample = Join-Path $work 'sample ąę film.mkv'      # spaces + non-ASCII on purpose
$noDts  = Join-Path $work 'no-dts.mka'

Write-Host "Generating test files in $work ..." -ForegroundColor Cyan
& $ffmpeg -hide_banner -loglevel error -y `
    -f lavfi -i 'testsrc=size=320x180:rate=24' -f lavfi -i 'sine=440:sample_rate=48000' -f lavfi -i 'sine=330:sample_rate=96000' -t 10 `
    -filter_complex '[1]pan=5.1(side)|c0=c0|c1=c0|c2=c0|c3=0.1*c0|c4=c0|c5=c0[a51];[2]pan=7.1|c0=c0|c1=c0|c2=c0|c3=0.1*c0|c4=c0|c5=c0|c6=c0|c7=c0[a71]' `
    -map 0 -map '[a51]' -map '[a71]' -c:v mpeg4 -c:a:0 dca -strict -2 -b:a:0 1509k -c:a:1 flac `
    -metadata:s:a:0 language=pol -metadata:s:a:1 language=eng $raw
& $mkvmerge -q -o $sample --sync 1:200 $raw
& $ffmpeg -hide_banner -loglevel error -y -i $raw -map 0:2 -c copy $noDts
$sampleAscii = Join-Path $work 'sample film.mkv'
Copy-Item -LiteralPath $sample -Destination $sampleAscii -ErrorAction SilentlyContinue
if (-not ((Test-Path -LiteralPath $sampleAscii) -and (Test-Path -LiteralPath $noDts))) {
    Write-Host 'Could not generate the test files.' -ForegroundColor Red; exit 1
}

# --- Helpers ----------------------------------------------------------------------
function Invoke-Converter($HostExe, [string[]]$Arguments, [string]$StdIn) {
    $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script) + $Arguments
    $text = if ($PSBoundParameters.ContainsKey('StdIn')) { $StdIn | & $HostExe @all 2>&1 | Out-String }
            else { & $HostExe @all 2>&1 | Out-String }
    @{ Exit = $LASTEXITCODE; Text = $text }
}

function Get-AudioInfo([string]$Path) {
    (& $ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,channels,sample_rate -of json -i $Path | Out-String |
        ConvertFrom-Json).streams[0]
}

$results = New-Object System.Collections.ArrayList
function Assert-Case([string]$Name, [scriptblock]$Check, $Run) {
    $problems = @(& $Check)
    [void]$results.Add(@{ Name = $Name; Ok = ($problems.Count -eq 0) })
    if ($problems.Count -eq 0) { Write-Host "[PASS] $Name" -ForegroundColor Green }
    else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $problems | ForEach-Object { Write-Host "       - $_" -ForegroundColor Red }
        if ($Run) { Write-Host ($Run.Text.Trim() -split "`n" | Select-Object -Last 15 | ForEach-Object { "       | $_" } | Out-String) }
    }
}

# --- Cases -------------------------------------------------------------------------
foreach ($h in $hosts) {
    $hn  = $h.Name
    $dir = Join-Path $work ($hn -replace '\W', '')

    # 1. Default: first DTS track, English, delay warning, .dts + .eac3
    $out = "$dir\c1"
    $r = Invoke-Converter $h.Exe @($sample, '-Language', 'en', '-OutDir', $out)
    Assert-Case "${hn}: DTS 5.1 -> E-AC3 (en)" {
        if ($r.Exit -ne 0) { "exit code $($r.Exit)" }
        if ($r.Text -notmatch 'Done: eac3, 6 ch') { 'no "Done" line' }
        if ($r.Text -notmatch 'offset by 200 ms') { 'no delay warning' }
        if ($r.Text -match 'Estimating duration') { 'ffmpeg warning not hidden' }
        if (-not (Get-ChildItem $out -Filter '*.1.pol.dts'))  { '.dts missing' }
        if (-not (Get-ChildItem $out -Filter '*.1.pol.eac3')) { '.eac3 missing' }
    } $r

    # 2. 7.1 / 96 kHz FLAC track, Polish, no .dts
    $out = "$dir\c2"
    $r = Invoke-Converter $h.Exe @($sample, '-TrackIndex', '2', '-SkipExtract', '-Language', 'pl', '-OutDir', $out)
    $eac3 = Get-ChildItem $out -Filter '*.2.eng.eac3' -ErrorAction SilentlyContinue | Select-Object -First 1
    Assert-Case "${hn}: 7.1 96 kHz -> 5.1 48 kHz (pl)" {
        if ($r.Exit -ne 0) { "exit code $($r.Exit)" }
        if ($r.Text -notmatch 'Gotowe') { 'no Polish "Gotowe" line' }
        if ($r.Text -match 'flac ,') { 'empty profile left a stray comma' }
        if (-not $eac3) { '.eac3 missing' }
        else {
            $a = Get-AudioInfo $eac3.FullName
            if ($a.codec_name -ne 'eac3' -or [int]$a.channels -ne 6 -or [int]$a.sample_rate -ne 48000) {
                "unexpected output: $($a.codec_name) $($a.channels) ch $($a.sample_rate) Hz"
            }
        }
        if (Get-ChildItem $out -Filter '*.dts' -ErrorAction SilentlyContinue) { '.dts written despite -SkipExtract' }
    } $r

    # 3. Several files, one missing: the rest still runs, exit code = failures
    $r = Invoke-Converter $h.Exe @($sample, (Join-Path $work 'missing.mkv'), '-Language', 'en', '-OutDir', "$dir\c3")
    Assert-Case "${hn}: several files, one missing" {
        if ($r.Exit -ne 1) { "exit code $($r.Exit), expected 1" }
        if ($r.Text -notmatch 'File not found') { 'no "File not found" error' }
        if ($r.Text -notmatch '1 of 2') { 'no summary' }
        if (-not (Get-ChildItem "$dir\c3" -Filter '*.eac3' -ErrorAction SilentlyContinue)) { 'the valid file was not converted' }
    } $r

    # 4. File without DTS: clear error
    $r = Invoke-Converter $h.Exe @($noDts, '-Language', 'en', '-OutDir', "$dir\c4")
    Assert-Case "${hn}: no DTS track" {
        if ($r.Exit -ne 1) { "exit code $($r.Exit), expected 1" }
        if ($r.Text -notmatch 'No DTS track found') { 'no "No DTS track found" error' }
    } $r

    # 5. Prompt mode: two quoted paths dropped into the console.
    #    ASCII-only name: text piped to a child process loses non-ASCII characters in PS 5.1
    #    (not an issue when a user drops files into a real console window).
    $r = Invoke-Converter $h.Exe @('-ListTracks', '-Language', 'en') -StdIn "`"$sampleAscii`" `"$noDts`""
    Assert-Case "${hn}: prompt with two dropped files" {
        if ($r.Exit -ne 0) { "exit code $($r.Exit)" }
        if (([regex]::Matches($r.Text, 'Audio tracks in')).Count -ne 2) { 'expected 2 track lists' }
        if ($r.Text -match 'ERROR') { 'error printed' }
    } $r

    # 6. Whole output redirected to a file (stderr of ffmpeg must not count as a failure)
    $log = "$dir\c6.log"
    $cmd = "& '$script' '$($sample -replace "'", "''")' -Language en -OutDir '$dir\c6' *> '$log'; exit `$LASTEXITCODE"
    & $h.Exe -NoProfile -ExecutionPolicy Bypass -Command $cmd
    $exit = $LASTEXITCODE
    $logText = if (Test-Path $log) { Get-Content $log -Raw } else { '' }
    Assert-Case "${hn}: output redirected to a log file" {
        if ($exit -ne 0) { "exit code $exit" }
        if ($logText -notmatch 'Done: eac3') { 'no "Done" line in the log' }
        if ($logText -notmatch 'Index\s+Codec') { 'track table missing from the log' }
    } @{ Text = $logText }
}

# --- Summary -------------------------------------------------------------------------
$failed = @($results | Where-Object { -not $_.Ok }).Count
Write-Host ''
if ($failed) { Write-Host "$failed of $($results.Count) test(s) failed." -ForegroundColor Red }
else         { Write-Host "All $($results.Count) tests passed." -ForegroundColor Green }

if ($KeepFiles) { Write-Host "Test files kept in: $work" }
else { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
exit $failed
