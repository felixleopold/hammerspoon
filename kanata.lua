local M = {}
local log = hs.logger.new('Kanata', 'warning')

-- Module state
local menuBar = nil
local currentMode = "normal"
local fileWatcher = nil
local config = nil
local menuUpdateInProgress = false
local lastMenuUpdate = 0

-- Helper function to expand path
local function expandPath(path)
    if path:sub(1, 1) == "~" then
        return os.getenv("HOME") .. path:sub(2)
    end
    return path
end

-- Mode configurations 
local modes = {
    normal = {
        symbol = "◯",  -- Empty circle
        tooltip = "Kanata: Normal Mode"
    },
    vim = {
        symbol = "◆",  -- Diamond
        tooltip = "Kanata: Vim Mode"
    },
    typing = {
        symbol = "●",  -- Filled circle
        tooltip = "Kanata: Typing Mode"
    },
    gaming = {
        symbol = "▲",  -- Triangle
        tooltip = "Kanata: Gaming Mode"
    }
}

-- Function to create menu bar icon with symbol
local function createMenuBarIcon(mode)
    local modeConfig = modes[mode]
    if not modeConfig then
        log.e("Unknown mode: " .. tostring(mode))
        return nil
    end
    
    log.d("Creating menu bar icon for mode: " .. mode .. " with symbol: " .. modeConfig.symbol)
    
    -- Create text-based icon using the symbol
    local symbol = modeConfig.symbol
    
    -- Create an attributed string for the symbol
    local styledText = hs.styledtext.new(symbol, {
        font = { name = "SF Pro Display", size = 16 },
        color = { white = 1.0 }, -- White text for visibility
        paragraphStyle = { alignment = "center" }
    })
    
    -- Create canvas with the styled text
    local canvas = hs.canvas.new({x = 0, y = 0, w = 20, h = 20})
    canvas[1] = {
        type = "text",
        text = styledText,
        frame = { x = 0, y = 0, w = 20, h = 20 }
    }
    
    local image = canvas:imageFromCanvas()
    log.d("Created menu bar icon successfully with symbol: " .. symbol)
    return image
end

-- Function to update menu bar display
local function updateMenuBar()
    if not menuBar then 
        log.e("Menu bar object is nil!")
        return 
    end
    
    -- Prevent concurrent updates
    if menuUpdateInProgress then
        log.d("Menu update already in progress, skipping")
        return
    end
    
    local now = hs.timer.secondsSinceEpoch()
    -- Rate limit updates to prevent excessive calls
    if now - lastMenuUpdate < 0.1 then
        log.d("Rate limiting menu update")
        return
    end
    
    menuUpdateInProgress = true
    lastMenuUpdate = now
    
    local modeConfig = modes[currentMode]
    if not modeConfig then
        log.e("Unknown current mode: " .. tostring(currentMode))
        menuUpdateInProgress = false
        return
    end
    
    log.i("Updating menu bar for mode: " .. currentMode)
    
    -- Update icon
    local icon = createMenuBarIcon(currentMode)
    if icon then
        menuBar:setIcon(icon)
        log.i("Menu bar icon updated successfully")
    else
        log.e("Failed to create menu bar icon")
        -- Fallback: set title if icon fails
        menuBar:setTitle(modeConfig.symbol)
    end
    
    -- Update tooltip
    menuBar:setTooltip(modeConfig.tooltip)
    
    menuUpdateInProgress = false
    log.i("Updated menu bar to mode: " .. currentMode)
end

