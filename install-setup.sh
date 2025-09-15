#!/bin/bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
MAGENTA='\033[0;35m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Clear input cue to make it obvious the script is waiting for user input
need_input() { echo -e "${MAGENTA}[INPUT]${NC} $1" > /dev/tty 2>/dev/null || echo "$1"; }

CONFIG_CREATED=0

# Determine the real target user and home, even if invoked with sudo
IS_ROOT=0
if [ "$(id -u)" -eq 0 ]; then
	IS_ROOT=1
fi
TARGET_USER=${SUDO_USER:-$(id -un)}
# Resolve target user's home reliably
TARGET_HOME=$(eval echo "~${TARGET_USER}")
# Run commands as the target user, preserving HOME
RUN_AS_USER=""
if [ "$IS_ROOT" -eq 1 ]; then
	RUN_AS_USER=(sudo -u "$TARGET_USER" -H)
fi

# Append a line to a file if it's not already present
append_line_if_absent() {
	local file="$1"
	local line="$2"
	mkdir -p "$(dirname "$file")"
	if [ ! -f "$file" ] || ! grep -Fqx "$line" "$file" 2>/dev/null; then
		printf '%s\n' "$line" >> "$file"
		info "Updated ${file}"
	fi
}

# Ensure brew is available in PATH for this process and future shells
ensure_brew_path_now() {
	if command -v brew >/dev/null 2>&1; then
		return 0
	fi
	# Common locations
	if [ -x "/opt/homebrew/bin/brew" ]; then
		eval "$('/opt/homebrew/bin/brew' shellenv)" || true
	elif [ -x "/usr/local/bin/brew" ]; then
		eval "$('/usr/local/bin/brew' shellenv)" || true
	fi
}

persist_brew_shellenv() {
	# Prefer zsh on modern macOS; also update bash profile for completeness
	local brew_bin
	brew_bin=$(command -v brew || true)
	if [ -z "$brew_bin" ]; then
		# Assume Apple Silicon default if not yet on PATH
		brew_bin="/opt/homebrew/bin/brew"
	fi
	local line="eval \"$($brew_bin shellenv 2>/dev/null || echo '/opt/homebrew/bin/brew shellenv')\""
	# Write to the target user's profiles
	append_line_if_absent "$TARGET_HOME/.zprofile" "$line"
	append_line_if_absent "$TARGET_HOME/.bash_profile" "$line"
}

confirm() {
	local prompt="$1"
	local default="${2:-yes}"
	local ans=""
	# Allow non-interactive override
	if [ "${AUTO_YES:-}" = "1" ] || [ "${YES:-}" = "1" ]; then
		return 0
	fi
	local hint="[Y/n]"
	[ "$default" = "no" ] && hint="[y/N]"
	if [ -r /dev/tty ] && [ -w /dev/tty ]; then
		printf "%s %s " "$prompt" "$hint" > /dev/tty
		IFS= read -r ans < /dev/tty || true
	else
		IFS= read -r ans || true
	fi
	if [ -z "$ans" ]; then
		[ "$default" = "yes" ] && return 0 || return 1
	fi
	[[ "$ans" =~ ^[Yy]$ ]]
}

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		err "Missing required command: $1"
		return 1
	fi
}

install_homebrew() {
	if command -v brew >/dev/null 2>&1; then
		info "Homebrew is already installed"
		return
	fi
	step "Installing Homebrew (this can take several minutes)"
	"${RUN_AS_USER[@]}" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	# Make brew available now and for future shells
	ensure_brew_path_now || true
	"${RUN_AS_USER[@]}" bash -lc 'eval "$(brew shellenv)" >/dev/null 2>&1 || true'
	persist_brew_shellenv
	info "Homebrew installed and PATH configured"
}

install_pkg() {
	local pkg="$1"
	ensure_brew_path_now || true
	if brew list --formula "$pkg" >/dev/null 2>&1 || brew list --cask "$pkg" >/dev/null 2>&1; then
		info "$pkg already installed"
		return
	fi
	step "Installing $pkg (this may take a moment)"
	if brew info --cask "$pkg" >/dev/null 2>&1; then
		"${RUN_AS_USER[@]}" brew install --cask "$pkg"
	else
		"${RUN_AS_USER[@]}" brew install "$pkg"
	fi
}

