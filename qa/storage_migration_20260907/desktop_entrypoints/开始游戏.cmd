@echo off
chcp 65001 >nul
call "%~dp0开发工程\Play.cmd" %*
exit /b %errorlevel%
