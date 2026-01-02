# Mole - Windows System Cleanup Script
# PowerShell equivalent of clean.sh for Windows

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$ShowErrors,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Script configuration
$Script:TotalItems = 0
$Script:FilesClean = 0
$Script:TotalSizeCleaned = 0
$Script:WhitelistSkippedCount = 0

# Color codes
$Script:Colors = @{
    Purple = "Magenta"
    Green = "Green"
    Blue = "Cyan"
    Yellow = "Yellow"
    Gray = "DarkGray"
    Red = "Red"
}

# Icons (ASCII-safe for PowerShell)
$Script:Icons = @{
    Arrow = "->"
    Success = "[OK]"
    Warning = "[!]"
    Error = "[X]"
    Info = "[i]"
    Solid = "*"
}

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

function Get-FreeSpace {
    $drive = Get-PSDrive -Name C
    $freeGB = [math]::Round($drive.Free / 1GB, 2)
    return "$freeGB GB"
}

function Get-PathSize {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return 0
    }

    try {
        $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [int64]($size / 1KB)  # Return size in KB
    } catch {
        return 0
    }
}

function Format-Bytes {
    param([int64]$Bytes)

    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    } elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    } elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    } else {
        return "$Bytes bytes"
    }
}

function Start-Section {
    param([string]$Name)

    Write-Host ""
    Write-ColorMessage "$($Icons.Arrow) $Name" -Color $Colors.Purple
}

function Remove-PathSafely {
    param(
        [string[]]$Paths,
        [string]$Description
    )

    $existingPaths = @()
    foreach ($path in $Paths) {
        if (Test-Path $path) {
            $existingPaths += $path
        }
    }

    if ($existingPaths.Count -eq 0) {
        return
    }

    # Show scanning message
    Write-ColorMessage "  Scanning $Description..." -Color $Colors.Gray

    # Calculate total size
    $totalSize = 0
    $totalCount = 0

    foreach ($path in $existingPaths) {
        $sizeKB = Get-PathSize -Path $path
        if ($sizeKB -gt 0) {
            $totalSize += $sizeKB
            $totalCount++
        }
    }

    if ($totalSize -eq 0) {
        Write-Host "`r  $($Icons.Info) No items found for $Description" -NoNewline
        Write-Host ""
        return
    }

    $sizeHuman = Format-Bytes ($totalSize * 1KB)

    if ($DryRun) {
        Write-Host "`r  $($Icons.Arrow) $Description $sizeHuman (dry run)" -ForegroundColor $Colors.Yellow
    } else {
        # Show cleaning message
        Write-Host "`r  Cleaning $Description..." -NoNewline

        $cleaned = 0
        foreach ($path in $existingPaths) {
            try {
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                $cleaned++
                # Update progress
                $pct = [math]::Round(($cleaned / $existingPaths.Count) * 100)
                Write-Host "`r  Cleaning $Description... $pct%" -NoNewline
            } catch {
                if ($ShowErrors) {
                    Write-Host ""
                    Write-ColorMessage "  Failed to remove: $path - $($_.Exception.Message)" -Color $Colors.Red
                }
            }
        }
        Write-Host "`r  $($Icons.Success) $Description $sizeHuman                    " -ForegroundColor $Colors.Green
    }

    $Script:FilesClean += $totalCount
    $Script:TotalSizeCleaned += $totalSize
    $Script:TotalItems++
}

function Clear-UserCaches {
    Start-Section "Windows User Caches"

    $tempPath = [System.IO.Path]::GetTempPath()
    $userTemp = $env:TEMP
    $localAppData = $env:LOCALAPPDATA
    $appData = $env:APPDATA

    # Windows temp folders
    $paths = @(
        "$userTemp\*",
        "$env:WINDIR\Temp\*",
        "$localAppData\Temp\*"
    )

    Remove-PathSafely -Paths $paths -Description "Temporary files"

    # Windows prefetch
    if (Test-Path "$env:WINDIR\Prefetch") {
        Remove-PathSafely -Paths @("$env:WINDIR\Prefetch\*.pf") -Description "Prefetch cache"
    }

    # Thumbnail cache
    Remove-PathSafely -Paths @(
        "$localAppData\Microsoft\Windows\Explorer\thumbcache_*.db",
        "$localAppData\Microsoft\Windows\Explorer\iconcache_*.db"
    ) -Description "Thumbnail cache"

    # Windows Error Reporting
    Remove-PathSafely -Paths @("$localAppData\CrashDumps\*") -Description "Crash dumps"

    # Windows Update cache
    Remove-PathSafely -Paths @("$env:WINDIR\SoftwareDistribution\Download\*") -Description "Windows Update cache"
}

