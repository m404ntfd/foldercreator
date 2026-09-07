@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0ShirtDesignFolderBuilder.ps1"
if errorlevel 1 (
  echo.
  echo Shirt Design Folder Builder could not start.
  echo Please take a picture of this window and send it for help.
  echo.
  pause
)

