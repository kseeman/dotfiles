# Scripts

This directory contains utility scripts for setting up development environments and configurations.

## setup-macos-fastfetch.sh

**Enhanced macOS Terminal Setup Script**

Replicates the HyDE (Hyprland Desktop Environment) fastfetch + Kitty terminal setup on macOS with comprehensive backup and failure recovery.

### Features

- 🎨 **Exact color matching** - Replicates HyDE's dark blue theme
- 🖼️ **Image support** - Displays logos alongside system information  
- 📊 **System information** - Shows CPU, GPU, memory, storage, uptime
- 🛡️ **Comprehensive backups** - Timestamped backups with full rollback capability
- 🔄 **Retry logic** - Automatically retries failed package installations
- 🚨 **Error handling** - Interactive rollback on failure
- 🧪 **Testing suite** - 8-point validation of successful installation
- 🗑️ **Easy uninstall** - Complete removal with backup restoration

### What it installs

- **Homebrew** (if not present)
- **fastfetch** - System information tool
- **Kitty Terminal** - Terminal with image protocol support
- **CaskaydiaCove Nerd Font** - For proper icon rendering

### What it configures

- **Kitty terminal** - Color theme, fonts, window settings
- **fastfetch** - System info layout matching HyDE style
- **Shell startup** - Automatic fastfetch display on new terminal sessions
- **Aliases** - Convenient shortcuts (`ff`, `clear-and-fetch`)

### Usage

```bash
# Download or copy the script to your Mac
./scripts/setup-macos-fastfetch.sh
```

### Safety Features

- **Pre-flight checks** - Validates macOS, disk space, network
- **Comprehensive backups** - All modified files backed up with timestamps
- **State tracking** - Tracks installed packages, modified files, created files
- **Interactive rollback** - Option to undo all changes on failure
- **Installation logging** - Complete log of all actions
- **Safe file operations** - Atomic file operations with validation

### Files Modified/Created

- `~/.config/kitty/kitty.conf` - Kitty terminal configuration
- `~/.config/fastfetch/config.jsonc` - fastfetch system info layout
- `~/.config/fastfetch/logo/` - Logo images directory
- `~/.zshrc` - Shell configuration (appended, not replaced)
- `~/.zprofile` - Homebrew PATH setup (if needed)
- `~/.local/bin/uninstall-fastfetch-setup.sh` - Uninstall script

### Backup & Recovery

- **Backup location**: `~/.fastfetch-setup-backup-YYYYMMDD_HHMMSS/`
- **Installation log**: `~/.fastfetch-setup.log`
- **Uninstall**: `~/.local/bin/uninstall-fastfetch-setup.sh`

### Requirements

- macOS (any recent version)
- 500MB+ free disk space
- Internet connection (for package downloads)
- Terminal access

### Troubleshooting

If the script fails:
1. Check `~/.fastfetch-setup.log` for detailed error information
2. Run the uninstall script to restore backups: `~/.local/bin/uninstall-fastfetch-setup.sh`
3. Backup directory contains all original files if manual restoration is needed

The script is designed to be completely safe - it can restore your system to exactly the state it was in before running.