function Clear-BrowserCaches {
    Start-Section "Browser Caches"

    $localAppData = $env:LOCALAPPDATA
    $appData = $env:APPDATA

    # Chrome
    $chromePaths = @(
        "$localAppData\Google\Chrome\User Data\Default\Cache\*",
        "$localAppData\Google\Chrome\User Data\Default\Code Cache\*",
        "$localAppData\Google\Chrome\User Data\Default\GPUCache\*"
    )
    Remove-PathSafely -Paths $chromePaths -Description "Chrome cache"

    # Edge
    $edgePaths = @(
        "$localAppData\Microsoft\Edge\User Data\Default\Cache\*",
        "$localAppData\Microsoft\Edge\User Data\Default\Code Cache\*",
        "$localAppData\Microsoft\Edge\User Data\Default\GPUCache\*"
    )
    Remove-PathSafely -Paths $edgePaths -Description "Edge cache"

    # Firefox
    $firefoxProfile = Get-ChildItem "$appData\Mozilla\Firefox\Profiles" -ErrorAction SilentlyContinue |
                      Select-Object -First 1
    if ($firefoxProfile) {
        $firefoxPaths = @(
            "$($firefoxProfile.FullName)\cache2\*",
            "$($firefoxProfile.FullName)\startupCache\*"
        )
        Remove-PathSafely -Paths $firefoxPaths -Description "Firefox cache"
    }
}

function Clear-DeveloperTools {
    Start-Section "Developer Tools"

    $userProfile = $env:USERPROFILE

    # npm cache
    if (Test-Path "$userProfile\.npm") {
        Remove-PathSafely -Paths @("$userProfile\.npm\_cacache\*") -Description "npm cache"
    }

    # Yarn cache
    if (Test-Path "$userProfile\.yarn") {
        Remove-PathSafely -Paths @("$userProfile\.yarn\cache\*") -Description "Yarn cache"
    }

    # pip cache
    if (Test-Path "$localAppData\pip") {
        Remove-PathSafely -Paths @("$localAppData\pip\cache\*") -Description "pip cache"
    }

    # Gradle cache
    if (Test-Path "$userProfile\.gradle") {
        Remove-PathSafely -Paths @("$userProfile\.gradle\caches\*") -Description "Gradle cache"
    }

    # Maven cache (only old artifacts)
    if (Test-Path "$userProfile\.m2\repository") {
        $oldMaven = Get-ChildItem "$userProfile\.m2\repository" -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-90) }
        if ($oldMaven) {
            $oldMavenPaths = $oldMaven | ForEach-Object { $_.FullName }
            Remove-PathSafely -Paths $oldMavenPaths -Description "Maven old artifacts (90+ days)"
        }
    }

    # NuGet cache
    if (Test-Path "$userProfile\.nuget\packages") {
        $oldNuget = Get-ChildItem "$userProfile\.nuget\packages" -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-60) }
        if ($oldNuget) {
            $oldNugetPaths = $oldNuget | ForEach-Object { $_.FullName }
            Remove-PathSafely -Paths $oldNugetPaths -Description "NuGet old packages (60+ days)"
        }
    }

    # Visual Studio temp files
    Remove-PathSafely -Paths @(
        "$localAppData\Microsoft\VisualStudio\*\ComponentModelCache\*",
        "$localAppData\Microsoft\VisualStudio\*\Extensions\*\Cache\*",
        "$env:TEMP\VSFeedbackIntelliCodeLogs\*"
    ) -Description "Visual Studio cache"
}

function Clear-ApplicationCaches {
    Start-Section "Application Caches"

    $localAppData = $env:LOCALAPPDATA

    # Discord
    Remove-PathSafely -Paths @(
        "$appData\discord\Cache\*",
        "$appData\discord\Code Cache\*",
        "$appData\discord\GPUCache\*"
    ) -Description "Discord cache"

    # Slack
    Remove-PathSafely -Paths @(
        "$appData\Slack\Cache\*",
        "$appData\Slack\Code Cache\*",
        "$appData\Slack\GPUCache\*"
    ) -Description "Slack cache"

    # Teams
    Remove-PathSafely -Paths @(
        "$appData\Microsoft\Teams\Cache\*",
        "$appData\Microsoft\Teams\GPUCache\*",
        "$appData\Microsoft\Teams\blob_storage\*"
    ) -Description "Teams cache"

    # Spotify
    Remove-PathSafely -Paths @(
        "$appData\Spotify\Storage\*",
        "$localAppData\Spotify\Storage\*"
    ) -Description "Spotify cache"
}