backup_dir() {
	local path="$1"
	if [ -e "$path" ]; then
		local ts
		ts="$(date +%Y%m%d_%H%M%S)"
		local backup="${path}.backup.${ts}"
		mv "$path" "$backup"
		info "Backed up ${path} -> ${backup}"
	fi
}

clone_repo() {
	local dest="$TARGET_HOME/.hammerspoon"
	local repo="https://github.com/felixleopold/hammerspoon.git"
	if [ -d "$dest/.git" ]; then
		info "Repository already present in $dest"
		return
	fi
	if [ -d "$dest" ]; then
		warn "$dest exists"
		if confirm "Backup and replace existing ~/.hammerspoon?" no; then
			backup_dir "$dest"
		else
			err "Cancelled by user"
			exit 1
		fi
	fi
	"${RUN_AS_USER[@]}" git clone "$repo" "$dest"
	info "Cloned repository"
}

ensure_user_config() {
	local tpl="$TARGET_HOME/.hammerspoon/config_user.lua.template"
	local cfg="$TARGET_HOME/.hammerspoon/config_user.lua"
	if [ ! -f "$cfg" ]; then
		"${RUN_AS_USER[@]}" cp "$tpl" "$cfg"
		info "Created user config from template"
		CONFIG_CREATED=1
	fi
}

set_app_defaults() {
	local cfg="$TARGET_HOME/.hammerspoon/config_user.lua"
	step "Configuring app defaults"
	need_input "Primary Browser [Safari/Chrome/Arc/Brave] (default: Safari):"
	read -r -p "> " primary_browser </dev/tty || true
	primary_browser=${primary_browser:-Safari}
	need_input "Secondary Browser (default: Chrome):"
	read -r -p "> " secondary_browser </dev/tty || true
	secondary_browser=${secondary_browser:-Chrome}
	need_input "Code Editor [Visual Studio Code/Sublime Text] (default: Visual Studio Code):"
	read -r -p "> " editor </dev/tty || true
	editor=${editor:-Visual Studio Code}
	need_input "Terminal [Terminal/iTerm] (default: Terminal):"
	read -r -p "> " terminal </dev/tty || true
	terminal=${terminal:-Terminal}

	# Detect Fabric binary to set path override (optional)
	local fabpath=""
	if command -v fabric-ai >/dev/null 2>&1; then
		fabpath="$(command -v fabric-ai)"
	elif command -v fabric >/dev/null 2>&1; then
		fabpath="$(command -v fabric)"
	fi

	# Telemetry opt-in
	step "Telemetry (optional)"
	local telemetry_enabled="false"
	if confirm "Enable optional hotkey usage telemetry?" no; then
		telemetry_enabled="true"
	fi
	local telemetry_username=""
	if [ "$telemetry_enabled" = "true" ]; then
		need_input "Telemetry username (optional, press Enter to skip):"
		read -r -p "> " telemetry_username </dev/tty || true
	fi

	# Decide whether to overwrite
	# Always write minimal overrides when config was just created or exists; backup first
	backup_dir "$cfg"
	cat > "$cfg" <<'EOF'
-- User overrides generated by install-setup.sh
local defaults = {
	applications = {
		Browser = "__PRIMARY_BROWSER__",
		Browser2 = "__SECONDARY_BROWSER__",
		Editor = "__EDITOR__",
		Terminal = "__TERMINAL__",
	},
    telemetry = {
        enabled = __TELEMETRY_ENABLED__,
        username = __TELEMETRY_USERNAME__,
        includeAppName = true,
    },
}
return defaults
EOF
	# Inject values
	sed -i '' "s|__PRIMARY_BROWSER__|${primary_browser}|g" "$cfg"
	sed -i '' "s|__SECONDARY_BROWSER__|${secondary_browser}|g" "$cfg"
	sed -i '' "s|__EDITOR__|${editor}|g" "$cfg"
	sed -i '' "s|__TERMINAL__|${terminal}|g" "$cfg"
	if [ "$telemetry_enabled" = "true" ]; then
		sed -i '' "s|__TELEMETRY_ENABLED__|true|g" "$cfg"
	else
		sed -i '' "s|__TELEMETRY_ENABLED__|false|g" "$cfg"
	fi
	if [ -n "$telemetry_username" ]; then
		sed -i '' "s|__TELEMETRY_USERNAME__|\"${telemetry_username}\"|g" "$cfg"
	else
		sed -i '' "s|__TELEMETRY_USERNAME__|nil|g" "$cfg"
	fi
	# serverUrl comes from defaults if present; not prompted here

	# If we detected a Fabric path, add it as an override by appending a small block before the return
	if [ -n "$fabpath" ]; then
		# Insert fabric block above final return
		sed -i '' $'s|return defaults|\
-- Fabric path override added by installer\
defaults.fabric = defaults.fabric or {}\
defaults.fabric.fabricPath = "'"$fabpath"'"\
\
return defaults|g' "$cfg"
		fi
		info "Wrote overrides to config_user.lua (backup created)"
}

