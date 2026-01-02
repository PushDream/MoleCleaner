# Mole - Windows Optimize Script
# Runs Windows maintenance tasks with safety prompts

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Help
)

$ErrorActionPreference = "Continue"

function Write-ColorMessage {
    param(
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewline
    )

    if ($NoNewline) {
        Write-Host $Message -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Confirm-Action {
    param([string]$Message)

    Write-ColorMessage "$Message [Y/n]: " -Color Yellow -NoNewline
    $answer = Read-Host
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $true
    }
    return $answer.Trim().ToLower() -in @("y", "yes")
}

function Show-Help {
    Write-Host "Mole Optimize - Windows maintenance tasks"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  mole optimize [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -DryRun   Preview tasks without running them"
    Write-Host "  -Help     Show this help message"
}

if ($Help) {
    Show-Help
    exit 0
}

Write-Host ""
Write-ColorMessage "Optimize and Check" -Color Magenta
Write-Host ""

if ($DryRun) {
    Write-ColorMessage "DRY RUN MODE - No changes will be applied" -Color Yellow
    Write-Host ""
}

$isAdmin = Test-IsAdmin
if (-not $isAdmin) {
    Write-ColorMessage "Note: Some tasks require Administrator access." -Color DarkGray
    Write-Host ""
}

$tasks = @(
    [pscustomobject]@{
        Name = "Flush DNS cache"
        Description = "Clear the system DNS resolver cache"
        RequiresAdmin = $false
        Command = { ipconfig /flushdns }
    },
    [pscustomobject]@{
        Name = "System image repair (DISM)"
        Description = "Repair Windows system image integrity"
        RequiresAdmin = $true
        Command = { DISM /Online /Cleanup-Image /RestoreHealth }
    },
    [pscustomobject]@{
        Name = "System File Checker (SFC)"
        Description = "Repair protected system files"
        RequiresAdmin = $true
        Command = { sfc /scannow }
    }
)

$completed = 0
$skipped = 0

foreach ($task in $tasks) {
    Write-ColorMessage "-> $($task.Name)" -Color Cyan
    Write-ColorMessage "   $($task.Description)" -Color DarkGray

    if ($DryRun) {
        Write-ColorMessage "   Would run" -Color DarkGray
        Write-Host ""
        continue
    }

    if ($task.RequiresAdmin -and -not $isAdmin) {
        Write-ColorMessage "   Skipped (requires Administrator)" -Color Yellow
        Write-Host ""
        $skipped++
        continue
    }

    if (-not (Confirm-Action "   Run this task")) {
        Write-ColorMessage "   Skipped" -Color DarkGray
        Write-Host ""
        $skipped++
        continue
    }

    try {
        & $task.Command
        Write-ColorMessage "   Done" -Color Green
        Write-Host ""
        $completed++
    } catch {
        Write-ColorMessage "   Failed: $($_.Exception.Message)" -Color Red
        Write-Host ""
        $skipped++
    }
}

Write-ColorMessage "Optimization complete" -Color Magenta
Write-ColorMessage "Applied: $completed | Skipped: $skipped" -Color Gray
Write-Host ""
