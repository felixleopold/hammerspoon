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
        -- Log system information
        log.i("System Information:")
        log.i("  OS Version: " .. hs.host.operatingSystemVersion())
        log.i("  Hostname: " .. hs.host.localizedName())
        log.i("  Hammerspoon Version: " .. hs.processInfo.version)
        
        -- Check if we have accessibility permissions
        if not hs.accessibilityState() then
            log.e("Accessibility permissions not granted. Please enable Hammerspoon in System Settings > Privacy & Security > Accessibility")
            hs.alert.show("Accessibility permissions required")
            return
        end

        local app = hs.application.frontmostApplication()
        if not app then 
            log.w("No frontmost application found")
            return 
        end
        
        local appName = app:name()
        log.i("Cycling windows for app: " .. appName .. " in direction: " .. direction)
        
        -- Get windows directly from the application
        local allWindows = app:allWindows()
        if not allWindows then
            log.e("Failed to get application windows")
            return
        end
        log.d("Total windows found for " .. appName .. ": " .. #allWindows)
        
        -- Log all windows for debugging
        for i, win in ipairs(allWindows) do
            if win then
                local title = win:title() or ""
                local role = win:role() or ""
                local subrole = win:subrole() or ""
                local frame = win:frame()
                log.d(string.format("Window %d: title='%s', role='%s', subrole='%s', id=%d, visible=%s, minimized=%s", 
                    i, title, role, subrole, win:id(),
                    tostring(win:isVisible()), tostring(win:isMinimized())))
                log.d(string.format("  Frame: x=%d, y=%d, w=%d, h=%d", 
                    frame.x, frame.y, frame.w, frame.h))
                
                -- Try to get window AXAttributes
                local axapp = hs.axuielement.applicationElement(app)
                if axapp then
                    local axwin = hs.axuielement.windowElement(win)
                    if axwin then
                        local attrs = axwin:allAttributeValues()
                        log.d("  AX Attributes: " .. hs.inspect(attrs))
                    end
                end
            end
        end
        
        local windows = {}
        
        -- Filter windows
        for _, win in ipairs(allWindows) do
            if not win then
                log.w("Found nil window")
                goto continue
            end
            
            local title = win:title() or ""
            local role = win:role() or ""
            local subrole = win:subrole() or ""
            
            -- Extra logging for Finder windows
            if appName == "Finder" then
                log.i(string.format("Analyzing Finder window: title='%s', role='%s', subrole='%s', id=%d", 
                    title, role, subrole, win:id()))
                log.i(string.format("Window properties: visible=%s, minimized=%s, standard=%s", 
                    tostring(win:isVisible()), 
                    tostring(win:isMinimized()),
                    tostring(subrole == "AXStandardWindow")))
                
                -- For Finder, include any window that:
                -- 1. Has a title, OR
                -- 2. Is a standard window
                if title ~= "" or subrole == "AXStandardWindow" then
                    if win:isVisible() and not win:isMinimized() then
                        table.insert(windows, win)
                        log.i(string.format("Including Finder window: '%s'", title))
                    else
                        log.i(string.format("Skipping invisible/minimized Finder window: '%s'", title))
                    end
                else
                    log.i(string.format("Skipping special Finder window: '%s'", title))
                end
            else
                -- For other apps, just check visibility
                if win:isVisible() and not win:isMinimized() then
                    table.insert(windows, win)
                    log.i(string.format("Including window: title='%s', role='%s', subrole='%s', id=%d", 
                        title, role, subrole, win:id()))
                else
                    log.i(string.format("Skipping invisible/minimized window: '%s'", title))
                end
            end
            ::continue::
        end
        
        log.i("Found " .. #windows .. " usable windows for " .. appName)
        
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
                log.i(string.format("Current window %d of %d: '%s' (id=%d)", 
                    i, #windows, win:title() or "", win:id()))
                break
            end
        end
        
        if not currentIndex then
            log.i("Current window not in cycle list, focusing first window")
            if not windows[1]:focus() then
                log.e("Failed to focus first window")
                return
            end
            return
        end
        
        -- Calculate next window index
        local nextIndex
        if direction == "next" then
            nextIndex = currentIndex % #windows + 1
        else
            nextIndex = (currentIndex - 2) % #windows + 1
        end
        
        log.i(string.format("Moving from window %d ('%s', id=%d) to %d ('%s', id=%d)", 
            currentIndex, windows[currentIndex]:title() or "", windows[currentIndex]:id(),
            nextIndex, windows[nextIndex]:title() or "", windows[nextIndex]:id()))
            
        if not windows[nextIndex]:focus() then
            log.e("Failed to focus next window")
            return
        end
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
