# MoleCleaner - System Maintenance Tool for Windows
# Main entry point for MoleCleaner on Windows

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Continue"

# Get the directory where Mole is installed
$MoleDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BinDir = Join-Path $MoleDir "bin"

# Color output
function Write-ColorMessage {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

# Show help
function Show-Help {
    Write-Host ""
    Write-ColorMessage "MoleCleaner - System Maintenance Tool for Windows" -Color Magenta
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  mole <command> [options]"
    Write-Host ""
    Write-Host "Commands:"
    Write-ColorMessage "  clean             " -Color Cyan -NoNewline
    Write-Host "Deep system cleanup - remove caches, temp files, logs"
    Write-ColorMessage "  uninstall <app>   " -Color Cyan -NoNewline
    Write-Host "Completely remove an application and its leftovers"
    Write-ColorMessage "  analyze [path]    " -Color Cyan -NoNewline
    Write-Host "Interactive disk space analyzer"
    Write-ColorMessage "  status            " -Color Cyan -NoNewline
    Write-Host "Real-time system monitoring dashboard"
    Write-ColorMessage "  optimize          " -Color Cyan -NoNewline
    Write-Host "System maintenance tasks with safety prompts"
    Write-ColorMessage "  purge             " -Color Cyan -NoNewline
    Write-Host "Remove project build artifacts"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -DryRun           Preview changes without making them"
    Write-Host "  -ShowErrors       Show detailed error information"
    Write-Host "  -Help             Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  mole clean                    # Deep clean your system"
    Write-Host "  mole clean -DryRun            # Preview what would be cleaned"
    Write-Host "  mole uninstall Chrome         # Uninstall Chrome and remove leftovers"
    Write-Host "  mole uninstall -List          # List all installed applications"
    Write-Host "  mole analyze                  # Explore disk usage"
    Write-Host "  mole status                   # Show system status dashboard"
    Write-Host "  mole optimize                 # Run maintenance tasks"
    Write-Host "  mole purge                    # Clean project artifacts"
    Write-Host ""
    Write-Host "For more info: https://github.com/tw93/mole"
    Write-Host ""
}

# Check if a command was provided
if (-not $Command -or $Command -eq "-Help" -or $Command -eq "--help" -or $Command -eq "help") {
    Show-Help
    exit 0
}

# Parse arguments into a hashtable for named parameters
$ScriptArgs = @{}
$PositionalArgs = @()

foreach ($arg in $Arguments) {
    if ($arg -match '^-(\w+)$') {
        # Switch parameter
        $ScriptArgs[$Matches[1]] = $true
    } elseif ($arg -match '^-(\w+):(.+)$') {
        # Named parameter with value
        $ScriptArgs[$Matches[1]] = $Matches[2]
    } else {
        # Positional parameter
        $PositionalArgs += $arg
    }
}

# Route to appropriate command
switch ($Command.ToLower()) {
    "clean" {
        $CleanScript = Join-Path $BinDir "clean.ps1"
        if (Test-Path $CleanScript) {
            & $CleanScript @ScriptArgs @PositionalArgs
            exit $LASTEXITCODE
        } else {
            Write-ColorMessage "Error: clean.ps1 not found in $BinDir" -Color Red
            exit 1
        }
    }

    "uninstall" {
        $UninstallScript = Join-Path $BinDir "uninstall.ps1"
        if (Test-Path $UninstallScript) {
            & $UninstallScript @ScriptArgs @PositionalArgs
            exit $LASTEXITCODE
        } else {
            Write-ColorMessage "Error: uninstall.ps1 not found in $BinDir" -Color Red
            exit 1
        }
    }

    "analyze" {
        $AnalyzeScript = Join-Path $BinDir "analyze.ps1"
        if (Test-Path $AnalyzeScript) {
            & $AnalyzeScript @ScriptArgs @PositionalArgs
            exit $LASTEXITCODE
        } else {
            Write-ColorMessage "Error: analyze.ps1 not found in $BinDir" -Color Red
            Write-ColorMessage "Build the analyzer first: .\scripts\build-analyze-windows.ps1" -Color Yellow
            exit 1
        }
    }

    "status" {
        $StatusScript = Join-Path $BinDir "status.ps1"
        if (Test-Path $StatusScript) {
            & $StatusScript @ScriptArgs @PositionalArgs
            exit $LASTEXITCODE
        } else {
            Write-ColorMessage "Error: status.ps1 not found in $BinDir" -Color Red
            Write-ColorMessage "Build the status monitor first: .\scripts\build-status-windows.ps1" -Color Yellow
            exit 1
        }
    }

    "optimize" {
        $OptimizeScript = Join-Path $BinDir "optimize.ps1"
        if (Test-Path $OptimizeScript) {
            & $OptimizeScript @ScriptArgs @PositionalArgs
            exit $LASTEXITCODE
        } else {
            Write-ColorMessage "Error: optimize.ps1 not found in $BinDir" -Color Red
            exit 1
        }
    }

    "purge" {
        $PurgeScript = Join-Path $BinDir "purge.ps1"
        if (Test-Path $PurgeScript) {
            & $PurgeScript @ScriptArgs @PositionalArgs
            exit $LASTEXITCODE
        } else {
            Write-ColorMessage "Error: purge.ps1 not found in $BinDir" -Color Red
            exit 1
        }
    }

    "version" {
        Write-ColorMessage "MoleCleaner for Windows" -Color Magenta
        Write-Host "Version: 1.0.0"
        Write-Host "Platform: Windows"
        Write-Host ""
        exit 0
    }

    default {
        Write-ColorMessage "Error: Unknown command '$Command'" -Color Red
        Write-Host ""
        Write-Host "Run 'mole help' for usage information"
        exit 1
    }
}
