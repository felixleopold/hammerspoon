local M = {}
local log = hs.logger.new('Applications', 'debug')
local setup = require("setup")
local appGroups = require("appGroups")
local telemetry = require("telemetry")

function M.setup(config)
    log.i("Setting up application shortcuts")
    
    -- Configure logging based on user settings
    if config.debug then
        local debugEnabled = false
        
        if config.debug.appLaunching then
            log.i("Application launching debug logging enabled")
            debugEnabled = true
        end
        
        if config.debug.appFocusing then
            log.i("Application focusing debug logging enabled")
            debugEnabled = true
        end
        
        -- Set log level based on whether any app-related debugging is enabled
        if debugEnabled then
            log.setLogLevel('debug')
        else
            log.setLogLevel('warning')
        end
    end
    
    log.d("Loaded configuration: " .. hs.inspect(config))

    -- Helper function to launch or focus applications
    local function launchOrFocus(appName)
        log.i("Attempting to launch or focus: " .. hs.inspect(appName))
        
        -- Handle table-based app configuration
        local appConfig = appName
        if type(appName) == "table" then
            log.d("Using extended application configuration: " .. hs.inspect(appName))
        else
            -- Convert string to standard format for consistent handling
            appConfig = { name = appName }
        end
        
        -- Special handling for Finder
        if appConfig.name == "Finder" then
            local frontApp = hs.application.frontmostApplication()
            if frontApp and frontApp:name() == "Finder" then
                -- Finder is already frontmost, show all Finder windows
                log.i("Finder is already frontmost, showing all Finder windows")
                local finder = hs.application.get("Finder")
                if finder then
                    local windows = finder:allWindows()
                    local visibleWindows = {}
                    
                    -- Collect all valid Finder windows
                    for _, win in ipairs(windows) do
                        local title = win:title() or ""
                        local role = win:role() or ""
                        local subrole = win:subrole() or ""
                        
                        -- Only include actual Finder windows (not dialogs or special windows)
                        if title ~= "" and 
                           role == "AXWindow" and 
                           subrole == "AXStandardWindow" and
                           win:isStandard() then
                            table.insert(visibleWindows, win)
                            log.d(string.format("Found valid Finder window: '%s'", title))
                        else
                            log.d(string.format("Skipping window: title='%s', role='%s', subrole='%s', standard=%s", 
                                title, role, subrole, tostring(win:isStandard())))
                        end
                    end
                    
                    if #visibleWindows > 0 then
                        log.i(string.format("Found %d Finder windows to show", #visibleWindows))
                        
                        -- Get screen frame for positioning
                        local screen = hs.screen.mainScreen()
                        local screenFrame = screen:frame()
                        
                        -- Calculate grid layout based on number of windows
                        local cols = math.ceil(math.sqrt(#visibleWindows))
                        local rows = math.ceil(#visibleWindows / cols)
                        
                        local windowWidth = screenFrame.w / cols
                        local windowHeight = screenFrame.h / rows
                        
                        -- Position windows in a grid
                        for i, win in ipairs(visibleWindows) do
                            -- Unminimize and show the window first
                            if win:isMinimized() then
                                win:unminimize()
                            end
                            
                            -- Calculate grid position
                            local col = (i - 1) % cols
                            local row = math.floor((i - 1) / cols)
                            
                            local x = screenFrame.x + (col * windowWidth)
                            local y = screenFrame.y + (row * windowHeight)
                            
                            -- Set window frame
                            local newFrame = {
                                x = x,
                                y = y,
                                w = windowWidth,
                                h = windowHeight
                            }
                            
                            win:setFrame(newFrame)
                            win:raise()
                            
                            log.d(string.format("Positioned window '%s' at grid position (%d,%d)", 
                                win:title() or "Untitled", col, row))
                        end
                        
                        -- Focus the first window
                        if visibleWindows[1] then
                            visibleWindows[1]:focus()
                        end
                        
                        hs.alert.show(string.format("📁 Showing %d Finder windows", #visibleWindows), 1.5)
                    else
                        log.i("No valid Finder windows found to show")
                        hs.alert.show("📁 No Finder windows to show", 1.5)
                    end
                end
                return
            end
        end
        
        -- Special handling for Minecraft (Java)
        if appConfig.name == "java" then
            -- Find all Java windows
            local allWindows = hs.window.allWindows()
            for _, win in ipairs(allWindows) do
                local app = win:application()
                local title = win:title()
                -- Check for any Minecraft version (title starts with "Minecraft")
                if app and app:name() == "java" and title and title:match("^Minecraft%s*[%d%.]*$") then
                    log.i("Found Minecraft window: " .. title)
                    win:focus()
                    return
                end
            end
            -- If no Minecraft window found, launch the launcher instead
            log.i("No Minecraft window found, launching launcher instead")
            hs.application.launchOrFocus("Minecraft Launcher")
            return
        end
        
        -- Try to find the application by bundle ID if provided
        if appConfig.bundleID then
            log.d("Trying to find app by bundle ID: " .. appConfig.bundleID)
            local app = hs.application.get(appConfig.bundleID)
            if app then
                log.i("Found application by bundle ID, activating")
                app:activate()
                return
            else
                log.d("App not found by bundle ID, will try other methods")
            end
        end
        
        -- Try to launch by path if provided
        if appConfig.path and hs.fs.attributes(appConfig.path) then
            log.d("Launching app by path: " .. appConfig.path)
            local success = hs.execute("open \"" .. appConfig.path .. "\"")
            if success then
                log.i("Successfully launched app by path")
                return
            else
                log.w("Failed to launch app by path, will try other methods")
            end
        end
        
        -- Try standard launch or focus by name
        log.d("Trying standard launchOrFocus with app name: " .. appConfig.name)
        if hs.application.launchOrFocus(appConfig.name) then
            log.i("Successfully launched/focused app using standard method")
            return
        end
        
        -- Try getting app by name as fallback
        log.d("Trying to get app by name")
        local app = hs.application.get(appConfig.name)
        if app then
            log.i("Found app by name, activating")
            app:activate()
            return
        end
        
        -- Last resort: try open -a command
        log.w("All methods failed, trying open -a as last resort")
        hs.execute("open -a \"" .. appConfig.name .. "\"")
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

    -- Set up application shortcuts (primary layer)
    for name, shortcut in pairs(config.shortcuts.appShortcuts) do
        local appConfig = config.applications[name]
        if appConfig then
            local appDisplay = type(appConfig) == "table" and appConfig.name or appConfig
            log.i("Setting up shortcut for " .. name .. ": " .. hs.inspect(shortcut) .. " to launch " .. appDisplay)
            -- Register telemetry label for app launch
            telemetry.registerHotkeyLabel(shortcut.mods, shortcut.key, "app:" .. tostring(appDisplay))
            bindHotkey(shortcut, function() 
                log.i("Launching " .. appDisplay .. " via shortcut " .. hs.inspect(shortcut))
                launchOrFocus(appConfig)
            end)
        else
            log.w("No application defined for shortcut: " .. name .. ". Please check your configuration.")
        end
    end

    -- Set up application shortcuts (second layer)
    if config.shortcuts.appShortcuts2 then
        for name, shortcut in pairs(config.shortcuts.appShortcuts2) do
            local appConfig = config.applications[name]
            if appConfig then
                local appDisplay = type(appConfig) == "table" and appConfig.name or appConfig
                log.i("Setting up SECOND-LAYER shortcut for " .. name .. ": " .. hs.inspect(shortcut) .. " to launch " .. appDisplay)
                telemetry.registerHotkeyLabel(shortcut.mods, shortcut.key, "app2:" .. tostring(appDisplay))
                bindHotkey(shortcut, function()
                    log.i("Launching (layer2) " .. appDisplay .. " via shortcut " .. hs.inspect(shortcut))
                    launchOrFocus(appConfig)
                end)
            else
                log.w("No application defined for second-layer shortcut: " .. name .. ". Please check your configuration.")
            end
        end
    end

    -- Set up app groups
    if config.appGroups then
        log.i("Setting up application groups")
        appGroups.setup(config)
        
        -- Set up app group shortcuts
        for groupName, shortcut in pairs(config.shortcuts.appGroupShortcuts) do
            local groupConfig = shortcut.groupConfig
            if groupConfig then
                log.i(string.format("Setting up app group shortcut for '%s': %s to cycle through %s", 
                    groupName, 
                    hs.inspect(shortcut), 
                    table.concat(groupConfig.apps, ", ")))
                
                -- Register telemetry label for app group
                telemetry.registerHotkeyLabel(shortcut.mods, shortcut.key, "appGroup:" .. tostring(groupName))
                bindHotkey(shortcut, function()
                    log.i(string.format("Triggered app group '%s' via shortcut %s", groupName, hs.inspect(shortcut)))
                    appGroups.launchGroupApp(groupName, groupConfig, config)
                end)
            else
                log.w("No group configuration found for app group shortcut: " .. groupName)
            end
        end
    else
        log.i("No application groups configured")
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

            -- Register telemetry label for general action
            telemetry.registerHotkeyLabel(shortcut.mods, shortcut.key, "general:" .. tostring(shortcut.action))
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
                elseif shortcut.action == "openKanataConfig" then
                    log.i("Triggered: Open Kanata config in editor")
                    local path = config.folders.kanata
                    local editor = config.applications.Editor
                    if path and editor then
                        log.d(string.format("Opening Kanata config: path=%s, editor=%s", path, editor))
                        openInEditor(path, editor)
                    else
                        log.e("Missing configuration for Kanata editor shortcut", {
                            path = path,
                            editor = editor
                        })
                    end
				elseif shortcut.action == "openDotfilesConfig" then
					log.i("Triggered: Open Dotfiles in editor")
					local path = config.folders.dotfiles
					local editor = config.applications.Editor
					if path and editor then
						log.d(string.format("Opening Dotfiles: path=%s, editor=%s", path, editor))
						openInEditor(path, editor)
					else
						log.e("Missing configuration for Dotfiles editor shortcut", {
							path = path,
							editor = editor
						})
					end
                elseif shortcut.action == "copyBrowserUrl" then
                    local frontApp = hs.application.frontmostApplication()
                    local frontAppName = frontApp and frontApp:name()
                    local frontAppClass = frontApp and frontApp:bundleID()
                    
                    -- Helper function to check if it's a browser
                    local function isBrowser(app)
                        if not app then return false end
                        local name = app:name()
                        local class = app:bundleID()
                        
                        -- Check against configured browser names
                        if name == config.applications.Browser or name == config.applications.Browser2 then
                            return true
                        end
                        
                        -- Check for Zen Browser specifically (it can show up as just "Zen")
                        if name == "Zen" or name == "Zen Browser" or (class and class:match("zen%-browser")) then
                            return true
                        end
                        
                        -- Check for Edge specifically
                        if name == "Microsoft Edge" or (class and class:match("com%.microsoft%.edgemac")) then
                            return true
                        end
                        
                        return false
                    end
                    
                    -- Check if we're in a browser
                    if isBrowser(frontApp) then
                        log.i("Copying URL from browser: " .. frontAppName .. " (class: " .. (frontAppClass or "nil") .. ")")
                        -- Use cmd+L to select URL, wait a bit, then copy
                        hs.eventtap.keyStroke({"cmd"}, "l", 0)
                        hs.timer.usleep(100000) -- 100ms delay
                        hs.eventtap.keyStroke({"cmd"}, "c", 0)
                        hs.timer.usleep(50000) -- 50ms delay
                        hs.eventtap.keyStroke({}, "escape", 0)
                        
                        -- Verify we got a URL
                        hs.timer.doAfter(0.2, function()
                            local url = hs.pasteboard.getContents()
                            if url and url:match("^https?://") then
                                log.i("Successfully copied URL: " .. url)
                                hs.alert.show("✓ URL copied", 1)
                            else
                                log.w("Copied content is not a URL: " .. (url or "nil"))
                                hs.alert.show("❌ Failed to copy URL", 2)
                            end
                        end)
                    else
                        log.w("Not in a browser (current app: " .. frontAppName .. ", class: " .. (frontAppClass or "nil") .. ")")
                    end
                elseif shortcut.action == "createSymlink" then
                    log.i("Triggered symlink creation")
                    
                    -- Check if debug is enabled
                    local debugEnabled = config.debug and config.debug.symlinkCreation
                    
                    -- Get source paths from clipboard
                    local clipboardContent = hs.pasteboard.getContents()
                    if not clipboardContent then
                        hs.alert.show("❌ No path in clipboard", 2)
                        return
                    end
                    
                    if debugEnabled then
                        log.d("Clipboard content: " .. clipboardContent)
                    end
                    
                    -- Check if the clipboard content is from Finder (contains multiple paths)
                    local sourcePaths = {}
                    
                    -- First, try to split by newlines (most reliable separator)
                    if clipboardContent:find("\n") then
                        if debugEnabled then
                            log.d("Splitting clipboard content by newlines")
                        end
                        
                        for path in clipboardContent:gmatch("[^\r\n]+") do
                            if path and path:len() > 0 then
                                table.insert(sourcePaths, path)
                                if debugEnabled then
                                    log.d("Found path from newline split: " .. path)
                                end
                            end
                        end
                    else
                        -- If no newlines, check if it's a Finder-style space-separated list
                        -- This is a heuristic: if we find multiple file paths that exist, it's likely a space-separated list
                        if debugEnabled then
                            log.d("No newlines found, checking for space-separated paths")
                        end
                        
                        local potentialPaths = {}
                        local inQuote = false
                        local currentPath = ""
                        
                        -- Parse the clipboard content character by character to handle quoted paths
                        for i = 1, #clipboardContent do
                            local char = clipboardContent:sub(i, i)
                            
                            if char == '"' or char == "'" then
                                inQuote = not inQuote
                                if debugEnabled then
                                    log.d("Quote character found, inQuote = " .. tostring(inQuote))
                                end
                            elseif char == ' ' and not inQuote then
                                if currentPath ~= "" then
                                    table.insert(potentialPaths, currentPath)
                                    if debugEnabled then
                                        log.d("Found potential path: " .. currentPath)
                                    end
                                    currentPath = ""
                                end
                            else
                                currentPath = currentPath .. char
                            end
                        end
                        
                        -- Add the last path if there is one
                        if currentPath ~= "" then
                            table.insert(potentialPaths, currentPath)
                            if debugEnabled then
                                log.d("Found final potential path: " .. currentPath)
                            end
                        end
                        
                        -- Check if these paths exist
                        local validPathCount = 0
                        for _, path in ipairs(potentialPaths) do
                            -- Remove quotes if present
                            local cleanPath = path:gsub("^[\"'](.+)[\"']$", "%1")
                            -- Expand ~ if present
                            cleanPath = cleanPath:gsub("^~", os.getenv("HOME"))
                            
                            if debugEnabled then
                                log.d("Checking if path exists: " .. cleanPath)
                            end
                            
                            if hs.fs.attributes(cleanPath) then
                                validPathCount = validPathCount + 1
                                table.insert(sourcePaths, path)
                                if debugEnabled then
                                    log.d("Valid path found: " .. cleanPath)
                                end
                            else
                                if debugEnabled then
                                    log.d("Invalid path: " .. cleanPath)
                                end
                            end
                        end
                        
                        -- If we didn't find multiple valid paths, treat the whole clipboard as a single path
                        if validPathCount <= 1 then
                            sourcePaths = {clipboardContent}
                            if debugEnabled then
                                log.d("Using entire clipboard as a single path: " .. clipboardContent)
                            end
                        end
                    end
                    
                    -- If no valid paths found, alert the user
                    if #sourcePaths == 0 then
                        hs.alert.show("❌ No valid paths found in clipboard", 2)
                        return
                    end
                    
                    log.i("Found " .. #sourcePaths .. " paths in clipboard")
                    if debugEnabled then
                        for i, path in ipairs(sourcePaths) do
                            log.d("Path " .. i .. ": " .. path)
                        end
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
                    
                    -- Track success and failures
                    local successCount = 0
                    local failedPaths = {}
                    
                    -- Process each source path
                    for _, sourcePath in ipairs(sourcePaths) do
                        -- Expand ~ if present in source path
                        sourcePath = sourcePath:gsub("^~", os.getenv("HOME"))
                        
                        -- Remove quotes if present
                        sourcePath = sourcePath:gsub("^[\"'](.+)[\"']$", "%1")
                        
                        -- Validate source path exists
                        if not hs.fs.attributes(sourcePath) then
                            table.insert(failedPaths, sourcePath .. " (path does not exist)")
                            goto continue_symlink
                        end
                        
                        -- Get the filename from the source path
                        local filename = sourcePath:match("([^/]+)$")
                        if not filename then
                            table.insert(failedPaths, sourcePath .. " (could not determine filename)")
                            goto continue_symlink
                        end
                        
                        -- Combine target directory with filename
                        local targetPath = targetDir .. "/" .. filename
                        
                        -- Create the symlink
                        local command = string.format('ln -s "%s" "%s"', 
                            sourcePath:gsub('"', '\\"'), -- Escape double quotes in source path
                            targetPath:gsub('"', '\\"')  -- Escape double quotes in target path
                        )
                        
                        if debugEnabled then
                            log.d("Executing command: " .. command)
                        end
                        
                        local output, status = hs.execute(command)
                        
                        if status then
                            successCount = successCount + 1
                        else
                            local errorMsg = output or "Unknown error"
                            table.insert(failedPaths, sourcePath .. " (" .. errorMsg:gsub("\n", " ") .. ")")
                        end
                        
                        ::continue_symlink::
                    end
                    
                    -- Show results
                    if successCount > 0 and #failedPaths == 0 then
                        hs.alert.show(string.format("✓ Created %d symlink(s) in current Finder location", successCount), 2)
                    elseif successCount > 0 and #failedPaths > 0 then
                        hs.alert.show(string.format("⚠️ Created %d symlink(s), but %d failed", successCount, #failedPaths), 3)
                        for _, failedPath in ipairs(failedPaths) do
                            log.e("Failed to create symlink: " .. failedPath)
                        end
                    else
                        hs.alert.show("❌ Failed to create any symlinks", 3)
                        for _, failedPath in ipairs(failedPaths) do
                            log.e("Failed to create symlink: " .. failedPath)
                        end
                    end
                elseif shortcut.action == "openInEditor" then
                    -- Only proceed if Finder is the frontmost application
                    local frontApp = hs.application.frontmostApplication()
                    if not frontApp or frontApp:name() ~= "Finder" then
                        log.w("Not in Finder, ignoring editor shortcut")
                        return
                    end

                    -- Use AppleScript to get the current folder path
                    local script = [[
                        tell application "Finder"
                            set theFolder to POSIX path of (folder of front window as alias)
                        end tell
                        
                        do shell script "/usr/bin/open -a ]] .. config.applications.Editor .. [[ " & quoted form of theFolder
                        return true
                    ]]
                    
                    local ok, result = hs.osascript.applescript(script)
                    if not ok then
                        hs.alert.show("❌ Failed to open editor window", 2)
                        log.e("Failed to open editor: " .. (result or "unknown error"))
                    else
                        log.i("Successfully opened editor in folder")
                    end
                elseif shortcut.action == "reloadHammerspoonConfig" then
                    log.i("Triggered: Reload Hammerspoon configuration")
                    hs.alert.show("Reloading Hammerspoon configuration...", 1)
                    hs.timer.doAfter(0.5, function()
                        hs.reload()
                    end)
                elseif shortcut.action == "openInEditor2" then
                    -- Only proceed if Finder is the frontmost application
                    local frontApp = hs.application.frontmostApplication()
                    if not frontApp or frontApp:name() ~= "Finder" then
                        log.w("Not in Finder, ignoring editor shortcut")
                        return
                    end
                    
                    -- Check if the secondary editor is configured and exists
                    local editorName = config.applications.Editor2
                    if not editorName then
                        log.e("Secondary editor is not configured")
                        hs.alert.show("❌ Secondary editor is not configured", 2)
                        return
                    end
                    
                    -- First check if the editor exists
                    local editorExists = hs.execute('ls -l /Applications/ | grep -i "' .. editorName .. '"')
                    if editorExists == "" then
                        log.e("Secondary editor '" .. editorName .. "' does not seem to be installed")
                        hs.alert.show("❌ Secondary editor not found: " .. editorName, 2)
                        return
                    end
                    
                    -- Get the current folder first to isolate if that's where the error is
                    local getFolderScript = [[
                        tell application "Finder"
                            try
                                set theFolder to POSIX path of (folder of front window as alias)
                                return theFolder
                            on error errMsg
                                return "ERROR: " & errMsg
                            end try
                        end tell
                    ]]
                    
                    local ok, folderResult = hs.osascript.applescript(getFolderScript)
                    if not ok or not folderResult or folderResult:match("^ERROR:") then
                        hs.alert.show("❌ Could not get current Finder folder", 2)
                        log.e("Failed to get Finder folder: " .. (folderResult or "unknown error"))
                        return
                    end
                    
                    log.i("Got Finder folder: " .. folderResult)
                    
                    -- Now try to open the editor with the folder
                    local openScript = [[
                        try
                            do shell script "/usr/bin/open -a \"]] .. editorName .. [[\" \"]] .. folderResult .. [[\""
                            return true
                        on error errMsg
                            return "ERROR: " & errMsg
                        end try
                    ]]
                    
                    local ok, result = hs.osascript.applescript(openScript)
                    if not ok or not result or tostring(result):match("^ERROR:") then
                        hs.alert.show("❌ Failed to open secondary editor window", 2)
                        log.e("Failed to open secondary editor: " .. tostring(result or "unknown error"))
                    else
                        log.i("Successfully opened secondary editor in folder")
                    end
                elseif shortcut.action == "openInKitty" then
                    -- Only proceed if Finder is the frontmost application
                    local frontApp = hs.application.frontmostApplication()
                    if not frontApp or frontApp:name() ~= "Finder" then
                        log.w("Not in Finder, ignoring terminal shortcut")
                        return
                    end

                    -- Use AppleScript to trigger the service menu
                    local script = [[
                        tell application "Finder"
                            set theFolder to POSIX path of (folder of front window as alias)
                        end tell
                        
                        do shell script "/usr/bin/open -a ]] .. config.applications.Terminal .. [[ " & quoted form of theFolder
                        return true
                    ]]
                    
                    local ok, result = hs.osascript.applescript(script)
                    if not ok then
                        hs.alert.show("❌ Failed to open terminal window", 2)
                        log.e("Failed to open terminal: " .. (result or "unknown error"))
                    else
                        log.i("Successfully opened terminal in folder")
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
            -- Register telemetry label for folder open
            telemetry.registerHotkeyLabel((shortcut.mods or config.triggers.folder), shortcut.key, "folder:" .. tostring(name))
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
            -- Register telemetry label for utility action
            telemetry.registerHotkeyLabel(shortcut.mods, shortcut.key, "utils:" .. tostring(shortcut.action))

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
                    local frontAppName = frontApp and frontApp:name()
                    local frontAppClass = frontApp and frontApp:bundleID()
                    
                    -- Helper function to check if it's a browser
                    local function isBrowser(app)
                        if not app then return false end
                        local name = app:name()
                        local class = app:bundleID()
                        
                        -- Check against configured browser names
                        if name == config.applications.Browser or name == config.applications.Browser2 then
                            return true
                        end
                        
                        -- Check for Zen Browser specifically (it can show up as just "Zen")
                        if name == "Zen" or name == "Zen Browser" or (class and class:match("zen%-browser")) then
                            return true
                        end
                        
                        -- Check for Edge specifically
                        if name == "Microsoft Edge" or (class and class:match("com%.microsoft%.edgemac")) then
                            return true
                        end
                        
                        return false
                    end
                    
                    -- Check if we're in a browser
                    if isBrowser(frontApp) then
                        log.i("Copying URL from browser: " .. frontAppName .. " (class: " .. (frontAppClass or "nil") .. ")")
                        -- Use cmd+L to select URL, wait a bit, then copy
                        hs.eventtap.keyStroke({"cmd"}, "l", 0)
                        hs.timer.usleep(100000) -- 100ms delay
                        hs.eventtap.keyStroke({"cmd"}, "c", 0)
                        hs.timer.usleep(50000) -- 50ms delay
                        hs.eventtap.keyStroke({}, "escape", 0)
                        
                        -- Verify we got a URL
                        hs.timer.doAfter(0.2, function()
                            local url = hs.pasteboard.getContents()
                            if url and url:match("^https?://") then
                                log.i("Successfully copied URL: " .. url)
                                hs.alert.show("✓ URL copied", 1)
                            else
                                log.w("Copied content is not a URL: " .. (url or "nil"))
                                hs.alert.show("❌ Failed to copy URL", 2)
                            end
                        end)
                    else
                        log.w("Not in a browser (current app: " .. frontAppName .. ", class: " .. (frontAppClass or "nil") .. ")")
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
