@echo off
REM Mole - Windows launcher wrapper
REM This allows running "mole" instead of ".\mole.ps1"

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0mole.ps1" %*