-- Function to execute kanata-layer command
local function executeKanataLayer(mode)
    if not config or not config.kanata or not config.kanata.kanataLayerCommand then
        log.d("No kanata-layer command configured, skipping")
        return
    end
    
    local baseCommand = config.kanata.kanataLayerCommand
    
    -- Try to resolve the full path if it's not absolute
    local command
    if baseCommand:match("^/") then
        -- Already absolute path
        command = baseCommand .. " " .. mode
    else
        -- Try to find the command in PATH
        local whichResult = hs.execute("which " .. baseCommand)
        if whichResult and whichResult ~= "" then
            local fullPath = whichResult:gsub("%s+", "") -- Remove whitespace
            command = fullPath .. " " .. mode
            log.i("Resolved command path: " .. fullPath)
        else
            -- Fallback to the original command (might be in PATH when executed)
            command = baseCommand .. " " .. mode
            log.w("Could not resolve full path for: " .. baseCommand)
        end
    end
    
    log.i("Executing kanata-layer command: " .. command)
    
    -- Execute the command with proper environment
    hs.task.new("/bin/bash", function(exitCode, stdOut, stdErr)
        if exitCode == 0 then
            log.i("kanata-layer command executed successfully")
            if stdOut and stdOut ~= "" then
                log.d("Command output: " .. stdOut)
            end
        else
            log.e("kanata-layer command failed with exit code: " .. exitCode)
            if stdErr and stdErr ~= "" then
                log.e("Error output: " .. stdErr)
            end
            if stdOut and stdOut ~= "" then
                log.e("Standard output: " .. stdOut)
            end
        end
    end, {"-c", "source ~/.zshrc 2>/dev/null; " .. command}):start()
end

-- Function to set mode
local function setMode(mode, fromMenuBar)
    if not modes[mode] then
        log.e("Invalid mode: " .. tostring(mode))
        return false
    end
    
    local oldMode = currentMode
    currentMode = mode
    
    log.i("Setting mode from " .. oldMode .. " to " .. mode .. " (fromMenuBar: " .. tostring(fromMenuBar or false) .. ")")
    
    -- Update menu bar immediately
    updateMenuBar()
    
    -- Write mode to status file if configured
    if config.kanata.statusFile then
        local statusFile = expandPath(config.kanata.statusFile)
        local file = io.open(statusFile, "w")
        if file then
            file:write(mode)
            file:close()
            log.d("Wrote mode '" .. mode .. "' to status file: " .. statusFile)
        else
            log.e("Failed to write to status file: " .. statusFile)
        end
    end
    
    -- Execute kanata-layer command only if changed from menu bar
    if fromMenuBar then
        executeKanataLayer(mode)
    end
    
    -- Refresh menu to update checkmarks (only when changed from menu bar)
    if fromMenuBar and menuBar then
        hs.timer.doAfter(0.2, function()
            if not menuUpdateInProgress then
                menuBar:setMenu(createMenu)
                log.d("Menu refreshed after mode change from menu bar")
            end
        end)
    end
    
    return true
end

