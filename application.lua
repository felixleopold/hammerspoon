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
        log.i("Binding hotkey: mods=" .. hs.inspect(shortcut.mods) .. ", key=" .. shortcut.key)
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

    -- Helper function to find window with path
    local function findWindowWithPath(app, path)
        if not app then return nil end
        for _, win in ipairs(app:allWindows()) do
            -- Different editors store the path in different ways
            local winTitle = win:title()
            if winTitle then
                -- Check if the path is in the window title
                if winTitle:find(path, 1, true) then
                    return win
                end
            end
        end
        return nil
    end

    -- Helper function to open folder in editor
    local function openInEditor(path, editorName)
        if not path or not editorName then 
            log.e("Missing required parameters:", {path = path, editor = editorName})
            return 
        end
        
        path = expandPath(path)
        log.i(string.format("Opening %s in %s", path, editorName))
        
        -- Try to find existing editor window with this path
        local editor = hs.application.get(editorName)
        if editor then
            log.d("Found existing editor instance")
            local existingWindow = findWindowWithPath(editor, path)
            if existingWindow then
                log.i("Found existing window with path, focusing it")
                existingWindow:focus()
                return
            else
                log.d("No existing window found with path")
            end
        else
            log.d("No existing editor instance found")
        end
        
        -- Launch or focus editor and open the path
        log.i("Launching editor and opening path")
        hs.application.launchOrFocus(editorName)
        hs.timer.doAfter(0.1, function()
            local command = string.format('/usr/bin/open -a "%s" "%s"', editorName, path)
            log.d("Executing command: " .. command)
            local output, status = hs.execute(command)
            if status then
                log.i("Successfully opened folder in editor")
            else
                log.e("Failed to open folder in editor: " .. (output or "unknown error"))
            end
        end)
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

    -- Set up general shortcuts first
    if config.shortcuts.general then
        log.i("Setting up general shortcuts: " .. hs.inspect(config.shortcuts.general))
        for _, shortcut in ipairs(config.shortcuts.general) do
            log.i(string.format("Processing general shortcut: action=%s, mods=%s, key=%s", 
                shortcut.action,
                hs.inspect(shortcut.mods),
                shortcut.key))

            if not shortcut.mods or not shortcut.key or not shortcut.action then
                log.e("Invalid general shortcut configuration: " .. hs.inspect(shortcut))
                goto continue
            end

            bindHotkey(shortcut, function()
                log.i("Triggered general shortcut: " .. shortcut.action)
                if shortcut.action == "openHammerspoonConfig" then
                    log.i("Triggered: Open Hammerspoon config in editor")
                    local path = config.folders.hammerspoon
                    local editor = config.applications.Editor
                    if path and editor then
                        log.d(string.format("Opening Hammerspoon config: path=%s, editor=%s", path, editor))
                        openInEditor(path, editor)
                    else
                        log.e("Missing configuration for Hammerspoon editor shortcut", {
                            path = path,
                            editor = editor
                        })
                    end
                elseif shortcut.action == "copyBrowserUrl" then
                    local frontApp = hs.application.frontmostApplication()
                    if frontApp and frontApp:name() == config.applications.Browser then
                        log.i("Copying URL from Browser")
                        hs.eventtap.keyStroke({"cmd"}, "l")
                        hs.timer.doAfter(0.1, function()
                            hs.eventtap.keyStroke({"cmd"}, "c")
                            hs.timer.doAfter(0.1, function()
                                hs.eventtap.keyStroke({}, "escape")
                            end)
                        end)
                    end
                elseif shortcut.action == "createSymlink" then
                    log.i("Triggered symlink creation")
                    
                    -- Get source path from clipboard
                    local sourcePath = hs.pasteboard.getContents()
                    if not sourcePath then
                        hs.alert.show("❌ No path in clipboard", 2)
                        return
                    end
                    
                    -- Expand ~ if present in source path
                    sourcePath = sourcePath:gsub("^~", os.getenv("HOME"))
                    
                    -- Validate source path exists
                    if not hs.fs.attributes(sourcePath) then
                        hs.alert.show("❌ Source path does not exist: " .. sourcePath, 2)
                        return
                    end
                    
                    -- Get current Finder window path using AppleScript
                    local script = [[
                        tell application "Finder"
                            if (count of windows) is 0 then
                                return POSIX path of (home as text)
                            end if
                            
                            try
                                return POSIX path of (target of front window as text)
                            on error
                                return POSIX path of (home as text)
                            end try
                        end tell
                    ]]
                    
                    local ok, targetDir = hs.osascript.applescript(script)
                    if not ok or not targetDir then
                        hs.alert.show("❌ Could not get current Finder location", 2)
                        return
                    end
                    
                    -- Remove trailing slash if present
                    targetDir = targetDir:gsub("/$", "")
                    
                    -- Get the filename from the source path
                    local filename = sourcePath:match("([^/]+)$")
                    if not filename then
                        hs.alert.show("❌ Could not determine filename from source path", 2)
                        return
                    end
                    
                    -- Combine target directory with filename
                    local targetPath = targetDir .. "/" .. filename
                    
                    -- Create the symlink
                    local command = string.format('ln -s "%s" "%s"', sourcePath, targetPath)
                    local output, status = hs.execute(command)
                    
                    if status then
                        hs.alert.show("✓ Created symlink in current Finder location", 2)
                    else
                        local errorMsg = output or "Unknown error"
                        hs.alert.show("❌ Failed to create symlink: " .. errorMsg, 3)
                    end
                end
            end)
            ::continue::
        end
    else
        log.w("No general shortcuts configured")
    end

    -- Set up folder shortcuts
    for name, shortcut in pairs(config.shortcuts.folderShortcuts) do
        local path = config.folders[name]
        if path then
            path = expandPath(path)
            log.d("Setting up folder shortcut for " .. name .. ": " .. hs.inspect(shortcut) .. " to open " .. path)
            -- Use custom modifiers if provided, otherwise use default folder modifiers
            local mods = shortcut.mods or config.triggers.folder
            bindHotkey({mods = mods, key = shortcut.key}, function()
                if hs.fs.attributes(path) then
                    -- Normal folder opening behavior
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
                shortcut.action, 
                table.concat(shortcut.mods, "+"), 
                shortcut.key))
            
            bindHotkey({mods = shortcut.mods, key = shortcut.key}, function()
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
                            
                            -- Close all visible Finder windows except empty windows
                            if win:isVisible() and not win:isMinimized() and title ~= "" then
                                log.d(string.format("Closing window: title='%s', role='%s', subrole='%s'", 
                                    title, role, subrole))
                                win:close()
                                closedCount = closedCount + 1
                            else
                                log.d(string.format("Skipping window: title='%s', role='%s', subrole='%s', visible=%s, minimized=%s", 
                                    title, role, subrole, tostring(win:isVisible()), tostring(win:isMinimized())))
                            end
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
                elseif shortcut.action == "closeOtherAppWindows" then
                    local currentWindow = hs.window.focusedWindow()
                    if not currentWindow then
                        log.w("No focused window")
                        return
                    end

                    local app = currentWindow:application()
                    if not app then
                        log.w("No application found for current window")
                        return
                    end

                    log.i("Closing other windows for " .. app:name())
                    local closedCount = 0
                    local windows = app:allWindows()
                    for _, win in ipairs(windows) do
                        if win:id() ~= currentWindow:id() and win:isVisible() and not win:isMinimized() then
                            log.d(string.format("Closing window: '%s'", win:title() or "Untitled"))
                            win:close()
                            closedCount = closedCount + 1
                        else
                            log.d(string.format("Skipping window: '%s' (current=%s, visible=%s, minimized=%s)", 
                                win:title() or "Untitled",
                                tostring(win:id() == currentWindow:id()),
                                tostring(win:isVisible()),
                                tostring(win:isMinimized())))
                        end
                    end
                    log.i("Closed " .. closedCount .. " windows")

                elseif shortcut.action == "closeOtherApps" then
                    local frontApp = hs.application.frontmostApplication()
                    if not frontApp then
                        log.w("No frontmost application")
                        return
                    end

                    log.i("Closing other applications except " .. frontApp:name())
                    local closedCount = 0
                    local apps = hs.application.runningApplications()
                    
                    -- List of bundle IDs for system apps we want to keep running
                    local systemApps = {
                        ["com.apple.finder"] = true,        -- Finder
                        ["com.apple.dock"] = true,          -- Dock
                        ["com.apple.dock.extra"] = true,    -- Dock Extra
                        ["com.apple.systemuiserver"] = true, -- Menu bar
                        ["com.apple.loginwindow"] = true,    -- Login window
                        ["com.apple.WindowManager"] = true,  -- Window manager
                        ["com.apple.notificationcenterui"] = true, -- Notification Center
                        ["com.apple.controlcenter"] = true,  -- Control Center
                        ["org.hammerspoon.Hammerspoon"] = true, -- Hammerspoon itself
                        ["com.apple.wallpaper.agent"] = true, -- Wallpaper
                        ["com.apple.UIKitSystemApp"] = true,  -- System UI
                        ["com.apple.TextInputMenuAgent"] = true, -- Text Input Menu
                        ["com.apple.TextInputSwitcher"] = true, -- Text Input Switcher
                        ["com.apple.Spotlight"] = true,        -- Spotlight
                        ["com.apple.ViewBridgeAuxiliary"] = true -- View Bridge (UI related)
                    }

                    -- List of bundle ID patterns that indicate system processes
                    local systemPatterns = {
                        "^com%.apple%.TextInput",
                        "^com%.apple%.appkit%.xpc",
                        "^com%.apple%.UIKit",
                        "^com%.apple%.ViewBridge",
                        "^com%.apple%.CoreServices",
                        "^com%.apple%.systemui"
                    }

                    for _, app in ipairs(apps) do
                        local bundleID = app:bundleID()
                        local name = app:name()
                        
                        -- Check if the bundle ID matches any system patterns
                        local isSystemProcess = false
                        if bundleID then
                            for _, pattern in ipairs(systemPatterns) do
                                if string.match(bundleID:lower(), pattern:lower()) then
                                    isSystemProcess = true
                                    break
                                end
                            end
                        end
                        
                        -- Only close apps that:
                        -- 1. Have a bundle ID
                        -- 2. Are not the current app
                        -- 3. Are not in our system apps list
                        -- 4. Are not helper processes
                        -- 5. Are not system UI processes
                        -- 6. Don't match system patterns
                        if bundleID and 
                           bundleID ~= frontApp:bundleID() and
                           not systemApps[bundleID] and
                           not string.lower(name):match("helper") and
                           not string.lower(name):match("agent") and
                           not string.lower(name):match("daemon") and
                           not string.lower(name):match("service") and
                           not isSystemProcess and
                           not app:isHidden() then
                            
                            log.d(string.format("Closing application: %s (%s)", 
                                name or "Unknown",
                                bundleID or "No Bundle ID"))
                            app:kill()
                            closedCount = closedCount + 1
                        else
                            local skipReason = "unknown"
                            if not bundleID then skipReason = "no bundle ID"
                            elseif bundleID == frontApp:bundleID() then skipReason = "current app"
                            elseif systemApps[bundleID] then skipReason = "system app"
                            elseif string.lower(name):match("helper") then skipReason = "helper process"
                            elseif string.lower(name):match("agent") then skipReason = "agent process"
                            elseif string.lower(name):match("daemon") then skipReason = "daemon process"
                            elseif string.lower(name):match("service") then skipReason = "service process"
                            elseif isSystemProcess then skipReason = "system UI process"
                            elseif app:isHidden() then skipReason = "hidden"
                            end
                            
                            log.d(string.format("Skipping application: %s (%s) - reason: %s", 
                                name or "Unknown",
                                bundleID or "No Bundle ID",
                                skipReason))
                        end
                    end
                    log.i("Closed " .. closedCount .. " applications")
                end
            end)
        end
    end

    log.i("Application shortcuts setup complete")
end

return M
