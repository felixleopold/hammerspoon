local M = {}
local log = hs.logger.new('Self', 'debug')

-- Table to store all custom functions
local functions = {}

-- Example function
function functions.sayHello()
    log.i("Showing hello message")
    hs.alert.show("Hello from custom shortcut!")
end

-- Add your custom functions here
-- function functions.yourFunctionName()
--     log.i("Your function description")
--     -- Your code here
-- end

function M.setup(config)
    log.i("Setting up self-organized shortcuts")
    
    -- Validate config
    if not config.self or not config.self.shortcuts then
        log.w("No self-organized shortcuts configured")
        return
    end

    -- Process each shortcut
    for _, shortcut in ipairs(config.self.shortcuts) do
        log.i(string.format("Setting up custom shortcut: %s (%s + %s)",
            shortcut.name,
            table.concat(shortcut.mods, "+"),
            shortcut.key))

        -- Validate function exists
        if not functions[shortcut.name] then
            log.e(string.format("Function '%s' not found in self.lua", shortcut.name))
            goto continue
        end

        -- Bind the shortcut
        hs.hotkey.bind(shortcut.mods, shortcut.key, function()
            log.i(string.format("Executing custom function: %s", shortcut.name))
            functions[shortcut.name]()
        end)

        ::continue::
    end

    log.i("Self-organized shortcuts setup complete")
end

return M
