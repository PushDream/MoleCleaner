# Build script for Windows disk analyzer
# Compiles the Go analyzer for Windows

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

Write-Host "Building Mole Disk Analyzer for Windows..." -ForegroundColor Cyan

# Get project root
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$CmdDir = Join-Path $ProjectRoot "cmd\analyze"
$BinDir = Join-Path $ProjectRoot "bin"

# Ensure bin directory exists
if (-not (Test-Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir | Out-Null
}

# Get version from git tags or default
try {
    $Version = (git describe --tags --abbrev=0 2>$null)
    if (-not $Version) {
        $Version = "dev"
    }
} catch {
    $Version = "dev"
}

$BuildTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "Version: $Version" -ForegroundColor Gray
Write-Host "Build Time: $BuildTime" -ForegroundColor Gray
Write-Host ""

# Set Go environment for Windows
$env:GOOS = "windows"
$env:GOARCH = "amd64"

# Build output path
$OutputPath = Join-Path $BinDir "analyze-go.exe"

# Build flags
$LDFlags = "-s -w"

Write-Host "Building for Windows (amd64)..." -ForegroundColor Yellow

try {
    Push-Location $CmdDir
    go build -ldflags $LDFlags -trimpath -o $OutputPath
    Pop-Location

    if (Test-Path $OutputPath) {
        $Size = (Get-Item $OutputPath).Length
        $SizeMB = [math]::Round($Size / 1MB, 2)
        Write-Host "[OK] Build successful: $OutputPath ($SizeMB MB)" -ForegroundColor Green
    } else {
        throw "Build failed: output file not found"
    }
} catch {
    Pop-Location
    Write-Host "[ERROR] Build failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Disk analyzer ready! Run it with:" -ForegroundColor Cyan
Write-Host "  .\bin\analyze.ps1" -ForegroundColor White
