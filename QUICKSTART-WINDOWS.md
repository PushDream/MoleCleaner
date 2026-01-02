# MoleCleaner for Windows - Quick Start Guide

## Installation (5 minutes)

### Option 1: Install (Recommended)

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/PushDream/MoleCleaner.git
   cd MoleCleaner
   ```

2. **Run the installer as Administrator:**
   - Right-click PowerShell
   - Select "Run as Administrator"
- Navigate to the MoleCleaner directory
   - Run: `.\install-windows.ps1`

3. **Restart your terminal** to use the `mole` command from anywhere

### Option 2: Run Without Installing

```powershell
git clone https://github.com/tw93/mole.git
cd mole
.\mole clean          # Use .\mole instead of just mole
```

The `mole.bat` launcher works from the repo directory without installation.

## Common Commands

### System Cleanup
```powershell
# Clean system (preview first)
mole clean -DryRun

# Actually clean
mole clean
```

### Uninstall Applications
```powershell
# List all installed apps
mole uninstall -List

# Uninstall an app
mole uninstall "Google Chrome"

# Preview uninstall
mole uninstall "Adobe Reader" -DryRun
```

### System Monitor
```powershell
# View real-time system stats
mole status

# Press 'q' to exit
```

## What Gets Cleaned?

- ✅ Windows temp files (5-20 GB typically)
- ✅ Browser caches (Chrome, Edge, Firefox)
- ✅ Developer caches (npm, pip, Gradle, Maven, NuGet)
- ✅ Application caches (Discord, Slack, Teams, Spotify)
- ✅ Thumbnail and icon cache
- ✅ Prefetch cache
- ✅ Windows Update downloads
- ✅ Recycle Bin

## Troubleshooting

### "Cannot be loaded because running scripts is disabled"
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Access denied" or "Insufficient permissions"
Run PowerShell as Administrator

### Status monitor not found
```powershell
.\scripts\build-status-windows.ps1
```

## Keyboard Shortcuts

### Status Monitor
- `q` or `Esc` - Exit
- `Ctrl+C` - Force quit

## Safety Tips

- ✅ Always use `-DryRun` first to preview
- ✅ Backup important data before major cleanups
- ✅ Review uninstall confirmations carefully
- ⚠️ Don't run during active development work
- ⚠️ Close applications before cleaning their caches

## Getting Help

```powershell
# Show all commands
mole help

# Get version info
mole version
```

For detailed information: [WINDOWS.md](WINDOWS.md)

## Typical Results

First-time cleanup usually recovers:
- 💾 **10-30 GB** on developer machines
- 💾 **5-15 GB** on regular user machines
- 💾 **20-50 GB** if you've never cleaned before

## Next Steps

1. Run `mole clean -DryRun` to see what can be cleaned
2. Review the list and run `mole clean` to free up space
3. Use `mole status` to monitor system health
4. Explore disk usage with `mole analyze`
5. Run `mole optimize` for maintenance checks
6. Use `mole purge -DryRun` to find heavy project artifacts
7. Check back monthly for best results

---

**Note:** The Windows version is actively being developed. New Windows parity commands are now available:
- Disk analyzer
- System optimization
- Project artifact cleanup
