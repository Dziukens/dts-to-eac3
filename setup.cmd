@echo off
rem Instaluje ffmpeg i MKVToolNix przez winget (pomija juz zainstalowane).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup.ps1"
echo.
pause
