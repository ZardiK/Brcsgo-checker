@echo off

rem Запускаем PowerShell-скрипт
PowerShell.exe -ExecutionPolicy Bypass -File "%~dp0\steam_checker.ps1"

pause
