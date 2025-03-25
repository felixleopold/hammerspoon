-- Minecraft window management and shortcuts
local log = hs.logger.new('minecraft', 'debug')

-- Flag to track if a command is being executed
local isExecutingCommand = false

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

-- Helper function to send chat command with key protection
local function sendChatCommand(command, autoExecute, config)
    -- If a command is already being executed, ignore new commands
    if isExecutingCommand then
        log.i("Ignoring command, another command is in progress:", command)
        return
    end
    
    -- Set the executing flag
    isExecutingCommand = true
    
    -- Create a function to reset the flag
    local function resetExecuting()
        isExecutingCommand = false
        log.d("Command execution flag reset, ready for new commands")
    end
    
    -- Get delay settings from config or use defaults
    local chatOpenDelay = (config and config.delays and config.delays.chatOpen) or 50000
    local commandExecutionDelay = (config and config.delays and config.delays.commandExecution) or 200
    
    log.d("Using delays: chatOpen=" .. chatOpenDelay .. "μs, commandExecution=" .. commandExecutionDelay .. "ms")
    
    -- Check if we're in a Minecraft window
    local focusedWindow = hs.window.focusedWindow()
    if not focusedWindow then
        log.e("No focused window found when trying to send command:", command)
        hs.alert.show("Error: No focused window for Minecraft command", 2)
        resetExecuting()
        return
    end
    
    local app = focusedWindow:application()
    if not app or app:name() ~= "java" then
        log.e("Not in a Minecraft window when trying to send command:", command)
        hs.alert.show("Error: Not in Minecraft window", 2)
        resetExecuting()
        return
    end
    
    log.d("Sending 't' keystroke to open chat")
    -- Press T to open chat
    hs.eventtap.keyStroke({}, "t")
    
    -- Small delay to ensure chat is open
    log.d("Waiting " .. chatOpenDelay .. "μs for chat to open")
    hs.timer.usleep(chatOpenDelay)
    
    log.d("Typing command: " .. command)
    -- Type the command
    hs.eventtap.keyStrokes(command)
    
    -- Log the command being sent
    log.i("Executing command:", command, autoExecute and "(auto)" or "(manual)")
    
    if autoExecute then
        -- For auto-execute commands, add a delay before allowing new commands
        log.d("Auto-executing command with Enter key")
        hs.timer.usleep(chatOpenDelay)
        hs.eventtap.keyStroke({}, "return")
        -- Add a small delay after command execution before allowing new commands
        log.d("Setting timer to reset execution flag after " .. commandExecutionDelay .. "ms")
        hs.timer.doAfter(commandExecutionDelay / 1000, resetExecuting)
    else
        -- For manual commands, reset immediately since user needs to type more
        log.d("Manual command, resetting execution flag immediately")
        resetExecuting()
    end
end

