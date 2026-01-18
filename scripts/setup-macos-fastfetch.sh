#!/bin/bash

# Enhanced macOS Fastfetch + Kitty Terminal Setup Script
# Replicates the HyDE terminal setup with comprehensive backup and failure recovery

set -eE  # Exit on error and inherit ERR trap

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables for state tracking
BACKUP_DIR="$HOME/.fastfetch-setup-backup-$(date +%Y%m%d_%H%M%S)"
TEMP_DIR="/tmp/fastfetch-setup-$$"
INSTALLATION_LOG="$HOME/.fastfetch-setup.log"
INSTALLED_PACKAGES=()
MODIFIED_FILES=()
CREATED_FILES=()
SETUP_FAILED=false

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$INSTALLATION_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$INSTALLATION_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$INSTALLATION_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$INSTALLATION_LOG"
}

log_debug() {
    echo -e "${CYAN}[DEBUG]${NC} $1" >> "$INSTALLATION_LOG"
}

# Backup and restore functions
create_backup() {
    local file_path="$1"
    local backup_name="$2"
    
    if [[ -f "$file_path" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp "$file_path" "$BACKUP_DIR/$backup_name"
        log_debug "Backed up $file_path to $BACKUP_DIR/$backup_name"
        return 0
    fi
    return 1
}

create_directory_backup() {
    local dir_path="$1"
    local backup_name="$2"
    
    if [[ -d "$dir_path" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$dir_path" "$BACKUP_DIR/$backup_name"
        log_debug "Backed up directory $dir_path to $BACKUP_DIR/$backup_name"
        return 0
    fi
    return 1
}

restore_backup() {
    local backup_name="$1"
    local target_path="$2"
    
    if [[ -f "$BACKUP_DIR/$backup_name" ]]; then
        cp "$BACKUP_DIR/$backup_name" "$target_path"
        log_debug "Restored $backup_name to $target_path"
        return 0
    elif [[ -d "$BACKUP_DIR/$backup_name" ]]; then
        rm -rf "$target_path"
        cp -r "$BACKUP_DIR/$backup_name" "$target_path"
        log_debug "Restored directory $backup_name to $target_path"
        return 0
    fi
    return 1
}

# Cleanup and rollback functions
cleanup_temp() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        log_debug "Cleaned up temporary directory: $TEMP_DIR"
    fi
}

rollback_installation() {
    log_warning "Rolling back installation due to failure..."
    
    # Restore backed up files
    for file in "${MODIFIED_FILES[@]}"; do
        case "$file" in
            "zshrc")
                restore_backup "zshrc.backup" "$HOME/.zshrc" && log_info "Restored .zshrc"
                ;;
            "zprofile")
                restore_backup "zprofile.backup" "$HOME/.zprofile" && log_info "Restored .zprofile"
                ;;
            "kitty_config")
                restore_backup "kitty" "$HOME/.config/kitty" && log_info "Restored Kitty configuration"
                ;;
            "fastfetch_config")
                restore_backup "fastfetch" "$HOME/.config/fastfetch" && log_info "Restored fastfetch configuration"
                ;;
        esac
    done
    
    # Remove created files
    for file in "${CREATED_FILES[@]}"; do
        if [[ -f "$file" ]] || [[ -d "$file" ]]; then
            rm -rf "$file"
            log_info "Removed created file/directory: $file"
        fi
    done
    
    # Uninstall packages if they were installed by this script
    if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then
        log_info "Uninstalling packages that were installed..."
        for package in "${INSTALLED_PACKAGES[@]}"; do
            case "$package" in
                "fastfetch")
                    brew uninstall fastfetch 2>/dev/null && log_info "Uninstalled fastfetch"
                    ;;
                "kitty")
                    brew uninstall --cask kitty 2>/dev/null && log_info "Uninstalled Kitty"
                    ;;
                "font-caskaydia-cove-nerd-font")
                    brew uninstall --cask font-caskaydia-cove-nerd-font 2>/dev/null && log_info "Uninstalled Nerd Font"
                    ;;
            esac
        done
    fi
    
    log_warning "Rollback completed. Check $INSTALLATION_LOG for details."
}

