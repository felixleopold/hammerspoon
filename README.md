# Hammerspoon Configuration

A powerful and customizable configuration for Hammerspoon, featuring window management, application shortcuts, folder navigation, and Fabric AI integration.

## Setup

1. Install Hammerspoon from https://www.hammerspoon.org/
2. Clone this repository to `~/.hammerspoon/`
3. Grant required permissions:
   - Open System Settings > Privacy & Security > Accessibility
   - Enable Hammerspoon
   - This is required for window management and keyboard shortcuts
4. Launch Hammerspoon
5. The configuration will load automatically

## Features

### Window Management
- Move windows to different positions (left half, right half, top half, bottom half, etc.)
- Move windows between multiple screens
- Resize windows to various preset sizes
- Cycle through application windows
- Special handling for Finder windows

### Application Shortcuts
- Quick launch or focus for commonly used applications
- Open specific folders with customizable shortcuts
- Copy current URL from Zen Browser
- Close all Finder windows with a single shortcut

### Fabric AI Integration
- Execute various Fabric patterns directly from Hammerspoon
- Process clipboard content using Fabric AI
- Summarize YouTube videos and perform other text-related tasks

## Shortcuts

### Window Management
- `Alt + A`: Move window to left half
- `Alt + D`: Move window to right half
- `Alt + W`: Move window to top half
- `Alt + H`: Move window to bottom half
- `Alt + C`: Center window
- `Alt + F`: Full screen
- `Cmd + Alt + A`: Move window to previous screen
- `Cmd + Alt + D`: Move window to next screen
- `Alt + E`: Cycle forward through app windows
- `Alt + Q`: Cycle backward through app windows

### Application Shortcuts (Ctrl + Alt + Cmd)
- `Z`: Launch Zen Browser
- `A`: Launch Microsoft Edge
- `V`: Launch VS Code
- `T`: Launch Terminal
- `O`: Launch Obsidian
- `M`: Launch Mail
- `S`: Launch Spotify
- `F`: Launch Finder
- `W`: Launch WhatsApp
- `P`: Launch System Settings
- `U`: Launch UTM

### Folder Shortcuts (Cmd + Shift)
- `H`: Open Home folder
- `D`: Open Desktop folder
- `L`: Open Downloads folder
- `F`: Open Documents folder
- `P`: Open Pictures folder
- `A`: Open Applications folder
- `O`: Open Obsidian vault
- `S`: Open School folder
- `R`: Open Projects folder

### Utility Shortcuts
- `Cmd + Shift + X`: Close all Finder windows
- `Ctrl + C`: Copy URL from Zen Browser (when focused)

### Fabric AI Integration
Basic patterns (Ctrl + Alt):
- `S`: Summarize text
- `W`: Extract wisdom
- `I`: Improve writing
- `F`: Find action items

Advanced patterns (Ctrl + Alt + Shift):
- `E`: Write essay
- `S`: Create social post
- `A`: Generate art prompt
- `Y`: YouTube summary
- `K`: YouTube key points
- `L`: YouTube lecture notes
- `C`: Explain code
- `I`: Improve code
- `D`: Document code

Research patterns (Ctrl + Alt + Cmd):
- `R`: Deep research
- `A`: Academic summary
- `E`: Extract references

Pattern chooser:
- `Cmd + Alt + Shift + P`: Show pattern chooser

## Installation

1. Install [Hammerspoon](https://www.hammerspoon.org/)
2. Clone this repository to `~/.hammerspoon/`:
   ```bash
   git clone https://github.com/yourusername/hammerspoon.git ~/.hammerspoon
   ```
3. Launch Hammerspoon or reload your configuration

## Configuration

The configuration is split into several files for better organization:
- `init.lua`: Main initialization file
- `config.lua`: User configuration (applications, shortcuts, etc.)
- `application.lua`: Application management
- `windowManagement.lua`: Window management features
- `fabric.lua`: Fabric AI integration

## Logging

The configuration includes detailed logging for troubleshooting:
- Window management operations
- Application launching
- Folder operations
- Fabric pattern execution

Logs can be viewed in the Hammerspoon Console (click the Hammerspoon menubar icon and select "Console").

## Version History

### 1.3.1
- Fixed window cycling issues with folder opening
- Fixed shortcuts triggering without modifiers
- Improved Finder window handling
- Added better logging throughout
- Simplified trigger configuration

### 1.3.0
- Added utility shortcuts for Finder and Zen Browser
- Improved window cycling with better Finder support
- Added detailed logging throughout
- Fixed various window management issues

### 1.2.0
- Added Fabric AI integration
- Improved window management
- Added support for multiple screens

### 1.1.0
- Added folder shortcuts
- Improved application management
- Added window cycling

### 1.0.0
- Initial release
- Basic window management
- Application shortcuts