function Clear-RecycleBin {
    Start-Section "Recycle Bin"

    Write-ColorMessage "  Checking Recycle Bin..." -Color $Colors.Gray

    if ($DryRun) {
        $recycleBinSize = (Get-ChildItem -Path 'C:\$Recycle.Bin' -Recurse -Force -ErrorAction SilentlyContinue |
                           Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        if ($recycleBinSize -gt 0) {
            $sizeHuman = Format-Bytes $recycleBinSize
            Write-Host "`r  $($Icons.Arrow) Recycle Bin $sizeHuman (dry run)" -ForegroundColor $Colors.Yellow
        } else {
            Write-Host "`r  $($Icons.Info) Recycle Bin is already empty"
        }
    } else {
        try {
            Write-Host "`r  Emptying Recycle Bin..." -NoNewline
            Clear-RecycleBin -Force -ErrorAction Stop
            Write-Host "`r  $($Icons.Success) Recycle Bin emptied          " -ForegroundColor $Colors.Green
            $Script:TotalItems++
        } catch {
            Write-Host ""
            if ($ShowErrors) {
                Write-ColorMessage "  Failed to empty Recycle Bin: $($_.Exception.Message)" -Color $Colors.Red
            }
        }
    }
}

function Show-Summary {
    Write-Host ""
    Write-Host ""

    $freedGB = [math]::Round($Script:TotalSizeCleaned / 1024 / 1024, 2)

    if ($DryRun) {
        Write-ColorMessage "Dry Run Complete - No Changes Made" -Color $Colors.Purple
        Write-Host ""
        Write-ColorMessage "  Potential space: " -Color White -NoNewline
        Write-ColorMessage "$freedGB GB" -Color $Colors.Green
        Write-ColorMessage "  Items: $($Script:FilesClean) | Categories: $($Script:TotalItems)" -Color White
    } else {
        Write-ColorMessage "Cleanup Complete" -Color $Colors.Purple
        Write-Host ""
        Write-ColorMessage "  Space freed: " -Color White -NoNewline
        Write-ColorMessage "$freedGB GB" -Color $Colors.Green
        Write-ColorMessage "  Items cleaned: $($Script:FilesClean) | Categories: $($Script:TotalItems)" -Color White
        Write-ColorMessage "  Free space now: $(Get-FreeSpace)" -Color White
    }

    Write-Host ""
}

# Interactive category selection
function Show-CategoryMenu {
    $categories = @(
        [PSCustomObject]@{Name="Windows User Caches"; Enabled=$true; Function="Clear-UserCaches"},
        [PSCustomObject]@{Name="Browser Caches"; Enabled=$true; Function="Clear-BrowserCaches"},
        [PSCustomObject]@{Name="Developer Tools"; Enabled=$true; Function="Clear-DeveloperTools"},
        [PSCustomObject]@{Name="Application Caches"; Enabled=$true; Function="Clear-ApplicationCaches"},
        [PSCustomObject]@{Name="Recycle Bin"; Enabled=$true; Function="Clear-RecycleBin"}
    )

    if ($NonInteractive -or $DryRun) {
        return $categories
    }

    Clear-Host
    Write-Host ""
    Write-ColorMessage "Select Categories to Clean" -Color $Colors.Purple
    Write-Host ""
    Write-ColorMessage "Use arrow keys to navigate, Space to toggle, Enter to continue" -Color $Colors.Gray
    Write-Host ""

    $selected = 0
    $done = $false

    # Function to draw the menu
    function Draw-CategoryMenu {
        param($cats, $sel)

        Clear-Host
        Write-Host ""
        Write-ColorMessage "Select Categories to Clean" -Color $Colors.Purple
        Write-Host ""
        Write-ColorMessage "Arrow keys: navigate | Space: toggle | Enter: continue | Esc: cancel" -Color $Colors.Gray
        Write-Host ""

        for ($i = 0; $i -lt $cats.Count; $i++) {
            $cursor = if ($i -eq $sel) { ">" } else { " " }
            $checkbox = if ($cats[$i].Enabled) { "[X]" } else { "[ ]" }
            $color = if ($i -eq $sel) { $Colors.Yellow } else { "White" }

            Write-ColorMessage "$cursor $checkbox $($cats[$i].Name)" -Color $color
        }
        Write-Host ""
    }

    # Initial draw
    Draw-CategoryMenu -cats $categories -sel $selected

    while (-not $done) {
        # Get key input
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                $selected = ($selected - 1 + $categories.Count) % $categories.Count
                Draw-CategoryMenu -cats $categories -sel $selected
            }
            40 { # Down arrow
                $selected = ($selected + 1) % $categories.Count
                Draw-CategoryMenu -cats $categories -sel $selected
            }
            32 { # Spacebar
                # Toggle the enabled state
                $newState = -not $categories[$selected].Enabled
                $categories[$selected].Enabled = $newState

                # Debug: Show what we just toggled
                if ($ShowErrors) {
                    Write-Host "Toggled $($categories[$selected].Name) to $newState (index $selected)" -ForegroundColor Cyan
                    Start-Sleep -Milliseconds 500
                }
                Draw-CategoryMenu -cats $categories -sel $selected
            }
            13 { # Enter
                $done = $true
            }
            27 { # Escape
                Write-Host ""
                Write-ColorMessage "Cancelled" -Color $Colors.Gray
                exit 0
            }
        }
    }

    # Return the modified categories array
    return ,$categories
}

