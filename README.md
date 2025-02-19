# Hammerspoon Configuration Framework

A modern, modular Hammerspoon configuration framework focused on productivity and extensibility. This framework provides a structured way to manage your Hammerspoon configuration with easy customization options.

## Overview

This framework is organized into several modules:
- **Application Management**: Quick app switching and window control
- **Window Management**: Window positioning, sizing, and cycling
- **Fabric AI Integration**: AI-powered text processing and automation
- **Custom Shortcuts**: Self-organized system for personal additions

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
│   └── fabric.lua        # AI integration
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

3. For AI features (optional), install Fabric CLI:
```bash
go install github.com/mrakinola/fabric-cli@latest
```

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