install_hammerspoon() {
	step "Installing Hammerspoon"
	install_pkg hammerspoon
}

install_fabric() {
	step "Installing Fabric"
	if ! command -v fabric-ai >/dev/null 2>&1 && ! command -v fabric >/dev/null 2>&1; then
		install_pkg fabric-ai || true
	fi
	# Alias for convenience
	if ! grep -q "alias fabric='fabric-ai'" "$TARGET_HOME/.zshrc" 2>/dev/null; then
		"${RUN_AS_USER[@]}" /bin/sh -c "printf '%s\n' \"alias fabric='fabric-ai'\" >> '$TARGET_HOME/.zshrc'"
		info "Added alias fabric -> fabric-ai to $TARGET_HOME/.zshrc"
	fi
}

setup_fabric_patterns() {
	step "Installing Fabric patterns"
	"${RUN_AS_USER[@]}" mkdir -p "$TARGET_HOME/.config/fabric/patterns"
	local src_dir="$TARGET_HOME/.hammerspoon/fabric-patterns"
	if [ -d "$src_dir" ]; then
		"${RUN_AS_USER[@]}" rsync -a "$src_dir/" "$TARGET_HOME/.config/fabric/patterns/"
		"${RUN_AS_USER[@]}" rm -rf "$src_dir"
		info "Installed Fabric patterns"
	else
		if [ -d "$(pwd)/fabric-patterns" ]; then
			"${RUN_AS_USER[@]}" rsync -a "$(pwd)/fabric-patterns/" "$TARGET_HOME/.config/fabric/patterns/"
			info "Installed Fabric patterns from current directory"
		else
			warn "fabric-patterns directory not found in repo"
		fi
	fi
}

write_fabric_env() {
	step "Configuring Fabric API keys"
	local envdir="$TARGET_HOME/.config/fabric"
	local envfile="$envdir/.env"
	"${RUN_AS_USER[@]}" mkdir -p "$envdir"

	# Existing values preserved
	local groq_key=""
	local yt_key=""
	if [ -f "$envfile" ]; then
		groq_key=$(grep '^GROQ_API_KEY=' "$envfile" | sed 's/^GROQ_API_KEY=//') || true
		yt_key=$(grep '^YOUTUBE_API_KEY=' "$envfile" | sed 's/^YOUTUBE_API_KEY=//') || true
	fi

	# Before key prompts
	step "Opening README instructions for API keys in your default browser"
	open_help_links
	need_input "Groq API Key (leave blank to keep current):"
	read -r -p "> " in_groq </dev/tty || true
	need_input "YouTube API Key (optional):"
	read -r -p "> " in_yt </dev/tty || true

	groq_key=${in_groq:-$groq_key}
	yt_key=${in_yt:-$yt_key}

	{
		echo "# Fabric env configured by install-setup.sh"
		[ -n "$groq_key" ] && echo "GROQ_API_KEY=$groq_key"
		[ -n "$yt_key" ] && echo "YOUTUBE_API_KEY=$yt_key"
	} | "${RUN_AS_USER[@]}" tee "$envfile" >/dev/null
	"${RUN_AS_USER[@]}" chmod 600 "$envfile"
	info "Wrote $envfile"
}

