@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Offline.ps1" %*
set "result=%errorlevel%"
if not "%result%"=="0" echo Installation failed. Exit code: %result%
pause
exit /b %result%
