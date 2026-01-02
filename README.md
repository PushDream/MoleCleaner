<div align="center">
  <h1>MoleCleaner Windows</h1>
  <p><em>Deep clean and optimize your Windows PC.</em></p>
</div>

<p align="center">
  <a href="https://github.com/PushDream/MoleCleaner-Windows/stargazers"><img src="https://img.shields.io/github/stars/PushDream/MoleCleaner-Windows?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/PushDream/MoleCleaner-Windows/releases"><img src="https://img.shields.io/github/v/tag/PushDream/MoleCleaner-Windows?label=version&style=flat-square" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License"></a>
  <a href="https://github.com/PushDream/MoleCleaner-Windows/commits"><img src="https://img.shields.io/github/commit-activity/m/PushDream/MoleCleaner-Windows?style=flat-square" alt="Commits"></a>
</p>

## Features

- System cleanup for Windows temp files, caches, and browser data
- Application uninstaller with leftover cleanup
- System monitor (CPU, memory, disk, network, battery)
- Disk analyzer (interactive space explorer)
- Optimize tasks (DISM, SFC, DNS cache)
- Project purge for common build artifacts

## Quick Start (Windows)

1. Clone the repository:
   ```powershell
   git clone https://github.com/PushDream/MoleCleaner-Windows.git
   cd MoleCleaner-Windows
   ```

2. Run the installer as Administrator:
   ```powershell
   .\install-windows.ps1
   ```

3. Restart your terminal for PATH changes to take effect.

## Usage

```powershell
mole clean              # Deep clean your system
mole clean -DryRun       # Preview what would be cleaned
mole uninstall -List     # List installed apps
mole uninstall "Chrome"  # Uninstall an app and leftovers
mole status              # Show system status dashboard
mole analyze             # Explore disk usage
mole optimize            # Run maintenance tasks
mole purge -DryRun        # Find project artifacts
```

## Attribution

MoleCleaner Windows is based on the original macOS project by Tw93:
- https://github.com/tw93/mole

## License

MIT License - see LICENSE for details.
