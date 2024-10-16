local M = {}
local log = hs.logger.new('Fabric', 'debug')
local setup = require("setup")

function M.setup()
    log.i("Setting up Fabric integration")

    local config = setup.getConfig()

    -- Helper function to execute Fabric patterns
    local function executeFabricPattern(pattern, model)
        local clipboardContent = hs.pasteboard.getContents()
        if not clipboardContent or clipboardContent == "" then
            hs.alert.show("Error: Clipboard is empty")
            return
        end

        local escapedContent = clipboardContent:gsub("'", "'\\''")
        local command = string.format('%s/go/bin/fabric --stream --pattern %s --model=%s <<EOF\n%s\nEOF', os.getenv("HOME"), pattern, model, escapedContent)

        hs.task.new("/bin/bash", function(exitCode, stdOut, stdErr)
            if exitCode == 0 then
                hs.pasteboard.setContents(stdOut)
                hs.timer.doAfter(0.1, function()
                    hs.eventtap.keyStroke({"cmd"}, "v")
                    hs.alert.show("Text processed and pasted")
                end)
            else
                hs.alert.show("Error processing text: " .. (stdErr or "Unknown error"))
            end
        end, {"-c", command}):start()
    end

    -- Define Fabric patterns
    local patterns = {
        { text = "Correct Text", subText = "Pattern: correct", command = "correct", model = config.fabric.model },
        { text = "Improve Text", subText = "Pattern: improve", command = "improve", model = config.fabric.model },
        { text = "Translate", subText = "Pattern: translate", command = "translate", model = config.fabric.model },
        { text = "Overview", subText = "Pattern: overview", command = "overview", model = config.fabric.model },
        { text = "LaTeX", subText = "Pattern: latex", command = "latex", model = config.fabric.model },
        { text = "LaTeX Plus", subText = "Pattern: latex-plus", command = "latex-plus", model = config.fabric.model },
        { text = "Note Name", subText = "Pattern: note_name", command = "note_name", model = config.fabric.model },
        { text = "General", subText = "Pattern: general", command = "general", model = config.fabric.model },
    }

    -- Bind hotkeys for Fabric patterns
    hs.hotkey.bind({"ctrl", "alt"}, "I", function() executeFabricPattern("correct", config.fabric.model) end)
    hs.hotkey.bind({"ctrl", "alt"}, "O", function() executeFabricPattern("improve", config.fabric.model) end)
    hs.hotkey.bind({"ctrl", "alt"}, "E", function() executeFabricPattern("translate", config.fabric.model) end)
    hs.hotkey.bind({"ctrl", "alt"}, "L", function() executeFabricPattern("latex", config.fabric.model) end)
    hs.hotkey.bind({"ctrl", "alt"}, "P", function() executeFabricPattern("latex-plus", config.fabric.model) end)
    hs.hotkey.bind({"ctrl", "alt"}, "G", function() executeFabricPattern("general", config.fabric.model) end)
    hs.hotkey.bind({"ctrl", "alt"}, "N", function() executeFabricPattern("note_name", config.fabric.model) end)

    -- Add shortcut to show pattern chooser
    hs.hotkey.bind({"cmd", "alt", "shift"}, "P", function()
        local chooser = hs.chooser.new(function(choice)
            if choice then
                executeFabricPattern(choice.command, choice.model)
            end
        end)

        chooser:choices(patterns)
        chooser:show()
    end)

    log.i("Fabric integration setup complete")
end

return M
