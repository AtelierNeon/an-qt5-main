@echo off

setlocal
echo [Windows] Running quick (re)build ...
set MY_PROJECT_SHOULD_DISABLE_CLEAN_BUILD=ON
call %~dp0\build-windows-preset.cmd
if "%ERRORLEVEL%" neq "0" (
    exit /b !ERRORLEVEL!
)
endlocal
