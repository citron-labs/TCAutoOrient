@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -STA -File "%~dp0InstallWindow.ps1"
if errorlevel 1 (
  echo.
  echo Setup could not start or returned an error. See the message above.
  pause
)
