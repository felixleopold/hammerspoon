-- Initialize logger
local log = hs.logger.new('MyConfig', 'debug')

-- Set the path for Hammerspoon files
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.hammerspoon/?.lua"

-- Load modules
local application = require("application")
local windowManagement = require("windowManagement")
local fabric = require("fabric")
local setup = require("setup")
local version = require("version")

-- Disable animation for window movements
hs.window.animationDuration = 0

-- Function to reload the Hammerspoon configuration
function reloadConfig(files)
    local doReload = false
    for _, file in pairs(files) do
        if file:sub(-4) == ".lua" or file:sub(-5) == ".json" then
            doReload = true
        end
    end
    if doReload then
        hs.reload()
    end
end

-- Set up auto-reload of configuration
local myWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon", reloadConfig):start()

-- Load configuration
local config = setup.getConfig()

-- Use this config when setting up modules
application.setup(config)
windowManagement.setup(config)
fabric.setup(config)

-- Show a notification when the configuration is loaded
hs.alert.show("Hammerspoon configuration v" .. version.current .. " loaded")
log.i("Hammerspoon configuration version " .. version.current .. " loaded")