# Error handling
error_handler() {
    local exit_code=$?
    local line_number=$1
    
    log_error "Script failed at line $line_number with exit code $exit_code"
    SETUP_FAILED=true
    
    # Ask user if they want to rollback
    echo -e "${YELLOW}Setup failed. Would you like to rollback changes? (y/N): ${NC}"
    read -r response
    case "$response" in
        [yY]|[yY][eE][sS])
            rollback_installation
            ;;
        *)
            log_info "Rollback skipped. Manual cleanup may be required."
            log_info "Backup directory: $BACKUP_DIR"
            log_info "Installation log: $INSTALLATION_LOG"
            ;;
    esac
    
    cleanup_temp
    exit $exit_code
}

# Set up error handling
trap 'error_handler $LINENO' ERR
trap cleanup_temp EXIT

# Utility functions
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_package_installed() {
    local package="$1"
    brew list "$package" >/dev/null 2>&1
}

is_cask_installed() {
    local cask="$1"
    brew list --cask "$cask" >/dev/null 2>&1
}

# Pre-flight checks
preflight_checks() {
    log_info "Running pre-flight checks..."
    
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is designed for macOS only!"
        exit 1
    fi
    
    # Check available disk space (need at least 500MB)
    local available_space
    available_space=$(df -k "$HOME" | tail -1 | awk '{print $4}')
    if [[ $available_space -lt 512000 ]]; then
        log_error "Insufficient disk space. Need at least 500MB free."
        exit 1
    fi
    
    # Check network connectivity
    if ! ping -c 1 github.com >/dev/null 2>&1; then
        log_warning "No network connectivity detected. Some features may not work."
    fi
    
    # Create necessary directories
    mkdir -p "$TEMP_DIR"
    mkdir -p "$BACKUP_DIR"
    touch "$INSTALLATION_LOG"
    
    log_success "Pre-flight checks completed"
}

# Enhanced Homebrew installation
install_homebrew() {
    if command_exists brew; then
        log_success "Homebrew is already installed"
        return 0
    fi
    
    log_info "Installing Homebrew..."
    
    # Download and verify Homebrew installation script
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$TEMP_DIR/install_homebrew.sh"
    
    if [[ ! -f "$TEMP_DIR/install_homebrew.sh" ]]; then
        log_error "Failed to download Homebrew installation script"
        return 1
    fi
    
    # Run Homebrew installation
    /bin/bash "$TEMP_DIR/install_homebrew.sh" || {
        log_error "Homebrew installation failed"
        return 1
    }
    
    # Configure PATH for different Mac architectures
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        # Apple Silicon Mac
        create_backup "$HOME/.zprofile" "zprofile.backup"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
        MODIFIED_FILES+=("zprofile")
    elif [[ -f "/usr/local/bin/brew" ]]; then
        # Intel Mac
        create_backup "$HOME/.zprofile" "zprofile.backup"
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
        MODIFIED_FILES+=("zprofile")
    fi
    
    # Verify installation
    if command_exists brew; then
        log_success "Homebrew installed successfully"
        return 0
    else
        log_error "Homebrew installation verification failed"
        return 1
    fi
}

# Enhanced package installation with retry logic
install_package_with_retry() {
    local package_type="$1"  # "formula" or "cask"
    local package_name="$2"
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Installing $package_name (attempt $attempt/$max_attempts)..."
        
        if [[ "$package_type" == "cask" ]]; then
            if brew install --cask "$package_name" 2>/dev/null; then
                INSTALLED_PACKAGES+=("$package_name")
                log_success "$package_name installed successfully"
                return 0
            fi
        else
            if brew install "$package_name" 2>/dev/null; then
                INSTALLED_PACKAGES+=("$package_name")
                log_success "$package_name installed successfully"
                return 0
            fi
        fi
        
        log_warning "$package_name installation attempt $attempt failed"
        ((attempt++))
        
        if [[ $attempt -le $max_attempts ]]; then
            log_info "Waiting 5 seconds before retry..."
            sleep 5
        fi
    done
    
    log_error "Failed to install $package_name after $max_attempts attempts"
    return 1
}

