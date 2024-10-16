local M = {}
local log = hs.logger.new('WindowManagement', 'debug')

local function moveWindowToPosition(win, x, y, w, h)
    if win then
        local screen = win:screen()
        local max = screen:frame()
        win:setFrame({
            x = max.x + (max.w * x),
            y = max.y + (max.h * y),
            w = max.w * w,
            h = max.h * h
        })
    end
end

-- Function to ensure the layouts file exists
local function ensureLayoutFileExists()
    local layoutsFile = os.getenv("HOME") .. "/.hammerspoon/savedLayouts.json"
    if not hs.fs.attributes(layoutsFile) then
        hs.fs.mkdir(os.getenv("HOME") .. "/.hammerspoon")
        local file = io.open(layoutsFile, "w")
        if file then
            file:write("{}")
            file:close()
        end
    end
end

-- Function to save the current window layout
local function saveLayout(name, numWindows)
    log.d("Saving layout: " .. name .. " with " .. numWindows .. " windows")
    local layout = {}
    local appBundleIDs = {}
    local windowInfo = {}
    
    local allWindows = hs.window.orderedWindows()
    local selectedWindows = {}
    
    -- Select the last numWindows windows, prioritizing visible windows
    for i = 1, #allWindows do
        local win = allWindows[i]
        if win:isVisible() and not win:isMinimized() then
            table.insert(selectedWindows, 1, win)
            if #selectedWindows == numWindows then
                break
            end
        end
    end
    
    -- If we don't have enough visible windows, add minimized windows
    if #selectedWindows < numWindows then
        for i = 1, #allWindows do
            local win = allWindows[i]
            if win:isMinimized() and not hs.fnutils.contains(selectedWindows, win) then
                table.insert(selectedWindows, 1, win)
                if #selectedWindows == numWindows then
                    break
                end
            end
        end
    end
    
    for i, win in ipairs(selectedWindows) do
        local app = win:application()
        local screen = win:screen()
        local winFrame = win:frame()
        local screenFrame = screen:frame()
        
        if app and screen and winFrame and screenFrame then
            table.insert(layout, {
                x = (winFrame.x - screenFrame.x) / screenFrame.w,
                y = (winFrame.y - screenFrame.y) / screenFrame.h,
                w = winFrame.w / screenFrame.w,
                h = winFrame.h / screenFrame.h,
                screen = screen:getUUID()
            })
            table.insert(appBundleIDs, app:bundleID())
            
            local info = {
                bundleID = app:bundleID(),
                title = win:title()
            }
            if app:bundleID() == "com.apple.finder" then
                local ok, path = hs.osascript.applescript(string.format([[
                    tell application "Finder"
                        set win to window "%s"
                        if win exists then
                            return POSIX path of (target of win as alias)
                        end if
                    end tell
                ]], win:title()))
                if ok then
                    info.path = path
                end
            end
            table.insert(windowInfo, info)
        end
    end

    local layoutData = {
        layout = layout,
        appBundleIDs = appBundleIDs,
        windowInfo = windowInfo
    }

    local layoutsFile = os.getenv("HOME") .. "/.hammerspoon/savedLayouts.json"
    local file = io.open(layoutsFile, "r")
    local savedLayouts = {}
    if file then
        local content = file:read("*all")
        file:close()
        savedLayouts = hs.json.decode(content) or {}
    end

    savedLayouts[name] = layoutData

    file = io.open(layoutsFile, "w")
    if file then
        file:write(hs.json.encode(savedLayouts))
        file:close()
        log.i("Layout saved successfully: " .. name)
        hs.alert.show("Layout saved: " .. name)
    else
        log.e("Error saving layout: Unable to open file for writing")
        hs.alert.show("Error saving layout")
    end
end

