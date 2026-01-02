# Mole - Windows Application Uninstaller
# PowerShell script to completely remove applications and their leftovers

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$AppName,
    [switch]$DryRun,
    [switch]$List
)

$ErrorActionPreference = "Continue"

# Color output functions
$Script:Colors = @{
    Purple = "Magenta"
    Green = "Green"
    Blue = "Cyan"
    Yellow = "Yellow"
    Gray = "DarkGray"
    Red = "Red"
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

function Get-InstalledApplications {
    # Get all installed applications from registry
    $registryPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $apps = @()
    foreach ($path in $registryPaths) {
        $apps += Get-ItemProperty $path -ErrorAction SilentlyContinue |
                 Where-Object { $_.DisplayName } |
                 Select-Object DisplayName, DisplayVersion, Publisher, UninstallString, InstallLocation
    }

    return $apps | Sort-Object DisplayName -Unique
}

function Get-ApplicationLeftovers {
    param([string]$AppName)

    $leftovers = @()
    $localAppData = $env:LOCALAPPDATA
    $appData = $env:APPDATA
    $programData = $env:ProgramData
    $userProfile = $env:USERPROFILE

    # Common leftover locations
    $searchPaths = @(
        "$localAppData\$AppName",
        "$appData\$AppName",
        "$programData\$AppName",
        "$userProfile\.$AppName",
        "${env:ProgramFiles}\$AppName",
        "${env:ProgramFiles(x86)}\$AppName"
    )

    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $leftovers += $path
        }
    }

    # Check for registry keys
    $regPaths = @(
        "HKCU:\Software\$AppName",
        "HKLM:\Software\$AppName",
        "HKLM:\Software\WOW6432Node\$AppName"
    )

    foreach ($regPath in $regPaths) {
        if (Test-Path $regPath) {
            $leftovers += $regPath
        }
    }

    return $leftovers
}

function Uninstall-Application {
    param(
        [string]$DisplayName,
        [string]$UninstallString
    )

    Write-ColorMessage "`nUninstalling: $DisplayName" -Color $Colors.Purple

    if ($DryRun) {
        Write-ColorMessage "  -> Would run: $UninstallString (dry run)" -Color $Colors.Yellow
        return $true
    }

    try {
        # Parse uninstall string
        if ($UninstallString -match '^"([^"]+)"(.*)$') {
            $exe = $Matches[1]
            $args = $Matches[2].Trim()
        } else {
            $parts = $UninstallString -split ' ', 2
            $exe = $parts[0]
            $args = if ($parts.Length -gt 1) { $parts[1] } else { '' }
        }

        # Add silent flags if not present
        if ($args -notmatch '/S' -and $args -notmatch '/quiet' -and $args -notmatch '/silent') {
            if ($exe -match 'msiexec') {
                $args += ' /quiet /norestart'
            } else {
                $args += ' /S'
            }
        }

        Write-ColorMessage "  Running uninstaller..." -Color $Colors.Gray

        if ($args) {
            $process = Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru -NoNewWindow
        } else {
            $process = Start-Process -FilePath $exe -Wait -PassThru -NoNewWindow
        }

        if ($process.ExitCode -eq 0) {
            Write-ColorMessage "  [OK] Uninstallation completed" -Color $Colors.Green
            return $true
        } else {
            Write-ColorMessage "  [!] Uninstaller exited with code: $($process.ExitCode)" -Color $Colors.Yellow
            return $false
        }
    } catch {
        Write-ColorMessage "  [X] Failed to run uninstaller: $($_.Exception.Message)" -Color $Colors.Red
        return $false
    }
}

