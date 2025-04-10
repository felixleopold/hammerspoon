# Changelog

## [1.5.0] - 2025-04-09 
### Added
- **Internal Clipboard History**: Added a self-contained clipboard history manager within Hammerspoon.
  - Monitors pasteboard changes and stores the last 9 text items.
  - Use `Ctrl+Shift+[1-9]` to paste items from this internal history.
  - Pasting an item moves it to the top of the internal history (mimicking Maccy).
  - This feature is independent of external clipboard managers like Maccy.
  - Note: History is ephemeral and lost on Hammerspoon reload/quit.
  - Added configuration section `clipboard` in `config.lua` (though currently only uses the `shortcuts.mods` part).

## [1.4.6] - 2024-03-15
### Added
- **Finder to Editor2 Shortcut**: Added `⌘'` (Command + Apostrophe) to open the current Finder location in the secondary editor (`Editor2` defined in config).

## [1.4.0] - 2024-12-12

### Added
- Modern macOS-style notifications with rounded corners
- New Fabric patterns:
  - Correct text (R)
  - Improve text (I)
  - YouTube summarize (S)
  - LaTeX plus (L)
  - General AI (G)
  - Translate (T)
  - Note name (N)
- Automatic content pasting after Fabric processing
- Improved error handling with truncated messages

### Changed
- Simplified Fabric pattern configuration
- Updated notification styling to match macOS design
- Improved YouTube content handling
- Streamlined error messages

### Fixed
- Window cycling issues
- Fabric command execution and path handling
- Alert positioning and styling
- Pattern execution feedback

## [1.3.1] - Previous Release
- Fixed window cycling issues with folder opening
- Fixed shortcuts triggering without modifiers
- Improved Finder window handling
- Added better logging throughout
- Simplified trigger configuration

[Previous versions omitted for brevity]
