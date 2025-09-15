#!/bin/bash

# Hammerspoon Configuration Framework - Automated Installation Script
# This script automates the installation process and guides you through setup

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Sudo-aware user resolution
IS_ROOT=0
if [ "$(id -u)" -eq 0 ]; then IS_ROOT=1; fi
TARGET_USER=${SUDO_USER:-$(id -un)}
TARGET_HOME=$(eval echo "~${TARGET_USER}")
RUN_AS_USER=()
if [ "$IS_ROOT" -eq 1 ]; then RUN_AS_USER=(sudo -u "$TARGET_USER" -H); fi

# Helper to append a literal line to a file if absent
append_line_if_absent() {
    local file="$1"; shift
    local line="$1"
    mkdir -p "$(dirname "$file")"
    if [ ! -f "$file" ] || ! grep -Fqx "$line" "$file" 2>/dev/null; then
        printf '%s\n' "$line" >> "$file"
    fi
}

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if Homebrew is installed
check_homebrew() {
    if command_exists brew; then
        print_status "Homebrew is installed ✓"
        return
    fi
    # Try common brew locations and add to current PATH
    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$('/opt/homebrew/bin/brew' shellenv)" || true
    elif [ -x "/usr/local/bin/brew" ]; then
        eval "$('/usr/local/bin/brew' shellenv)" || true
    fi
    if command_exists brew; then
        print_status "Homebrew found and added to PATH ✓"
        return
    fi
    print_warning "Homebrew is not installed. Installing now (this may take several minutes)..."
    "${RUN_AS_USER[@]}" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Persist brew path for future shells
    local brew_bin
    brew_bin=$(command -v brew || true)
    if [ -z "$brew_bin" ]; then
        brew_bin="/opt/homebrew/bin/brew"
    fi
    # Write literal shellenv eval so it runs in user shells
    local line_z='eval "$('"$brew_bin"' shellenv)"'
    append_line_if_absent "$TARGET_HOME/.zprofile" "$line_z"
    append_line_if_absent "$TARGET_HOME/.bash_profile" "$line_z"
    # Make brew available to this process
    if [ -x "$brew_bin" ]; then
        eval "$("$brew_bin" shellenv)" || true
        print_status "Homebrew installed and PATH configured ✓"
    else
        print_error "Failed to install Homebrew automatically. Please install manually from https://brew.sh and re-run."
        exit 1
    fi
}

# Function to install Hammerspoon
install_hammerspoon() {
    print_step "Installing Hammerspoon..."
    local brew_bin
    brew_bin=$(command -v brew || echo /opt/homebrew/bin/brew)
    if "$brew_bin" list hammerspoon &>/dev/null; then
        print_status "Hammerspoon is already installed ✓"
    else
        "${RUN_AS_USER[@]}" "$brew_bin" install hammerspoon
        print_status "Hammerspoon installed successfully ✓"
    fi
}

# Function to clone the repository
clone_repository() {
    print_step "Setting up Hammerspoon configuration..."
    
    if [ -d "$HOME/.hammerspoon" ]; then
        print_warning "~/.hammerspoon directory already exists"
        read -p "Do you want to backup and replace it? (y/N): " -n 1 -r </dev/tty
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mv "$HOME/.hammerspoon" "$HOME/.hammerspoon.backup.$(date +%Y%m%d_%H%M%S)"
            print_status "Existing configuration backed up"
        else
            print_error "Installation cancelled"
            exit 1
        fi
    fi
    
    git clone https://github.com/felixleopold/hammerspoon.git ~/.hammerspoon
    print_status "Repository cloned successfully ✓"
}

# Function to install Fabric AI
install_fabric() {
    print_step "Installing Fabric AI..."
    local brew_bin
    brew_bin=$(command -v brew || echo /opt/homebrew/bin/brew)
    if command_exists fabric-ai; then
        print_status "Fabric AI is already installed ✓"
    else
        "${RUN_AS_USER[@]}" "$brew_bin" install fabric-ai || true
        print_status "Fabric AI installed successfully ✓"
    fi
    
    # Ensure Homebrew shellenv is persisted so fabric is on PATH in new shells
    if [ -x "$brew_bin" ]; then
        local line_z='eval "$('"$brew_bin"' shellenv)"'
        append_line_if_absent "$TARGET_HOME/.zprofile" "$line_z"
    fi
    # Add alias to .zshrc if it doesn't exist
    if ! grep -q "alias fabric='fabric-ai'" "$TARGET_HOME/.zshrc" 2>/dev/null; then
        "${RUN_AS_USER[@]}" /bin/sh -c "printf '%s\n' \"alias fabric='fabric-ai'\" >> '$TARGET_HOME/.zshrc'"
        print_status "Added fabric alias to $TARGET_HOME/.zshrc ✓"
    else
        print_status "Fabric alias already exists in $TARGET_HOME/.zshrc ✓"
    fi
}