function Remove-ApplicationLeftovers {
    param([string]$AppName)

    $leftovers = Get-ApplicationLeftovers -AppName $AppName

    if ($leftovers.Count -eq 0) {
        Write-ColorMessage "  [OK] No leftovers found" -Color $Colors.Green
        return
    }

    Write-ColorMessage "`nRemoving leftovers:" -Color $Colors.Purple

    foreach ($item in $leftovers) {
        if ($item -match '^HK') {
            # Registry key
            if ($DryRun) {
                Write-ColorMessage "  -> Would remove registry: $item (dry run)" -Color $Colors.Yellow
            } else {
                try {
                    Remove-Item -Path $item -Recurse -Force -ErrorAction Stop
                    Write-ColorMessage "  [OK] Removed registry: $item" -Color $Colors.Green
                } catch {
                    Write-ColorMessage "  [X] Failed to remove registry: $item" -Color $Colors.Red
                }
            }
        } else {
            # File system path
            if ($DryRun) {
                $size = (Get-ChildItem -Path $item -Recurse -Force -ErrorAction SilentlyContinue |
                         Measure-Object -Property Length -Sum).Sum
                $sizeStr = if ($size -gt 1GB) { "{0:N2} GB" -f ($size / 1GB) }
                          elseif ($size -gt 1MB) { "{0:N2} MB" -f ($size / 1MB) }
                          else { "{0:N2} KB" -f ($size / 1KB) }
                Write-ColorMessage "  -> Would remove: $item ($sizeStr) (dry run)" -Color $Colors.Yellow
            } else {
                try {
                    Remove-Item -Path $item -Recurse -Force -ErrorAction Stop
                    Write-ColorMessage "  [OK] Removed: $item" -Color $Colors.Green
                } catch {
                    Write-ColorMessage "  [X] Failed to remove: $item" -Color $Colors.Red
                }
            }
        }
    }
}

# Main logic
if ($List) {
    Write-ColorMessage "Installed Applications:" -Color $Colors.Purple
    Write-Host ""
    $apps = Get-InstalledApplications
    $apps | ForEach-Object {
        Write-ColorMessage "  * $($_.DisplayName)" -Color White
        if ($_.DisplayVersion) {
            Write-ColorMessage "    Version: $($_.DisplayVersion)" -Color $Colors.Gray
        }
        if ($_.Publisher) {
            Write-ColorMessage "    Publisher: $($_.Publisher)" -Color $Colors.Gray
        }
    }
    Write-Host ""
    Write-ColorMessage "Total: $($apps.Count) applications" -Color $Colors.Blue
    exit 0
}

if (-not $AppName) {
    Write-ColorMessage "Error: Application name required" -Color $Colors.Red
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  mole uninstall <AppName>     # Uninstall an application"
    Write-Host "  mole uninstall -List         # List all installed applications"
    Write-Host "  mole uninstall <AppName> -DryRun  # Preview what would be removed"
    Write-Host ""
    exit 1
}

# Find the application
$apps = Get-InstalledApplications | Where-Object { $_.DisplayName -like "*$AppName*" }

if ($apps.Count -eq 0) {
    Write-ColorMessage "Error: No application found matching '$AppName'" -Color $Colors.Red
    Write-Host ""
    Write-ColorMessage "Tip: Use 'mole uninstall -List' to see all installed applications" -Color $Colors.Gray
    exit 1
}

if ($apps.Count -gt 1) {
    Write-ColorMessage "Multiple applications found matching '$AppName':" -Color $Colors.Yellow
    Write-Host ""
    $apps | ForEach-Object { Write-ColorMessage "  * $($_.DisplayName)" -Color White }
    Write-Host ""
    Write-ColorMessage "Please be more specific" -Color $Colors.Gray
    exit 1
}

$app = $apps[0]

# Confirm uninstall
Write-ColorMessage "Found: $($app.DisplayName)" -Color $Colors.Purple
if ($app.DisplayVersion) {
    Write-ColorMessage "Version: $($app.DisplayVersion)" -Color $Colors.Gray
}
if ($app.Publisher) {
    Write-ColorMessage "Publisher: $($app.Publisher)" -Color $Colors.Gray
}
Write-Host ""

if (-not $DryRun -and -not $NonInteractive) {
    $confirm = Read-Host "Uninstall this application? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-ColorMessage "Cancelled" -Color $Colors.Gray
        exit 0
    }
}

# Run uninstaller
if ($app.UninstallString) {
    $success = Uninstall-Application -DisplayName $app.DisplayName -UninstallString $app.UninstallString
} else {
    Write-ColorMessage "  [!] No uninstaller found for this application" -Color $Colors.Yellow
    $success = $false
}

# Remove leftovers
Start-Sleep -Seconds 2  # Wait for uninstaller to complete
Remove-ApplicationLeftovers -AppName $app.DisplayName

Write-Host ""
if ($DryRun) {
    Write-ColorMessage "Dry run complete - no changes made" -Color $Colors.Yellow
} else {
    Write-ColorMessage "Uninstallation complete" -Color $Colors.Green
}
