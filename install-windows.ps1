# MoleCleaner Installation Script for Windows
# Installs MoleCleaner system maintenance tool

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$InstallPath = "$env:ProgramFiles\MoleCleaner",
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

function Write-ColorMessage {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

if ($Uninstall) {
    Write-ColorMessage "`nUninstalling MoleCleaner..." -Color Magenta

    # Remove from PATH
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $newPath = ($currentPath -split ';' | Where-Object { $_ -ne $InstallPath }) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")

    # Remove installation directory
    if (Test-Path $InstallPath) {
        Remove-Item -Path $InstallPath -Recurse -Force
        Write-ColorMessage "[OK] Removed $InstallPath" -Color Green
    }

    Write-ColorMessage "`nMoleCleaner has been uninstalled" -Color Green
    Write-Host ""
    exit 0
}

Write-ColorMessage "`nMoleCleaner Installation for Windows" -Color Magenta
Write-ColorMessage "====================================`n" -Color Magenta

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-ColorMessage "Error: This script must be run as Administrator" -Color Red
    Write-Host "Right-click and select 'Run as Administrator'"
    exit 1
}

# Get current directory (should be MoleCleaner repo root)
$SourceDir = $PSScriptRoot

Write-Host "Installing to: $InstallPath"
Write-Host ""

# Create installation directory
if (Test-Path $InstallPath) {
    Write-ColorMessage "Installation directory already exists, removing..." -Color Yellow
    Remove-Item -Path $InstallPath -Recurse -Force
}

New-Item -ItemType Directory -Path $InstallPath | Out-Null

# Copy files
Write-Host "Copying files..."
Copy-Item -Path "$SourceDir\mole.ps1" -Destination $InstallPath
Copy-Item -Path "$SourceDir\mole.bat" -Destination $InstallPath
Copy-Item -Path "$SourceDir\bin" -Destination $InstallPath -Recurse
Copy-Item -Path "$SourceDir\README.md" -Destination $InstallPath -ErrorAction SilentlyContinue
Copy-Item -Path "$SourceDir\LICENSE" -Destination $InstallPath -ErrorAction SilentlyContinue

Write-ColorMessage "[OK] Files copied" -Color Green

# Build the status monitor
Write-Host ""
Write-Host "Building status monitor..."
$BuildScript = Join-Path $SourceDir "scripts\build-status-windows.ps1"
if (Test-Path $BuildScript) {
    try {
        & $BuildScript
        # Copy the built binary to installation
        $BuiltBinary = Join-Path $SourceDir "bin\status-go.exe"
        if (Test-Path $BuiltBinary) {
            Copy-Item -Path $BuiltBinary -Destination "$InstallPath\bin\" -Force
            Write-ColorMessage "[OK] Status monitor built and installed" -Color Green
        }
    } catch {
        Write-ColorMessage "[!] Warning: Could not build status monitor" -Color Yellow
        Write-Host "  You can build it later by running: .\scripts\build-status-windows.ps1"
    }
} else {
    Write-ColorMessage "[!] Warning: Build script not found" -Color Yellow
}

# Build the disk analyzer
Write-Host ""
Write-Host "Building disk analyzer..."
$AnalyzeBuildScript = Join-Path $SourceDir "scripts\build-analyze-windows.ps1"
if (Test-Path $AnalyzeBuildScript) {
    try {
        & $AnalyzeBuildScript
        # Copy the built binary to installation
        $BuiltAnalyzer = Join-Path $SourceDir "bin\analyze-go.exe"
        if (Test-Path $BuiltAnalyzer) {
            Copy-Item -Path $BuiltAnalyzer -Destination "$InstallPath\bin\" -Force
            Write-ColorMessage "[OK] Disk analyzer built and installed" -Color Green
        }
    } catch {
        Write-ColorMessage "[!] Warning: Could not build disk analyzer" -Color Yellow
        Write-Host "  You can build it later by running: .\scripts\build-analyze-windows.ps1"
    }
} else {
    Write-ColorMessage "[!] Warning: Build script not found" -Color Yellow
}

# Add to PATH
Write-Host ""
Write-Host "Adding to PATH..."
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$InstallPath*") {
    $newPath = "$currentPath;$InstallPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    Write-ColorMessage "[OK] Added to system PATH" -Color Green
    Write-ColorMessage "  Note: Restart your terminal for PATH changes to take effect" -Color Yellow
} else {
    Write-ColorMessage "[OK] Already in PATH" -Color Green
}

# Create desktop shortcut (optional)
Write-Host ""
$createShortcut = Read-Host "Create desktop shortcut? (y/N)"
if ($createShortcut -eq 'y' -or $createShortcut -eq 'Y') {
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\MoleCleaner.lnk")
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-NoExit -Command `"cd '$InstallPath'; .\mole.ps1 help`""
    $Shortcut.WorkingDirectory = $InstallPath
    $Shortcut.Description = "MoleCleaner System Maintenance Tool"
    $Shortcut.Save()
    Write-ColorMessage "[OK] Desktop shortcut created" -Color Green
}

Write-Host ""
Write-ColorMessage "Installation complete!" -Color Green
Write-Host ""
Write-Host "Usage:"
Write-Host "  mole clean              # Clean system caches and temp files"
Write-Host "  mole uninstall <app>    # Uninstall applications completely"
Write-Host "  mole analyze            # Explore disk usage"
Write-Host "  mole status             # Show system status dashboard"
Write-Host "  mole optimize           # Run maintenance tasks"
Write-Host "  mole purge              # Clean project artifacts"
Write-Host "  mole help               # Show all commands"
Write-Host ""
Write-ColorMessage "Note: Restart your terminal for the 'mole' command to work" -Color Yellow
Write-Host "      Or use: powershell -File '$InstallPath\mole.ps1'"
Write-Host ""
