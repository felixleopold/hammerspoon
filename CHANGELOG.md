# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
