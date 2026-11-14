@echo off
rem Installs ffmpeg and MKVToolNix via winget (skips what is already installed).
rem Options are passed through, e.g.:  setup.cmd -Language en
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup.ps1" %*
echo.
pause
