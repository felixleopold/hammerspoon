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

    -- Function to execute fabric pattern with custom instruction
    local function executeFabricPatternWithInstruction(patternId, instruction)
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
            
            -- Also try looking for fabric-ai (homebrew installation)
            if fabricPath == "" then
                fabricPath = hs.execute("which fabric-ai"):gsub("%s+", "")
                log.i("Found fabric-ai in PATH: " .. (fabricPath ~= "" and fabricPath or "not found"))
            end
        end
        
        -- If still not found, try common installation paths
        if fabricPath == "" then
            local possiblePaths = {
                os.getenv("HOME") .. "/go/bin/fabric",  -- Go installation (most common)
                os.getenv("HOME") .. "/.local/bin/fabric",
                "/usr/local/bin/fabric",
                "/opt/homebrew/bin/fabric",
                "/opt/homebrew/bin/fabric-ai"  -- Homebrew installation
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
1. Install fabric: go install github.com/danielmiessler/fabric@latest
   or with Homebrew: brew install fabric-ai
2. Set the correct path in config.lua (fabric.fabricPath)
Default installation paths are: 
- Go: ~/go/bin/fabric
- Homebrew: /opt/homebrew/bin/fabric-ai
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
                pattern.id)
        else
            -- For regular patterns
            local baseCommand = string.format('echo "%s" | %s --pattern %s',
                clipboardContent:gsub('"', '\\"'),
                fabricPath,
                pattern.id)
            
            -- Handle pattern variables
            if pattern.variables then
                for varName, defaultValue in pairs(pattern.variables) do
                    if varName == "instruction" and instruction then
                        -- Use provided instruction if available
                        baseCommand = baseCommand .. string.format(' -v=%s:"%s"', 
                            varName, instruction:gsub('"', '\\"'))
                    elseif defaultValue and defaultValue ~= "" then
                        -- Use default value if available
                        baseCommand = baseCommand .. string.format(' -v=%s:"%s"', 
                            varName, defaultValue:gsub('"', '\\"'))
                    end
                end
            end
            
            command = baseCommand
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
        log.i("Pattern: " .. pattern.id)
        log.i("Content length: " .. #clipboardContent)

        -- Show processing alert
        showProcessAlert("Processing with " .. pattern.name .. "...")

        -- Execute the command and capture both stdout and stderr
        local output, status, type, rc = hs.execute(command)
        
        if status then
            if output and output ~= "" then
                -- Success with output
                log.i("Got output: " .. output)  -- Debug log
                hs.pasteboard.setContents(output)
                log.i("Successfully processed text with pattern: " .. pattern.id)
                
                -- Show success alert
                showProcessAlert("✓ " .. pattern.name .. " completed")
                
                -- Verify clipboard content
                log.i("Clipboard content after setting: " .. (hs.pasteboard.getContents() or "nil"))  -- Debug log
                
                -- Increase delay before pasting
                hs.timer.doAfter(0.3, function()
                    log.i("Attempting to paste content")  -- Debug log
                    hs.eventtap.keyStroke({"cmd"}, "v")
                    
                    -- Show paste confirmation after a longer delay
                    hs.timer.doAfter(0.5, function()
                        -- Verify final clipboard content
                        log.i("Final clipboard content: " .. (hs.pasteboard.getContents() or "nil"))  -- Debug log
                        showProcessAlert("Content pasted")
                    end)
                end)
            else
                -- Success but no output
                showProcessAlert("⚠️ No output received")
                log.e("No output received from fabric command for pattern: " .. pattern.id)
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
                log.e("Pattern '" .. pattern.id .. "' not found. Please check available patterns using 'fabric -l'")
            end
        end
    end

    -- Function to show variable input prompt
    local function showVariablePrompt(patternId, variableName)
        -- Store the current window to restore focus later
        local currentWindow = hs.window.focusedWindow()
        
        -- Create a chooser for variable input
        local chooser = hs.chooser.new(function(choice)
            if choice then
                -- Restore focus to the original window
                if currentWindow then
                    currentWindow:focus()
                    -- Small delay to ensure focus is restored
                    hs.timer.doAfter(0.1, function()
                        executeFabricPatternWithInstruction(patternId, choice.text)
                    end)
                else
                    executeFabricPatternWithInstruction(patternId, choice.text)
                end
            end
        end)
        
        -- Configure the chooser appearance for a modern macOS look
        chooser:width(25) -- Make it 25% of screen width (more compact)
        chooser:rows(0)  -- Hide the choices area completely
        chooser:bgDark(true)  -- Dark mode
        chooser:fgColor({ hex = "#e5e5e5" })  -- Light gray text for better readability
        chooser:subTextColor({ hex = "#666666" })  -- Darker gray subtext
        chooser:searchSubText(false)  -- Don't search in subtext
        chooser:placeholderText("Enter " .. variableName)  -- Simpler placeholder
        
        -- Minimal choice display
        chooser:queryChangedCallback(function(query)
            if query and query ~= "" then
                chooser:choices({
                    {
                        text = query,
                        subText = "⏎ to execute"  -- Unicode symbol for cleaner look
                    }
                })
            else
                chooser:choices({})
            end
        end)
        
        -- Show the chooser
        chooser:show()
    end

    -- Main execute function that handles all patterns
    local function executeFabricPattern(patternId)
        -- Get pattern configuration
        local pattern = patternLookup[patternId]
        if not pattern then
            log.e("Pattern not found: " .. patternId)
            return
        end

        log.i("Executing pattern: " .. patternId .. " with variables: " .. hs.inspect(pattern.variables))

        -- Check if pattern has variables that need user input
        if pattern.variables then
            -- Find first variable that needs user input
            for varName, defaultValue in pairs(pattern.variables) do
                log.i("Checking variable: " .. varName .. " with default value: " .. tostring(defaultValue))
                if not defaultValue or defaultValue == "" then
                    log.i("Variable needs user input, showing prompt for: " .. varName)
                    showVariablePrompt(patternId, varName)
                    return
                end
            end
        end
        
        -- For patterns without variables or with all defaults, execute without instruction
        executeFabricPatternWithInstruction(patternId, nil)
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
