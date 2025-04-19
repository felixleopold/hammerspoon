# Hammerspoon Configuration Framework

A modern, modular Hammerspoon configuration framework focused on productivity and extensibility. This framework provides a structured way to manage your Hammerspoon configuration with easy customization options.

## Overview

This framework is organized into several modules:
- **Application Management**: Quick app switching and window control
- **Window Management**: Precise window positioning including halves, thirds, and corners
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
├── application.lua    # App management
├── windowManagement.lua  # Window control
├── fabric.lua        # AI integration
├── clipboard.lua     # Internal clipboard history
└── docs/
    ├── SHORTCUTS.md      # Default shortcuts
    └── CHANGELOG.md      # Version history
```

## Installation

### Prerequisites

- macOS 10.14 or later
- [Homebrew](https://brew.sh/)

#### Installing Homebrew
Follow the installation instructions provided on the official [Homebrew website](https://brew.sh/)  
or directly execute the command:  
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Step-by-Step Installation

1. **Install Hammerspoon**:
   ```bash
   brew install hammerspoon
   ```

2. **Clone this repository**:
   ```bash
   git clone https://github.com/felixleopold/hammerspoon.git ~/.hammerspoon
   ```

3. **Setup Fabric AI** (optional, but recommended for AI features):
   ```bash
   brew install fabric-ai
   
   echo "alias fabric='fabric-ai'" >> ~/.zshrc
   source ~/.zshrc
   ```
   For more details, see the [Fabric Documentation](https://github.com/danielmiessler/fabric?tab=readme-ov-file#installation)

4. **Launch Hammerspoon**:
   ```bash
   open -a Hammerspoon
   ```
   When prompted, grant Hammerspoon the required accessibility permissions in System Settings.

5. **Configure your setup**:
   ```bash
   open ~/.hammerspoon/config.lua
   ```

## Initial Configuration

After installation, you should customize the configuration for your system:

1. **Update Application Definitions**:
   Edit the `applications` section in `config.lua` to match the applications you have installed:

   ```lua
   applications = {
       Browser = "Safari", -- Change to your primary browser
       Editor = "Visual Studio Code", -- Change to your preferred editor
       Terminal = "Terminal", -- Change to your terminal app
       -- Add more applications as needed
   }
   ```

   You can now also use an extended format for applications that need special handling:

   ```lua
   Emacs = {
       name = "Emacs.app",
       bundleID = "org.gnu.Emacs",
       path = "/Applications/Emacs.app" -- Full path if installed in a non-standard location
   },
   ```

2. **Customize Shortcuts**:
   Modify the shortcut keys in the `shortcuts` section to match your preferences.

3. **Reload Configuration**:
   After making changes, reload your configuration with:
   - **⌘⌃⌥⇧R** (Command + Control + Option + Shift + R)

## Key Features

### Window Management

The framework includes advanced window management features:

- **Basic Positioning**:
  - **⌥A**: Left half of screen
  - **⌥D**: Right half of screen
  - **⌥W**: Top half of screen
  - **⌥S**: Bottom half of screen
  - **⌥C**: Center window
  - **⌥F**: Full screen

- **Screen Management**:
  - **⌘⌥A**: Move to previous screen
  - **⌘⌥D**: Move to next screen

### Application Shortcuts

Launch or focus applications with **⌃⌥⌘** (Control + Option + Command) plus a key:
- **⌃⌥⌘Z**: Primary browser
- **⌃⌥⌘C**: Primary editor
- *And more defined in your configuration*

Open specific Finder folders with **⌘⇧** (Command + Shift) plus a key:
- **⌘⇧A**: Applications Folder
- **⌘⇧D**: Desktop Folder
- *And more defined in your configuration*

### Utility Shortcuts

- **⌘⇧X**: Close all Finder windows
- **⌘⇧W**: Close all windows of currect application except for the focused one

### Fabric Shorctus
Execute a fabric pattern call on the current clipboard content with **⌃⌥** (Control + Option) plus a key:
- **⌃⌥R**: Correct Pattern
- **⌃⌥M**: Markdown Pattern

### Internal Clipboard History

Access the last 9 copied text items with **⌃⇧1** through **⌃⇧9**

## Advanced Configuration

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
3. Reload Hammerspoon with **⌘⌃⌥⇧R**

## Troubleshooting

1. Check the Hammerspoon Console for errors (Help > Console in Hammerspoon menu)
2. Verify your configuration in `config.lua`
3. Look for log messages from specific modules
4. Ensure all required applications are installed
5. If everything fails, try resetting Hammerspoon:
   ```bash
   # Backup your custom configuration
   cp ~/.hammerspoon/config.lua ~/config.lua.backup
   
   # Reset Hammerspoon
   rm -rf ~/.hammerspoon
   git clone https://github.com/felixleopold/hammerspoon.git ~/.hammerspoon
   
   # Restore your configuration
   cp ~/config.lua.backup ~/.hammerspoon/config.lua
   ```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## See Also

- [SHORTCUTS.md](docs/SHORTCUTS.md) - Default keyboard shortcuts
- [CHANGELOG.md](docs/CHANGELOG.md) - Version history
- [Hammerspoon Documentation](https://www.hammerspoon.org/docs/)
