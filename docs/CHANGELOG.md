# Changelog

## [1.8.0] - 2025-09-15

### Added
- **Second-layer Application Shortcuts**: Shift-activated app layer
  - New trigger `triggers.app2 = { "ctrl", "alt", "cmd", "shift" }`
  - New config section `shortcuts.apps2` for defining second-layer app hotkeys
  - Works alongside existing `apps` without conflicts; includes telemetry labels
- **Optional Telemetry**: Local hotkey usage tracking (privacy-first)
  - Logs to `~/.hammerspoon/telemetry_events.jsonl`
  - Can optionally POST to your server (disabled by default)
  - Enable via `telemetry` section in `config_user.lua` or through the installer

### Improved
- **Mouse Speed Finder**: Better defaults and messaging for suggestions
  - Clearer next steps in alerts; safer default thresholds
  - Minor polish to toggle/report shortcuts in docs

### Fixed
- **Macros**: Reliability improvements when opening the editor from the chooser
  - Reduced edge cases where the timing editor wouldn’t attach to the last macro

## [1.7.0] - 2025-01-06

### Added
- **Kanata Integration**: New visual menu bar indicator for Kanata keyboard modes
  - Three distinct mode indicators: Normal (◯), Vim (◆), Typing (●)
  - Terminal command integration with `kanata-mode` script
  - Automatic file monitoring for real-time mode updates
  - Right-click menu for manual mode switching
  - Configurable status file location and default mode
  - Perfect for integration with actual Kanata keyboard configurations
  - See `docs/KANATA.md` for detailed setup and usage instructions

### Technical
- Added `kanata.lua` module with menu bar integration using Unicode symbols
- Added configuration sections in both `config_defaults.lua` and `config_user.lua`
- Created terminal scripts: `kanata-mode` (simple) and `kanata_mode.sh` (detailed)
- Implemented file watcher for automatic status updates
- Added comprehensive documentation and troubleshooting guide
- Switched from colored circles to distinct Unicode symbols for better visibility across all system themes

## [1.6.1] - 2025-05-13

### Improved
- **Enhanced Left-Right Modifier System**: Implemented exact modifier matching to ensure seamless integration with system shortcuts
  - Left Control now works perfectly for both window management AND normal system shortcuts
  - Left Ctrl + A/D/C/F triggers window management
  - Left Ctrl + C/V/Z still works as normal copy/paste/undo
  - Right Control remains completely unaffected for system shortcuts
  - Added comprehensive testing and documentation
  - Improved event handling to only consume events for exact modifier matches

### Technical
- Updated `leftRightModifier.lua` with exact modifier matching algorithm
- Added best-match handler selection for overlapping key combinations
- Enhanced debugging and logging capabilities
- Added test shortcuts for verification

## [1.6.0] - 2025-05-15
### Added
- **Left-Right Modifier Key Support**: Added ability to distinguish between left and right modifier keys.
  - Window management can now be configured to use specific left or right modifiers.
  - New trigger types: `lwindow` and `rwindow` for left/right specific window management.
  - All modifier keys (ctrl, alt, cmd, shift) can be prefixed with `l` or `r` to specify the side.
  - See the new documentation in `docs/LEFT_RIGHT_MODIFIERS.md` for details.
- **Enhanced Window Navigation**: Improved window movement behavior when working with multiple monitors.

### Changed
- Refactored window management code for better maintainability.
- Updated configuration templates with examples of left/right modifier usage.

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