# Enhanced package installation
install_packages() {
    log_info "Installing required packages..."
    
    # Update Homebrew
    log_info "Updating Homebrew..."
    brew update || log_warning "Homebrew update failed, continuing anyway..."
    
    # Install fastfetch
    if ! is_package_installed "fastfetch"; then
        install_package_with_retry "formula" "fastfetch" || return 1
    else
        log_info "fastfetch is already installed"
    fi
    
    # Install Kitty
    if ! is_cask_installed "kitty"; then
        install_package_with_retry "cask" "kitty" || return 1
    else
        log_info "Kitty is already installed"
    fi
    
    # Install Nerd Font
    if ! is_cask_installed "font-caskaydia-cove-nerd-font"; then
        install_package_with_retry "cask" "font-caskaydia-cove-nerd-font" || return 1
    else
        log_info "CaskaydiaCove Nerd Font is already installed"
    fi
    
    log_success "All packages installed successfully"
}

# Safe file operations
safe_create_file() {
    local file_path="$1"
    local content="$2"
    local backup_name="$3"
    
    # Create backup if file exists
    if [[ -f "$file_path" ]]; then
        create_backup "$file_path" "$backup_name"
    fi
    
    # Create directory if it doesn't exist
    local dir_path
    dir_path=$(dirname "$file_path")
    if [[ ! -d "$dir_path" ]]; then
        mkdir -p "$dir_path"
        CREATED_FILES+=("$dir_path")
    fi
    
    # Write content to file
    echo "$content" > "$file_path" || {
        log_error "Failed to create $file_path"
        return 1
    }
    
    CREATED_FILES+=("$file_path")
    log_debug "Created file: $file_path"
    return 0
}

# Enhanced configuration functions
configure_kitty_enhanced() {
    log_info "Configuring Kitty terminal..."
    
    # Backup existing Kitty configuration
    create_directory_backup "$HOME/.config/kitty" "kitty"
    MODIFIED_FILES+=("kitty_config")
    
    local kitty_config='# Font configuration
font_family CaskaydiaCove Nerd Font Mono
font_size 14.0
bold_font auto
italic_font auto
bold_italic_font auto

# Window settings
window_padding_width 25
hide_window_decorations titlebar-only
enable_audio_bell no

# Tab bar styling
tab_bar_edge bottom
tab_bar_style powerline
tab_powerline_style slanted
tab_title_template {title}{"'\'':{}:'\''.format(num_windows) if num_windows > 1 else '\'''\''"}

# Performance settings
repaint_delay 10
input_delay 3
sync_to_monitor yes

# HyDE-inspired dark blue theme
background #000b1e
foreground #0abdc6
cursor #0abdc6
cursor_trail 1
selection_background #1c61c2
selection_foreground #0abdc6

# Color palette matching your Linux setup
# Black, Gray
color0  #000b1e
color8  #1c61c2
color7  #0abdc6
color15 #0abdc6

# Red
color1  #ff0000
color9  #ff0000

# Green (Purple in your setup)
color2  #d300c4
color10 #d300c4

# Yellow
color3  #f57800
color11 #ff5780

# Blue
color4  #133e7c
color12 #00ff00

# Purple
color5  #711c91
color13 #711c91

# Teal
color6  #0abdc6
color14 #0abdc6'

    safe_create_file "$HOME/.config/kitty/kitty.conf" "$kitty_config" "kitty.conf.backup" || return 1
    log_success "Kitty configuration created"
}