local function loadLayout(name)
    log.d("Loading layout: " .. name)
    local layoutsFile = os.getenv("HOME") .. "/.hammerspoon/savedLayouts.json"
    local file = io.open(layoutsFile, "r")
    if not file then
        log.e("Error: Unable to read saved layouts")
        hs.alert.show("Error: Unable to read saved layouts")
        return
    end

    local content = file:read("*all")
    file:close()
    local savedLayouts = hs.json.decode(content) or {}

    local layoutData = savedLayouts[name]
    if not layoutData then
        log.e("Error: Layout not found")
        hs.alert.show("Error: Layout not found")
        return
    end

    log.d("Layout data: " .. hs.inspect(layoutData))

    -- Close Finder windows only if Finder is part of the layout
    local closeFinder = false
    for _, bundleID in ipairs(layoutData.appBundleIDs) do
        if bundleID == "com.apple.finder" then
            closeFinder = true
            break
        end
    end

    if closeFinder then
        hs.osascript.applescript([[
            tell application "Finder"
                close every window
            end tell
        ]])
    end

    for i, winData in ipairs(layoutData.layout) do
        local bundleID = layoutData.appBundleIDs[i]
        local app = hs.application.get(bundleID)
        
        if not app then
            log.d("Opening application: " .. bundleID)
            app = hs.application.open(bundleID, 5, true)
        end

        if app then
            local screen = hs.screen.find(winData.screen)
            if not screen then
                log.d("Screen not found, using primary screen")
                screen = hs.screen.primaryScreen()
            end
            local screenFrame = screen:frame()

            app:activate()
            hs.timer.usleep(500000) -- Wait for 0.5 seconds

            local win
            if bundleID == "com.apple.finder" then
                local path = layoutData.windowInfo[i].path or "~"
                local script = string.format([[
                    tell application "Finder"
                        set targetFolder to POSIX file "%s" as alias
                        make new Finder window to targetFolder
                    end tell
                ]], path)
                hs.osascript.applescript(script)
                win = app:focusedWindow()
            else
                -- Retry mechanism to ensure the window is properly opened and focused
                for attempt = 1, 3 do
                    win = app:focusedWindow() or app:mainWindow()
                    if not win then
                        app:selectMenuItem({"File", "New Window"})
                        hs.timer.usleep(500000) -- Wait for 0.5 seconds
                    else
                        break
                    end
                end
            end

            if win then
                if win:isMinimized() then
                    win:unminimize()
                    hs.timer.usleep(500000) -- Wait for 0.5 seconds
                end
                local newFrame = hs.geometry.rect(
                    screenFrame.x + screenFrame.w * winData.x,
                    screenFrame.y + screenFrame.h * winData.y,
                    screenFrame.w * winData.w,
                    screenFrame.h * winData.h
                )
                win:setFrame(newFrame)
                log.d("Positioned window for " .. app:name())
            else
                log.e("Failed to get window for " .. app:name())
            end
        else
            log.e("Failed to open application: " .. bundleID)
        end
        
        hs.timer.usleep(500000) -- Wait for 0.5 seconds between each window
    end

    log.i("Layout loaded: " .. name)
    hs.alert.show("Layout loaded: " .. name)
end