configure_fabric_model() {
	step "Selecting Fabric defaults"
	local cfgdir="$TARGET_HOME/.config/fabric"
	"${RUN_AS_USER[@]}" mkdir -p "$cfgdir"
	local provider="Groq"
	local model="llama-3.1-70b-versatile"
	need_input "Default model (press Enter to accept $model):"
	read -r -p "> " in_model </dev/tty || true
	model=${in_model:-$model}
	{
		echo "PROVIDER=$provider"
		echo "DEFAULT_MODEL=$model"
	} | "${RUN_AS_USER[@]}" tee "$cfgdir/defaults" >/dev/null
	info "Fabric defaults saved"
}

open_help_links() {
	step "Opening help links (you can follow along)"
	# Use the target user's launch services to open in default browser
	"${RUN_AS_USER[@]}" open -g "https://console.groq.com/keys" || true
	"${RUN_AS_USER[@]}" open -g "https://console.cloud.google.com/marketplace/product/google/youtube.googleapis.com" || true
	"${RUN_AS_USER[@]}" open -g "https://github.com/felixleopold/hammerspoon/blob/config/README.md#fabric-ai-setup" || true
	"${RUN_AS_USER[@]}" open -g "https://github.com/felixleopold/hammerspoon/blob/config/README.md#get-required-api-keys" || true
}

final_notes() {
	echo
	echo -e "${GREEN}========================================${NC}"
	echo -e "${GREEN} Guided setup complete${NC}"
	echo -e "${GREEN}========================================${NC}"
	echo
	echo "We opened the Accessibility settings for you."
	need_input "Enable Hammerspoon in Accessibility, then press Enter here to continue."
	read -r -p "> " _ </dev/tty || true
	echo "You can reload Hammerspoon with ⌘⌃⌥⇧R (or via menu)."
}

main() {
	# Honor non-interactive auto-yes
	if [ "${AUTO_YES:-}" = "1" ] || [ "${YES:-}" = "1" ]; then
		info "AUTO_YES enabled; proceeding without interactive confirmations"
	fi
	# Preflight summary and confirmation
	echo -e "${GREEN}========================================${NC}"
	echo -e "${GREEN} Hammerspoon Configuration - Guided Setup${NC}"
	echo -e "${GREEN}========================================${NC}"
	echo
	echo "This script will:"
	echo "- Install Homebrew (if missing) and configure your shell PATH"
	echo "- Install Hammerspoon and Fabric via Homebrew"
	echo "- Clone the configuration into ~/.hammerspoon"
	echo "- Create and customize your config_user.lua"
	echo "- Configure Fabric API keys and defaults"
	echo "- Open guides for getting API keys with screenshots"
	echo "- Launch Hammerspoon and open Accessibility settings"
	echo
	if [ "$IS_ROOT" -eq 1 ]; then
		warn "Running under sudo; Homebrew and user files will be installed as $TARGET_USER"
	fi
	if ! confirm "Proceed with installation?"; then
		err "Cancelled by user"
		exit 1
	fi

	step "Prerequisites"
	install_homebrew
	require_cmd brew || exit 1

	step "Install apps"
	install_hammerspoon
	clone_repo
	ensure_user_config
	set_app_defaults
	install_fabric
	setup_fabric_patterns
	write_fabric_env
	configure_fabric_model

	if confirm "Open step-by-step key setup guides in your browser now?"; then
		open_help_links
	fi

	# Launch Hammerspoon and open Accessibility pane automatically
	step "Launching Hammerspoon and opening Accessibility settings"
	"${RUN_AS_USER[@]}" open -a Hammerspoon || true
	open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true

	final_notes
}

main "$@"