# Enhanced logo download with fallback
download_logos_enhanced() {
    log_info "Setting up logos..."
    
    local logo_dir="$HOME/.config/fastfetch/logo"
    mkdir -p "$logo_dir"
    CREATED_FILES+=("$logo_dir")
    
    # Create ASCII fallback logo
    local ascii_logo="                    'c.
                 ,xNMM.
               .OMMMMo
               OMMM0,
     .;loddo:' loolloddol;.
   cKMMMMMMMMMMNWMMMMMMMMMM0:
 .KMMMMMMMMMMMMMMMMMMMMMMMWd.
 XMMMMMMMMMMMMMMMMMMMMMMMX.
;MMMMMMMMMMMMMMMMMMMMMMMM:
:MMMMMMMMMMMMMMMMMMMMMMMM:
.MMMMMMMMMMMMMMMMMMMMMMMMX.
 kMMMMMMMMMMMMMMMMMMMMMMMMWd.
 .XMMMMMMMMMMMMMMMMMMMMMMMMMMk
  .XMMMMMMMMMMMMMMMMMMMMMMMMK.
    kMMMMMMMMMMMMMMMMMMMMMMd
     ;KMMMMMMMWXXWMMMMMMMk.
       .cooc,.    .,coo:."

    safe_create_file "$logo_dir/macos.txt" "$ascii_logo" "" || return 1
    
    # Try to download better logos
    if command_exists curl; then
        log_info "Attempting to download additional logos..."
        
        # Array of logo URLs to try
        local logos=(
            "https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Apple_logo_black.svg/505px-Apple_logo_black.svg.png|apple-logo.png"
            "https://upload.wikimedia.org/wikipedia/commons/thumb/2/22/MacOS_logo_%282017%29.svg/512px-MacOS_logo_%282017%29.svg.png|macos-logo.png"
        )
        
        for logo_info in "${logos[@]}"; do
            local url="${logo_info%|*}"
            local filename="${logo_info#*|}"
            local filepath="$logo_dir/$filename"
            
            if curl -f -s -L --connect-timeout 10 -o "$filepath" "$url" 2>/dev/null; then
                log_success "Downloaded $filename"
                CREATED_FILES+=("$filepath")
            else
                log_warning "Failed to download $filename, skipping..."
            fi
        done
    fi
    
    log_success "Logo setup completed"
}

# Enhanced fastfetch configuration
configure_fastfetch_enhanced() {
    log_info "Configuring fastfetch..."
    
    # Backup existing fastfetch configuration
    create_directory_backup "$HOME/.config/fastfetch" "fastfetch"
    MODIFIED_FILES+=("fastfetch_config")
    
    local fastfetch_config='{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "source": "auto",
    "height": 18,
    "type": "kitty"
  },
  "display": {
    "separator": " : "
  },
  "modules": [
    {
      "type": "title",
      "key": "  ",
      "format": "{6}@{7} {8}",
      "keyColor": "blue"
    },
    {
      "type": "custom",
      "format": "┌──────────────────────────────────────────┐"
    },
    {
      "type": "os",
      "key": "  󰣇 OS",
      "format": "{2} {12}",
      "keyColor": "red"
    },
    {
      "type": "kernel",
      "key": "   Kernel",
      "format": "{2}",
      "keyColor": "red"
    },
    {
      "type": "packages",
      "key": "  󰏗 Packages",
      "keyColor": "green"
    },
    {
      "type": "display",
      "key": "  󰍹 Display",
      "format": "{1}x{2} @ {3}Hz",
      "keyColor": "green"
    },
    {
      "type": "terminal",
      "key": "   Terminal",
      "keyColor": "yellow"
    },
    {
      "type": "shell",
      "key": "   Shell",
      "format": "{1} {4}",
      "keyColor": "yellow"
    },
    {
      "type": "custom",
      "format": "└──────────────────────────────────────────┘"
    },
    "break",
    {
      "type": "title",
      "key": "  ",
      "format": "Hardware Information"
    },
    {
      "type": "custom",
      "format": "┌──────────────────────────────────────────┐"
    },
    {
      "type": "cpu",
      "format": "{1}",
      "key": "   CPU",
      "keyColor": "blue"
    },
    {
      "type": "gpu",
      "format": "{1} {2}",
      "key": "  󰊴 GPU",
      "keyColor": "blue"
    },
    {
      "type": "memory",
      "key": "   Memory",
      "keyColor": "magenta"
    },
    {
      "type": "disk",
      "key": "  󰋊 Storage",
      "folders": "/",
      "keyColor": "red",
      "format": "{1} / {2} ({3})"
    },
    {
      "type": "uptime",
      "key": "  󱫐 Uptime",
      "keyColor": "red"
    },
    {
      "type": "custom",
      "format": "└──────────────────────────────────────────┘"
    },
    {
      "type": "colors",
      "paddingLeft": 2,
      "symbol": "circle"
    },
    "break"
  ]
}'

    safe_create_file "$HOME/.config/fastfetch/config.jsonc" "$fastfetch_config" "config.jsonc.backup" || return 1
    log_success "Fastfetch configuration created"
}

