-- Minecraft window management and Kanata integration
local log = hs.logger.new('minecraft', 'debug')

-- Kanata integration state
local kanataModule = nil
local previousKanataMode = nil

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
    
    if not appNameMatches then
        if debug then log.d("App name doesn't match Minecraft criteria") end
        return false
    end
    
    -- Check if window title contains any of the configured patterns
    local titleMatches = false
    local windowTitle = window:title() or ""
    for _, pattern in ipairs(detection.titlePatterns) do
        if string.match(string.lower(windowTitle), string.lower(pattern)) then
            titleMatches = true
            break
        end
    end
    
    -- Accept standard window types
    local roleOk = window:role() == "AXWindow" or window:role() == "AXApplication"
    local subroleOk = window:subrole() == "AXStandardWindow" or window:subrole() == "AXUnknown"
    
    local isMinecraft = appNameMatches and titleMatches and roleOk and subroleOk
    
    if debug then
        log.d(string.format("Window check results: appMatch=%s, titleMatch=%s, roleOk=%s, subroleOk=%s, isMinecraft=%s",
            tostring(appNameMatches), tostring(titleMatches), tostring(roleOk), tostring(subroleOk), tostring(isMinecraft)))
    end
    
    if isMinecraft then
        log.i("Minecraft window detected:", window:title())
    end
           
    return isMinecraft
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
        previousKanataMode = currentMode
        kanata.setMode("gaming", true)
    end
end

-- Function to restore previous Kanata mode when Minecraft loses focus
local function restorePreviousMode(config, kanata)
    if not config.minecraft or not config.minecraft.kanataSwitching then
        log.d("Kanata switching disabled in config")
        return
    end

    if previousKanataMode and previousKanataMode ~= "gaming" then
        log.i("Restoring Kanata from gaming mode to " .. previousKanataMode)
        kanata.setMode(previousKanataMode, true)
        previousKanataMode = nil
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

    
    -- Subscribe to window focus events to detect Minecraft focus changes
    local windowFilter = hs.window.filter.new()
    windowFilter:subscribe(hs.window.filter.windowFocused, function(window, appName)
        if not window then return end

        -- Check if the focused window is a Minecraft window
        if isMinecraftWindow(window, config) then
            if not minecraftActive then
                log.i("Minecraft window focused: " .. window:title())
                minecraftActive = true
                switchToGamingMode(config, kanataModule)
            end
        else
            if minecraftActive then
                log.d("Lost Minecraft focus")
                minecraftActive = false
                restorePreviousMode(config, kanataModule)
            end
        end
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