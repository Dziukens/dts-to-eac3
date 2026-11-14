<#
.SYNOPSIS
    Buduje paczkę do GitHub Release: dist\dts-to-eac3-v<wersja>.zip + dist\release-notes-v<wersja>.md

.DESCRIPTION
    ZIP powstaje z ostatniego commita (git archive), więc zawiera dokładnie to, co jest w repozytorium.
    Pliki deweloperskie są pomijane (export-ignore w .gitattributes). Skrypty mają końce linii CRLF.
    Opis wydania to sekcja "## v<wersja>" z CHANGELOG.md, gotowa do wklejenia na GitHubie.

.EXAMPLE
    .\build-release.ps1 -Version 1.0.0
#>
param(
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$tag  = "v$Version"
$name = "dts-to-eac3-$tag"
$dist = Join-Path $PSScriptRoot 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null

$dirty = git status --porcelain --untracked-files=no
if ($dirty) { Write-Warning "Masz niezacommitowane zmiany - nie trafią do ZIP-a (budowany z HEAD):`n$($dirty -join "`n")" }

# --- ZIP ----------------------------------------------------------------------
$zip = Join-Path $dist "$name.zip"
git archive --format=zip --worktree-attributes --prefix="$name/" -o $zip HEAD
if ($LASTEXITCODE -ne 0) { throw 'git archive nie powiódł się.' }

# --- Opis wydania z CHANGELOG.md ----------------------------------------------
$changelog = Get-Content (Join-Path $PSScriptRoot 'CHANGELOG.md') -Encoding UTF8
$start = [array]::IndexOf($changelog, "## $tag")
if ($start -lt 0) { throw "Brak sekcji '## $tag' w CHANGELOG.md." }
$end = $start + 1
while ($end -lt $changelog.Count -and $changelog[$end] -notmatch '^## ') { $end++ }
$notes = ($changelog[($start + 1)..($end - 1)] -join "`n").Trim()
$notesFile = Join-Path $dist "release-notes-$tag.md"
[IO.File]::WriteAllText($notesFile, $notes + "`n", (New-Object Text.UTF8Encoding $false))

# --- Podsumowanie -------------------------------------------------------------
Add-Type -AssemblyName System.IO.Compression.FileSystem
$entries = [IO.Compression.ZipFile]::OpenRead($zip)
try { $files = $entries.Entries | Where-Object { $_.Name } | ForEach-Object FullName } finally { $entries.Dispose() }

Write-Host "`nZIP:  $zip ($([math]::Round((Get-Item $zip).Length / 1KB, 1)) KB)" -ForegroundColor Green
$files | ForEach-Object { Write-Host "      $_" }
Write-Host "Opis: $notesFile" -ForegroundColor Green
Write-Host "Commit: $(git rev-parse --short HEAD)"
Write-Host @"

Publikacja:
  git tag $tag && git push origin $tag
  GitHub -> Releases -> Draft a new release -> tag $tag
  tytuł: $tag, opis: zawartość $notesFile, załącznik: $zip
"@
