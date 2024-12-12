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
        
        log.i("Cycling windows for app: " .. app:name() .. " in direction: " .. direction)
        
        -- Special handling for Finder
        if app:name() == "Finder" then
            local windows = {}
            local allWindows = app:allWindows()
            log.i("Found " .. #allWindows .. " total Finder windows")
            
            -- Include all Finder windows except Desktop
            for _, win in ipairs(allWindows) do
                local title = win:title()
                local role = win:role()
                local subrole = win:subrole()
                local isVisible = win:isVisible()
                
                log.i("Window details:")
                log.i("  - Title: " .. (title or "nil"))
                log.i("  - Role: " .. (role or "nil"))
                log.i("  - Subrole: " .. (subrole or "nil"))
                log.i("  - Visible: " .. tostring(isVisible))
                
                if title and title ~= "" and title ~= "Desktop" and isVisible then
                    log.i("Including window: " .. title)
                    table.insert(windows, win)
                else
                    log.i("Skipping window: " .. (title or "nil") .. " (empty title or Desktop)")
                end
            end
            
            if #windows <= 1 then 
                log.i("Not enough Finder windows to cycle (" .. #windows .. " windows)")
                return 
            end
            
            -- Sort windows by ID to maintain consistent order
            table.sort(windows, function(a, b) return a:id() < b:id() end)
            
            local focusedWindow = hs.window.focusedWindow()
            if focusedWindow then
                log.i("Current focused window: " .. (focusedWindow:title() or "nil"))
            else
                log.w("No focused window found")
            end
            
            local currentIndex
            
            -- Find current window index
            for i, win in ipairs(windows) do
                if win:id() == focusedWindow:id() then
                    currentIndex = i
                    log.d("Current window index: " .. i .. " of " .. #windows)
                    break
                end
            end
            
            if not currentIndex then
                log.i("Current window not found in list, focusing first window")
                windows[1]:focus()
                return
            end
            
            -- Calculate next window index
            local nextIndex
            if direction == "next" then
                nextIndex = currentIndex % #windows + 1
            else
                nextIndex = (currentIndex - 2) % #windows + 1
            end
            
            log.i("Moving from window " .. currentIndex .. " to " .. nextIndex)
            -- Focus next window
            windows[nextIndex]:focus()
            return
        end
        
        -- Normal handling for other applications
        local windows = app:visibleWindows()
        if #windows <= 1 then return end
        
        -- Sort windows by ID to maintain consistent order
        table.sort(windows, function(a, b) return a:id() < b:id() end)
        
        local focusedWindow = hs.window.focusedWindow()
        local currentIndex
        
        -- Find current window index
        for i, win in ipairs(windows) do
            if win:id() == focusedWindow:id() then
                currentIndex = i
                break
            end
        end
        
        if not currentIndex then return end
        
        -- Calculate next window index
        local nextIndex
        if direction == "next" then
            nextIndex = currentIndex % #windows + 1
        else
            nextIndex = (currentIndex - 2) % #windows + 1
        end
        
        -- Focus next window
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
