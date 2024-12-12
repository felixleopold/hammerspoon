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
        
        win:setFrame(winFrame, config.windowAnimation)
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
        
        win:moveToScreen(nextScreen, false, true, config.windowAnimation)
    end

    -- Window cycling functions
    local function cycleWindows(direction)
        local app = hs.application.frontmostApplication()
        if not app then return end
        
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

    -- Helper function to convert shortcut string to modifiers and key
    local function parseShortcut(shortcutStr)
        local mods = {}
        local parts = {}
        for part in shortcutStr:gmatch("[^+]+") do
            table.insert(parts, part:lower())
        end
        local key = parts[#parts]
        for i = 1, #parts - 1 do
            table.insert(mods, parts[i])
        end
        return mods, key:upper()
    end

    -- Bind window management shortcuts
    for name, shortcut in pairs(config.windows) do
        local mods, key = parseShortcut(shortcut)
        
        if name == "left" then
            hs.hotkey.bind(mods, key, function() moveWindow("left") end)
        elseif name == "right" then
            hs.hotkey.bind(mods, key, function() moveWindow("right") end)
        elseif name == "top" then
            hs.hotkey.bind(mods, key, function() moveWindow("top") end)
        elseif name == "bottom" then
            hs.hotkey.bind(mods, key, function() moveWindow("bottom") end)
        elseif name == "center" then
            hs.hotkey.bind(mods, key, function() moveWindow("center") end)
        elseif name == "full" then
            hs.hotkey.bind(mods, key, function() moveWindow("full") end)
        elseif name == "nextScreen" then
            hs.hotkey.bind(mods, key, function() moveToScreen("next") end)
        elseif name == "prevScreen" then
            hs.hotkey.bind(mods, key, function() moveToScreen("prev") end)
        elseif name == "nextWindow" then
            hs.hotkey.bind(mods, key, function() cycleWindows("next") end)
        elseif name == "prevWindow" then
            hs.hotkey.bind(mods, key, function() cycleWindows("prev") end)
        end
    end

    log.i("Window management setup complete")
end

return M