-- Function to read current mode from status file
local function readModeFromFile()
    local statusFile = expandPath(config.kanata.statusFile)
    local file = io.open(statusFile, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content then
            local mode = content:match("^%s*(.-)%s*$") -- Trim whitespace
            if mode and (mode == "normal" or mode == "vim" or mode == "typing" or mode == "gaming") then
                log.i("Read mode from file: " .. mode)
                return mode
            else
                log.w("Invalid mode in file: " .. tostring(mode))
            end
        end
    else
        log.d("Status file not found, will create on first mode change")
    end
    
    -- Return default mode if file doesn't exist or is invalid
    local defaultMode = config.kanata.defaultMode or "normal"
    log.i("Using default mode: " .. defaultMode)
    return defaultMode
end

-- Function to create menu bar menu
local function createMenu()
    -- Capture current mode at menu creation time to avoid race conditions
    local menuCurrentMode = currentMode
    local menu = {}
    
    -- Add mode options
    for modeName, modeConfig in pairs(modes) do
        table.insert(menu, {
            title = modeConfig.tooltip,
            fn = function() 
                log.i("Mode change requested from menu bar: " .. modeName)
                -- Prevent menu updates during user interaction
                hs.timer.doAfter(0.05, function()
                    setMode(modeName, true) -- fromMenuBar = true
                end)
            end,
            checked = (menuCurrentMode == modeName)
        })
    end
    
    -- Add separator
    table.insert(menu, { title = "-" })
    
    -- Add refresh option
    table.insert(menu, {
        title = "Refresh from File",
        fn = function()
            hs.timer.doAfter(0.05, function()
                local fileMode = readModeFromFile()
                if fileMode then
                    setMode(fileMode, false) -- fromMenuBar = false (this is a file refresh)
                    hs.alert.show("Kanata mode refreshed: " .. fileMode)
                else
                    hs.alert.show("No valid mode found in status file")
                end
            end)
        end
    })
    
    -- Add status file info
    if config.kanata.statusFile then
        table.insert(menu, {
            title = "Status File: " .. config.kanata.statusFile,
            disabled = true
        })
    end
    
    -- Add kanata-layer command info if configured
    if config and config.kanata and config.kanata.kanataLayerCommand then
        table.insert(menu, {
            title = "Layer Command: " .. config.kanata.kanataLayerCommand,
            disabled = true
        })
    end
    
    return menu
end

-- Function to set up file watcher for status file changes
local function setupFileWatcher()
    local statusFile = expandPath(config.kanata.statusFile)
    local statusDir = statusFile:match("(.+)/[^/]+$") or "~/.config/kanata"
    statusDir = expandPath(statusDir)
    
    log.i("Setting up file watcher for directory: " .. statusDir)
    log.i("Watching for changes to: " .. statusFile)
    
    -- Create directory if it doesn't exist
    hs.execute("mkdir -p " .. statusDir)
    
    fileWatcher = hs.pathwatcher.new(statusDir, function(files)
        -- Check if our status file was modified
        local statusFileName = statusFile:match("[^/]+$")
        for _, file in ipairs(files) do
            if file:match(statusFileName) then
                log.d("Status file change detected: " .. file)
                
                -- Delay file reading to avoid conflicts with menu interactions
                hs.timer.doAfter(0.1, function()
                    local newMode = readModeFromFile()
                    if newMode and newMode ~= currentMode then
                        log.i("Mode changed from " .. currentMode .. " to " .. newMode .. " (via file)")
                        currentMode = newMode
                        updateMenuBar()
                    end
                end)
                break
            end
        end
    end):start()
    
    log.i("File watcher started for Kanata status file")
end

-- Function to force refresh the menu bar (useful for debugging)
function M.forceRefresh()
    if menuBar then
        menuUpdateInProgress = false -- Reset any stuck state
        updateMenuBar()
        menuBar:returnToMenuBar()
        log.i("Forced menu bar refresh")
    else
        log.w("Cannot refresh - menu bar not initialized")
    end
end

-- Function to detect and recover from stuck menu states
local function checkMenuHealth()
    if menuUpdateInProgress then
        local now = hs.timer.secondsSinceEpoch()
        if now - lastMenuUpdate > 5 then -- Stuck for more than 5 seconds
            log.w("Menu update appears stuck, resetting state")
            menuUpdateInProgress = false
            updateMenuBar()
        end
    end
end

-- Function to setup the kanata integration
function M.setup(cfg)
    config = cfg
    -- Configure logging per user config
    if config and config.debug and config.debug.kanata then
        log.setLogLevel('debug')
    else
        log.setLogLevel('warning')
    end
    
    if not config.kanata or not config.kanata.enabled then
        log.i("Kanata integration disabled")
        return
    end
    
    log.i("Setting up Kanata integration")
    
    -- Read initial mode from file or use default
    currentMode = readModeFromFile()
    
    -- Create menu bar item
    menuBar = hs.menubar.new()
    if not menuBar then
        log.e("Failed to create menu bar item")
        return
    end
    
    -- Set up menu bar
    menuBar:setMenu(createMenu)
    updateMenuBar()
    
    -- Set up file watcher
    setupFileWatcher()
    
    -- Set up periodic refresh to ensure menu bar stays in sync (less frequent)
    hs.timer.doEvery(15, function()
        -- Check for stuck menu states
        checkMenuHealth()
        
        -- Check for mode mismatches
        local fileMode = readModeFromFile()
        if fileMode and fileMode ~= currentMode then
            log.i("Periodic check: Mode mismatch detected, updating from " .. currentMode .. " to " .. fileMode)
            currentMode = fileMode
            updateMenuBar()
        end
    end)
    
    log.i("Kanata integration setup complete with initial mode: " .. currentMode)
end

-- Export functions for terminal command integration
M.setMode = setMode
M.getCurrentMode = function() return currentMode end
M.getModes = function() return modes end

return M 