# Main execution
function Start-Cleanup {
    Clear-Host
    Write-Host ""
    Write-ColorMessage "Mole - Clean Your Windows PC" -Color $Colors.Purple
    Write-Host ""

    Write-ColorMessage "$($Icons.Info) Windows $(([System.Environment]::OSVersion.Version).Major).$(([System.Environment]::OSVersion.Version).Minor) | Free space: $(Get-FreeSpace)" -Color $Colors.Blue
    Write-Host ""

    if ($DryRun) {
        Write-ColorMessage "Dry Run Mode - Preview only, no deletions" -Color $Colors.Yellow
        Write-Host ""
    }

    # Show interactive menu (unless in dry-run or non-interactive mode)
    $categories = Show-CategoryMenu

    # Count enabled categories
    $enabledCount = ($categories | Where-Object { $_.Enabled }).Count

    if ($enabledCount -eq 0) {
        Write-ColorMessage "No categories selected. Exiting." -Color $Colors.Gray
        exit 0
    }

    Clear-Host
    Write-Host ""
    Write-ColorMessage "Mole - Clean Your Windows PC" -Color $Colors.Purple
    Write-Host ""
    Write-ColorMessage "$($Icons.Info) Windows $(([System.Environment]::OSVersion.Version).Major).$(([System.Environment]::OSVersion.Version).Minor) | Free space: $(Get-FreeSpace)" -Color $Colors.Blue

    if ($DryRun) {
        Write-ColorMessage "Dry Run Mode - Preview only, no deletions" -Color $Colors.Yellow
    }

    Write-Host ""

    # Ask for confirmation if not dry-run and not non-interactive
    if (-not $DryRun -and -not $NonInteractive) {
        # Debug: Show all category states
        if ($ShowErrors) {
            Write-Host "DEBUG - Category states:" -ForegroundColor Cyan
            foreach ($cat in $categories) {
                Write-Host "  $($cat.Name): Enabled=$($cat.Enabled)" -ForegroundColor Cyan
            }
            Write-Host ""
        }

        Write-ColorMessage "Ready to clean $enabledCount categories" -Color $Colors.Yellow
        Write-Host ""
        Write-Host "This will:"
        foreach ($category in $categories) {
            if ($category.Enabled) {
                Write-Host "  * Clean $($category.Name)"
            }
        }
        Write-Host ""
        Write-ColorMessage "Continue? (Y/n): " -Color $Colors.Yellow -NoNewline
        $confirmation = Read-Host

        if ($confirmation -eq 'n' -or $confirmation -eq 'N') {
            Write-Host ""
            Write-ColorMessage "Cancelled" -Color $Colors.Gray
            exit 0
        }

        Clear-Host
        Write-Host ""
        Write-ColorMessage "Mole - Clean Your Windows PC" -Color $Colors.Purple
        Write-Host ""
        Write-ColorMessage "$($Icons.Info) Windows $(([System.Environment]::OSVersion.Version).Major).$(([System.Environment]::OSVersion.Version).Minor) | Free space: $(Get-FreeSpace)" -Color $Colors.Blue
        Write-Host ""
    }

    Write-ColorMessage "Cleaning $enabledCount categories..." -Color $Colors.Gray
    Write-Host ""

    # Perform cleanup for selected categories
    foreach ($category in $categories) {
        if ($category.Enabled) {
            & $category.Function
        }
    }

    # Show summary
    Show-Summary
}

# Run cleanup
Start-Cleanup
