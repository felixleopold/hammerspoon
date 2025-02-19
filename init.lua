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
local self = require("self")

-- Disable animation for window movements
hs.window.animationDuration = 0

-- Custom alert styling
local ALERT_STYLE = {
    strokeWidth = 1,
    radius = 9,  -- macOS-style rounded corners
    textFont = ".AppleSystemUIFont",
    textSize = 13,  -- Standard system size
    fadeInDuration = 0.15,
    fadeOutDuration = 0.15,
    atScreenEdge = 2,
    padding = 12,
    strokeColor = { white = 1, alpha = 0.05 },  -- Subtle border
    fillColor = { white = 0.15, alpha = 0.90 },  -- Slightly translucent dark background
    textColor = { white = 1, alpha = 1 },  -- Crisp white text
    backgroundStyle = "dark",  -- Ensures proper contrast
}

-- Set global alert styling
hs.alert.defaultStyle = ALERT_STYLE

-- Helper function for consistent alerts
function showAlert(message, duration)
    duration = duration or 2  -- Default duration
    hs.alert.show(message, ALERT_STYLE, duration)
end

-- Function to reload the configuration
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
log.i("Loading configuration...")
local config = setup.getConfig()
if not config then
    log.e("Failed to load configuration")
    return
end

-- Debug print the loaded configuration
log.i("Configuration loaded successfully")
log.d("General shortcuts: " .. hs.inspect(config.shortcuts.general))

-- Use this config when setting up modules
log.i("Setting up modules with configuration")
application.setup(config)
windowManagement.setup(config)
fabric.setup(config)
self.setup(config)

-- Show a notification when the configuration is loaded
hs.alert.show("Hammerspoon configuration v" .. version.current .. " loaded")
log.i("Hammerspoon configuration version " .. version.current .. " loaded")
