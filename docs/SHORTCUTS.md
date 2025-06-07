# Default Shortcuts

This document lists all the default keyboard shortcuts available in the Hammerspoon Configuration Framework. These shortcuts are defined in `config_defaults.lua` and can be customized in your `config_user.lua` file.

## Application Shortcuts
All app shortcuts use `⌃⌥⌘` (Ctrl+Option+Cmd) as base modifier

| Shortcut | Application | Description |
|----------|-------------|-------------|
| ⌃⌥⌘Z | Browser | Primary web browser (default: Safari) |
| ⌃⌥⌘X | Browser2 | Secondary browser (default: Chrome) |
| ⌃⌥⌘C | Editor | Primary code editor (default: Visual Studio Code) |
| ⌃⌥⌘V | Editor2 | Secondary editor (default: Sublime Text) |
| ⌃⌥⌘T | Terminal | Terminal emulator (default: Terminal) |
| ⌃⌥⌘N | Notes | Note-taking app (default: Notes) |
| ⌃⌥⌘M | Mail | Email client (default: Mail) |
| ⌃⌥⌘S | Spotify | Music player (default: Spotify) |
| ⌃⌥⌘F | Finder | File manager (default: Finder) |
| ⌃⌥⌘W | WhatsApp | Messaging app (default: WhatsApp) |
| ⌃⌥⌘P | Settings | System preferences (default: System Settings) |

## Application Groups
Application group shortcuts use `⌃⌥⌘` (Ctrl+Option+Cmd) as base modifier

*Note: Application groups are disabled by default. Uncomment and configure them in your `config_user.lua` to enable.*

| Shortcut | Group | Description |
|----------|-------|-------------|
| ⌃⌥⌘B | Browsers | Cycle through browser applications |
| ⌃⌥⌘E | Editors | Cycle through editor applications |

## Window Management
All window shortcuts use `⌥` (Alt) as base modifier

### Basic Window Positioning
| Shortcut | Action | Description |
|----------|--------|-------------|
| ⌥A | Left Half | Move window to left half of screen |
| ⌥D | Right Half | Move window to right half of screen |
| ⌥W | Top Half | Move window to top half of screen |
| ⌥S | Bottom Half | Move window to bottom half of screen |
| ⌥C | Center | Center window on screen |
| ⌥F | Full Screen | Maximize window to full screen |

### Screen Management
| Shortcut | Action | Description |
|----------|--------|-------------|
| ⌘⌥D | Next Screen | Move window to next screen |
| ⌘⌥A | Previous Screen | Move window to previous screen |

### Thirds Window Management
| Shortcut | Action | Description |
|----------|--------|-------------|
| ⌥1 | First Third | Move window to first third (left) |
| ⌥2 | Middle Third | Move window to middle third |
| ⌥3 | Last Third | Move window to last third (right) |
| ⌥4 | Two-Thirds Left | Move window to two-thirds on left |
| ⌥5 | Two-Thirds Right | Move window to two-thirds on right |

### Corner Window Management
*Note: Corner shortcuts are commented out by default. Uncomment them in your `config_user.lua` to enable.*

| Shortcut | Action | Description |
|----------|--------|-------------|
| ⌥Q | Top-Left | Move window to top-left corner |
| ⌥E | Top-Right | Move window to top-right corner |
| ⌥Z | Bottom-Left | Move window to bottom-left corner |
| ⌥V | Bottom-Right | Move window to bottom-right corner |

## Folder Shortcuts
All folder shortcuts use `⌘⇧` (Cmd+Shift) as base modifier

| Shortcut | Folder | Description |
|----------|--------|-------------|
| ⌘⇧H | Home | Open home directory (~) |
| ⌘⇧D | Desktop | Open desktop folder (~/Desktop) |
| ⌘⇧L | Downloads | Open downloads folder (~/Downloads) |
| ⌘⇧F | Documents | Open documents folder (~/Documents) |
| ⌘⇧A | Applications | Open applications folder (/Applications) |

