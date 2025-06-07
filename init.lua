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
local inspectWindows = require("inspect_windows")
local minecraft = require("minecraft")
local clipboard = require("clipboard")
local macro = require("macro")
local leftRightModifier = require("leftRightModifier")
local kanata = require("kanata")
local appGroups = require("appGroups")

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
        -- Skip clipboard files (both history and stored files)
        if not file:match("hammerspoon_clipboard") and 
           not file:match("clipboard_history%.json") and
           not file:match("clipboard_files/") then
            if file:sub(-4) == ".lua" or file:sub(-5) == ".json" then
                doReload = true
            end
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
    log.e("Failed to load configuration, using empty configuration")
    config = {
        applications = {},
        folders = {},
        triggers = {},
        shortcuts = {
            general = {},
            appShortcuts = {},
            folderShortcuts = {},
            windowManagement = {},
            utils = {}
        },
        self = {
            shortcuts = {}
        }
    }
    hs.alert.show("Failed to load configuration. Check console for details.", 5)
end

-- Check if we're using the new configuration system
if setup.usingNewConfigSystem then
    log.i("Using new configuration system")
    if setup.usingUserConfig then
        log.i("User configuration loaded from config_user.lua")
    else
        log.i("Using default configuration (no user config found)")
    end
else
    log.w("Using legacy configuration system (config.lua)")
end

-- Debug print the loaded configuration
log.i("Configuration loaded successfully")
log.d("General shortcuts: " .. hs.inspect(config.shortcuts.general or {}))

-- Debug kanata configuration
log.i("Kanata config check: " .. hs.inspect(config.kanata))
if config.kanata then
    log.i("Kanata enabled: " .. tostring(config.kanata.enabled))
else
    log.e("Kanata config is nil!")
end

-- Use this config when setting up modules
log.i("Setting up modules with configuration")

-- Safely initialize modules with fallback for errors
local function safeSetup(module, name)
    local success, err = pcall(function() 
        module.setup(config)
    end)
    if not success then
        log.e("Failed to set up " .. name .. " module: " .. tostring(err))
        hs.alert.show("Failed to initialize " .. name .. " module", 3)
    else
        log.i("Successfully set up " .. name .. " module")
    end
end

-- Set up core modules with error handling
safeSetup(application, "application")
safeSetup(windowManagement, "window management")
safeSetup(fabric, "fabric")
safeSetup(self, "self")

-- Initialize macro module if configuration permits
log.i("Initializing macro module")
if config.macros and config.macros.enabled ~= false then
    safeSetup(macro, "macro")
else
    log.i("Macro module disabled in config")
end

-- Initialize clipboard if enabled
if config.clipboard and config.clipboard.enabled then
    log.i("Initializing clipboard module")
    safeSetup(clipboard, "clipboard")
else
    log.i("Clipboard module disabled in config")
end

-- Only initialize Minecraft if enabled in config
if config and config.minecraft and config.minecraft.enabled then
    log.i("Initializing Minecraft module")
    local success, err = pcall(function() minecraft(config) end)
    if not success then
        log.e("Failed to initialize Minecraft module: " .. tostring(err))
    end
else
    log.i("Minecraft module disabled in config")
end

-- Initialize kanata module if enabled
if config.kanata and config.kanata.enabled then
    log.i("Initializing Kanata module")
    safeSetup(kanata, "kanata")
else
    log.i("Kanata module disabled in config")
end

-- Set up hotkey to inspect windows (Cmd + Alt + Shift + I)
hs.hotkey.bind({"cmd", "alt", "shift"}, "I", inspectWindows)

-- Add diagnostic hotkey for left/right modifiers (Cmd + Alt + Shift + M)
hs.hotkey.bind({"cmd", "alt", "shift"}, "M", function()
    local state = leftRightModifier.getState()
    log.i("Left/Right Modifier State: " .. hs.inspect(state))
    hs.alert.show("Left/Right Modifier Status: " .. #state.keyHandlers .. " handlers active")
end)

-- Add diagnostic hotkey for app groups (Cmd + Alt + Shift + G)
hs.hotkey.bind({"cmd", "alt", "shift"}, "G", function()
    if config.appGroups then
        local groupInfo = {}
        for groupName, groupConfig in pairs(config.appGroups) do
            local state = appGroups.getGroupState(groupName)
            table.insert(groupInfo, string.format("%s: mode=%s, index=%d", 
                groupName, state.mode, state.currentIndex))
        end
        local message = "App Groups:\n" .. table.concat(groupInfo, "\n")
        log.i("App Groups State: " .. hs.inspect(groupInfo))
        hs.alert.show(message, 3)
    else
        hs.alert.show("No app groups configured", 2)
    end
end)

-- Add diagnostic hotkey for kanata (Cmd + Alt + Shift + K)
hs.hotkey.bind({"cmd", "alt", "shift"}, "K", function()
    log.i("Manual Kanata test triggered")
    log.i("Config kanata section: " .. hs.inspect(config.kanata))
    
    if config.kanata then
        log.i("Attempting to manually setup Kanata...")
        local success, err = pcall(function()
            kanata.setup(config)
        end)
        if success then
            -- Force refresh the menu bar
            kanata.forceRefresh()
            hs.alert.show("Kanata setup successful! Check menu bar.", 3)
        else
            hs.alert.show("Kanata setup failed: " .. tostring(err), 5)
            log.e("Kanata setup error: " .. tostring(err))
        end
    else
        hs.alert.show("No kanata config found", 3)
    end
end)

-- Show a notification when the configuration is loaded
hs.alert.show("Hammerspoon configuration v" .. version.current .. " loaded")
log.i("Hammerspoon configuration version " .. version.current .. " loaded")
