# Hammerspoon Configuration

<p align="center">
  <img src="wizzard.gif" alt="Hammerspoon Setup Wizard" width="100">
</p>

**Creator:** Felix Mrak

## Version 1.2.0

This repository contains a custom Hammerspoon configuration that enhances productivity on macOS through window management, application shortcuts, and integration with the Fabric AI tool.

## Table of Contents

1. [Installation](#installation)
2. [Features](#features)
   - [Window Management](#window-management)
   - [Application Shortcuts](#application-shortcuts)
   - [Fabric AI Integration](#fabric-ai-integration)
   - [Saved Layouts](#saved-layouts)
3. [Setup Wizard](#setup-wizard)
4. [Usage](#usage)
5. [Customization](#customization)
6. [Updating](#updating)
7. [Troubleshooting](#troubleshooting)
8. [Changelog](#changelog)

## Installation

1. Install [Hammerspoon](https://www.hammerspoon.org/) on your macOS system.
2. Clone this repository:   ```
   git clone https://github.com/felixleopold/hammerspoon-config.git ~/.hammerspoon   ```
3. Ensure Fabric is installed and accessible in your PATH.
4. Reload the Hammerspoon configuration.

## Features

### Window Management

- Move windows to different positions on the screen (left half, right half, top half, bottom half, etc.)
- Move windows between multiple screens
- Resize windows to various preset sizes
- Save and load custom window layouts
- Cycle through windows of the current application

### Application Shortcuts

- Quick launch or focus for commonly used applications
- Open specific folders with customizable shortcuts
- Copy current URL from configured browsers

### Fabric AI Integration

- Execute various Fabric patterns directly from Hammerspoon
- Process clipboard content using Fabric AI
- Summarize YouTube videos and perform other text-related tasks

### Saved Layouts

- Save and load custom window arrangements
- Supports multiple applications and screens
- Hotkeys for quick saving and loading

## Setup Wizard

The Setup Wizard is a graphical user interface that allows you to easily configure your Hammerspoon settings. To use the Setup Wizard:

1. Press `Ctrl + Alt + Cmd + Shift + S` to launch the wizard (or your custom shortcut if changed).
2. The wizard window will open with several tabs:
   - **Folders**: Configure paths for quick access to important folders.
   - **Applications**: Set the applications for various shortcuts.
   - **Shortcuts**: Customize keyboard shortcuts for applications, folders, and window management.
   - **Fabric**: Configure Fabric AI models and patterns.
   - **Window Management**: Adjust window management settings.

3. Navigate through the tabs and modify settings as needed.
4. Click "Save Configuration" to apply your changes.
5. The wizard will automatically trigger a reload of your Hammerspoon configuration.

Key features of the Setup Wizard:
- User-friendly interface for easy configuration
- Ability to reset to default settings
- Real-time updates to your Hammerspoon configuration
- Customizable shortcuts for all major functions

## Usage

### Window Management

- `Alt + A`: Move window to left half of the screen
- `Alt + D`: Move window to right half of the screen
- `Alt + W`: Move window to top half of the screen
- `Alt + S`: Move window to bottom half of the screen
- `Alt + F`: Fullscreen
- `Alt + C`: Center window
- `Ctrl + Alt + A`: Move window to left screen
- `Ctrl + Alt + D`: Move window to right screen
- `Alt + E`: Cycle forward through app windows
- `Alt + Q`: Cycle backward through app windows
- `Alt + Cmd + S`: Save current window layout
- `Alt + Cmd + L`: Load a saved window layout

### Application Shortcuts

- `Cmd + Shift + D`: Open Desktop folder
- `Cmd + Shift + R`: Open Radboud folder
- `Cmd + Shift + A`: Open Applications folder
- `Cmd + Shift + L`: Open Downloads folder
- `Cmd + Shift + H`: Open Home folder
- `Cmd + Shift + O`: Open Obsidian vault
- `Cmd + Shift + F`: Open Documents folder
- `Cmd + Shift + C`: Copy current URL from browser
- `Ctrl + Alt + Cmd + P`: Open System Settings
- `Ctrl + Alt + Cmd + A`: Open Arc browser
- `Ctrl + Alt + Cmd + Z`: Open Zen Browser
- `Ctrl + Alt + Cmd + T`: Open Terminal
- `Ctrl + Alt + Cmd + S`: Open Spotify
- `Ctrl + Alt + Cmd + M`: Open Mail
- `Ctrl + Alt + Cmd + O`: Open Obsidian
- `Ctrl + Alt + Cmd + W`: Open WhatsApp
- `Ctrl + Alt + Cmd + F`: Open Finder
- `Ctrl + Alt + Cmd + V`: Open Visual Studio Code
- `Ctrl + Alt + Cmd + C`: Open Cursor editor

### Fabric AI Integration

- `Ctrl + Alt + I`: Correct Text
- `Ctrl + Alt + O`: Improve Text
- `Ctrl + Alt + E`: Translate
- `Ctrl + Alt + L`: LaTeX
- `Ctrl + Alt + P`: LaTeX Plus
- `Ctrl + Alt + G`: General Pattern
- `Ctrl + Alt + N`: Note Name
- `Cmd + Alt + Shift + P`: Show Pattern Chooser

## Customization

- Use the Setup Wizard (Ctrl + Alt + Cmd + Shift + S) to customize most settings.
- For advanced customization, you can still modify the Lua files directly:
  - Edit `init.lua` in `~/.hammerspoon/` to change global settings or add new modules.
  - Modify `application.lua`, `windowManagement.lua`, and `fabric.lua` for specific functionalities.

## Updating

To update to the latest version:
1. Pull the latest changes:   ```
   cd ~/.hammerspoon
   git pull   ```
2. Launch the Setup Wizard to review and adjust any new settings.
3. Reload Hammerspoon configuration

## Troubleshooting

If you encounter issues:
1. Check the Hammerspoon console for error messages.
2. Ensure all required dependencies are installed and properly configured.
3. Verify that your `user_config.json` file is correctly formatted and contains valid settings.
4. Try resetting to default settings using the Setup Wizard.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and detailed changes.
