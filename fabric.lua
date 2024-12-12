local M = {}
local log = hs.logger.new('Fabric', 'debug')
local setup = require("setup")

function M.setup(config)
    log.i("Setting up Fabric integration")

    -- Create pattern lookup table for faster access
    local patternLookup = {}
    for _, pattern in ipairs(config.fabric.patterns) do
        patternLookup[pattern.id] = pattern
    end

    local function executeFabricPattern(patternId)
        local clipboardContent = hs.pasteboard.getContents()
        if not clipboardContent or clipboardContent == "" then
            log.w("Error: Clipboard is empty")
            return
        end

        -- Get pattern configuration
        local pattern = patternLookup[patternId]
        if not pattern then
            log.e("Pattern not found: " .. patternId)
            return
        end

        -- Get the model to use (pattern-specific, or default)
        local modelToUse = pattern.model or config.fabric.defaultModel or "gpt-4"

        -- Get the command to use (some patterns might use a different command)
        local commandToUse = pattern.command or pattern.id

        -- Find fabric executable
        local fabricPath = ""
        
        -- First try the configured path
        if config.fabric.fabricPath then
            local configPath = config.fabric.fabricPath:gsub("^~", os.getenv("HOME"))
            if hs.fs.attributes(configPath) then
                fabricPath = configPath
                log.i("Found fabric at configured path: " .. fabricPath)
            else
                log.w("Configured fabric path not found: " .. configPath)
            end
        end
        
        -- If configured path doesn't work, try to find it
        if fabricPath == "" then
            fabricPath = hs.execute("which fabric"):gsub("%s+", "")
            log.i("Found fabric in PATH: " .. (fabricPath ~= "" and fabricPath or "not found"))
        end
        
        -- If still not found, try common installation paths
        if fabricPath == "" then
            local possiblePaths = {
                os.getenv("HOME") .. "/go/bin/fabric",  -- Go installation (most common)
                os.getenv("HOME") .. "/.local/bin/fabric",
                "/usr/local/bin/fabric",
                "/opt/homebrew/bin/fabric"
            }
            for _, path in ipairs(possiblePaths) do
                if hs.fs.attributes(path) then
                    fabricPath = path
                    log.i("Found fabric in alternate location: " .. path)
                    break
                end
            end
        end
        
        if fabricPath == "" then
            log.e([[
Could not find fabric executable. Please:
1. Install fabric: go install github.com/mrakinola/fabric-cli@latest
2. Set the correct path in config.lua (fabric.fabricPath)
Default installation path is: ~/go/bin/fabric
            ]])
            return
        end
        
        -- Build the fabric command
        local command
        if pattern.youtube then
            -- For YouTube patterns
            command = string.format('%s -y "%s" --stream --pattern %s',
                fabricPath,
                clipboardContent:gsub('"', '\\"'),  -- Escape quotes in URL
                commandToUse)
        else
            -- For regular patterns (including general)
            command = string.format('echo "%s" | %s --pattern %s',
                clipboardContent:gsub('"', '\\"'),
                fabricPath,
                commandToUse)
        end
        
        -- Helper function to truncate messages
        local function truncateMessage(msg, limit)
            limit = limit or 100  -- Default to 100 characters
            if #msg > limit then
                return msg:sub(1, limit-3) .. "..."
            end
            return msg
        end
        
        -- Helper function to show alerts (clears previous alerts first)
        local function showProcessAlert(message)
            hs.alert.closeAll()
            showAlert(message)
        end
        
        log.i("Executing command: " .. command)
        log.i("Pattern: " .. commandToUse)
        log.i("Content length: " .. #clipboardContent)

        -- Show processing alert
        showProcessAlert("Processing with " .. pattern.name .. "...")

        -- Execute the command and capture both stdout and stderr
        local output, status, type, rc = hs.execute(command)
        
        if status then
            if output and output ~= "" then
                -- Success with output
                hs.pasteboard.setContents(output)
                log.i("Successfully processed text with pattern: " .. commandToUse)
                
                -- Show success alert
                showProcessAlert("✓ " .. pattern.name .. " completed")
                
                -- Automatically paste the result
                hs.timer.doAfter(0.1, function()
                    hs.eventtap.keyStroke({"cmd"}, "v")
                    -- Show paste confirmation after a short delay
                    hs.timer.doAfter(0.2, function()
                        showProcessAlert("Content pasted")
                    end)
                end)
            else
                -- Success but no output
                showProcessAlert("⚠️ No output received")
                log.e("No output received from fabric command for pattern: " .. commandToUse)
            end
        else
            -- Command failed
            local errorMsg = output or "Unknown error"
            log.e("Error processing text: " .. errorMsg)
            log.e("Return code: " .. tostring(rc))
            log.e("Error type: " .. tostring(type))
            
            -- Show truncated error
            local shortError = errorMsg:match("^[^\n]+") or "Unknown error"  -- Get first line only
            showProcessAlert("❌ Error: " .. truncateMessage(shortError, 80))
            
            -- Additional pattern-specific error info
            if errorMsg:match("could not get pattern") then
                log.e("Pattern '" .. commandToUse .. "' not found. Please check available patterns using 'fabric -l'")
            end
        end
    end

    -- Bind shortcuts for all patterns
    for _, pattern in ipairs(config.fabric.patterns) do
        if pattern.shortcut and pattern.shortcut.mods and #pattern.shortcut.mods > 0 then
            log.i("Setting up fabric pattern shortcut: " .. pattern.id .. " with " .. hs.inspect(pattern.shortcut))
            hs.hotkey.bind(pattern.shortcut.mods, pattern.shortcut.key, function()
                log.i("Executing fabric pattern: " .. pattern.id)
                executeFabricPattern(pattern.id)
            end)
        else
            log.d("Skipping pattern shortcut for " .. pattern.id .. " (no modifiers defined)")
        end
    end

    -- Create choices for the chooser
    local choices = {}
    if config.fabric.categories then
        for _, category in ipairs(config.fabric.categories) do
            for _, patternId in ipairs(category.patterns) do
                local pattern = patternLookup[patternId]
                if pattern then
                    table.insert(choices, {
                        text = pattern.name,
                        subText = pattern.desc .. " (" .. category.name .. ")",
                        patternId = pattern.id
                    })
                end
            end
        end
    else
        -- If no categories defined, just add all patterns
        for _, pattern in ipairs(config.fabric.patterns) do
            table.insert(choices, {
                text = pattern.name,
                subText = pattern.desc,
                patternId = pattern.id
            })
        end
    end

    -- Add shortcut to show pattern chooser
    hs.hotkey.bind(config.fabric.chooserShortcut.mods, config.fabric.chooserShortcut.key, function()
        local chooser = hs.chooser.new(function(choice)
            if choice then
                executeFabricPattern(choice.patternId)
            end
        end)

        chooser:choices(choices)
        chooser:show()
    end)

    log.i("Fabric integration setup complete")
end

return M
