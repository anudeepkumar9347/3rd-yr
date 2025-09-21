@echo off
REM Voice PD Detector - Windows Batch Launcher
REM This is a simple wrapper for the PowerShell script

echo Voice PD Detector - Windows Launcher
echo.

REM Check if PowerShell is available
where powershell >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: PowerShell not found. Please install PowerShell or use Windows 10/11.
    pause
    exit /b 1
)

REM Default action
set ACTION=run
if "%1"=="setup" set ACTION=setup
if "%1"=="help" set ACTION=help
if "%1"=="-h" set ACTION=help
if "%1"=="--help" set ACTION=help

echo Running: start.ps1 %ACTION%
echo.

REM Run the PowerShell script with execution policy bypass
powershell -ExecutionPolicy Bypass -File "%~dp0start.ps1" %ACTION% %2 %3 %4 %5

if %ERRORLEVEL% neq 0 (
    echo.
    echo Script failed with error code %ERRORLEVEL%
    pause
)
