@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_local.ps1" %*
set "launchExit=%errorlevel%"
if not "%launchExit%"=="0" pause
exit /b %launchExit%
