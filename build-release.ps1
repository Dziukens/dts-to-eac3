<#
.SYNOPSIS
    Builds the GitHub Release package: dist\dts-to-eac3-v<version>.zip + dist\release-notes-v<version>.md

.DESCRIPTION
    The ZIP is built from the last commit (git archive), so it contains exactly what is in the repository.
    Developer files are left out (export-ignore in .gitattributes). Scripts have CRLF line endings.
    The release notes are the "## v<version>" section of CHANGELOG.md, ready to paste on GitHub.

    Stops if tracked files have uncommitted changes, so the ZIP always matches a commit.
    -Force builds anyway (the changes are still left out of the ZIP).

.EXAMPLE
    .\build-release.ps1 -Version 1.0.0
#>
param(
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$tag  = "v$Version"
$name = "dts-to-eac3-$tag"
$dist = Join-Path $PSScriptRoot 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null

$dirty = git status --porcelain --untracked-files=no
if ($dirty) {
    $msg = "Uncommitted changes - they would not be in the ZIP (built from HEAD):`n$($dirty -join "`n")"
    if (-not $Force) { throw "$msg`nCommit them first, or use -Force." }
    Write-Warning $msg
}

# --- ZIP ----------------------------------------------------------------------
$zip = Join-Path $dist "$name.zip"
git archive --format=zip --worktree-attributes --prefix="$name/" -o $zip HEAD
if ($LASTEXITCODE -ne 0) { throw 'git archive failed.' }

# --- Release notes from CHANGELOG.md -------------------------------------------
$changelog = Get-Content (Join-Path $PSScriptRoot 'CHANGELOG.md') -Encoding UTF8
$start = [array]::IndexOf($changelog, "## $tag")
if ($start -lt 0) { throw "No '## $tag' section in CHANGELOG.md." }
$end = $start + 1
while ($end -lt $changelog.Count -and $changelog[$end] -notmatch '^## ') { $end++ }
$notes = ($changelog[($start + 1)..($end - 1)] -join "`n").Trim()
$notesFile = Join-Path $dist "release-notes-$tag.md"
[IO.File]::WriteAllText($notesFile, $notes + "`n", (New-Object Text.UTF8Encoding $false))

# --- Summary ------------------------------------------------------------------
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try { $files = $archive.Entries | Where-Object { $_.Name } | ForEach-Object FullName } finally { $archive.Dispose() }

Write-Host "`nZIP:    $zip ($([math]::Round((Get-Item $zip).Length / 1KB, 1)) KB)" -ForegroundColor Green
$files | ForEach-Object { Write-Host "        $_" }
Write-Host "Notes:  $notesFile" -ForegroundColor Green
Write-Host "Commit: $(git rev-parse --short HEAD)"
Write-Host @"

To publish:
  git tag $tag && git push origin $tag
  GitHub -> Releases -> Draft a new release -> tag $tag
  title: $tag, description: contents of $notesFile, attachment: $zip
"@
