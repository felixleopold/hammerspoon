# Hammerspoon Configuration Framework

A modern, modular Hammerspoon configuration framework focused on productivity and extensibility. This framework provides a structured way to manage your Hammerspoon configuration with easy customization options.

## Overview

This framework is organized into several modules:
- **Application Management**: Quick app switching and window control
- **Window Management**: Window positioning, sizing, and cycling
- **Internal Clipboard History**: Paste recent text items (`Ctrl+Shift+[1-9]`)
- **Fabric AI Integration**: AI-powered text processing and automation
- **Custom Shortcuts**: Self-organized system for personal additions
- **Terminal Integration**: Quick terminal access from Finder
- **Debug Tools**: Utilities for configuration and troubleshooting

## Project Structure

```
~/.hammerspoon/
├── init.lua           # Main entry point
├── config.lua         # User configuration
├── self.lua           # Custom user functions
├── setup.lua          # Configuration processor
├── modules/
│   ├── application.lua    # App management
│   ├── windowManagement.lua  # Window control
│   ├── fabric.lua        # AI integration
│   └── clipboard.lua     # Internal clipboard history
└── docs/
    ├── SHORTCUTS.md      # Default shortcuts
    └── CHANGELOG.md      # Version history
```

## Installation

1. Install Hammerspoon:
```bash
brew install hammerspoon
```

2. Clone this repository:
```bash
git clone [repository-url] ~/.hammerspoon
```

3. Install Fabric:
```bash
go install github.com/danielmiessler/fabric@latest
```
[Fabric Documentation](https://github.com/danielmiessler/fabric?tab=readme-ov-file#installation)

4. Launch Hammerspoon and allow accessibility permissions

## Configuration

### Basic Configuration
1. Open `config.lua`
2. Modify the `applications` section to match your installed apps
3. Adjust shortcuts in the `shortcuts` section
4. Save and reload Hammerspoon (⌘⌃⌥⇧R)

Example configuration:
```lua
applications = {
    Browser = "Safari",
    Editor = "Visual Studio Code",
    Terminal = "iTerm",
    -- Add your applications
}
```

### Adding Custom Shortcuts

1. Add your shortcut to `config.lua` in the `self` section:
```lua
self = {
    shortcuts = {
        {
            name = "myCustomFunction",
            desc = "What this shortcut does",
            mods = { "cmd", "alt", "shift" },
            key = "K",
        },
    },
}
```

2. Add the corresponding function in `self.lua`:
```lua
function functions.myCustomFunction()
    log.i("Executing my custom function")
    -- Your code here
    hs.alert.show("Custom function executed!")
end
```

### Extending the Framework

To add new functionality:

1. Create a new module file (e.g., `mymodule.lua`)
2. Follow the module pattern:
```lua
local M = {}
local log = hs.logger.new('MyModule', 'debug')

function M.setup(config)
    -- Your initialization code
end

return M
```

3. Add your module to `init.lua`:
```lua
local mymodule = require("mymodule")
mymodule.setup(config)
```

## Updating

1. Pull the latest changes:
```bash
cd ~/.hammerspoon
git pull
```

2. Check CHANGELOG.md for breaking changes
3. Reload Hammerspoon

## Troubleshooting

1. Check the Hammerspoon Console for errors
2. Verify your configuration in `config.lua`
3. Look for log messages from specific modules
4. Ensure all required applications are installed

### Debug Shortcuts

- **⌘⌃⌥⇧I** (Command + Control + Option + Shift + I): Inspect all visible windows
  - Shows detailed information about all visible windows including:
    - Application name
    - Window title
    - Window role
    - Window subrole
  - Useful for configuring window management rules and debugging window detection

### Default Shortcuts

The framework comes with several built-in shortcuts:

#### General Shortcuts
- **⌘.** (Command + Period): Open current Finder location in terminal
- **⌘;** (Command + Semicolumn): Open current Finder location in Editor
- **⌘'** (Command + Apostrophe): Open current Finder location in Editor2
- **⌃C** (Control + C): Copy URL from browser
- **⌘⌃⌥⇧S** (Command + Control + Option + Shift + S): Open Hammerspoon config in editor
- **⌘⇧⌥L** (Command + Shift + Option + L): Create symbolic links from clipboard paths to current Finder location

#### Internal Clipboard History
- **⌃⇧1...9** (Control + Shift + Number 1 through 9): Paste the corresponding text item from the internal clipboard history.
  - The history stores the last 9 unique text items copied.
  - Pasting an item moves it to the top of the history.
  - Non-text items are ignored by this history.
  - History is lost when Hammerspoon reloads or quits.
  - This feature operates independently of external clipboard managers like Maccy.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - See LICENSE file for details

## See Also

- [SHORTCUTS.md](docs/SHORTCUTS.md) - Default keyboard shortcuts
- [CHANGELOG.md](docs/CHANGELOG.md) - Version history
- [Hammerspoon Documentation](https://www.hammerspoon.org/docs/)
