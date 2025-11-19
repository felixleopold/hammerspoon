---@diagnostic disable: undefined-global
-- Minecraft window management and Kanata integration
local log = hs.logger.new('minecraft', 'debug')

-- Kanata integration state
local kanataModule = nil
local windowFilter = nil
-- By removing previousKanataMode, we make the logic stateless and more robust.
-- The module will now always revert to the default mode instead of trying to remember the previous one.

-- Periodic click state
local periodicClickTimer = nil

-- Function to check if the focused window is Minecraft
local function isMinecraftWindow(window, config)
    if not window then return false end

    local app = window:application()
    if not app then return false end

    -- Get the application name
    local appName = app:name()

    -- Get configuration or use defaults
    local mcConfig = config and config.minecraft or {}
    local debug = mcConfig.debug or false
    local detection = mcConfig.detection or {
        appNames = {"java"},
        titlePatterns = {"minecraft", "Minecraft"}
    }

    -- Log window details if debug is enabled
    if debug then
        log.d(string.format("Checking window: App=%s, Title=%s, Role=%s, Subrole=%s",
            appName,
            window:title() or "nil",
            window:role() or "nil",
            window:subrole() or "nil"))
    end

    -- Check if app name matches any in the configured list
    local appNameMatches = false
    for _, name in ipairs(detection.appNames) do
        if appName == name then
            appNameMatches = true
            break
        end
    end

    if debug then
        log.d(string.format("Checking window: App=%s, Title=%s, Role=%s, Subrole=%s",
            appName,
            window:title() or "nil",
            window:role() or "nil",
            window:subrole() or "nil"))
        log.d(string.format("Window check results: appMatch=%s (treating all '%s' as Minecraft)",
            tostring(appNameMatches), table.concat(detection.appNames, ", ")))
    end

    if appNameMatches then
        log.i("Minecraft window detected:", window:title())
        return true
    end

    return false
end

-- Function to switch Kanata to gaming mode when Minecraft is focused
local function switchToGamingMode(config, kanata)
    if not config.minecraft or not config.minecraft.kanataSwitching then
        log.d("Kanata switching disabled in config")
        return
    end

    local currentMode = kanata.getCurrentMode()
    if currentMode ~= "gaming" then
        log.i("Switching Kanata from " .. currentMode .. " to gaming mode for Minecraft")
        -- No longer need to store the previous mode.
        kanata.setMode("gaming", true)
    end
end

-- Function to restore previous Kanata mode when Minecraft loses focus
local function restorePreviousMode(config, kanata)
    if not config.minecraft or not config.minecraft.kanataSwitching then
        log.d("Kanata switching disabled in config")
        return
    end

    -- Per user request, always revert specifically to normal mode regardless of previous mode.
    local targetMode = "normal"
    local currentMode = kanata.getCurrentMode()
    if currentMode ~= targetMode then
        log.i("Restoring Kanata mode to normal (was: " .. tostring(currentMode) .. ")")
        kanata.setMode(targetMode, true)
    end
end

-- Function to perform the periodic click
local function performPeriodicClick()
    log.d("Performing periodic click for Minecraft")
    hs.eventtap.leftClick(hs.mouse.getAbsolutePosition())
end

-- Function to start the periodic click timer
local function startPeriodicClickTimer(config)
    if not config.minecraft or not config.minecraft.periodicClick or not config.minecraft.periodicClick.enabled then
        log.d("Periodic click disabled in config")
        return
    end

    local interval = config.minecraft.periodicClick.interval or 145
    log.i("Starting periodic click timer (interval: " .. interval .. "s)")
    
    -- Stop any existing timer
    if periodicClickTimer then
        periodicClickTimer:stop()
        periodicClickTimer = nil
    end
    
    -- Create and start new timer
    periodicClickTimer = hs.timer.doEvery(interval, performPeriodicClick)
    -- Perform first click immediately
    performPeriodicClick()
end

-- Function to stop the periodic click timer
local function stopPeriodicClickTimer()
    if periodicClickTimer then
        log.i("Stopping periodic click timer")
        periodicClickTimer:stop()
        periodicClickTimer = nil
    end
