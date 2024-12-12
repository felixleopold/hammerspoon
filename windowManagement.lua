local M = {}
local log = hs.logger.new('WindowManagement', 'debug')

function M.setup(config)
    log.i("Setting up window management")

    -- Window movement functions
    local function moveWindow(direction)
        local win = hs.window.focusedWindow()
        if not win then return end
        
        local screen = win:screen()
        local frame = screen:frame()
        local winFrame = win:frame()
        
        if direction == "left" then
            winFrame.x = frame.x
            winFrame.y = frame.y
            winFrame.w = frame.w / 2
            winFrame.h = frame.h
        elseif direction == "right" then
            winFrame.x = frame.x + (frame.w / 2)
            winFrame.y = frame.y
            winFrame.w = frame.w / 2
            winFrame.h = frame.h
        elseif direction == "top" then
            winFrame.x = frame.x
            winFrame.y = frame.y
            winFrame.w = frame.w
            winFrame.h = frame.h / 2
        elseif direction == "bottom" then
            winFrame.x = frame.x
            winFrame.y = frame.y + (frame.h / 2)
            winFrame.w = frame.w
            winFrame.h = frame.h / 2
        elseif direction == "center" then
            winFrame.x = frame.x + (frame.w * 0.125)
            winFrame.y = frame.y + (frame.h * 0.125)
            winFrame.w = frame.w * 0.75
            winFrame.h = frame.h * 0.75
        elseif direction == "full" then
            winFrame = frame
        end
        
        win:setFrame(winFrame, config.windowManagement.animationDuration)
    end

    -- Screen movement functions
    local function moveToScreen(direction)
        local win = hs.window.focusedWindow()
        if not win then return end
        
        local screen = win:screen()
        local nextScreen
        
        if direction == "next" then
            nextScreen = screen:next()
        else
            nextScreen = screen:previous()
        end
        
        win:moveToScreen(nextScreen, false, true, config.windowManagement.animationDuration)
    end

    -- Window cycling functions
    local function cycleWindows(direction)
        local app = hs.application.frontmostApplication()
        if not app then 
            log.w("No frontmost application found")
            return 
        end
        
        local appName = app:name()
        log.i("Cycling windows for app: " .. appName .. " in direction: " .. direction)
        
        -- Get windows using both methods for better compatibility
        local windows = {}
        local seenIds = {}
        
        -- Method 1: Get windows from application
        local appWindows = app:allWindows()
        for _, win in ipairs(appWindows) do
            if win and win:isVisible() and not win:isMinimized() then
                local title = win:title() or ""
                local role = win:role() or ""
                local subrole = win:subrole() or ""
                
                log.i(string.format("Found window via app:allWindows(): title='%s', role='%s', subrole='%s'", 
                    title, role, subrole))
                
                -- Only include standard windows with titles
                if title ~= "" and role == "AXWindow" then
                    table.insert(windows, win)
                    seenIds[win:id()] = true
                    log.i(string.format("Including window: '%s'", title))
                else
                    log.i(string.format("Skipping non-standard window: '%s'", title))
                end
            end
        end
        
        -- Method 2: Get windows from window filter
        local wf = hs.window.filter.new(false)
        wf:setAppFilter(appName, {
            allowRoles = {'AXWindow'},
            visible = true,
            currentSpace = true,
            fullscreen = true
        })
        local filterWindows = wf:getWindows()
        
        for _, win in ipairs(filterWindows) do
            if win and not seenIds[win:id()] and win:isVisible() and not win:isMinimized() then
                local title = win:title() or ""
                local role = win:role() or ""
                local subrole = win:subrole() or ""
                
                log.i(string.format("Found window via filter: title='%s', role='%s', subrole='%s'", 
                    title, role, subrole))
                
                if title ~= "" and role == "AXWindow" then
                    table.insert(windows, win)
                    seenIds[win:id()] = true
                    log.i(string.format("Including additional window: '%s'", title))
                end
            end
        end
        
        log.i("Found " .. #windows .. " windows for " .. appName)
        
        if #windows <= 1 then
            log.i("Not enough windows to cycle")
            return
        end
        
        -- Sort windows by ID to maintain consistent order
        table.sort(windows, function(a, b) return a:id() < b:id() end)
        
        local focusedWindow = hs.window.focusedWindow()
        if not focusedWindow then
            log.w("No focused window")
            return
        end
        
        -- Find current window index
        local currentIndex
        for i, win in ipairs(windows) do
            if win:id() == focusedWindow:id() then
                currentIndex = i
                log.i(string.format("Current window %d of %d: '%s'", 
                    i, #windows, win:title() or ""))
                break
            end
        end
        
        if not currentIndex then
            log.i("Current window not in cycle list, focusing first window")
            windows[1]:focus()
            return
        end
        
        -- Calculate next window index with proper wrapping
        local nextIndex
        if direction == "next" then
            nextIndex = currentIndex + 1
            if nextIndex > #windows then
                nextIndex = 1
            end
        else
            nextIndex = currentIndex - 1
            if nextIndex < 1 then
                nextIndex = #windows
            end
        end
        
        log.i(string.format("Moving from window %d ('%s') to %d ('%s')", 
            currentIndex, windows[currentIndex]:title() or "",
            nextIndex, windows[nextIndex]:title() or ""))
            
        windows[nextIndex]:focus()
    end

    -- Bind window management shortcuts
    for name, shortcut in pairs(config.shortcuts.windowManagement) do
        if name == "left" then
            hs.hotkey.bind(shortcut.mods, shortcut.key, function() moveWindow("left") end)
        elseif name == "right" then
            hs.hotkey.bind(shortcut.mods, shortcut.key, function() moveWindow("right") end)
        elseif name == "top" then
            hs.hotkey.bind(shortcut.mods, shortcut.key, function() moveWindow("top") end)
        elseif name == "bottom" then
            hs.hotkey.bind(shortcut.mods, shortcut.key, function() moveWindow("bottom") end)
        elseif name == "center" then
            hs.hotkey.bind(shortcut.mods, shortcut.key, function() moveWindow("center") end)
        elseif name == "full" then
            hs.hotkey.bind(shortcut.mods, shortcut.key, function() moveWindow("full") end)
        elseif name == "nextScreen" then
            hs.hotkey.bind(shortcut.mods, shortcut.key, function() moveToScreen("next") end)
        elseif name == "prevScreen" then
            hs.hotkey.bind(shortcut.mods, shortcut.key, function() moveToScreen("prev") end)
        elseif name == "nextWindow" then
            hs.hotkey.bind(shortcut.mods, shortcut.key, function() cycleWindows("next") end)
        elseif name == "prevWindow" then
            hs.hotkey.bind(shortcut.mods, shortcut.key, function() cycleWindows("prev") end)
        end
    end

    log.i("Window management setup complete")
end

return M