function M.setup()
    log.i("Setting up window management")
    ensureLayoutFileExists()

    local opt = {"alt"}
    local optCmd = {"alt", "cmd"}

    -- Move window to left half
    hs.hotkey.bind(opt, "A", function()
        moveWindowToPosition(hs.window.focusedWindow(), 0, 0, 0.5, 1)
    end)

    -- Move window to right half
    hs.hotkey.bind(opt, "D", function()
        moveWindowToPosition(hs.window.focusedWindow(), 0.5, 0, 0.5, 1)
    end)

    -- Move window to top half
    hs.hotkey.bind(opt, "W", function()
        moveWindowToPosition(hs.window.focusedWindow(), 0, 0, 1, 0.5)
    end)

    -- Move window to bottom half
    hs.hotkey.bind(opt, "S", function()
        moveWindowToPosition(hs.window.focusedWindow(), 0, 0.5, 1, 0.5)
    end)

    -- Move window to full screen
    hs.hotkey.bind(opt, "F", function()
        moveWindowToPosition(hs.window.focusedWindow(), 0, 0, 1, 1)
    end)

    -- Center window
    hs.hotkey.bind(opt, "C", function()
        hs.window.focusedWindow():centerOnScreen()
    end)

    -- Move window to left screen
    hs.hotkey.bind({"ctrl", "alt"}, "A", function()
        local win = hs.window.focusedWindow()
        if win then
            win:moveOneScreenWest()
        end
    end)

    -- Move window to right screen
    hs.hotkey.bind({"ctrl", "alt"}, "D", function()
        local win = hs.window.focusedWindow()
        if win then
            win:moveOneScreenEast()
        end
    end)

    -- Cycle through windows of the current application
    local function cycleWindowsOfApp(reverse)
        local currentWindow = hs.window.focusedWindow()
        if not currentWindow then
            log.d("No focused window")
            return
        end
    
        local app = currentWindow:application()
        local windows = app:allWindows()
        log.d("Total windows for app: " .. #windows)
    
        -- Filter out minimized windows and the window with ID 0, then sort by ID
        local activeWindows = hs.fnutils.filter(windows, function(w)
            return not w:isMinimized() and w:id() ~= 0
        end)
        table.sort(activeWindows, function(a, b) return a:id() < b:id() end)
        log.d("Active windows: " .. #activeWindows)
    
        if #activeWindows <= 1 then
            log.d("Not enough windows to cycle")
            return
        end
    
        -- Find the index of the current window
        local currentIndex
        for i, w in ipairs(activeWindows) do
            if w:id() == currentWindow:id() then
                currentIndex = i
                break
            end
        end
        log.d("Current window index: " .. tostring(currentIndex))
    
        if not currentIndex then
            log.d("Current window not found in active windows, focusing first window")
            activeWindows[1]:focus()
            return
        end
    
        local nextIndex
        if reverse then
            nextIndex = currentIndex > 1 and currentIndex - 1 or #activeWindows
        else
            nextIndex = currentIndex < #activeWindows and currentIndex + 1 or 1
        end
        log.d("Next window index: " .. nextIndex)
    
        activeWindows[nextIndex]:focus()
        log.d("Focused window: " .. activeWindows[nextIndex]:title())
    end
    -- Cycle forward through app windows
    hs.hotkey.bind(opt, "E", function()
        log.d("Cycling forward")
        cycleWindowsOfApp(false)
    end)

    -- Cycle backward through app windows
    hs.hotkey.bind(opt, "Q", function()
        log.d("Cycling backward")
        cycleWindowsOfApp(true)
    end)

    -- Add hotkey for saving layouts
    hs.hotkey.bind(optCmd, "S", function()
        local numWindowsChooser = hs.chooser.new(function(choice)
            if choice then
                local numWindows = tonumber(choice.text)
                local button, layoutName = hs.dialog.textPrompt("Name Layout", "Enter a name for this layout:", "", "Save", "Cancel")
                if button == "Save" and layoutName and layoutName ~= "" then
                    saveLayout(layoutName, numWindows)
                else
                    hs.alert.show("Layout save cancelled or empty name provided")
                end
            else
                hs.alert.show("No number of windows selected")
            end
        end)

        numWindowsChooser:choices({
            {text = "1"}, {text = "2"}, {text = "3"}, {text = "4"}, {text = "5"}
        })

        numWindowsChooser:show()
    end)

    -- Add hotkey for loading layouts
    hs.hotkey.bind({"alt", "cmd"}, "L", function()
        local layoutsFile = os.getenv("HOME") .. "/.hammerspoon/savedLayouts.json"
        local file = io.open(layoutsFile, "r")
        if not file then
            hs.alert.show("Error: No saved layouts found")
            return
        end

        local content = file:read("*all")
        file:close()
        local savedLayouts = hs.json.decode(content) or {}

        local layoutNames = {}
        for name, _ in pairs(savedLayouts) do
            table.insert(layoutNames, {text = name})
        end

        if #layoutNames == 0 then
            hs.alert.show("No saved layouts found")
            return
        end

        local chooser = hs.chooser.new(function(choice)
            if choice then
                loadLayout(choice.text)
            end
        end)

        chooser:choices(layoutNames)
        chooser:show()
    end)

    log.i("Window management setup complete")
end

return M