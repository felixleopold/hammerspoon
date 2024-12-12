local M = {}
local log = hs.logger.new('WindowManagement', 'debug')

-- Initialize module with configuration
function M.setup(config)
    if not config.shortcuts or not config.shortcuts.windowManagement then
        log.w("No window management shortcuts configured")
        return
    end

    local shortcuts = config.shortcuts.windowManagement

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
            if w and not w:isMinimized() and w:id() ~= 0 and w:isVisible() then
                table.insert(activeWindows, w)
                log.i(string.format("Including window: '%s' (ID: %d)", 
                    w:title() or "Untitled", w:id()))
            else
                log.i(string.format("Excluding window: '%s' (ID: %d) - Minimized: %s, ID zero: %s, Visible: %s", 
                    w:title() or "Untitled", w:id(), 
                    tostring(w:isMinimized()), 
                    tostring(w:id() == 0),
                    tostring(w:isVisible())))
            end
        end

        -- Sort windows by ID
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

        -- Calculate next window index
        local nextIndex
        if reverse then
            nextIndex = currentIndex > 1 and currentIndex - 1 or #activeWindows
            log.i("Cycling backward from " .. currentIndex .. " to " .. nextIndex)
        else
            nextIndex = currentIndex < #activeWindows and currentIndex + 1 or 1
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
        log.i("Binding next window shortcut: " .. hs.inspect(shortcuts.nextWindow))
        hs.hotkey.bind(config.triggers.window, shortcuts.nextWindow.key, function()
            log.i("Triggered: Cycle to next window")
            cycleWindowsOfApp(false)
        end)
    end

    if shortcuts.prevWindow then
        log.i("Binding previous window shortcut: " .. hs.inspect(shortcuts.prevWindow))
        hs.hotkey.bind(config.triggers.window, shortcuts.prevWindow.key, function()
            log.i("Triggered: Cycle to previous window")
            cycleWindowsOfApp(true)
        end)
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
        elseif direction == "maximize" then
            frame = screenFrame
        end
        
        win:setFrame(frame)
    end

    -- Bind window movement shortcuts
    if shortcuts.moveLeft then
        hs.hotkey.bind(shortcuts.moveLeft.mods, shortcuts.moveLeft.key, function()
            moveWindow("left")
        end)
    end

    if shortcuts.moveRight then
        hs.hotkey.bind(shortcuts.moveRight.mods, shortcuts.moveRight.key, function()
            moveWindow("right")
        end)
    end

    if shortcuts.moveUp then
        hs.hotkey.bind(shortcuts.moveUp.mods, shortcuts.moveUp.key, function()
            moveWindow("up")
        end)
    end

    if shortcuts.moveDown then
        hs.hotkey.bind(shortcuts.moveDown.mods, shortcuts.moveDown.key, function()
            moveWindow("down")
        end)
    end

    if shortcuts.maximize then
        hs.hotkey.bind(shortcuts.maximize.mods, shortcuts.maximize.key, function()
            moveWindow("maximize")
        end)
    end
end

return M
