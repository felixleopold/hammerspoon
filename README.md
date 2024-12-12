# Hammerspoon Configuration

A modern, feature-rich Hammerspoon configuration focused on productivity and ease of use.

## Features

### Window Management
- Quick window cycling for Finder and other applications
- Window closing shortcuts
- Efficient window management controls

### Fabric AI Integration
Integrated AI assistance with keyboard shortcuts:
- `Cmd+Alt+Shift+R` - Correct text
- `Cmd+Alt+Shift+I` - Improve text
- `Cmd+Alt+Shift+S` - Summarize YouTube content
- `Cmd+Alt+Shift+L` - LaTeX processing
- `Cmd+Alt+Shift+G` - General AI interaction
- `Cmd+Alt+Shift+T` - Translate text
- `Cmd+Alt+Shift+N` - Generate note name
- `Cmd+Alt+Shift+P` - Pattern chooser

### Application Management
- Quick application switching
- Custom application shortcuts
- Efficient window management

## Installation

1. Install Hammerspoon:
   ```bash
   brew install hammerspoon
   ```

2. Clone this repository:
   ```bash
   git clone [repository-url] ~/.hammerspoon
   ```

3. Install Fabric CLI (required for AI features):
   ```bash
   go install github.com/mrakinola/fabric-cli@latest
   ```

4. Launch Hammerspoon and allow accessibility permissions

## Configuration

The configuration is split into modules for better organization:
- `init.lua` - Main configuration and module loading
- `config.lua` - User preferences and shortcuts
- `application.lua` - Application management
- `windowManagement.lua` - Window control features
- `fabric.lua` - AI integration
- `setup.lua` - Configuration initialization

## UI Features
- Modern macOS-style notifications
- Clean, minimal interface
- Informative status messages

## Requirements
- macOS (tested on latest version)
- Hammerspoon
- Go (for Fabric CLI installation)
- Fabric CLI tool
