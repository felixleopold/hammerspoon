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

    -- Window cycling functions
    local function cycleWindowsOfApp(reverse)
        log.i("Starting window cycling...")
        
        -- Get current window and validate
        local currentWindow = hs.window.focusedWindow()
        if not currentWindow then
            log.e("No focused window found")
            return
        end
        log.i("Current window: " .. (currentWindow:title() or "Untitled") .. " (ID: " .. currentWindow:id() .. ")")

        -- Get application and validate
        local app = currentWindow:application()
        if not app then
            log.e("No application found for current window")
            return
        end
        log.i("Application: " .. (app:name() or "Unknown"))

        -- Get all windows
        local allWindows = app:allWindows()
        log.i("Total windows found: " .. #allWindows)
        
        -- Log all windows for debugging
        for i, w in ipairs(allWindows) do
            log.i(string.format("Window %d: '%s' (ID: %d, Minimized: %s)", 
                i, w:title() or "Untitled", w:id(), tostring(w:isMinimized())))
        end

        -- Filter windows
        local activeWindows = {}
        for _, w in ipairs(allWindows) do
            -- Only include windows that are visible, not minimized, have a valid ID and a title
            if w and not w:isMinimized() and w:id() ~= 0 and w:isVisible() and w:title() ~= "" then
                table.insert(activeWindows, w)
                log.i(string.format("Including window: '%s' (ID: %d)", 
                    w:title() or "Untitled", w:id()))
            else
                log.i(string.format("Excluding window: '%s' (ID: %d) - Minimized: %s, ID zero: %s, Visible: %s, Empty title: %s", 
                    w:title() or "Untitled", w:id(), 
                    tostring(w:isMinimized()), 
                    tostring(w:id() == 0),
                    tostring(w:isVisible()),
                    tostring(w:title() == "")))
            end
        end

        -- Sort windows by ID to maintain consistent order
        table.sort(activeWindows, function(a, b) return a:id() < b:id() end)
        log.i("Active windows after filtering: " .. #activeWindows)

        if #activeWindows <= 1 then
            log.w("Not enough windows to cycle (count: " .. #activeWindows .. ")")
            return
        end

        -- Find current window index
        local currentIndex
        for i, w in ipairs(activeWindows) do
            if w:id() == currentWindow:id() then
                currentIndex = i
                log.i("Found current window at index " .. i)
                break
            end
        end

        if not currentIndex then
            log.w("Current window not found in active windows list, focusing first window")
            activeWindows[1]:focus()
            return
        end

        -- Calculate next window index with proper wrapping
        local nextIndex
        if reverse then
            nextIndex = currentIndex - 1
            if nextIndex < 1 then nextIndex = #activeWindows end
            log.i("Cycling backward from " .. currentIndex .. " to " .. nextIndex)
        else
            nextIndex = currentIndex + 1
            if nextIndex > #activeWindows then nextIndex = 1 end
            log.i("Cycling forward from " .. currentIndex .. " to " .. nextIndex)
        end

        -- Focus next window
        local nextWindow = activeWindows[nextIndex]
        log.i(string.format("Focusing window: '%s' (ID: %d)", 
            nextWindow:title() or "Untitled", nextWindow:id()))
        nextWindow:focus()
    end

    -- Bind window cycling shortcuts
    if shortcuts.nextWindow then
        log.i("Setting up next window shortcut")
        log.i("Mods: " .. hs.inspect(shortcuts.nextWindow.mods))
        log.i("Key: " .. shortcuts.nextWindow.key)
        hs.hotkey.bind(shortcuts.nextWindow.mods, shortcuts.nextWindow.key, function()
            log.i("Triggered: Cycle to next window")
            cycleWindowsOfApp(false)
        end)
    else
        log.w("No next window shortcut configured")
    end

    if shortcuts.prevWindow then
        log.i("Setting up previous window shortcut")
        log.i("Mods: " .. hs.inspect(shortcuts.prevWindow.mods))
        log.i("Key: " .. shortcuts.prevWindow.key)
        hs.hotkey.bind(shortcuts.prevWindow.mods, shortcuts.prevWindow.key, function()
            log.i("Triggered: Cycle to previous window")
            cycleWindowsOfApp(true)
        end)
    else
        log.w("No previous window shortcut configured")
    end

    -- Window movement functions
    local function moveWindow(direction)
        local win = hs.window.focusedWindow()
        if not win then return end

        local screen = win:screen()
        local frame = win:frame()
        local screenFrame = screen:frame()
        
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
