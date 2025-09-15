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
    if ! command_exists brew; then
        print_error "Homebrew is not installed!"
        echo "Please install Homebrew first by running:"
        echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        exit 1
    fi
    print_status "Homebrew is installed ✓"
}

# Function to install Hammerspoon
install_hammerspoon() {
    print_step "Installing Hammerspoon..."
    if brew list hammerspoon &>/dev/null; then
        print_status "Hammerspoon is already installed ✓"
    else
        brew install hammerspoon
        print_status "Hammerspoon installed successfully ✓"
    fi
}

# Function to clone the repository
clone_repository() {
    print_step "Setting up Hammerspoon configuration..."
    
    if [ -d "$HOME/.hammerspoon" ]; then
        print_warning "~/.hammerspoon directory already exists"
        read -p "Do you want to backup and replace it? (y/N): " -n 1 -r
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
    
    if command_exists fabric-ai; then
        print_status "Fabric AI is already installed ✓"
    else
        brew install fabric-ai
        print_status "Fabric AI installed successfully ✓"
    fi
    
    # Add alias to .zshrc if it doesn't exist
    if ! grep -q "alias fabric='fabric-ai'" ~/.zshrc 2>/dev/null; then
        echo "alias fabric='fabric-ai'" >> ~/.zshrc
        print_status "Added fabric alias to ~/.zshrc ✓"
    else
        print_status "Fabric alias already exists in ~/.zshrc ✓"
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
    read -p "Enable optional hotkey usage telemetry (writes local JSONL; can also POST to your server)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local username=""
        local server=""
        read -p "Telemetry username (optional): " username
        read -p "Telemetry server URL (optional, e.g. http://localhost:3000/api/hammerspoon/usage): " server
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

# Function to print next steps
print_next_steps() {
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Installation Complete! Next Steps:${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    
    echo -e "${BLUE}1. Grant Hammerspoon Accessibility Permissions:${NC}"
    echo "   - When prompted, grant Hammerspoon accessibility permissions in System Settings"
    echo "   - Go to System Settings > Privacy & Security > Accessibility"
    echo "   - Enable Hammerspoon if it's not already enabled"
    echo
    
    echo -e "${BLUE}2. Setup Fabric AI (Required for AI features):${NC}"
    echo "   - Open a new terminal window (to load the fabric alias)"
    echo "   - Run: fabric --setup"
    echo "   - Follow the prompts to set up your directories and API keys"
    echo
    
    echo -e "${BLUE}3. Get API Keys:${NC}"
    echo
    echo -e "${YELLOW}   Groq API Key (Free):${NC}"
    echo "   - Visit: https://console.groq.com/keys"
    echo "   - Login with your Google account"
    echo "   - Click 'Create API Key'"
    echo "   - Enter a name for your key"
    echo "   - Click 'Copy' to copy the API key"
    echo "   - Paste it into the Groq API key section when running 'fabric --setup'"
    echo
    
    echo -e "${YELLOW}   YouTube API Key (Optional, for YouTube features):${NC}"
    echo "   - Visit: https://console.cloud.google.com/marketplace/product/google/youtube.googleapis.com"
    echo "   - Click 'Enable' to enable the YouTube Data API v3"
    echo "   - Go to 'Credentials' in the left sidebar"
    echo "   - Click 'Create Credentials' and select 'API Key'"
    echo "   - Click 'Copy' to copy the API key"
    echo "   - Paste it into the YouTube API key section when running 'fabric --setup'"
    echo
    
    echo -e "${BLUE}4. Customize Your Configuration:${NC}"
    echo "   - Edit: ~/.hammerspoon/config_user.lua"
    echo "   - Update application definitions to match your installed apps"
    echo "   - Customize shortcuts to your preferences"
    echo
    
    echo -e "${BLUE}5. Reload Configuration:${NC}"
    echo "   - Press: ⌘⌃⌥⇧R (Command + Control + Option + Shift + R)"
    echo "   - Or restart Hammerspoon"
    echo
    
    echo -e "${GREEN}Quick Start Commands:${NC}"
    echo "   fabric --setup          # Setup Fabric AI with API keys"
    echo "   open ~/.hammerspoon/config_user.lua  # Edit configuration"
    echo
    
    echo -e "${GREEN}For more information, see the README.md file in ~/.hammerspoon/${NC}"
    echo
}

# Main installation process
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Hammerspoon Configuration Framework${NC}"
    echo -e "${GREEN}        Automated Installation${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    
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
    
    # Show next steps
    print_next_steps
}

# Run main function
main "$@" 