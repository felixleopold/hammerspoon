local M = {}
local log = hs.logger.new('Fabric', 'debug')
local setup = require("setup")

function M.setup()
    log.i("Setting up Fabric integration")

    local config = setup.getConfig()

    -- Helper function to execute Fabric patterns
    local function executeFabricPattern(pattern, model, isYouTube)
        local clipboardContent = hs.pasteboard.getContents()
        if not clipboardContent or clipboardContent == "" then
            hs.alert.show("Error: Clipboard is empty")
            return
        end

        -- Get the assigned model for the pattern, or use the specified model
        local assignedModel = config.fabric.patternModels[pattern] or model
        local modelToUse = config.fabric.models[assignedModel] or assignedModel

        local command
        if isYouTube then
            command = string.format('%s/go/bin/fabric -y "%s" --stream --pattern %s --model=%s', 
                                    os.getenv("HOME"), clipboardContent, pattern, modelToUse)
        else
            local escapedContent = clipboardContent:gsub("'", "'\\''")
            command = string.format('%s/go/bin/fabric --stream --pattern %s --model=%s <<EOF\n%s\nEOF', 
                                    os.getenv("HOME"), pattern, modelToUse, escapedContent)
        end

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
        { text = "Correct Text", subText = "Pattern: correct", command = "correct", model = config.fabric.models.default },
        { text = "Improve Text", subText = "Pattern: improve", command = "improve", model = config.fabric.models.default },
        { text = "Translate", subText = "Pattern: translate", command = "translate", model = config.fabric.models.default },
        { text = "Overview", subText = "Pattern: overview", command = "overview", model = config.fabric.models.default },
        { text = "LaTeX", subText = "Pattern: latex", command = "latex", model = config.fabric.models.default },
        { text = "LaTeX Plus", subText = "Pattern: latex-plus", command = "latex-plus", model = config.fabric.models.default },
        { text = "Note Name", subText = "Pattern: note_name", command = "note_name", model = config.fabric.models.default },
        { text = "General", subText = "Pattern: general", command = "general", model = config.fabric.models.default },
        -- YouTube patterns
        { text = "YT 5 Sentence Summary", subText = "Pattern: yt_create_5_sentence_summary", command = "yt_create_5_sentence_summary", model = config.fabric.models.default, isYouTube = true },
        { text = "YT Extract Wisdom", subText = "Pattern: yt_extract_wisdom", command = "yt_extract_wisdom", model = config.fabric.models.default, isYouTube = true },
        { text = "YT Summarize Lecture", subText = "Pattern: yt_summarize_lecture", command = "yt_summarize_lecture", model = config.fabric.models.default, isYouTube = true },
        { text = "YT Summarize Debate", subText = "Pattern: yt_summarize_debate", command = "yt_summarize_debate", model = config.fabric.models.default, isYouTube = true },
        { text = "YT Summarize", subText = "Pattern: yt_summarize", command = "yt_summarize", model = config.fabric.models.default, isYouTube = true },
        { text = "YT Extract Main Idea", subText = "Pattern: yt_extract_main_idea", command = "yt_extract_main_idea", model = config.fabric.models.default, isYouTube = true },
        { text = "YT Create Summary", subText = "Pattern: yt_create_summary", command = "yt_create_summary", model = config.fabric.models.default, isYouTube = true },
        { text = "YT Create Micro Summary", subText = "Pattern: yt_create_micro_summary", command = "yt_create_micro_summary", model = config.fabric.models.default, isYouTube = true },
    }

    -- Bind hotkeys for Fabric patterns
    hs.hotkey.bind({"ctrl", "alt"}, "I", function() executeFabricPattern("correct", config.fabric.models.default) end)
    hs.hotkey.bind({"ctrl", "alt"}, "O", function() executeFabricPattern("improve", config.fabric.models.default) end)
    hs.hotkey.bind({"ctrl", "alt"}, "E", function() executeFabricPattern("translate", config.fabric.models.default) end)
    hs.hotkey.bind({"ctrl", "alt"}, "L", function() executeFabricPattern("latex", config.fabric.models.default) end)
    hs.hotkey.bind({"ctrl", "alt"}, "P", function() executeFabricPattern("latex-plus", config.fabric.models.default) end)
    hs.hotkey.bind({"ctrl", "alt"}, "G", function() executeFabricPattern("general", config.fabric.models.default) end)
    hs.hotkey.bind({"ctrl", "alt"}, "N", function() executeFabricPattern("note_name", config.fabric.models.default) end)

    -- Add shortcut to show pattern chooser
    hs.hotkey.bind({"cmd", "alt", "shift"}, "P", function()
        local chooser = hs.chooser.new(function(choice)
            if choice then
                executeFabricPattern(choice.command, choice.model, choice.isYouTube)
            end
        end)

        chooser:choices(patterns)
        chooser:show()
    end)

    log.i("Fabric integration setup complete")
end

return M
