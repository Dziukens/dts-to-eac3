@echo off
rem Konwersja DTS / DTS-HD MA -> E-AC3.
rem Uzycie: przeciagnij jeden lub kilka plikow z filmami na ten plik
rem         albo uruchom go dwuklikiem i wklej sciezke do filmu.
setlocal EnableExtensions
set "SCRIPT=%~dp0Convert-DtsToEac3.ps1"
set "FAILED=0"

if not "%~1"=="" goto loop

echo Przeciagnij plik z filmem do tego okna (albo wklej sciezke) i nacisnij Enter.
set "FILE="
set /p "FILE=Plik: "
if not defined FILE goto end
set "FILE=%FILE:"=%"
call :convert "%FILE%"
goto end

:loop
if "%~1"=="" goto end
call :convert "%~1"
shift
goto loop

:convert
echo.
echo ==== %~nx1 ====
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -InputFile "%~1"
if errorlevel 1 (
    set /a FAILED+=1
    echo BLAD: konwersja pliku "%~nx1" nie powiodla sie.
)
exit /b 0

:end
echo.
if %FAILED% GTR 0 (echo Zakonczono z bledami: %FAILED%) else (echo Zakonczono.)
pause
