@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -STA -File "%~dp0Uninstall.ps1"
if errorlevel 1 pause