# Enhanced shell configuration
configure_shell_enhanced() {
    log_info "Configuring shell startup..."
    
    # Create comprehensive backup
    create_backup "$HOME/.zshrc" "zshrc.backup"
    MODIFIED_FILES+=("zshrc")
    
    # Check if our configuration already exists
    if grep -q "# Fastfetch + Kitty Terminal Setup (HyDE-style)" "$HOME/.zshrc" 2>/dev/null; then
        log_warning "Configuration already exists in .zshrc, skipping shell configuration"
        return 0
    fi
    
    local shell_config='
# ============================================================
# Fastfetch + Kitty Terminal Setup (HyDE-style)
# Generated by setup script on '$(date)'
# ============================================================

# Function to check if terminal supports images
do_render_image() {
    local TERMINAL_IMAGE_SUPPORT=(kitty konsole ghostty WezTerm iTerm2)
    local terminal_no_art=(vscode code codium)
    local CURRENT_TERMINAL="${TERM_PROGRAM:-$(ps -o comm= -p $(ps -o ppid= -p $$) 2>/dev/null | sed '\''s/.*\///'\'' || echo "unknown")}"
    
    # Skip in certain terminals/environments
    for term in "${terminal_no_art[@]}"; do
        if [[ "$CURRENT_TERMINAL" == *"$term"* ]]; then
            return 1
        fi
    done
    
    # Check if current terminal supports images
    for terminal in "${TERMINAL_IMAGE_SUPPORT[@]}"; do
        if [[ "$CURRENT_TERMINAL" == *"$terminal"* ]]; then
            return 0
        fi
    done
    
    return 1
}

# Display system info on startup (only in interactive shells)
if [[ $- == *i* ]] && [[ -z "$TMUX" ]] && [[ -z "$VSCODE_INJECTION" ]] && [[ "$SHLVL" -eq 1 ]]; then
    if command -v fastfetch >/dev/null 2>&1; then
        if do_render_image; then
            fastfetch --logo-type kitty --config ~/.config/fastfetch/config.jsonc 2>/dev/null || fastfetch --logo-type kitty 2>/dev/null || fastfetch
        else
            fastfetch --config ~/.config/fastfetch/config.jsonc 2>/dev/null || fastfetch
        fi
    fi
fi

# Convenient aliases
alias ff='\''fastfetch --logo-type kitty --config ~/.config/fastfetch/config.jsonc 2>/dev/null || fastfetch --logo-type kitty'\''
alias fastfetch='\''fastfetch --logo-type kitty'\''
alias clear-and-fetch='\''clear && fastfetch --logo-type kitty'\''

# Add ~/.local/bin to PATH if it'\''s not already there
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# End of Fastfetch setup
# ============================================================
'

    echo "$shell_config" >> "$HOME/.zshrc" || {
        log_error "Failed to update .zshrc"
        return 1
    }
    
    log_success "Shell configuration updated"
}

