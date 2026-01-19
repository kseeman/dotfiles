#!/bin/bash

# Enhanced macOS Fastfetch + Kitty Terminal Setup Script with Oh-My-Zsh
# Replicates the HyDE terminal setup with comprehensive backup and failure recovery
# Now includes oh-my-zsh integration similar to your Linux configuration

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
            "oh_my_zsh")
                restore_backup "oh-my-zsh" "$HOME/.oh-my-zsh" && log_info "Restored Oh-My-Zsh"
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

# Install Oh-My-Zsh
install_oh_my_zsh() {
    log_info "Setting up Oh-My-Zsh..."
    
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        log_success "Oh-My-Zsh is already installed"
        return 0
    fi
    
    # Backup existing oh-my-zsh if it exists
    create_directory_backup "$HOME/.oh-my-zsh" "oh-my-zsh"
    MODIFIED_FILES+=("oh_my_zsh")
    
    # Download and install Oh-My-Zsh
    curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$TEMP_DIR/install_omz.sh"
    
    if [[ ! -f "$TEMP_DIR/install_omz.sh" ]]; then
        log_error "Failed to download Oh-My-Zsh installation script"
        return 1
    fi
    
    # Install Oh-My-Zsh in unattended mode
    RUNZSH=no CHSH=no sh "$TEMP_DIR/install_omz.sh" || {
        log_error "Oh-My-Zsh installation failed"
        return 1
    }
    
    log_success "Oh-My-Zsh installed successfully"
}

# Install Oh-My-Zsh plugins
install_omz_plugins() {
    log_info "Installing Oh-My-Zsh plugins..."
    
    local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
    mkdir -p "$plugins_dir"
    
    # Install zsh-autosuggestions
    if [[ ! -d "$plugins_dir/zsh-autosuggestions" ]]; then
        log_info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions" || {
            log_warning "Failed to install zsh-autosuggestions"
        }
        CREATED_FILES+=("$plugins_dir/zsh-autosuggestions")
    else
        log_info "zsh-autosuggestions already installed"
    fi
    
    # Install zsh-syntax-highlighting
    if [[ ! -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
        log_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$plugins_dir/zsh-syntax-highlighting" || {
            log_warning "Failed to install zsh-syntax-highlighting"
        }
        CREATED_FILES+=("$plugins_dir/zsh-syntax-highlighting")
    else
        log_info "zsh-syntax-highlighting already installed"
    fi
    
    log_success "Oh-My-Zsh plugins installation completed"
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
    
    # Create hyde.conf similar to your Linux setup
    local hyde_config='# Font configuration
font_family CaskaydiaCove Nerd Font Mono
bold_font auto
italic_font auto
bold_italic_font auto
enable_audio_bell no
font_size 14.0
window_padding_width 25
cursor_trail 1

# Include theme configuration
include theme.conf'

    safe_create_file "$HOME/.config/kitty/hyde.conf" "$hyde_config" "hyde.conf.backup" || return 1
    
    # Create main kitty.conf that includes hyde.conf
    local kitty_config='include hyde.conf

# Minimal Tab bar styling 
tab_bar_edge                bottom
tab_bar_style               powerline
tab_powerline_style         slanted
tab_title_template          {title}{"'"'"' :{}:'"'"'".format(num_windows) if num_windows > 1 else "'"'"''"'"'"}

# Performance settings (optimized for macOS)
repaint_delay 10
input_delay 3
sync_to_monitor yes'

    safe_create_file "$HOME/.config/kitty/kitty.conf" "$kitty_config" "kitty.conf.backup" || return 1
    
    # Create theme.conf with HyDE-inspired colors
    local theme_config='# HyDE-inspired dark blue theme for macOS
background #000b1e
foreground #0abdc6
cursor #0abdc6
cursor_text_color #000b1e
selection_background #1c61c2
selection_foreground #0abdc6
url_color #0abdc6

# Black and Gray
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

    safe_create_file "$HOME/.config/kitty/theme.conf" "$theme_config" "theme.conf.backup" || return 1
    
    log_success "Kitty configuration created with HyDE-style theme"
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
    "type": "kitty-icat",
    "source": "auto",
    "width": 30,
    "height": 18,
    "preserveAspectRatio": true
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

# Function to check if terminal supports images (similar to HyDE setup)
create_terminal_functions() {
    log_info "Creating terminal helper functions..."
    
    mkdir -p "$HOME/.local/bin"
    
    local functions_script='#!/usr/bin/env zsh

# Function to check if terminal supports images (similar to HyDE)
do_render() {
    local type="${1:-image}"
    local TERMINAL_IMAGE_SUPPORT=(kitty konsole ghostty WezTerm iTerm2)
    local terminal_no_art=(vscode code codium)
    local TERMINAL_NO_ART="${TERMINAL_NO_ART:-${terminal_no_art[@]}}"
    local CURRENT_TERMINAL="${TERM_PROGRAM:-$(ps -o comm= -p $(ps -o ppid= -p $$) 2>/dev/null | sed '"'"'s/.*\///'"'"' || echo "unknown")}"

    case "${type}" in
    image)
        if [[ " ${TERMINAL_IMAGE_SUPPORT[@]} " =~ " ${CURRENT_TERMINAL} " ]]; then
            return 0
        else
            return 1
        fi
        ;;
    art)
        if [[ " ${TERMINAL_NO_ART[@]} " =~ " ${CURRENT_TERMINAL} " ]]; then
            return 1
        else
            return 0
        fi
        ;;
    *)
        return 1
        ;;
    esac
}

