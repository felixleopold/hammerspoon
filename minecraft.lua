-- Minecraft window management and shortcuts
local log = hs.logger.new('minecraft', 'debug')

-- Command execution state management
local commandQueue = {}
local isExecutingCommand = false
local lastCommandTime = 0

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

-- Enhanced command execution with queueing and better timing
local function sendChatCommand(command, autoExecute, config)
    local currentTime = hs.timer.secondsSinceEpoch()
    
    -- Get execution settings from config
    local executionConfig = (config and config.execution) or {}
    local enableQueue = executionConfig.enableQueue ~= false -- Default to true
    local minCommandInterval = (executionConfig.minCommandInterval or 100) / 1000 -- Convert to seconds
    
    -- Rate limiting: prevent commands too close together
    if currentTime - lastCommandTime < minCommandInterval then
        if enableQueue then
            log.d("Command rate limited, queuing:", command)
            table.insert(commandQueue, {command = command, autoExecute = autoExecute, config = config})
        else
            log.d("Command rate limited, ignoring:", command)
        end
        return
    end
    
    -- If a command is already being executed, queue this one
    if isExecutingCommand then
        if enableQueue then
            log.d("Command queued:", command)
            table.insert(commandQueue, {command = command, autoExecute = autoExecute, config = config})
        else
            log.d("Command ignored, another in progress:", command)
        end
        return
    end
    
    -- Set the executing flag
    isExecutingCommand = true
    lastCommandTime = currentTime
    
    -- Create a function to reset the flag and process queue
    local function resetExecuting()
        isExecutingCommand = false
        log.d("Command execution flag reset, ready for new commands")
        
        -- Process next command in queue if any
        if #commandQueue > 0 then
            local nextCommand = table.remove(commandQueue, 1)
            log.d("Processing queued command:", nextCommand.command)
            hs.timer.doAfter(0.05, function() -- Small delay between queued commands
                sendChatCommand(nextCommand.command, nextCommand.autoExecute, nextCommand.config)
            end)
        end
    end
    
    -- Get delay settings from config or use defaults
    local chatOpenDelay = (config and config.delays and config.delays.chatOpen) or 70000
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
    
    -- Enhanced chat opening with better timing
    log.d("Sending 't' keystroke to open chat")
    hs.eventtap.keyStroke({}, "t")
    
    -- Adaptive delay based on command type
    local adaptiveDelay = chatOpenDelay
    local adaptiveTiming = executionConfig.adaptiveTiming ~= false -- Default to true
    
    if adaptiveTiming then
        if string.match(command, "^//") then -- WorldEdit commands might need more time
            adaptiveDelay = chatOpenDelay * 1.2
        elseif string.match(command, "^/pa") then -- ProjectArena commands
            adaptiveDelay = chatOpenDelay * 1.1
        elseif string.match(command, "^/gaia") then -- Gaia commands
            adaptiveDelay = chatOpenDelay * 1.15
        end
    end
    
    log.d("Waiting " .. adaptiveDelay .. "μs for chat to open")
    hs.timer.usleep(adaptiveDelay)
    
    -- Clear any existing text in chat before typing command
    log.d("Clearing chat and typing command: " .. command)
    hs.eventtap.keyStroke({"cmd"}, "a") -- Select all
    hs.timer.usleep(10000) -- 10ms delay
    hs.eventtap.keyStrokes(command)
    
    -- Log the command being sent
    log.i("Executing command:", command, autoExecute and "(auto)" or "(manual)")
    
    if autoExecute then
        -- For auto-execute commands, add a delay before sending Enter
        log.d("Auto-executing command with Enter key")
        hs.timer.usleep(adaptiveDelay * 0.5) -- Half the chat open delay
        hs.eventtap.keyStroke({}, "return")
        
        -- Add a delay after command execution before allowing new commands
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
    
    -- Lightweight startup logging - avoid expensive hs.inspect
    log.i("Initializing Minecraft shortcuts")
    
    -- Optimized test function - only scans Java windows
    local function testMinecraftDetection()
        log.i("Testing Minecraft detection")
        local javaWindows = {}
        local foundMinecraft = false
        
        -- Only scan windows from Java applications to reduce overhead
        local javaApp = hs.application.get("java")
        if javaApp then
            local windows = javaApp:allWindows()
            for i, window in ipairs(windows) do
                local details = {
                    index = i,
                    title = window:title() or "No Title",
                    app = "java",
                    role = window:role() or "No Role",
                    subrole = window:subrole() or "No Subrole",
                    id = window:id(),
                    isMinecraft = isMinecraftWindow(window, config)
                }
                
                table.insert(javaWindows, details)
                
                if details.isMinecraft then
                    foundMinecraft = true
                    log.i("Found Minecraft window:", window:title())
                end
            end
        end
        
        -- Create a formatted output
        local output = "Minecraft Detection Results:\n\n"
        if #javaWindows == 0 then
            output = output .. "No Java windows found.\n"
        else
            for _, details in ipairs(javaWindows) do
                output = output .. string.format(
                    "%d: %s\n   App: %s\n   Role: %s\n   Subrole: %s\n   ID: %d\n   Is Minecraft: %s\n\n",
                    details.index, details.title, details.app, details.role, details.subrole, details.id,
                    details.isMinecraft and "YES" or "no"
                )
            end
        end
        
        -- Show the results in a large alert
        hs.alert.show(output, {textSize=12}, 10)
        
        return foundMinecraft
    end
    
    -- Add a hotkey to test Minecraft detection
    hs.hotkey.bind({"cmd", "alt", "shift"}, "T", testMinecraftDetection)
    
    -- Add a hotkey to clear command queue and show status
    hs.hotkey.bind({"cmd", "alt", "shift"}, "Q", function()
        local queueCount = #commandQueue
        commandQueue = {}
        isExecutingCommand = false
        lastCommandTime = 0
        
        local status = string.format("Minecraft Command Status:\nQueue cleared: %d commands\nExecution: %s\nReady for new commands", 
            queueCount, 
            isExecutingCommand and "BUSY" or "READY"
        )
        hs.alert.show(status, {textSize=12}, 3)
        log.i("Command queue cleared, status reset")
    end)
    
    -- Lightweight approach: No expensive window filter, use event-driven detection
    local minecraftHotkeys = {}
    local minecraftActive = false
    
    -- Function to bind Minecraft-specific shortcuts
    local function bindMinecraftShortcuts()
        if minecraftActive then return end -- Prevent double-binding
        
        minecraftActive = true
        log.i("Minecraft shortcuts activated")
        
        -- Log all the shortcuts we're about to bind
        log.d("Binding Minecraft shortcuts:")
        log.d("- ctrl+alt+c: /creative")
        log.d("- ctrl+alt+x: /survival")
        log.d("- ctrl+alt+s: /spectator")
        log.d("- ctrl+alt+l: /pa leave")
        log.d("- ctrl+alt+shift+[1-9]: /pa Arena[1-9]")
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
        
        -- Use Ctrl+Option+key to avoid conflicts with window management and Minecraft crouching
        minecraftHotkeys.creative = hs.hotkey.bind({"ctrl", "alt"}, "c", function() sendChatCommand("/creative", true, config.minecraft) end)
        minecraftHotkeys.survival = hs.hotkey.bind({"ctrl", "alt"}, "x", function() sendChatCommand("/survival", true, config.minecraft) end)
        minecraftHotkeys.spectator = hs.hotkey.bind({"ctrl", "alt"}, "s", function() sendChatCommand("/spectator", true, config.minecraft) end)
        minecraftHotkeys.leave = hs.hotkey.bind({"ctrl", "alt"}, "l", function() sendChatCommand("/pa leave", true, config.minecraft) end)
        
        -- Control + Option + Shift + number for arenas (1-9) to avoid conflict with game mode shortcuts
        for i = 1, 9 do
            minecraftHotkeys["arena"..i] = hs.hotkey.bind({"ctrl", "alt", "shift"}, tostring(i), function()
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
        if not minecraftActive then return end -- Prevent double-unbinding
        
        minecraftActive = false
        for _, hotkey in pairs(minecraftHotkeys) do
            hotkey:disable()
        end
        
        
        -- Reset command execution flag when unbinding shortcuts
        isExecutingCommand = false
        log.i("Minecraft shortcuts deactivated")
    end
    
    -- Lightweight window focus detection using application events
    local function checkForMinecraftFocus()
        local focusedWindow = hs.window.focusedWindow()
        if not focusedWindow then return end
        
        local app = focusedWindow:application()
        if not app or app:name() ~= "java" then
            if minecraftActive then
                log.d("Lost Minecraft focus")
                unbindMinecraftShortcuts()
            end
            return
        end
        
        -- Quick title check for Minecraft
        local title = focusedWindow:title() or ""
        if string.match(string.lower(title), "minecraft") then
            if not minecraftActive then
                log.i("Minecraft window focused:", title)
                bindMinecraftShortcuts()
            end
        elseif minecraftActive then
            log.d("Java window focused but not Minecraft:", title)
            unbindMinecraftShortcuts()
        end
    end
    
    -- Use lightweight application focus events instead of expensive window filter
    hs.application.watcher.new(function(appName, eventType, app)
        if eventType == hs.application.watcher.activated then
            -- Only check when Java app is activated
            if appName == "java" then
                hs.timer.doAfter(0.05, checkForMinecraftFocus) -- Small delay to ensure window is ready
            elseif minecraftActive then
                -- Another app activated, check if we lost Minecraft focus
                hs.timer.doAfter(0.05, checkForMinecraftFocus)
            end
        end
    end):start()
    
    -- Initial check after a longer delay to avoid blocking startup
    hs.timer.doAfter(0.5, checkForMinecraftFocus)
    
    -- Optimized manual hotkey - only checks Java windows
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
    
    log.i("Minecraft shortcuts ready")
end

-- Return the initialization function
return initMinecraftShortcuts 