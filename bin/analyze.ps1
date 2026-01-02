# Mole - Windows Disk Analyzer
# PowerShell wrapper for the Go-based analyzer

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Find the analyze-go.exe binary
$AnalyzeBinary = Join-Path $ScriptDir "analyze-go.exe"

if (-not (Test-Path $AnalyzeBinary)) {
    Write-Host "Error: analyze-go.exe not found in $ScriptDir" -ForegroundColor Red
    Write-Host "Please run the build script first: scripts\build-analyze-windows.ps1" -ForegroundColor Yellow
    exit 1
}

# Run the analyzer
try {
    & $AnalyzeBinary $args
    exit $LASTEXITCODE
} catch {
    Write-Host "Error running disk analyzer: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
