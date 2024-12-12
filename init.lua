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

-- Custom alert styling
local ALERT_STYLE = {
    strokeWidth = 1,
    radius = 9,  -- macOS-style rounded corners
    textFont = ".AppleSystemUIFont",
    textSize = 13,  -- Standard system size
    fadeInDuration = 0.15,
    fadeOutDuration = 0.15,
    atScreenEdge = 2,  -- 2 = bottom of screen
    padding = 12,
    strokeColor = { white = 1, alpha = 0.05 },  -- Subtle border
    fillColor = { white = 0.15, alpha = 0.90 },  -- Slightly translucent dark background
    textColor = { white = 1, alpha = 1 },  -- Crisp white text
    backgroundStyle = "dark",  -- Ensures proper contrast
    textStyle = {  -- Center align text
        paragraphStyle = {
            alignment = "center",
        }
    },
    maxWidth = 400,  -- Maximum width in pixels
}

-- Set global alert styling
hs.alert.defaultStyle = ALERT_STYLE

-- Current active alert
local currentAlert = nil

-- Helper function for consistent alerts
function showAlert(message, duration)
    -- Clear any existing alert
    if currentAlert then
        hs.alert.closeSpecific(currentAlert)
    end
    
    -- Truncate message if too long
    if #message > 50 then
        message = message:sub(1, 47) .. "..."
    end
    
    -- Show the alert
    duration = duration or 1.5  -- Default duration
    currentAlert = hs.alert.show(message, ALERT_STYLE, duration)
    
    return currentAlert
end

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
fabric.setup(config)
windowManagement.setup(config)
application.setup(config)

-- Show a notification when the configuration is loaded
hs.alert.show("Hammerspoon configuration v" .. version.current .. " loaded")
log.i("Hammerspoon configuration version " .. version.current .. " loaded")
