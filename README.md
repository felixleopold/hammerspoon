# Hammerspoon Configuration Framework

A modern, modular Hammerspoon configuration framework focused on productivity and extensibility. This framework provides a structured way to manage your Hammerspoon configuration with easy customization options.

## Overview

This framework is organized into several modules:
- **Application Management**: Quick app switching and window control
- **Window Management**: Precise window positioning including halves, thirds, and corners
- **Internal Clipboard History**: Paste recent text items (`Ctrl+Shift+[1-9]`)
- **Fabric AI Integration**: AI-powered text processing and automation
- **Macro Recording**: Record and playback mouse and keyboard actions
- **Custom Shortcuts**: Self-organized system for personal additions
- **Terminal Integration**: Quick terminal access from Finder
- **Debug Tools**: Utilities for configuration and troubleshooting

## Project Structure

```
~/.hammerspoon/
├── init.lua           # Main entry point
├── config.defaults.lua # Default configuration (don't edit)
├── config.user.lua    # User configuration (edit this)
├── config.user.lua.template # Template for user configuration
├── self.lua           # Custom user functions
├── setup.lua          # Configuration processor
├── application.lua    # App management
├── windowManagement.lua  # Window control
├── fabric.lua        # AI integration
├── clipboard.lua     # Internal clipboard history
├── macro.lua         # Macro recording and playback
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
    Install Fabric with homebrew and add an alias to `~/.zshrc`
   ```bash
   brew install fabric-ai
   
   # Optional: add an alias if you want to use just "fabric" instead of "fabric-ai"
   echo "alias fabric='fabric-ai'" >> ~/.zshrc
   source ~/.zshrc
   ```
   
   **Important:** Update the fabric path in your config:
   ```lua
   -- In config.lua, change this line:
   fabricPath = "/opt/homebrew/bin/fabric-ai", -- For Homebrew installation
   ```
   
   For more details, see the [Fabric Documentation](https://github.com/danielmiessler/fabric?tab=readme-ov-file#installation)

4. **Move fabric patterns** 
    Overwrite the fabric patterns in `~/.config/fabric/patterns` with the ones from this repository:
    ```bash
    rsync -a ~/.hammerspoon/fabric-patterns/ ~/.config/fabric/patterns/ && rm -rf ~/.hammerspoon/fabric-patterns
    ```

5. **Launch Hammerspoon**:
   ```bash
   open -a Hammerspoon
   ```
   When prompted, grant Hammerspoon the required accessibility permissions in System Settings.

6. **Configure your setup**:
   ```bash
   open ~/.hammerspoon/config.user.lua
   ```

## Initial Configuration

After installation, you should customize the configuration for your system:

1. **Create your user configuration file**:
   ```bash
   cp ~/.hammerspoon/config.user.lua.template ~/.hammerspoon/config.user.lua
   open ~/.hammerspoon/config.user.lua
   ```

2. **Update Application Definitions**:
   Edit the `applications` section in `config.user.lua` to match the applications you have installed:

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

3. **Customize Shortcuts**:
   Modify the shortcut keys in your `config.user.lua` to match your preferences.

4. **Reload Configuration**:
   After making changes, reload your configuration with:
   - **⌘⌃⌥⇧R** (Command + Control + Option + Shift + R)

## Configuration System

This framework uses a two-file configuration system:

1. **config.defaults.lua** - Contains default values and is part of the source code
2. **config.user.lua** - Contains your personal settings that override the defaults

When you update the framework, your personal settings in `config.user.lua` will be preserved.
New features and settings will be added to `config.defaults.lua` and will be automatically available to you.

You only need to add to `config.user.lua` the settings you want to customize. All other settings will use the defaults.

### Migrating from the old config system

If you're upgrading from a previous version that used `config.lua`, you'll need to manually migrate your settings:

1. Copy the template to create your user config:
   ```bash
   cp ~/.hammerspoon/config.user.lua.template ~/.hammerspoon/config.user.lua
   ```

2. Open both files:
   ```bash
   open ~/.hammerspoon/config.lua
   open ~/.hammerspoon/config.user.lua
   ```

3. Copy your customizations from `config.lua` to `config.user.lua`. You only need to copy the sections that differ from the defaults.

4. Once you've confirmed everything works, you can delete your old `config.lua` file or keep it as a backup.

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

### Macro Recording and Playback

The framework includes a macro recording and playback system:

- **⌥⌘[**: Start/stop recording a macro (toggle)
- **⌥⌘]**: Play the most recently saved macro
- **⌥⌘\\**: Open the macro chooser to select and play any saved macro

When recording, red circles will appear around your mouse cursor whenever you click, and a "Recording Macro..." indicator will be displayed on screen. When playing back a macro, blue circles will highlight the cursor actions.

The system records mouse movements, clicks, and keyboard inputs with accurate timing. Up to 10 macros can be saved, with the oldest ones being automatically replaced when this limit is reached.

### Fabric Shorctus
Execute a fabric pattern call on the current clipboard content with **⌃⌥** (Control + Option) plus a key:
- **⌃⌥R**: Correct Pattern
- **⌃⌥M**: Markdown Pattern

### Internal Clipboard History

Access the last 9 copied text items with **⌃⇧1** through **⌃⇧9**

## Advanced Configuration

### Adding Custom Shortcuts

1. Add your shortcut to `config.user.lua` in the `self` section:
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

When updating the framework, your personal configuration is preserved:

1. Pull the latest changes:
```bash
cd ~/.hammerspoon
git pull
```

2. If new configuration options are added, they will be available in `config.defaults.lua`.
   You can copy them to your `config.user.lua` if you want to customize them.

3. Check CHANGELOG.md for breaking changes

4. Reload Hammerspoon with **⌘⌃⌥⇧R**

## Troubleshooting

1. Check the Hammerspoon Console for errors (Help > Console in Hammerspoon menu)
2. Verify your configuration in `config.user.lua`
3. Look for log messages from specific modules
4. Ensure all required applications are installed
5. If everything fails, try resetting Hammerspoon:
   ```bash
   # Backup your custom configuration
   cp ~/.hammerspoon/config.user.lua ~/config.user.lua.backup
   
   # Reset Hammerspoon
   rm -rf ~/.hammerspoon
   git clone https://github.com/felixleopold/hammerspoon.git ~/.hammerspoon
   
   # Restore your configuration
   cp ~/config.user.lua.backup ~/.hammerspoon/config.user.lua
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
