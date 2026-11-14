@echo off
rem DTS / DTS-HD MA -> E-AC3.
rem Drag one or more movie files onto this file, or double-click it and paste a path.
rem Extra options are passed through, e.g.:  convert.cmd movie.mkv -Language en -Bitrate 1536k
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Convert-DtsToEac3.ps1" %*
echo.
pause