# Smart fastfetch function similar to HyDE user.zsh
smart_fastfetch() {
    if [[ $- == *i* ]]; then
        if command -v fastfetch >/dev/null; then
            if do_render "image"; then
                fastfetch --logo-type kitty --config ~/.config/fastfetch/config.jsonc
            else
                fastfetch --config ~/.config/fastfetch/config.jsonc
            fi
        fi
    fi
}'

    safe_create_file "$HOME/.local/bin/terminal-functions.sh" "$functions_script" "" || return 1
    chmod +x "$HOME/.local/bin/terminal-functions.sh"
    
    log_success "Terminal helper functions created"
}

# Enhanced shell configuration with Oh-My-Zsh integration
configure_shell_enhanced() {
    log_info "Configuring shell with Oh-My-Zsh integration..."
    
    # Create comprehensive backup
    create_backup "$HOME/.zshrc" "zshrc.backup"
    MODIFIED_FILES+=("zshrc")
    
    # Create a new .zshrc similar to your Linux setup but adapted for macOS
    local zshrc_config='# Path to your oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="robbyrussell"

# Which plugins would you like to load?
plugins=(
    git
    macos
    brew
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# User configuration
# Add ~/.local/bin to PATH if it'"'"'s not already there
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# ZSH Autosuggestion configuration (similar to HyDE)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
export ZSH_AUTOSUGGEST_STRATEGY

# History configuration (similar to HyDE)
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

# Source terminal functions
[[ -f "$HOME/.local/bin/terminal-functions.sh" ]] && source "$HOME/.local/bin/terminal-functions.sh"

# Startup fastfetch (similar to HyDE user.zsh)
if [[ $- == *i* ]] && [[ -z "$TMUX" ]] && [[ -z "$VSCODE_INJECTION" ]] && [[ "$SHLVL" -eq 1 ]]; then
    smart_fastfetch
fi

# Aliases (similar to HyDE terminal.zsh)
alias c='"'"'clear'"'"'
alias fastfetch='"'"'fastfetch --logo-type kitty'"'"'
alias ..='"'"'cd ..'"'"'
alias ...='"'"'cd ../..'"'"'
alias .3='"'"'cd ../../..'"'"'
alias .4='"'"'cd ../../../..'"'"'
alias .5='"'"'cd ../../../../..'"'"'
alias mkdir='"'"'mkdir -p'"'"'

# macOS specific aliases
alias brew-update='"'"'brew update && brew upgrade && brew cleanup'"'"'
alias show-hidden='"'"'defaults write com.apple.finder AppleShowAllFiles YES; killall Finder'"'"'
alias hide-hidden='"'"'defaults write com.apple.finder AppleShowAllFiles NO; killall Finder'"'"'

# Enable completions
autoload -Uz compinit
compinit

# Make tab completion case-insensitive
zstyle '"'"':completion:*'"'"' matcher-list '"'"'m:{a-zA-Z}={A-Za-z}'"'"'

# Enable colored output for ls
if [[ -x /usr/local/bin/gls ]]; then
    alias ls='"'"'gls --color=auto'"'"'
elif [[ "$OSTYPE" == darwin* ]]; then
    alias ls='"'"'ls -G'"'"'
fi'

    safe_create_file "$HOME/.zshrc" "$zshrc_config" "" || return 1
    log_success "Shell configuration updated with Oh-My-Zsh integration"
}

# Create comprehensive uninstall script
create_enhanced_uninstall_script() {
    log_info "Creating enhanced uninstall script..."
    
    mkdir -p "$HOME/.local/bin"
    
    local uninstall_script='#!/bin/bash

# Enhanced uninstall script for macOS Fastfetch + Kitty + Oh-My-Zsh setup

set -e

RED='"'"'\033[0;31m'"'"'
GREEN='"'"'\033[0;32m'"'"'
YELLOW='"'"'\033[1;33m'"'"'
NC='"'"'\033[0m'"'"'

log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
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

echo "Enhanced Fastfetch + Oh-My-Zsh Setup Uninstaller"
echo "==============================================="
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
    
    if [[ -d "$BACKUP_DIR/oh-my-zsh" ]]; then
        log_info "Restoring Oh-My-Zsh configuration..."
        rm -rf ~/.oh-my-zsh
        cp -r "$BACKUP_DIR/oh-my-zsh" ~/.oh-my-zsh
        log_success "Restored Oh-My-Zsh configuration"
    fi
else
    log_warning "No backup directory found."
    log_info "Removing configurations without backup restoration..."
    
    # Remove configurations
    [[ -d ~/.config/fastfetch ]] && rm -rf ~/.config/fastfetch && log_success "Removed fastfetch configuration"
    [[ -d ~/.config/kitty ]] && rm -rf ~/.config/kitty && log_success "Removed Kitty configuration"
    
    # Offer to remove Oh-My-Zsh
    echo -e "${YELLOW}Remove Oh-My-Zsh installation? (y/N): ${NC}"
    read -r response
    case "$response" in
        [yY]|[yY][eE][sS])
            [[ -d ~/.oh-my-zsh ]] && rm -rf ~/.oh-my-zsh && log_success "Removed Oh-My-Zsh"
            ;;
        *)
            log_info "Keeping Oh-My-Zsh installation"
            ;;
    esac