end

local M = {}

-- Initialize Minecraft integration with Kanata switching
function M.setup(config)
    -- Check if config is provided
    config = config or {}
    
    -- Ensure minecraft config exists
    config.minecraft = config.minecraft or {}
    
    -- Set debug mode based on config
    if config.minecraft.debug then
        log.setLogLevel('debug')
    end
    
    -- Get Kanata module reference
    kanataModule = require("kanata")
    
    -- Lightweight startup logging
    log.i("Initializing Minecraft integration with Kanata switching")
    
    -- Clean up any existing window filter from previous reloads
    if windowFilter then
        pcall(function() windowFilter:unsubscribeAll() end)
        windowFilter = nil
        log.d("Cleaned up previous window filter subscriptions")
    end

    -- State tracking for Minecraft focus
    local minecraftActive = false
    
    -- Test function for Minecraft detection
    local function testMinecraftDetection()
        log.i("Testing Minecraft detection")
        local javaApp = hs.application.get("java")
        local foundMinecraft = false
        
        if javaApp then
            local windows = javaApp:allWindows()
            for _, window in ipairs(windows) do
                if isMinecraftWindow(window, config) then
                    foundMinecraft = true
                    log.i("Found Minecraft window:", window:title())
                    break
                end
            end
        end
        
        if not foundMinecraft then
            log.i("No Minecraft windows found")
            hs.alert.show("No Minecraft windows detected")
        else
            hs.alert.show("Minecraft window detected")
        end
        
        return foundMinecraft
    end
    
    -- Add a hotkey to test Minecraft detection
    hs.hotkey.bind({"cmd", "alt", "shift"}, "T", testMinecraftDetection)

    -- Subscribe to window focus/unfocus events for configured Java apps only.
    -- We treat every matching app window as a Minecraft window per user request.
    windowFilter = hs.window.filter.new(false)
    for _, name in ipairs(config.minecraft.detection.appNames) do
        windowFilter:setAppFilter(name, { allowTitles = ".*" })
    end

    -- When a Java window gains focus
    windowFilter:subscribe(hs.window.filter.windowFocused, function(win)
        if not win then return end
        if not minecraftActive then
            log.i("Java window focused: " .. (win:title() or "(no title)"))
            minecraftActive = true
        end
        switchToGamingMode(config, kanataModule)
    end)

    -- When a Java window loses focus, revert unless another Java window immediately gains focus
    windowFilter:subscribe(hs.window.filter.windowUnfocused, function(_win)
        -- Debounce briefly to allow focus to move to another Java window without flipping modes
        hs.timer.doAfter(0.05, function()
            local fw = hs.window.focusedWindow()
            -- If no focused window or focused window is not in Java apps, revert
            local fwApp = fw and fw:application() and fw:application():name() or nil
            local isStillJava = false
            if fwApp then
                for _, name in ipairs(config.minecraft.detection.appNames) do
                    if fwApp == name then isStillJava = true break end
                end
            end
            if not isStillJava then
                if minecraftActive then
                    log.i("Java window defocused, restoring normal mode")
                    minecraftActive = false
                end
                restorePreviousMode(config, kanataModule)
            end
        end)
    end)
    
    -- Manual hotkey to focus Minecraft window
    hs.hotkey.bind({"cmd", "alt", "shift"}, "M", function()
        log.i("Manual Minecraft window check triggered")
        local javaApp = hs.application.get("java")
        local foundMinecraft = false
        
        if javaApp then
            local windows = javaApp:allWindows()
            for _, window in ipairs(windows) do
                if isMinecraftWindow(window, config) then
                    foundMinecraft = true
                    log.i("Found Minecraft window:", window:title())
                    if window ~= hs.window.focusedWindow() then
                        log.i("Focusing Minecraft window")
                        window:focus()
                    end
                    break
                end
            end
        end
        
        if not foundMinecraft then
            log.i("No Minecraft windows found")
            hs.alert.show("No Minecraft windows detected")
        end
    end)
    
    log.i("Minecraft integration ready with Kanata switching")
end

-- Return the module
return M 