-- Initialize Minecraft-specific shortcuts
local function initMinecraftShortcuts(config)
    -- Check if config is provided
    config = config or {}
    
    -- Ensure minecraft config exists
    config.minecraft = config.minecraft or {
        delays = {
            chatOpen = 50000,
            commandExecution = 200
        }
    }
    
    -- Set debug mode based on config
    if config.minecraft.debug then
        log.setLogLevel('debug')
    end
    
    log.i("Initializing Minecraft shortcuts with config:", hs.inspect(config.minecraft))
    
    -- Add a test function to manually check Minecraft detection
    local function testMinecraftDetection()
        log.i("Testing Minecraft detection")
        local allWindows = hs.window.allWindows()
        local foundMinecraft = false
        local windowDetails = {}
        
        for i, window in ipairs(allWindows) do
            local app = window:application()
            local appName = app and app:name() or "Unknown"
            
            -- Log all java windows
            if appName == "java" then
                local details = {
                    index = i,
                    title = window:title() or "No Title",
                    app = appName,
                    role = window:role() or "No Role",
                    subrole = window:subrole() or "No Subrole",
                    id = window:id(),
                    isMinecraft = isMinecraftWindow(window, config)
                }
                
                table.insert(windowDetails, details)
                
                if details.isMinecraft then
                    foundMinecraft = true
                    log.i("Found Minecraft window:", window:title())
                end
            end
        end
        
        -- Create a formatted output
        local output = "Minecraft Detection Results:\n\n"
        if #windowDetails == 0 then
            output = output .. "No Java windows found.\n"
        else
            for _, details in ipairs(windowDetails) do
                output = output .. string.format(
                    "%d: %s\n   App: %s\n   Role: %s\n   Subrole: %s\n   ID: %d\n   Is Minecraft: %s\n\n",
                    details.index, details.title, details.app, details.role, details.subrole, details.id,
                    details.isMinecraft and "YES" or "no"
                )
            end
        end
        
        -- Show the results in a large alert
        hs.alert.show(output, {textSize=12}, 10)
        
        -- Also log to console for reference
        log.i(output)
        
        return foundMinecraft
    end
    
    -- Add a hotkey to test Minecraft detection
    hs.hotkey.bind({"cmd", "alt", "shift"}, "T", testMinecraftDetection)
    
    -- Create a window filter for Minecraft with the updated detection function
    local minecraftFilter = hs.window.filter.new(function(window)
        return isMinecraftWindow(window, config)
    end)
    
    -- This will store our hotkeys
    local minecraftHotkeys = {}
    
    -- Function to bind Minecraft-specific shortcuts
    local function bindMinecraftShortcuts()
        log.i("Minecraft shortcuts activated")
        if _G.showAlert then
            _G.showAlert("Minecraft shortcuts activated", 2)
        else
            hs.alert.show("Minecraft shortcuts activated", 2)
        end
        
        -- Log all the shortcuts we're about to bind
        log.d("Binding Minecraft shortcuts:")
        log.d("- ctrl+c: /creative")
        log.d("- ctrl+x: /survival")
        log.d("- ctrl+s: /spectator")
        log.d("- ctrl+l: /pa leave")
        log.d("- ctrl+alt+[1-9]: /pa Arena[1-9]")
        log.d("- ctrl+g: /gaia revert")
        log.d("- ctrl+e: /gaia create")
        log.d("- ctrl+r: /gaia remove")
        log.d("- ctrl+t: /mv tp")
        log.d("- alt+1: //pos1")
        log.d("- alt+2: //pos2")
        log.d("- alt+s: //set")
        log.d("- alt+r: //replace")
        log.d("- alt+w: //wand")
        log.d("- alt+a: //walls")
        log.d("- alt+u: //undo")
        log.d("- alt+y: //redo")
        
        -- Control + key shortcuts
        minecraftHotkeys.creative = hs.hotkey.bind({"ctrl"}, "c", function() sendChatCommand("/creative", true, config.minecraft) end)
        minecraftHotkeys.survival = hs.hotkey.bind({"ctrl"}, "x", function() sendChatCommand("/survival", true, config.minecraft) end)
        minecraftHotkeys.spectator = hs.hotkey.bind({"ctrl"}, "s", function() sendChatCommand("/spectator", true, config.minecraft) end)
        minecraftHotkeys.leave = hs.hotkey.bind({"ctrl"}, "l", function() sendChatCommand("/pa leave", true, config.minecraft) end)
        
        -- Control + Option + number for arenas (1-9)
        for i = 1, 9 do
            minecraftHotkeys["arena"..i] = hs.hotkey.bind({"ctrl", "alt"}, tostring(i), function()
                sendChatCommand("/pa Arena"..i.." ", false, config.minecraft)
            end)
        end
        
        -- Control + key for Gaia and MV commands
        minecraftHotkeys.gaiaRevert = hs.hotkey.bind({"ctrl"}, "g", function() sendChatCommand("/gaia revert ", false, config.minecraft) end)
        minecraftHotkeys.gaiaCreate = hs.hotkey.bind({"ctrl"}, "e", function() sendChatCommand("/gaia create ", false, config.minecraft) end)
        minecraftHotkeys.gaiaRemove = hs.hotkey.bind({"ctrl"}, "r", function() sendChatCommand("/gaia remove ", false, config.minecraft) end)
        minecraftHotkeys.mvTp = hs.hotkey.bind({"ctrl"}, "t", function() sendChatCommand("/mv tp ", false, config.minecraft) end)
        
        -- Option + key for WorldEdit commands
        minecraftHotkeys.pos1 = hs.hotkey.bind({"alt"}, "1", function() sendChatCommand("//pos1", true, config.minecraft) end)
        minecraftHotkeys.pos2 = hs.hotkey.bind({"alt"}, "2", function() sendChatCommand("//pos2", true, config.minecraft) end)
        minecraftHotkeys.set = hs.hotkey.bind({"alt"}, "s", function() sendChatCommand("//set ", false, config.minecraft) end)
        minecraftHotkeys.replace = hs.hotkey.bind({"alt"}, "r", function() sendChatCommand("//replace ", false, config.minecraft) end)
        minecraftHotkeys.wand = hs.hotkey.bind({"alt"}, "w", function() sendChatCommand("//wand", true, config.minecraft) end)
        minecraftHotkeys.walls = hs.hotkey.bind({"alt"}, "a", function() sendChatCommand("//walls", true, config.minecraft) end)
        minecraftHotkeys.undo = hs.hotkey.bind({"alt"}, "u", function() sendChatCommand("//undo", true, config.minecraft) end)
        minecraftHotkeys.redo = hs.hotkey.bind({"alt"}, "y", function() sendChatCommand("//redo", true, config.minecraft) end)
    end
    
    -- Function to unbind Minecraft-specific shortcuts
    local function unbindMinecraftShortcuts()
        for _, hotkey in pairs(minecraftHotkeys) do
            hotkey:disable()
        end
        -- Reset command execution flag when unbinding shortcuts
        isExecutingCommand = false
        log.i("Minecraft shortcuts deactivated")
        if _G.showAlert then
            _G.showAlert("Minecraft shortcuts deactivated", 2)
        else
            hs.alert.show("Minecraft shortcuts deactivated", 2)
        end
    end
    
    -- Subscribe to window focus events with debug logging
    minecraftFilter:subscribe(hs.window.filter.windowFocused, function(window)
        log.i("Minecraft window focused:", window:title())
        bindMinecraftShortcuts()
    end)
    
    minecraftFilter:subscribe(hs.window.filter.windowUnfocused, function(window)
        log.i("Minecraft window unfocused:", window:title())
        unbindMinecraftShortcuts()
    end)
    
    -- Check if Minecraft is currently focused
    local focusedWindow = hs.window.focusedWindow()
    if focusedWindow and isMinecraftWindow(focusedWindow, config) then
        log.i("Minecraft is already focused at startup")
        bindMinecraftShortcuts()
    else
        log.d("No Minecraft window focused at startup")
        if focusedWindow then
            log.d("Current focused window:", focusedWindow:title(), "App:", focusedWindow:application():name())
        end
    end
    
    -- Add a manual hotkey to force-check for Minecraft windows
    hs.hotkey.bind({"cmd", "alt", "shift"}, "M", function()
        log.i("Manual Minecraft window check triggered")
        local allWindows = hs.window.allWindows()
        local foundMinecraft = false
        
        for _, window in ipairs(allWindows) do
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
        
        if not foundMinecraft then
            log.i("No Minecraft windows found")
            hs.alert.show("No Minecraft windows detected")
        end
    end)
    
    log.i("Minecraft shortcuts ready")
end

-- Return the initialization function
return initMinecraftShortcuts 