fi

# Remove created scripts
rm -f ~/.local/bin/terminal-functions.sh
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
echo'

    safe_create_file "$HOME/.local/bin/uninstall-fastfetch-setup.sh" "$uninstall_script" "" || return 1
    chmod +x "$HOME/.local/bin/uninstall-fastfetch-setup.sh"
    
    log_success "Enhanced uninstall script created"
}

# Enhanced testing
comprehensive_test() {
    log_info "Running comprehensive tests..."
    
    local test_passed=0
    local test_total=0
    
    # Test Oh-My-Zsh installation
    ((test_total++))
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        log_success "✓ Oh-My-Zsh installed"
        ((test_passed++))
    else
        log_error "✗ Oh-My-Zsh not found"
    fi
    
    # Test zsh-autosuggestions plugin
    ((test_total++))
    if [[ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]]; then
        log_success "✓ zsh-autosuggestions plugin installed"
        ((test_passed++))
    else
        log_error "✗ zsh-autosuggestions plugin missing"
    fi
    
    # Test zsh-syntax-highlighting plugin
    ((test_total++))
    if [[ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]]; then
        log_success "✓ zsh-syntax-highlighting plugin installed"
        ((test_passed++))
    else
        log_error "✗ zsh-syntax-highlighting plugin missing"
    fi
    
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
    if grep -q "smart_fastfetch" "$HOME/.zshrc" 2>/dev/null; then
        log_success "✓ Shell configuration updated"
        ((test_passed++))
    else
        log_error "✗ Shell configuration missing"
    fi
    
    # Test terminal functions
    ((test_total++))
    if [[ -x "$HOME/.local/bin/terminal-functions.sh" ]]; then
        log_success "✓ Terminal functions script created"
        ((test_passed++))
    else
        log_error "✗ Terminal functions script missing"
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
    echo "║  Enhanced macOS Fastfetch + Kitty + Oh-My-Zsh    ║"
    echo "║        With HyDE-style Configuration Management   ║"
    echo "╚═══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    log_info "Setup started at $(date)"
    log_info "Installation log: $INSTALLATION_LOG"
    log_info "Backup directory: $BACKUP_DIR"
    
    # Run setup steps
    preflight_checks
    install_homebrew
    install_oh_my_zsh
    install_omz_plugins
    install_packages
    configure_kitty_enhanced
    configure_fastfetch_enhanced
    create_terminal_functions
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
        echo "  2. Open Kitty terminal for the best experience with images"
        echo "  3. fastfetch will run automatically on new shell sessions"
        echo "  4. Oh-My-Zsh is configured with autosuggestions and syntax highlighting"
        echo "  5. HyDE-style aliases and functions are available"
        echo
        log_info "🗑️  To uninstall: ~/.local/bin/uninstall-fastfetch-setup.sh"
        echo
        log_success "Enjoy your new HyDE-style macOS terminal setup!"
    fi
    
    cleanup_temp
}

# Run main function
main "$@"