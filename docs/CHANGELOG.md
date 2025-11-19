# Changelog

## [1.9.0] - 2025-11-19

### Added

- **Antigravity Integration**
    - Added support for Antigravity editor (`agy`)
    - New shortcut `cmd + '` to open current Finder folder in Antigravity
    - Updated `application.lua` to support direct executable paths for editors

- **Default Editor Configuration**
    - Added `defaultEditor` setting to `config_user.lua` (defaults to "Editor")
    - System shortcuts (open config, open in editor) now respect `defaultEditor` setting

## [1.8.1] - 2025-01-27

### Improved

- **Enhanced Installation Scripts**
    - Added sudo-aware user handling for proper file ownership
    - Robust Homebrew PATH setup and persistence to shell profiles
    - Preflight confirmation with clear summary of actions
    - Progress notes for operations that may take time
    - Automatic Hammerspoon launch and Accessibility settings opening
    - Interactive waiting for user to complete required steps
    - Direct links to README sections with API key setup screenshots

- **Updated README**
    - Install commands now use `sudo` for proper permissions
    - Added links to guided sections with screenshots
    - Clearer description of interactive installation flow

## [1.8.0] - 2025-09-15

### Added

- **Second-layer Application Shortcuts**
    
    - New trigger `triggers.app2 = { "ctrl", "alt", "cmd", "shift" }`
        
    - New section `shortcuts.apps2`
        
    - Runs alongside `apps`; includes telemetry labels
        
- **Optional Telemetry**
    
    - Logs to `~/.hammerspoon/telemetry_events.jsonl`
        
    - Optional POST to a custom server (off by default)
        
    - Enable via `telemetry` in `config_user.lua` or the installer
        
- **Mouse Speed Finder**
    
    - Safer defaults, clearer next steps, better messages
        

### Fixed

- **Minecraft Kanata Integration**: Fixed the Minecraft Kanata integration to reliably switch to gaming mode.

- **Macros**: chooser → editor handoff reliability
    

### Docs

- Guided installer and README updated
    

---

## [1.7.1] - 2025-06-07

### Added

- Automated installer with comprehensive setup docs
    

### Changed

- Defaults aligned with documented shortcuts
    
- README cleanup and images
    

---

## [1.7.0] - 2025-01-06

### Added

- **Kanata integration**: menu-bar indicator and CLI (`kanata-mode`)
    
    - Modes: Normal (◯), Vim (◆), Typing (●)
        
    - File watcher, right-click switching, configurable status path
        
    - See `docs/KANATA.md`
        

### Technical

- `kanata.lua`, terminal scripts, new config sections
    

### Changed

- Config templates updated; common apps added; config shortcut moved to General
    

### Removed

- Conflicting `Cmd+Shift+P` “pictures” shortcut
    

---

## [1.6.1] - 2025-05-13

### Improved

- Exact left/right modifier matching
    
    - Left Ctrl + A/D/C/F = window management
        
    - Left Ctrl + C/V/Z = system shortcuts
        
    - Right Ctrl unaffected
        
- Better logging, tests, docs
    

---

## [1.6.0] - 2025-04-19

### Added

- Left/right modifier support for window management (`lwindow`, `rwindow`)
    
- Bundle ID support in app handling
    

### Changed

- Window management refactor
    
- Config structure and templates updated
    

---

## [1.5.0] - 2025-04-09

### Added

- Internal clipboard history
    
    - Tracks last 9 text items
        
    - `Ctrl+Shift+[1–9]` to paste
        
    - History resets on reload/quit
        
- Window management: corners and thirds; monitor jumping; screen-switching logic
    

### Removed

- HS window cycling on `Alt+Q/E`
    

---

## [1.4.6] - 2025-03-15

### Added

- Finder → Editor2 shortcut: `⌘'` opens current Finder path in `Editor2`
    

---

## [1.4.0] - 2024-12-12

### Added

- Rounded macOS-style notifications
    
- Fabric patterns: Correct (R), Improve (I), YouTube summarize (S), LaTeX plus (L), General AI (G), Translate (T), Note name (N), PDF name
    
- Automatic paste after Fabric actions
    
- First-run setup wizard
    
- Detailed system/window logging and extensive window debugging
    

### Changed

- Trigger-based shortcut system; new config structure and load order
    
- Simplified Fabric config
    
- Improved YouTube handling
    
- Updated alert positioning and styling
    

### Fixed

- Window cycling issues; include Desktop in Finder cycling
    
- Finder detection and filtering (`app:allWindows()`, subrole filtering)
    
- Pattern execution feedback and command path handling
    
- Truncated error handling
    

---

## [1.3.1] - 2024-12-12

### Fixed

- Window cycling with folder opening
    
- Shortcuts firing without modifiers
    
- Finder window handling
    
- Added logging
    
- Simplified trigger configuration
    

---

## [1.2.0] - 2024-10-20

### Added

- Setup wizard finalized and enabled by default
    
- Fabric pattern `pdf_name` support
    

### Fixed

- Obsidian folder path error
    

### Docs

- README updates
    

---

## [1.1.0] - 2024-10-19

### Added

- Fabric pattern support for YouTube summaries
    

---

## [1.0.1] - 2024-10-17

### Added

- Initial setup-wizard scaffolding
    

### Docs

- README update
    

---

## [1.0.0] - 2024-10-16

### Added

- Initial release
    
    - Open applications
        
    - Window management
        
    - Fabric integration
        

### Docs

- Initial README
    
- Initial setup function