local M = {}
local log = hs.logger.new('Applications', 'debug')
local setup = require("setup")

function M.setup(config)
    log.i("Setting up application shortcuts")
    log.d("Loaded configuration: " .. hs.inspect(config))

    -- Helper function to launch or focus applications
    local function launchOrFocus(appName)
        log.i("Attempting to launch or focus: " .. appName)
        hs.application.launchOrFocus(appName)
    end

    -- Helper function to bind hotkey
    local function bindHotkey(shortcut, callback)
        if type(shortcut) ~= "table" or not shortcut.mods or not shortcut.key then
            log.w("Invalid shortcut configuration: " .. hs.inspect(shortcut))
            return
        end
        if #shortcut.mods == 0 then
            log.w("Skipping shortcut with no modifiers: " .. shortcut.key)
            return
        end
        log.d("Binding hotkey: " .. hs.inspect(shortcut.mods) .. " + " .. shortcut.key)
        hs.hotkey.bind(shortcut.mods, shortcut.key, callback)
    end

    -- Helper function to expand path
    local function expandPath(path)
        if not path then return nil end
        
        -- Replace ~ with HOME environment variable
        if path:sub(1,1) == "~" then
            path = os.getenv("HOME") .. path:sub(2)
        end
        
        -- Convert to absolute path
        local absolutePath = hs.fs.pathToAbsolute(path)
        if not absolutePath then
            log.w("Could not resolve path: " .. path)
            return path
        end
        return absolutePath
    end

    -- Set up application shortcuts
    for name, shortcut in pairs(config.shortcuts.appShortcuts) do
        local appName = config.applications[name]
        if appName then
            log.i("Setting up shortcut for " .. name .. ": " .. hs.inspect(shortcut) .. " to launch " .. appName)
            bindHotkey(shortcut, function() 
                log.i("Launching " .. appName .. " via shortcut " .. hs.inspect(shortcut))
                launchOrFocus(appName)
            end)
        else
            log.w("No application defined for shortcut: " .. name .. ". Please check your configuration.")
        end
    end

    -- Set up folder shortcuts
    for name, shortcut in pairs(config.shortcuts.folderShortcuts) do
        local path = config.folders[name]
        if path then
            path = expandPath(path)
            log.d("Setting up folder shortcut for " .. name .. ": " .. hs.inspect(shortcut) .. " to open " .. path)
            bindHotkey(shortcut, function()
                if hs.fs.attributes(path) then
                    -- Get list of visible Finder windows before opening
                    local finder = hs.application.get("Finder")
                    local visibleWindows = {}
                    if finder then
                        for _, win in ipairs(finder:allWindows()) do
                            if win:isVisible() and not win:isMinimized() then
                                local title = win:title() or ""
                                local role = win:role() or ""
                                -- Skip special windows
                                if title ~= "" and role ~= "AXSystemDialog" then
                                    visibleWindows[win:id()] = {
                                        title = title,
                                        frame = win:frame()
                                    }
                                end
                            end
                        end
                    end

                    -- Open the folder
                    log.i("Opening folder: " .. path)
                    hs.execute(string.format('/usr/bin/open "%s"', path))

                    -- Wait a bit for the window to open
                    hs.timer.doAfter(0.1, function()
                        -- Restore previously visible windows
                        if finder then
                            for _, win in ipairs(finder:allWindows()) do
                                if win:isVisible() and not win:isMinimized() then
                                    local title = win:title() or ""
                                    local role = win:role() or ""
                                    -- If this is a new window (not in our list)
                                    if not visibleWindows[win:id()] and title ~= "" and role ~= "AXSystemDialog" then
                                        log.i("Found new window: " .. title)
                                        -- This is our newly opened window, bring it to front
                                        win:focus()
                                    end
                                end
                            end
                        end
                    end)
                else
                    log.w("Folder does not exist: " .. path)
                end
            end)
        else
            log.w("No path defined for folder: " .. name .. ". Please check your configuration.")
        end
    end

    -- Set up URL copying shortcut
    if config.shortcuts.general and config.shortcuts.general.copyUrl then
        bindHotkey(config.shortcuts.general.copyUrl, function()
            local browsers = {config.applications.PrimaryBrowser, config.applications.SecondaryBrowser}
            for _, browserName in ipairs(browsers) do
                local browser = hs.application.get(browserName)
                if browser then
                    browser:activate()
                    hs.timer.usleep(50000)
                    hs.eventtap.keyStroke({"cmd"}, "l")
                    hs.timer.usleep(50000)
                    hs.eventtap.keyStroke({"cmd"}, "c")
                    hs.timer.usleep(50000)
                    hs.eventtap.keyStroke({}, "escape")
                    local url = hs.pasteboard.getContents()
                    if url and url:match("^https?://") then
                        log.i("Copied URL: " .. url)
                        return
                    end
                end
            end
            log.e("Failed to copy URL from browser")
        end)
    else
        log.w("No copyUrl shortcut defined in general shortcuts. Please check your configuration.")
    end

    -- Set up utility shortcuts
    if config.shortcuts.utils then
        for _, shortcut in ipairs(config.shortcuts.utils) do
            log.i(string.format("Setting up utility shortcut: %s (%s + %s)", 
                shortcut.action, table.concat(shortcut.mods, "+"), shortcut.key))
            
            bindHotkey(shortcut, function()
                if shortcut.action == "closeFinderWindows" then
                    local finder = hs.application.get("Finder")
                    if finder then
                        log.i("Attempting to close all Finder windows")
                        local closedCount = 0
                        local windows = finder:allWindows()
                        log.d("Found " .. #windows .. " total Finder windows")
                        for _, win in ipairs(windows) do
                            local title = win:title() or ""
                            local role = win:role() or ""
                            local subrole = win:subrole() or ""
                            
                            -- Skip the special always-running Finder window
                            if title == "" or role == "AXSystemDialog" then
                                log.d(string.format("Skipping special Finder window: title='%s', role='%s', subrole='%s'", 
                                    title, role, subrole))
                                goto continue
                            end
                            
                            if win:isVisible() and not win:isMinimized() then
                                log.d(string.format("Closing window: title='%s', role='%s', subrole='%s'", 
                                    title, role, subrole))
                                win:close()
                                closedCount = closedCount + 1
                            else
                                log.d(string.format("Skipping invisible/minimized window: '%s'", title))
                            end
                            ::continue::
                        end
                        log.i("Closed " .. closedCount .. " Finder windows")
                    else
                        log.w("Finder not running")
                    end
                elseif shortcut.action == "copyBrowserUrl" then
                    local frontApp = hs.application.frontmostApplication()
                    if frontApp and frontApp:name() == config.applications.Browser then
                        log.i("Copying URL from Zen Browser")
                        -- Sequence: cmd+L to select URL, cmd+C to copy, ESC to deselect
                        log.d("Selecting URL bar")
                        hs.eventtap.keyStroke({"cmd"}, "l")
                        hs.timer.doAfter(0.1, function()
                            log.d("Copying URL")
                            hs.eventtap.keyStroke({"cmd"}, "c")
                            hs.timer.doAfter(0.1, function()
                                log.d("Deselecting URL bar")
                                hs.eventtap.keyStroke({}, "escape")
                                local url = hs.pasteboard.getContents()
                                log.i("Copied URL: " .. (url or "nil"))
                            end)
                        end)
                    else
                        log.w("Zen Browser not focused (current app: " .. (frontApp and frontApp:name() or "nil") .. ")")
                    end
                end
            end)
        end
    end

    log.i("Application shortcuts setup complete")
end

return M
