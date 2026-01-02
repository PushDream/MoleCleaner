# Mole - Windows Project Purge
# Removes build artifacts from common project directories

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string[]]$Paths,
    [switch]$DryRun,
    [switch]$Help
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

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

function Show-Help {
    Write-Host "Mole Purge - Remove project build artifacts"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  mole purge [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Paths <paths>   Custom root paths to scan"
    Write-Host "  -DryRun          Preview what would be deleted"
    Write-Host "  -Help            Show this help message"
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

function Format-Bytes {
    param([int64]$Bytes)
    if ($Bytes -lt 1KB) { return "$Bytes B" }
    if ($Bytes -lt 1MB) { return "{0:N1} KB" -f ($Bytes / 1KB) }
    if ($Bytes -lt 1GB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    return "{0:N2} GB" -f ($Bytes / 1GB)
}

function Get-DirectorySizeBytes {
    param([string]$Path)

    try {
        $sum = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        if ($null -eq $sum) { return 0 }
        return [int64]$sum
    } catch {
        return 0
    }
}

function Should-ExcludePath {
    param([string]$Path)

    $blocked = @(
        "\AppData\",
        "\Windows\",
        "\Program Files\",
        "\Program Files (x86)\"
    )

    foreach ($segment in $blocked) {
        if ($Path -like "*$segment*") {
            return $true
        }
    }
    return $false
}

function Get-SearchRoots {
    param([string[]]$CustomPaths)

    if ($CustomPaths -and $CustomPaths.Count -gt 0) {
        return $CustomPaths
    }

    $roots = @()
    $userHome = $env:USERPROFILE
    if ($userHome) {
        $candidates = @("Projects", "Project", "Source", "Code", "Dev", "Workspace", "Repos")
        foreach ($name in $candidates) {
            $candidate = Join-Path $userHome $name
            if (Test-Path $candidate) {
                $roots += $candidate
            }
        }
        if ($roots.Count -eq 0) {
            $roots += $userHome
        }
    }
    return $roots
}

if ($Help) {
    Show-Help
    exit 0
}

if ($Paths -and $Paths.Count -eq 1 -and $Paths[0] -eq "True") {
    $Paths = @()
}
if (-not $Paths -or $Paths.Count -eq 0) {
    if ($args.Count -gt 0) {
        $Paths = $args
    }
}

Write-Host ""
Write-ColorMessage "Purge Project Artifacts" -Color Magenta
Write-Host ""

if ($DryRun) {
    Write-ColorMessage "DRY RUN MODE - No changes will be applied" -Color Yellow
    Write-Host ""
}

$targets = @(
    "node_modules", "bower_components", ".yarn", ".pnpm-store",
    "venv", ".venv", "virtualenv", "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".tox",
    "vendor", ".bundle",
    ".gradle", "out",
    "build", "dist", "target", ".next", ".nuxt", ".output", ".parcel-cache", ".turbo", ".vite", ".nx",
    "coverage", ".coverage", ".nyc_output",
    ".angular", ".svelte-kit", ".astro", ".docusaurus",
    "DerivedData", "Pods", ".build", "Carthage", ".dart_tool",
    ".terraform"
)

$roots = Get-SearchRoots -CustomPaths $Paths
if (-not $roots -or $roots.Count -eq 0) {
    Write-ColorMessage "No valid search roots found." -Color Yellow
    exit 0
}

Write-ColorMessage "Scanning:" -Color Cyan
foreach ($root in $roots) {
    Write-ColorMessage "  - $root" -Color DarkGray
}
Write-Host ""

$found = @()
foreach ($root in $roots) {
    if (-not (Test-Path $root)) {
        continue
    }
    $items = Get-ChildItem -Path $root -Directory -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $targets -contains $_.Name -and -not (Should-ExcludePath $_.FullName) }
    if ($items) {
        $found += $items
    }
}

if (-not $found -or $found.Count -eq 0) {
    Write-ColorMessage "No project artifacts found." -Color Yellow
    Write-Host ""
    exit 0
}

$unique = $found | Sort-Object -Property FullName -Unique
$details = @()
$totalBytes = 0

foreach ($item in $unique) {
    $size = Get-DirectorySizeBytes -Path $item.FullName
    $details += [pscustomobject]@{
        Path = $item.FullName
        Size = $size
    }
    $totalBytes += $size
}

$details = $details | Sort-Object -Property Size -Descending

Write-ColorMessage "Found $($details.Count) directories" -Color Cyan
Write-ColorMessage ("Estimated space: {0}" -f (Format-Bytes $totalBytes)) -Color Gray
Write-Host ""

$previewCount = [math]::Min(15, $details.Count)
for ($i = 0; $i -lt $previewCount; $i++) {
    $item = $details[$i]
    Write-ColorMessage ("{0,2}. {1} ({2})" -f ($i + 1), $item.Path, (Format-Bytes $item.Size)) -Color DarkGray
}
if ($details.Count -gt $previewCount) {
    Write-ColorMessage ("... and {0} more" -f ($details.Count - $previewCount)) -Color DarkGray
}
Write-Host ""

if ($DryRun) {
    Write-ColorMessage "Dry run complete." -Color Green
    Write-Host ""
    exit 0
}

if (-not (Confirm-Action "Delete these artifacts")) {
    Write-ColorMessage "Cancelled." -Color Yellow
    Write-Host ""
    exit 0
}

$removedCount = 0
$removedBytes = 0

foreach ($item in $details) {
    try {
        Remove-Item -Path $item.Path -Recurse -Force -ErrorAction SilentlyContinue
        $removedCount++
        $removedBytes += $item.Size
    } catch {
        Write-ColorMessage "Failed to remove $($item.Path)" -Color Yellow
    }
}

Write-Host ""
Write-ColorMessage "Purge complete" -Color Magenta
Write-ColorMessage ("Removed {0} directories, freed {1}" -f $removedCount, (Format-Bytes $removedBytes)) -Color Gray
Write-Host ""