# Function to setup fabric patterns
setup_fabric_patterns() {
    print_step "Setting up Fabric patterns..."
    
    # Create fabric config directory if it doesn't exist
    mkdir -p ~/.config/fabric/patterns
    
    # Copy patterns from the repository
    if [ -d "$HOME/.hammerspoon/fabric-patterns" ]; then
        rsync -a ~/.hammerspoon/fabric-patterns/ ~/.config/fabric/patterns/
        rm -rf ~/.hammerspoon/fabric-patterns
        print_status "Fabric patterns installed successfully ✓"
    else
        print_warning "No fabric-patterns directory found in repository"
    fi
}

# Function to create user configuration
setup_user_config() {
    print_step "Setting up user configuration..."
    
    if [ ! -f "$HOME/.hammerspoon/config_user.lua" ]; then
        cp ~/.hammerspoon/config_user.lua.template ~/.hammerspoon/config_user.lua
        print_status "User configuration file created ✓"
    else
        print_status "User configuration file already exists ✓"
    fi
}

# Function to configure optional telemetry
configure_telemetry() {
    print_step "Telemetry (optional)"
    local cfg="$HOME/.hammerspoon/config_user.lua"
    read -p "Enable optional hotkey usage telemetry (writes local JSONL; can also POST to your server)? (y/N): " -n 1 -r </dev/tty
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local username=""
        local server=""
        read -p "Telemetry username (optional): " username </dev/tty
        read -p "Telemetry server URL (optional, e.g. http://localhost:3000/api/hammerspoon/usage): " server </dev/tty
        # Insert telemetry block before return defaults if present
        if grep -q "return defaults" "$cfg"; then
            tmpfile="$(mktemp)"
            awk -v u="$username" -v s="$server" '
                BEGIN {inserted=0}
                /return defaults/ && inserted==0 {
                    print "    telemetry = {";
                    print "        enabled = true,";
                    if (length(u)>0) { printf "        username = \"%s\",\n", u } else { print "        username = nil," }
                    if (length(s)>0) { printf "        serverUrl = \"%s\",\n", s } else { print "        serverUrl = nil," }
                    print "        includeAppName = true,";
                    print "    },";
                    inserted=1
                }
                { print }
            ' "$cfg" > "$tmpfile" && mv "$tmpfile" "$cfg"
        else
            cat >> "$cfg" <<EOF
defaults.telemetry = {
    enabled = true,
    username = ${username:+"$username"},
    serverUrl = ${server:+"$server"},
}
EOF
        fi
        print_status "Telemetry enabled in config_user.lua"
    else
        print_status "Telemetry not enabled"
    fi
}

# Function to launch Hammerspoon
launch_hammerspoon() {
    print_step "Launching Hammerspoon..."
    open -a Hammerspoon
    print_status "Hammerspoon launched ✓"
}

# Function to guide and wait for user actions interactively
interactive_followups() {
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Installation Complete! Finalizing...${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo

    # Launch Hammerspoon
    print_step "Launching Hammerspoon..."
    "${RUN_AS_USER[@]}" open -a Hammerspoon || true

    # Open Accessibility pane for granting permissions
    print_step "Opening Accessibility settings..."
    "${RUN_AS_USER[@]}" open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
    read -r -p "Enable Hammerspoon in Accessibility, then press Enter to continue..." _ </dev/tty || true

    # Open README sections with screenshots for API keys
    print_step "Opening README sections for API keys and setup (with screenshots)..."
    "${RUN_AS_USER[@]}" open "https://github.com/felixleopold/hammerspoon/blob/config/README.md#fabric-ai-setup" || true
    "${RUN_AS_USER[@]}" open "https://github.com/felixleopold/hammerspoon/blob/config/README.md#get-required-api-keys" || true

    # Prompt user to run fabric --setup (new terminal recommended)
    echo
    print_status "Open a new terminal so the 'fabric' alias is active."
    read -r -p "Then run 'fabric --setup' and complete prompts. Press Enter here when done..." _ </dev/tty || true

    print_status "You can edit your config at ~/.hammerspoon/config_user.lua and reload with ⌘⌃⌥⇧R."
}

# Main installation process
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Hammerspoon Configuration Framework${NC}"
    echo -e "${GREEN}        Automated Installation${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo "This script will:"
    echo "- Ensure Homebrew is installed and in your PATH"
    echo "- Install Hammerspoon and Fabric"
    echo "- Clone this repo to ~/.hammerspoon"
    echo "- Create a user config if missing"
    echo "- Launch Hammerspoon and guide final steps"
    echo
    # Support non-interactive override via AUTO_YES or YES
    if [ "${AUTO_YES:-}" = "1" ] || [ "${YES:-}" = "1" ]; then
        ans="y"
    else
        read -r -p "Proceed? [y/N]: " ans </dev/tty || true
    fi
    if [[ ! "$ans" =~ ^[Yy]$ ]]; then
        print_error "Installation cancelled"
        exit 1
    fi
    
    # Check prerequisites
    check_homebrew
    
    # Install components
    install_hammerspoon
    clone_repository
    install_fabric
    setup_fabric_patterns
    setup_user_config
    configure_telemetry
    launch_hammerspoon
    
    # Interactive follow-ups and waits
    interactive_followups
}

# Run main function
main "$@" 