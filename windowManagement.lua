local M = {}
local log = hs.logger.new('WindowManagement', 'debug')

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

    local shortcuts = config.shortcuts.windowManagement
    log.i("Loaded window management shortcuts: " .. hs.inspect(shortcuts))
    log.i("Available triggers: " .. hs.inspect(config.triggers))

    -- Helper function to check if window is on the left/right side of screen
    local function isWindowOnSide(win, side)
        if not win then return false end
        
        local screen = win:screen()
        local frame = win:frame()
        local screenFrame = screen:frame()
        
        -- More lenient detection - check if window is roughly on the side
        if side == "left" then
            return math.abs(frame.x - screenFrame.x) < 20
        elseif side == "right" then
            return math.abs((frame.x + frame.w) - (screenFrame.x + screenFrame.w)) < 20
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
                -- Move to the same side on the new screen
                local newScreenFrame = nextScreen:frame()
                if direction == "left" then
                    frame.x = newScreenFrame.x
                    frame.y = newScreenFrame.y
                    frame.w = newScreenFrame.w / 2
                    frame.h = newScreenFrame.h
                else
                    frame.x = newScreenFrame.x + (newScreenFrame.w / 2)
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
        end
        
        win:setFrame(frame)
    end

    -- Bind window movement shortcuts
    if shortcuts.left then
        log.i("Setting up left window shortcut")
        log.i("Mods: " .. hs.inspect(shortcuts.left.mods))
        log.i("Key: " .. shortcuts.left.key)
        hs.hotkey.bind(shortcuts.left.mods, shortcuts.left.key, function()
            log.i("Triggered: Move window left")
            moveWindow("left")
        end)
    else
        log.w("No left window shortcut configured")
    end

    if shortcuts.right then
        log.i("Setting up right window shortcut")
        log.i("Mods: " .. hs.inspect(shortcuts.right.mods))
        log.i("Key: " .. shortcuts.right.key)
        hs.hotkey.bind(shortcuts.right.mods, shortcuts.right.key, function()
            log.i("Triggered: Move window right")
            moveWindow("right")
        end)
    else
        log.w("No right window shortcut configured")
    end

    if shortcuts.top then
        log.i("Setting up top window shortcut")
        log.i("Mods: " .. hs.inspect(shortcuts.top.mods))
        log.i("Key: " .. shortcuts.top.key)
        hs.hotkey.bind(shortcuts.top.mods, shortcuts.top.key, function()
            log.i("Triggered: Move window up")
            moveWindow("up")
        end)
    else
        log.w("No top window shortcut configured")
    end

    if shortcuts.bottom then
        log.i("Setting up bottom window shortcut")
        log.i("Mods: " .. hs.inspect(shortcuts.bottom.mods))
        log.i("Key: " .. shortcuts.bottom.key)
        hs.hotkey.bind(shortcuts.bottom.mods, shortcuts.bottom.key, function()
            log.i("Triggered: Move window down")
            moveWindow("down")
        end)
    else
        log.w("No bottom window shortcut configured")
    end

    if shortcuts.center then
        log.i("Setting up center window shortcut")
        log.i("Mods: " .. hs.inspect(shortcuts.center.mods))
        log.i("Key: " .. shortcuts.center.key)
        hs.hotkey.bind(shortcuts.center.mods, shortcuts.center.key, function()
            log.i("Triggered: Center window")
            moveWindow("center")
        end)
    else
        log.w("No center window shortcut configured")
    end

    if shortcuts.full then
        log.i("Setting up maximize window shortcut")
        log.i("Mods: " .. hs.inspect(shortcuts.full.mods))
        log.i("Key: " .. shortcuts.full.key)
        hs.hotkey.bind(shortcuts.full.mods, shortcuts.full.key, function()
            log.i("Triggered: Maximize window")
            moveWindow("maximize")
        end)
    else
        log.w("No maximize window shortcut configured")
    end

    log.i("Window management setup complete")
end

return M
