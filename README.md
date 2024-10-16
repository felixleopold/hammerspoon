# Hammerspoon Configuration

**Creator:** Felix Mrak

## Version 1.0.1

This repository contains a custom Hammerspoon configuration that enhances productivity on macOS through window management, application shortcuts, and integration with the Fabric AI tool.

## Table of Contents

1. [Installation](#installation)
2. [Features](#features)
   - [Window Management](#window-management)
   - [Application Shortcuts](#application-shortcuts)
   - [Fabric AI Integration](#fabric-ai-integration)
   - [Saved Layouts](#saved-layouts)
3. [Usage](#usage)
4. [Customization](#customization)
5. [Updating](#updating)
6. [Troubleshooting](#troubleshooting)
7. [Changelog](#changelog)
8. [License](#license)

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

- `Cmd + Shift + D`: Open Desktop folder
- `Cmd + Shift + R`: Open Radboud folder
- `Cmd + Shift + A`: Open Applications folder
- `Cmd + Shift + L`: Open Downloads folder
- `Cmd + Shift + H`: Open Home folder
- `Cmd + Shift + O`: Open Obsidian vault
- `Cmd + Shift + F`: Open Documents folder
- `Cmd + Shift + C`: Copy current URL from Zen Browser
- `Ctrl + Alt + Cmd + P`: Open System Settings
- `Ctrl + Alt + Cmd + A`: Open Arc browser
- `Ctrl + Alt + Cmd + Z`: Open Zen Browser
- `Ctrl + Alt + Cmd + T`: Open Warp terminal
- `Ctrl + Alt + Cmd + S`: Open Spotify
- `Ctrl + Alt + Cmd + M`: Open Mail
- `Ctrl + Alt + Cmd + O`: Open Obsidian
- `Ctrl + Alt + Cmd + W`: Open WhatsApp
- `Ctrl + Alt + Cmd + F`: Open Finder
- `Ctrl + Alt + Cmd + V`: Open Visual Studio Code
- `Ctrl + Alt + Cmd + C`: Open Cursor editor

### Fabric AI Integration

- Execute various Fabric patterns directly from Hammerspoon
- Process clipboard content using Fabric AI
- Summarize YouTube videos and perform other text-related tasks

### Saved Layouts

- Save and load custom window arrangements
- Supports multiple applications and screens
- Hotkeys for quick saving and loading
- Layouts are stored in `~/.hammerspoon/savedLayouts.json`

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
- `Cmd + Shift + C`: Copy current URL from Zen Browser
- `Ctrl + Alt + Cmd + P`: Open System Settings
- `Ctrl + Alt + Cmd + A`: Open Arc browser
- `Ctrl + Alt + Cmd + Z`: Open Zen Browser
- `Ctrl + Alt + Cmd + T`: Open Warp terminal
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

- Modify `init.lua` in `~/.hammerspoon/` to change global settings or add new modules.
- Edit `application.lua`, `windowManagement.lua`, and `fabric.lua` in the iCloud Drive folder to customize functionality.
- Add new patterns to `fabric.lua` to extend Fabric AI integration.

## Updating

To update to the latest version:
1. Pull the latest changes:   ```
   cd ~/.hammerspoon
   git pull   ```
2. Reload Hammerspoon configuration

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