## General System Shortcuts
Various modifier combinations for system operations

| Shortcut | Action | Description |
|----------|--------|-------------|
| ⌘⌃⌥⇧S | Open Config | Open Hammerspoon config in editor |
| ⌘⌃⌥⇧R | Reload Config | Reload Hammerspoon configuration |
| ⌘. | Open in Terminal | Open current Finder path in terminal |
| ⌘; | Open in Editor | Open current Finder path in editor |

## Utility Shortcuts
Window and application management utilities

| Shortcut | Action | Description |
|----------|--------|-------------|
| ⌘⇧X | Close Finder Windows | Close all Finder windows |
| ⌘⇧W | Close Other Windows | Close other windows of current app |

## Clipboard History
All clipboard shortcuts use `⌃⇧` (Ctrl+Shift) as base modifier

| Shortcut | Action | Description |
|----------|--------|-------------|
| ⌃⇧1 | Paste Item 1 | Paste most recent clipboard item |
| ⌃⇧2 | Paste Item 2 | Paste second most recent item |
| ⌃⇧3 | Paste Item 3 | Paste third most recent item |
| ⌃⇧4 | Paste Item 4 | Paste fourth most recent item |
| ⌃⇧5 | Paste Item 5 | Paste fifth most recent item |
| ⌃⇧6 | Paste Item 6 | Paste sixth most recent item |
| ⌃⇧7 | Paste Item 7 | Paste seventh most recent item |
| ⌃⇧8 | Paste Item 8 | Paste eighth most recent item |
| ⌃⇧9 | Paste Item 9 | Paste ninth most recent item |

## Fabric AI Integration
All AI pattern shortcuts use `⌃⌥` (Ctrl+Alt) as base modifier

| Shortcut | Pattern | Description |
|----------|---------|-------------|
| ⌃⌥R | Correct | Fix and correct text |
| ⌃⌥I | Improve | Improve and enhance text |
| ⌃⌥S | YouTube Summary | Summarize YouTube content |
| ⌃⌥L | LaTeX | Enhanced LaTeX processing |
| ⌃⌥G | General AI | Custom AI instruction with user input |
| ⌃⌥T | Translate | Translate text |
| ⌃⌥N | Note Name | Generate a note name |
| ⌃⌥M | Markdown Format | Format text in Markdown |
| ⌃⌥F | Fact Check | Verify the accuracy of information |
| ⌘⌥⇧P | Pattern Chooser | Open Fabric pattern chooser |

## Macro Recording and Playback
Shortcuts for recording and playing back macros

| Shortcut | Action | Description |
|----------|--------|-------------|
| ⌥⌘[ | Record/Stop | Start or stop recording a macro |
| ⌥⌘] | Play Last | Play the most recently recorded macro |
| ⌥⌘\ | Macro Chooser | Open macro chooser to select and play |
| ⌥⌘E | Macro Editor | Open macro editor (if available) |

## Custom Shortcuts (Self-Organized)
Example custom shortcuts - add your own in `config_user.lua`

| Shortcut | Action | Description |
|----------|--------|-------------|
| ⌘⌥⇧H | Say Hello | Example custom function |

## Modifier Key Legend
- ⌘ Command (Cmd)
- ⌥ Option (Alt)  
- ⌃ Control (Ctrl)
- ⇧ Shift

## Notes

### Window Management Triggers
The framework supports different trigger combinations for window management:
- `window`: Uses either left or right Alt key
- `lwindow`: Uses only left Alt key
- `rwindow`: Uses only right Alt key

### Customization
All shortcuts can be customized in your `config_user.lua` file. You can:
- Change key combinations
- Add new shortcuts
- Disable existing shortcuts
- Create custom functions

### Application Names
Application shortcuts reference names defined in the `applications` section of your config. Make sure the application names match exactly with your installed applications.

### Fabric Patterns
Fabric AI patterns require proper setup with API keys. See the main README for setup instructions. 