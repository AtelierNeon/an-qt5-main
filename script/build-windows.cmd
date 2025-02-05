@echo off

rem Start delaying variable expansion
setlocal ENABLEDELAYEDEXPANSION

rem Set project root
set PROJECT_ROOT=%~dp0\..

rem Detect PowerShell
echo [Windows] Detecting PowerShell Core ...
set POWERSHELL=pwsh
%POWERSHELL% /? 1>nul 2>&1
if "%ERRORLEVEL%" neq "0" (
    echo [Windows] Detecting PowerShell Core ... NOT FOUND
    echo [Windows] Detecting Windows PowerShell ...
    set POWERSHELL=powershell
    !POWERSHELL! /? 1>nul 2>&1
    if "!ERRORLEVEL!" neq "0" (
        echo [Windows] Detecting Windows PowerShell ... NOT FOUND
        echo [Windows] Aborted ...
        exit /b 9009
    ) else (
        echo [Windows] Detecting Windows PowerShell ... FOUND
    )
) else (
    echo [Windows] Detecting PowerShell Core ... FOUND
)

rem Detect PowerShell script file
echo [Windows] Detecting PowerShell script file ...
set POWERSHELL_SCRIPT=build-windows.ps1
if not exist %PROJECT_ROOT%\script\%POWERSHELL_SCRIPT% (
    echo [Windows] Detecting PowerShell script file ... NOT FOUND
    echo [Windows] Aborted ...
    exit /b 2
) else (
    echo [Windows] Detecting PowerShell script file ... FOUND
)

rem !POWERSHELL! -ExecutionPolicy Unrestricted -File %PROJECT_ROOT%\script\%POWERSHELL_SCRIPT% -Config Release
!POWERSHELL! -ExecutionPolicy Unrestricted -File %PROJECT_ROOT%\script\%POWERSHELL_SCRIPT%
if "!ERRORLEVEL!" neq "0" (
    echo [Windows] Something wrong in running %POWERSHELL_SCRIPT%.
    echo [Windows] Aborting ...
    exit /b 3
) else (
    echo [Windows] Done ...
)

rem End delaying variable expansion
endlocal
