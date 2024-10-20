# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2024-10-20

### Added
- New graphical Setup Wizard using PyQt6 for easier configuration
  - Tabbed interface for organizing different configuration sections
  - Visual editing of shortcuts, applications, and folder paths
  - Integration with Fabric AI configuration
- "Reset to Default" functionality in the Setup Wizard
- Icon support for the Setup Wizard in the dock
- JetBrains Mono font support in the Setup Wizard (with Arial as fallback)

### Changed
- Improved user interface for window management configuration
- Enhanced Fabric AI integration with configurable models and patterns
- Updated `windowManagement.lua` to work seamlessly with the new Setup Wizard
- Refined the process for saving and loading window layouts

### Improved
- Better error handling and user feedback in the Setup Wizard
- More intuitive navigation between different configuration sections
- Enhanced visual styling for better user experience

### Fixed
- Issues with folder paths not being recognized consistently
- Inconsistencies in handling shortcuts across different configuration areas

## [1.1.1] - 2024-10-17

### Fixed
- Resolved issues with folder shortcuts not working consistently
- Improved path handling for user home directory and special folders

### Changed
- Updated `application.lua` to use `hs.fs.pathToAbsolute` for more robust path expansion
- Enhanced logging in `application.lua` for better troubleshooting

## [1.1.0] - 2024-10-17

### Added
- Integrated Fabric AI functionality with configurable models and patterns
- New setup wizard for easier configuration of all settings
- Persistent configuration saving after each change in the setup wizard
- Support for custom folder shortcuts
- Improved application launching with special handling for browsers

### Changed
- Restructured the codebase for better organization
- Updated window management shortcuts to be more comprehensive
- Improved error handling and logging throughout the application

### Fixed
- Issues with configuration not persisting between Hammerspoon reloads
- Bugs in the setup wizard navigation and item selection

## [1.0.9] - 2024-10-16

### Added
- Initial release of the Hammerspoon configuration
- Basic window management functionality
- Application launching shortcuts

## [1.0.8] - 2024-10-26

### Changed
- Removed separate "radboud" shortcut
- "School" shortcut now leads to the Radboud folder by default (~/Documents/Radboud)

## [1.0.7] - 2024-10-25

### Changed
- Fixed folder order in setup wizard to match specified order: Applications, Desktop, Documents, Downloads, Home, followed by Obsidian, School, and custom folders

## [1.0.6] - 2024-10-24

### Changed
- Reordered folder configuration to a specific order: Applications, Desktop, Documents, Downloads, Home, followed by Obsidian, School, and custom folders
- Capitalized the first letter of each folder name in the configuration

## [1.0.5] - 2024-10-23

### Changed
- Reordered folder configuration to be alphabetical, with numbered folders at the end
- Option to modify system folder paths (Desktop, Downloads, Home, Documents, Applications) in the setup wizard

## [1.0.4] - 2024-10-22

### Changed
- Renamed custom folders to start from folder8
- Added "school" folder (previously named Radboud)
- Updated folder shortcuts to reflect new folder names

## [1.0.3] - 2024-10-21

### Added
- Made all shortcuts fully customizable
- Improved setup wizard with more interactive options
- Added ability to customize folder shortcuts
- Added ability to customize application shortcuts

### Changed
- Restructured configuration to support more customizable options
- Updated setup process to provide a more user-friendly interface

### Improved
- Better error handling and default values for configuration

## [1.0.2] - 2024-10-20

### Added
- Comprehensive setup wizard for easy configuration
- User-configurable shortcuts, including for the setup wizard itself
- Expanded configuration options for window management
- Improved configuration loading with default fallbacks

## [1.0.1] - 2024-10-16

### Added
- Zen Browser URL copying feature
  - New shortcut (Cmd + Shift + C) to quickly copy the current URL from Zen Browser
  - Uses keyboard simulation for compatibility
  - Silent operation with no on-screen alerts

## [1.0.0] - 2024-10-16

### Added
- Initial release of the Hammerspoon configuration

#### Window Management
- Move windows to different screen positions (left half, right half, top half, bottom half)
- Full-screen and center window options
- Move windows between multiple screens
- Cycle through windows of the current application
- Save and load custom window layouts

#### Application Shortcuts
- Quick access to common folders (Desktop, Downloads, Documents, etc.)
- Launch or focus specific applications with custom key combinations

#### Fabric AI Integration
- Execute various Fabric patterns directly from Hammerspoon
- Shortcuts for text correction, improvement, and translation
- LaTeX and note-taking assistance
- YouTube video summarization

#### Configuration
- Auto-reload configuration when changes are detected
- Modular structure with separate files for different functionalities
- iCloud integration for syncing configuration across multiple Macs

#### Other Features
- Disable animation for window movements for faster response
- Logging system for debugging and tracking configuration loading

### Changed
- N/A (Initial release)

### Deprecated
- N/A (Initial release)

### Removed
- N/A (Initial release)

### Fixed
- N/A (Initial release)

### Security
- N/A (Initial release)
