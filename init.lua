-- Initialize logger
local log = hs.logger.new('MyConfig', 'debug')

-- Set user path dynamically
local userPath = os.getenv("HOME")

-- Set the path for Hammerspoon files
local configPath = userPath .. "/.hammerspoon"

-- Add the config path to package.path
package.path = package.path .. ";" .. configPath .. "/?.lua"

-- Load modules
local application = require("application")
local windowManagement = require("windowManagement")
local fabric = require("fabric")

-- Disable animation for window movements
hs.window.animationDuration = 0

-- Function to reload the Hammerspoon configuration
function reloadConfig(files)
    local doReload = false
    for _, file in pairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
        end
    end
    if doReload then
        hs.reload()
    end
end

-- Set up auto-reload of configuration
local myWatcher = hs.pathwatcher.new(configPath, reloadConfig):start()

-- Set up modules
application.setup(userPath, configPath)
windowManagement.setup(userPath, configPath)
fabric.setup(userPath, configPath)

local CONFIG_VERSION = "1.0.1"

-- Show a notification when the configuration is loaded, including the version number
hs.alert.show("Hammerspoon configuration v" .. CONFIG_VERSION .. " loaded")

log.i("Hammerspoon configuration version " .. CONFIG_VERSION .. " loaded")