# Create comprehensive uninstall script
create_enhanced_uninstall_script() {
    log_info "Creating enhanced uninstall script..."
    
    mkdir -p "$HOME/.local/bin"
    
    local uninstall_script='#!/bin/bash

# Enhanced uninstall script for macOS Fastfetch + Kitty setup

set -e

RED='\''\\033[0;31m'\''
GREEN='\''\\033[0;32m'\''
YELLOW='\''\\033[1;33m'\''
NC='\''\\033[0m'\''

log_info() {
    echo -e "\\033[0;34m[INFO]\\033[0m $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "Enhanced Fastfetch Setup Uninstaller"
echo "===================================="
echo

# Find the most recent backup
BACKUP_DIR=$(ls -1d ~/.fastfetch-setup-backup-* 2>/dev/null | tail -1)

if [[ -n "$BACKUP_DIR" ]] && [[ -d "$BACKUP_DIR" ]]; then
    log_info "Found backup directory: $BACKUP_DIR"
    
    # Restore configurations
    if [[ -f "$BACKUP_DIR/zshrc.backup" ]]; then
        log_info "Restoring .zshrc from backup..."
        cp "$BACKUP_DIR/zshrc.backup" ~/.zshrc
        log_success "Restored .zshrc"
    fi
    
    if [[ -f "$BACKUP_DIR/zprofile.backup" ]]; then
        log_info "Restoring .zprofile from backup..."
        cp "$BACKUP_DIR/zprofile.backup" ~/.zprofile
        log_success "Restored .zprofile"
    fi
    
    if [[ -d "$BACKUP_DIR/kitty" ]]; then
        log_info "Restoring Kitty configuration..."
        rm -rf ~/.config/kitty
        cp -r "$BACKUP_DIR/kitty" ~/.config/kitty
        log_success "Restored Kitty configuration"
    fi
    
    if [[ -d "$BACKUP_DIR/fastfetch" ]]; then
        log_info "Restoring fastfetch configuration..."
        rm -rf ~/.config/fastfetch
        cp -r "$BACKUP_DIR/fastfetch" ~/.config/fastfetch
        log_success "Restored fastfetch configuration"
    fi
else
    log_warning "No backup directory found."
    log_info "Removing configurations without backup restoration..."
    
    # Remove fastfetch configuration
    if [[ -d ~/.config/fastfetch ]]; then
        rm -rf ~/.config/fastfetch
        log_success "Removed fastfetch configuration"
    fi
    
    # Remove our additions from .zshrc
    if [[ -f ~/.zshrc ]]; then
        # Create a backup before modifying
        cp ~/.zshrc ~/.zshrc.uninstall-backup
        
        # Remove our configuration block
        sed -i.tmp '\''/# Fastfetch + Kitty Terminal Setup (HyDE-style)/,/# End of Fastfetch setup/d'\'' ~/.zshrc
        rm -f ~/.zshrc.tmp
        
        log_success "Removed fastfetch configuration from .zshrc"
        log_info "Backup created at ~/.zshrc.uninstall-backup"
    fi
fi

# Remove created scripts
rm -f ~/.local/bin/fastfetch-logo.sh
rm -f ~/.local/bin/uninstall-fastfetch-setup.sh

# Remove installation log
rm -f ~/.fastfetch-setup.log

log_success "Uninstall completed!"
echo
log_warning "The following packages were potentially installed and may need manual removal:"
echo "  • fastfetch: brew uninstall fastfetch"
echo "  • Kitty: brew uninstall --cask kitty"  
echo "  • Nerd Font: brew uninstall --cask font-caskaydia-cove-nerd-font"
echo
log_info "You may also want to remove backup directories:"
ls -1d ~/.fastfetch-setup-backup-* 2>/dev/null | head -5
echo
'

    safe_create_file "$HOME/.local/bin/uninstall-fastfetch-setup.sh" "$uninstall_script" "" || return 1
    chmod +x "$HOME/.local/bin/uninstall-fastfetch-setup.sh"
    
    log_success "Enhanced uninstall script created"
}

# Enhanced testing
comprehensive_test() {
    log_info "Running comprehensive tests..."
    
    local test_passed=0
    local test_total=0
    
    # Test fastfetch
    ((test_total++))
    if command_exists fastfetch; then
        log_success "✓ fastfetch command available"
        ((test_passed++))
    else
        log_error "✗ fastfetch command not found"
    fi
    
    # Test fastfetch configuration
    ((test_total++))
    if [[ -f "$HOME/.config/fastfetch/config.jsonc" ]]; then
        log_success "✓ fastfetch configuration exists"
        ((test_passed++))
    else
        log_error "✗ fastfetch configuration missing"
    fi
    
    # Test Kitty installation
    ((test_total++))
    if [[ -d "/Applications/kitty.app" ]] || command_exists kitty; then
        log_success "✓ Kitty terminal installed"
        ((test_passed++))
    else
        log_error "✗ Kitty terminal not found"
    fi
    
    # Test Kitty configuration
    ((test_total++))
    if [[ -f "$HOME/.config/kitty/kitty.conf" ]]; then
        log_success "✓ Kitty configuration exists"
        ((test_passed++))
    else
        log_error "✗ Kitty configuration missing"
    fi
    
    # Test shell configuration
    ((test_total++))
    if grep -q "do_render_image" "$HOME/.zshrc" 2>/dev/null; then
        log_success "✓ Shell configuration updated"
        ((test_passed++))
    else
        log_error "✗ Shell configuration missing"
    fi
    
    # Test logo directory
    ((test_total++))
    if [[ -d "$HOME/.config/fastfetch/logo" ]] && [[ -n "$(ls -A "$HOME/.config/fastfetch/logo" 2>/dev/null)" ]]; then
        log_success "✓ Logo directory exists with content"
        ((test_passed++))
    else
        log_warning "△ Logo directory empty or missing"
    fi
    
    # Test uninstall script
    ((test_total++))
    if [[ -x "$HOME/.local/bin/uninstall-fastfetch-setup.sh" ]]; then
        log_success "✓ Uninstall script created"
        ((test_passed++))
    else
        log_error "✗ Uninstall script missing"
    fi
    
    # Test actual fastfetch execution
    ((test_total++))
    if fastfetch --help >/dev/null 2>&1; then
        log_success "✓ fastfetch executes successfully"
        ((test_passed++))
    else
        log_error "✗ fastfetch execution failed"
    fi
    
    log_info "Tests completed: $test_passed/$test_total passed"
    
    if [[ $test_passed -eq $test_total ]]; then
        log_success "All tests passed!"
        return 0
    else
        log_warning "Some tests failed. Check the details above."
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════╗"
    echo "║     Enhanced macOS Fastfetch + Kitty Setup       ║"
    echo "║        With Comprehensive Backup & Recovery      ║"
    echo "╚═══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    log_info "Setup started at $(date)"
    log_info "Installation log: $INSTALLATION_LOG"
    log_info "Backup directory: $BACKUP_DIR"
    
    # Run setup steps
    preflight_checks
    install_homebrew
    install_packages
    configure_kitty_enhanced
    download_logos_enhanced
    configure_fastfetch_enhanced
    configure_shell_enhanced
    create_enhanced_uninstall_script
    comprehensive_test
    
    if [[ $SETUP_FAILED == false ]]; then
        echo -e "${GREEN}"
        echo "╔═══════════════════════════════════════════════════╗"
        echo "║            SETUP COMPLETED SUCCESSFULLY!         ║"
        echo "╚═══════════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        log_success "Enhanced setup completed successfully!"
        echo
        log_info "📁 Backup directory: $BACKUP_DIR"
        log_info "📋 Installation log: $INSTALLATION_LOG"
        echo
        log_info "🚀 Next steps:"
        echo "  1. Restart your terminal or run: source ~/.zshrc"
        echo "  2. Open Kitty terminal for the best experience"
        echo "  3. Try running: ff (alias for fastfetch)"
        echo "  4. Add your own logos to ~/.config/fastfetch/logo/"
        echo
        log_info "🗑️  To uninstall: ~/.local/bin/uninstall-fastfetch-setup.sh"
        echo
        log_success "Enjoy your new HyDE-style terminal setup!"
    fi
    
    cleanup_temp
}

# Run main function
main "$@"