local M = {}
local log = hs.logger.new('Fabric', 'debug')
local setup = require("setup")

function M.setup(config)
    log.i("Setting up Fabric integration")

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

    -- Create pattern lookup table for faster access
    local patternLookup = {}
    for _, pattern in ipairs(config.fabric.patterns) do
        patternLookup[pattern.id] = pattern
    end

    local function executeFabricPattern(patternId)
        local clipboardContent = hs.pasteboard.getContents()
        if not clipboardContent or clipboardContent == "" then
            hs.alert.show("Error: Clipboard is empty")
            return
        end

        -- Get pattern configuration
        local pattern = patternLookup[patternId]
        if not pattern then
            log.e("Pattern not found: " .. patternId)
            hs.alert.show("Error: Pattern not found")
            return
        end

        -- Get the model to use (pattern-specific, or default)
        local modelToUse = pattern.model or config.fabric.defaultModel or "gpt-4"

        -- Get the command to use (some patterns might use a different command)
        local commandToUse = pattern.command or pattern.id

        -- Build the fabric command
        local command = string.format('fabric --stream --pattern %s --model=%s', commandToUse, modelToUse)
        
        -- Add YouTube flag if it's a YouTube pattern
        if pattern.youtube then
            command = string.format('fabric -y "%s" --stream --pattern %s --model=%s', 
                clipboardContent, commandToUse, modelToUse)
        else
            -- Escape the content for shell
            local escapedContent = clipboardContent:gsub("'", "'\\''")
            command = string.format('%s <<EOF\n%s\nEOF', command, escapedContent)
        end

        hs.task.new("/bin/bash", function(exitCode, stdOut, stdErr)
            if exitCode == 0 then
                hs.pasteboard.setContents(stdOut)
                hs.timer.doAfter(0.1, function()
                    hs.eventtap.keyStroke({"cmd"}, "v")
                    hs.alert.show(pattern.name .. " completed")
                end)
            else
                hs.alert.show("Error processing text: " .. (stdErr or "Unknown error"))
            end
        end, {"-c", command}):start()
    end

    -- Bind shortcuts for all patterns
    for _, pattern in ipairs(config.fabric.patterns) do
        if pattern.shortcut then
            local mods, key = parseShortcut(pattern.shortcut)
            hs.hotkey.bind(mods, key, function()
                executeFabricPattern(pattern.id)
            end)
        end
    end

    -- Create choices for the chooser
    local choices = {}
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

    -- Add shortcut to show pattern chooser
    local chooserMods, chooserKey = parseShortcut(config.fabric.chooserShortcut)
    hs.hotkey.bind(chooserMods, chooserKey, function()
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
