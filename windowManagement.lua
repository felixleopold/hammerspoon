local M = {}
local log = hs.logger.new('WindowManagement', 'debug')
local leftRightModifier = require("leftRightModifier")

-- Initialize module with configuration
function M.setup(config)
    log.i("Starting window management setup")
    
    if not config then
        log.e("No config provided")
        return
    end
    
    if not config.shortcuts then
        log.e("No shortcuts in config")
        return
    end
    
    if not config.shortcuts.windowManagement then
        log.e("No window management shortcuts in config")
        return
    end

    -- Configure logging based on user settings
    if config.debug and config.debug.windowManagement ~= nil then
        if config.debug.windowManagement then
            log.setLogLevel('debug')
            log.i("Window management debug logging enabled")
        else
            log.setLogLevel('info')
        end
    end
    
    -- Configure logging for left/right modifier module
    leftRightModifier.configureLogging(config)

    local shortcuts = config.shortcuts.windowManagement
    log.i("Loaded window management shortcuts: " .. hs.inspect(shortcuts))
    log.d("Available triggers: " .. hs.inspect(config.triggers))

    -- Dump detailed info about window triggers
    if config.triggers.window then
        log.d("Window trigger modifiers: " .. hs.inspect(config.triggers.window))
    end
    if config.triggers.lwindow then
        log.d("Left window trigger modifiers: " .. hs.inspect(config.triggers.lwindow))
    end
    if config.triggers.rwindow then
        log.d("Right window trigger modifiers: " .. hs.inspect(config.triggers.rwindow))
    end

    -- Helper function to check if window is on the left/right side of screen
    local function isWindowOnSide(win, side)
        if not win then return false end
        
        local screen = win:screen()
        local frame = win:frame()
        local screenFrame = screen:frame()
        
        -- More precise detection - check if window is exactly on the side
        if side == "left" then
            -- Check if left edge of window is at left edge of screen AND
            -- window width is exactly half of screen width (with small tolerance)
            return math.abs(frame.x - screenFrame.x) < 5 and 
                   math.abs(frame.w - (screenFrame.w / 2)) < 10
        elseif side == "right" then
            -- Check if right edge of window is at right edge of screen AND
            -- window width is exactly half of screen width (with small tolerance)
            return math.abs((frame.x + frame.w) - (screenFrame.x + screenFrame.w)) < 5 and
                   math.abs(frame.w - (screenFrame.w / 2)) < 10
        end
        return false
    end

    -- Helper function to find next screen in direction
    local function findNextScreen(currentScreen, direction)
        local screens = hs.screen.allScreens()
        if #screens <= 1 then return nil end
        
        local currentFrame = currentScreen:frame()
        local nextScreen = nil
        local minDistance = math.huge
        
        for _, screen in ipairs(screens) do
            if screen:id() ~= currentScreen:id() then
                local screenFrame = screen:frame()
                local distance
                
                if direction == "right" then
                    -- For right direction, look for screens to the right of current screen
                    distance = screenFrame.x - (currentFrame.x + currentFrame.w)
                    if distance >= -20 and distance < minDistance then  -- Allow small overlap
                        minDistance = distance
                        nextScreen = screen
                    end
                elseif direction == "left" then
                    -- For left direction, look for screens to the left of current screen
                    distance = (currentFrame.x) - (screenFrame.x + screenFrame.w)
                    if distance >= -20 and distance < minDistance then  -- Allow small overlap
                        minDistance = distance
                        nextScreen = screen
                    end
                end
            end
        end
        
        if nextScreen then
            log.d(string.format("Found next screen in %s direction: %s (distance: %d)", 
                direction, nextScreen:name(), minDistance))
        else
            log.d("No next screen found in " .. direction .. " direction")
        end
        
        return nextScreen
    end

    -- Window movement functions
    local function moveWindow(direction)
        local win = hs.window.focusedWindow()
        if not win then 
            log.w("No focused window")
            return 
        end

        local screen = win:screen()
        local frame = win:frame()
        local screenFrame = screen:frame()
        
        -- Check if window is already on the side and there's another screen in that direction
        if (direction == "left" and isWindowOnSide(win, "left")) or
           (direction == "right" and isWindowOnSide(win, "right")) then
            local nextScreen = findNextScreen(screen, direction)
            if nextScreen then
                log.i("Moving window to next screen in " .. direction .. " direction")
                win:moveToScreen(nextScreen)
                -- Move to the appropriate side on the new screen
                local newScreenFrame = nextScreen:frame()
                if direction == "left" then
                    -- Moving left, place on right side of new screen
                    frame.x = newScreenFrame.x + (newScreenFrame.w / 2)
                    frame.y = newScreenFrame.y
                    frame.w = newScreenFrame.w / 2
                    frame.h = newScreenFrame.h
                else
                    -- Moving right, place on left side of new screen
                    frame.x = newScreenFrame.x
                    frame.y = newScreenFrame.y
                    frame.w = newScreenFrame.w / 2
                    frame.h = newScreenFrame.h
                end
                win:setFrame(frame)
                return
            else
                log.i("No screen found in " .. direction .. " direction")
                -- Continue with normal window movement
            end
        end
        
        -- Normal window movement if not on edge or no next screen
        if direction == "left" then
            frame.x = screenFrame.x
            frame.y = screenFrame.y
            frame.w = screenFrame.w / 2
            frame.h = screenFrame.h
        elseif direction == "right" then
            frame.x = screenFrame.x + (screenFrame.w / 2)
            frame.y = screenFrame.y
            frame.w = screenFrame.w / 2
            frame.h = screenFrame.h
        elseif direction == "up" then
            frame.x = screenFrame.x
            frame.y = screenFrame.y
            frame.w = screenFrame.w
            frame.h = screenFrame.h / 2
        elseif direction == "down" then
            frame.x = screenFrame.x
            frame.y = screenFrame.y + (screenFrame.h / 2)
            frame.w = screenFrame.w
            frame.h = screenFrame.h / 2
        elseif direction == "center" then
            -- Keep current window size, just center it on screen
            frame.x = screenFrame.x + (screenFrame.w - frame.w) / 2
            frame.y = screenFrame.y + (screenFrame.h - frame.h) / 2
        elseif direction == "maximize" then
            frame = screenFrame
        elseif direction == "third1" then
            -- First third (left)
            frame.x = screenFrame.x
            frame.y = screenFrame.y
            frame.w = screenFrame.w / 3
            frame.h = screenFrame.h
        elseif direction == "third2" then
            -- Middle third
            frame.x = screenFrame.x + (screenFrame.w / 3)
            frame.y = screenFrame.y
            frame.w = screenFrame.w / 3
            frame.h = screenFrame.h
        elseif direction == "third3" then
            -- Last third (right)
            frame.x = screenFrame.x + (2 * screenFrame.w / 3)
            frame.y = screenFrame.y
            frame.w = screenFrame.w / 3
            frame.h = screenFrame.h
        elseif direction == "twoThirdsLeft" then
            -- Two thirds on the left
            frame.x = screenFrame.x
            frame.y = screenFrame.y
            frame.w = 2 * screenFrame.w / 3
            frame.h = screenFrame.h
        elseif direction == "twoThirdsRight" then
            -- Two thirds on the right
            frame.x = screenFrame.x + (screenFrame.w / 3)
            frame.y = screenFrame.y
            frame.w = 2 * screenFrame.w / 3
            frame.h = screenFrame.h
        elseif direction == "topLeft" then
            -- Top left corner
            frame.x = screenFrame.x
            frame.y = screenFrame.y
            frame.w = screenFrame.w / 2
            frame.h = screenFrame.h / 2
        elseif direction == "topRight" then
            -- Top right corner
            frame.x = screenFrame.x + (screenFrame.w / 2)
            frame.y = screenFrame.y
            frame.w = screenFrame.w / 2
            frame.h = screenFrame.h / 2
        elseif direction == "bottomLeft" then
            -- Bottom left corner
            frame.x = screenFrame.x
            frame.y = screenFrame.y + (screenFrame.h / 2)
            frame.w = screenFrame.w / 2
            frame.h = screenFrame.h / 2
        elseif direction == "bottomRight" then
            -- Bottom right corner
            frame.x = screenFrame.x + (screenFrame.w / 2)
            frame.y = screenFrame.y + (screenFrame.h / 2)
            frame.w = screenFrame.w / 2
            frame.h = screenFrame.h / 2
        end
        
        win:setFrame(frame)
    end
    
    -- Helper function to bind shortcuts with optional left/right modifier detection
    local function bindWindowShortcut(shortcutName, shortcutConfig, actionFn)
        if not shortcutConfig then
            log.w("No " .. shortcutName .. " window shortcut configured")
            return
        end
        
        log.i("Setting up " .. shortcutName .. " window shortcut")
        log.i("Mods: " .. hs.inspect(shortcutConfig.mods))
        log.i("Key: " .. shortcutConfig.key)
        
        -- Check if we need to use left/right specific detection
        local usesLeftRightSpecific = false
        for _, mod in ipairs(shortcutConfig.mods) do
            if mod:sub(1,1) == "l" or mod:sub(1,1) == "r" then
                usesLeftRightSpecific = true
                log.i("Found left/right specific modifier: " .. mod)
                break
            end
        end
        
        if usesLeftRightSpecific then
            log.i("Using left/right specific modifier detection for " .. shortcutName)
            local id = leftRightModifier.bind(shortcutConfig.mods, shortcutConfig.key, function()
                log.i("LEFT/RIGHT SPECIFIC: Triggered " .. shortcutName)
                actionFn()
            end)
            if not id then
                log.e("Failed to bind left/right specific shortcut for " .. shortcutName)
            else
                log.i("Successfully bound left/right specific shortcut for " .. shortcutName .. " with ID " .. id)
            end
        else
            -- Use regular Hammerspoon hotkey binding
            log.i("Using regular hotkey binding for " .. shortcutName)
            hs.hotkey.bind(shortcutConfig.mods, shortcutConfig.key, function()
                log.i("REGULAR: Triggered " .. shortcutName)
                actionFn()
            end)
        end
    end

    -- Bind window movement shortcuts
    bindWindowShortcut("left", shortcuts.left, function()
        log.i("Triggered: Move window left")
        moveWindow("left")
    end)
    
    bindWindowShortcut("right", shortcuts.right, function()
        log.i("Triggered: Move window right")
        moveWindow("right")
    end)
    
    bindWindowShortcut("top", shortcuts.top, function()
        log.i("Triggered: Move window up")
        moveWindow("up")
    end)
    
    bindWindowShortcut("bottom", shortcuts.bottom, function()
        log.i("Triggered: Move window down")
        moveWindow("down")
    end)
    
    bindWindowShortcut("center", shortcuts.center, function()
        log.i("Triggered: Center window")
        moveWindow("center")
    end)
    
    bindWindowShortcut("full", shortcuts.full, function()
        log.i("Triggered: Maximize window")
        moveWindow("maximize")
    end)

    -- Add new shortcuts for thirds
    bindWindowShortcut("third1", shortcuts.third1, function()
        log.i("Triggered: Move window to first third")
        moveWindow("third1")
    end)
    
    bindWindowShortcut("third2", shortcuts.third2, function()
        log.i("Triggered: Move window to middle third")
        moveWindow("third2")
    end)
    
    bindWindowShortcut("third3", shortcuts.third3, function()
        log.i("Triggered: Move window to last third")
        moveWindow("third3")
    end)
    
    bindWindowShortcut("twoThirdsLeft", shortcuts.twoThirdsLeft, function()
        log.i("Triggered: Move window to two-thirds left")
        moveWindow("twoThirdsLeft")
    end)
    
    bindWindowShortcut("twoThirdsRight", shortcuts.twoThirdsRight, function()
        log.i("Triggered: Move window to two-thirds right")
        moveWindow("twoThirdsRight")
    end)

    -- Add new shortcuts for corners and halves
    bindWindowShortcut("topLeft", shortcuts.topLeft, function()
        log.i("Triggered: Move window to top left corner")
        moveWindow("topLeft")
    end)
    
    bindWindowShortcut("topRight", shortcuts.topRight, function()
        log.i("Triggered: Move window to top right corner")
        moveWindow("topRight")
    end)
    
    bindWindowShortcut("bottomLeft", shortcuts.bottomLeft, function()
        log.i("Triggered: Move window to bottom left corner")
        moveWindow("bottomLeft")
    end)
    
    bindWindowShortcut("bottomRight", shortcuts.bottomRight, function()
        log.i("Triggered: Move window to bottom right corner")
        moveWindow("bottomRight")
    end)

    -- Add test for left control key
    if shortcuts.testLeft then
        bindWindowShortcut("testLeft", shortcuts.testLeft, function()
            log.i("Left control key shortcut activated successfully")
            hs.alert.show("Left Control + T working! (Window management)", 2)
        end)
    end

    -- Add test for right control key
    if shortcuts.rightTest then
        bindWindowShortcut("rightTest", shortcuts.rightTest, function()
            log.i("Right modifier key shortcut activated successfully")
            hs.alert.show("Right modifier key working", 1)
        end)
    end

    log.i("Window management setup complete")
end

return M
