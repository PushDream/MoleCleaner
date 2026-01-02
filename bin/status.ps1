# Mole - Windows System Status Monitor
# PowerShell wrapper for the Go-based status monitor

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Find the status-go.exe binary
$StatusBinary = Join-Path $ScriptDir "status-go.exe"

if (-not (Test-Path $StatusBinary)) {
    Write-Host "Error: status-go.exe not found in $ScriptDir" -ForegroundColor Red
    Write-Host "Please run the build script first: scripts\build-status.ps1" -ForegroundColor Yellow
    exit 1
}

# Run the status monitor
try {
    & $StatusBinary $args
    exit $LASTEXITCODE
} catch {
    Write-Host "Error running status monitor: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
