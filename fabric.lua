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
        local fabricPath = hs.execute("which fabric"):gsub("%s+", "")
        if fabricPath == "" then
            -- Try common installation paths
            local possiblePaths = {
                os.getenv("HOME") .. "/.local/bin/fabric",
                "/usr/local/bin/fabric",
                "/opt/homebrew/bin/fabric"
            }
            for _, path in ipairs(possiblePaths) do
                if hs.fs.attributes(path) then
                    fabricPath = path
                    break
                end
            end
            if fabricPath == "" then
                log.e("Could not find fabric executable")
                return
            end
        end
        
        -- Build the fabric command
        local command
        if pattern.youtube then
            -- For YouTube patterns, check if the URL is from a browser
            local browserApps = {
                config.applications.Browser,     -- Primary browser (Zen)
                config.applications.Browser2,    -- Secondary browser (Edge)
            }
            local url = clipboardContent
            local foundUrl = false

            for _, browserName in ipairs(browserApps) do
                local browser = hs.application.get(browserName)
                if browser then
                    -- Try to get URL from browser
                    browser:activate()
                    hs.timer.usleep(50000)
                    hs.eventtap.keyStroke({"cmd"}, "l")
                    hs.timer.usleep(50000)
                    hs.eventtap.keyStroke({"cmd"}, "c")
                    hs.timer.usleep(50000)
                    hs.eventtap.keyStroke({}, "escape")
                    local browserUrl = hs.pasteboard.getContents()
                    if browserUrl and browserUrl:match("^https?://") then
                        url = browserUrl
                        foundUrl = true
                        break
                    end
                end
            end

            if not foundUrl then
                -- If no URL found in browsers, use clipboard content
                url = clipboardContent
            end

            -- Escape the URL for shell
            url = url:gsub('"', '\\"')
            command = string.format('echo "%s" | %s -y --stream --pattern %s --model=%s', 
                url, fabricPath, commandToUse, modelToUse)
        else
            -- Escape the content for shell
            local escapedContent = clipboardContent:gsub('"', '\\"')
            command = string.format('echo "%s" | %s --stream --pattern %s --model=%s',
                escapedContent, fabricPath, commandToUse, modelToUse)
        end

        log.i("Executing command: " .. command)
        hs.task.new("/bin/bash", function(exitCode, stdOut, stdErr)
            if exitCode == 0 then
                hs.pasteboard.setContents(stdOut)
                hs.timer.doAfter(0.1, function()
                    hs.eventtap.keyStroke({"cmd"}, "v")
                    log.i(pattern.name .. " completed")
                end)
            else
                log.e("Error processing text: " .. (stdErr or "Unknown error"))
            end
        end, {"-c", command}):start()
    end

    -- Bind shortcuts for all patterns
    for _, pattern in ipairs(config.fabric.patterns) do
        if pattern.shortcut then
            log.i("Setting up fabric pattern shortcut: " .. pattern.id .. " with " .. hs.inspect(pattern.shortcut))
            hs.hotkey.bind(pattern.shortcut.mods, pattern.shortcut.key, function()
                log.i("Executing fabric pattern: " .. pattern.id)
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
