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
local setup = require("setup")
local version = require("version")  -- Add this line to import the version module

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

-- Load configuration
local config = setup.getConfig()

-- Set up modules
application.setup()
windowManagement.setup()
fabric.setup()

-- Bind setup wizard
setup.bindSetupWizard()

-- Show a notification when the configuration is loaded
hs.alert.show("Hammerspoon configuration v" .. version.current .. " loaded")

log.i("Hammerspoon configuration version " .. version.current .. " loaded")
