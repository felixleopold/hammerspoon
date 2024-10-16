local M = {}
local log = hs.logger.new('Fabric', 'debug')

-- Function to unescape HTML entities
local function unescapeHtml(str)
    if not str then return "" end
    return str:gsub("&#(%d+);", function(n) return string.char(n) end)
                :gsub("&quot;", '"')
                :gsub("&apos;", "'")
                :gsub("&lt;", "<")
                :gsub("&gt;", ">")
                :gsub("&amp;", "&")
end

-- Function to execute a pattern
local function executePattern(pattern, model, userPath)
    local clipboardContent = hs.pasteboard.getContents()
    if not clipboardContent or clipboardContent == "" then
        hs.alert.show("Error: Clipboard is empty")
        return
    end

    local escapedContent = clipboardContent:gsub("'", "'\\''")
    local command
    if pattern:sub(1, 3) == "yt_" then
        command = string.format('%s/go/bin/fabric -y "%s" --pattern %s --model=%s', userPath, escapedContent, pattern, model)
    else
        command = string.format('%s/go/bin/fabric --stream --pattern %s --model=%s <<EOF\n%s\nEOF', userPath, pattern, model, escapedContent)
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

-- Define patterns
local patterns = {
    { text = "Correct Text", subText = "Pattern: correct (Model: gpt-4o-mini)", command = "correct", model = "gpt-4o-mini" },
    { text = "Improve Text", subText = "Pattern: improve (Model: gpt-4o-mini)", command = "improve", model = "gpt-4o-mini" },
    { text = "Translate", subText = "Pattern: translate (Model: gpt-4o)", command = "translate", model = "gpt-4o" },
    { text = "Overview", subText = "Pattern: overview (Model: llama-3.1-70b-versatile)", command = "overview", model = "llama-3.1-70b-versatile" },
    { text = "LaTeX", subText = "Pattern: latex (Model: gpt-4o)", command = "latex", model = "gpt-4o" },
    { text = "LaTeX Plus", subText = "Pattern: latex-plus (Model: gpt-4o)", command = "latex-plus", model = "gpt-4o" },
    { text = "Note Name", subText = "Pattern: note_name (Model: llama-3.1-70b-versatile)", command = "note_name", model = "llama-3.1-70b-versatile" },
    { text = "General", subText = "Pattern: general (Model: gpt-4o)", command = "general", model = "gpt-4o" },
    { text = "YT Summarize", subText = "Pattern: yt_summarize (Model: llama-3.1-70b-versatile)", command = "yt_summarize", model = "llama-3.1-70b-versatile" },
    { text = "YT Summarize Debate", subText = "Pattern: yt_summarize_debate (Model: llama-3.1-70b-versatile)", command = "yt_summarize_debate", model = "llama-3.1-70b-versatile" },
    { text = "YT Summarize Lecture", subText = "Pattern: yt_summarize_lecture (Model: llama-3.1-70b-versatile)", command = "yt_summarize_lecture", model = "llama-3.1-70b-versatile" },
    { text = "YT Create 5 Sentence Summary", subText = "Pattern: yt_create_5_sentence_summary (Model: llama-3.1-70b-versatile)", command = "yt_create_5_sentence_summary", model = "llama-3.1-70b-versatile" },
    { text = "YT Create Micro Summary", subText = "Pattern: yt_create_micro_summary (Model: llama-3.1-70b-versatile)", command = "yt_create_micro_summary", model = "llama-3.1-70b-versatile" },
    { text = "YT Create Summary", subText = "Pattern: yt_create_summary (Model: llama-3.1-70b-versatile)", command = "yt_create_summary", model = "llama-3.1-70b-versatile" },
    { text = "YT Extract Wisdom", subText = "Pattern: yt_extract_wisdom (Model: llama-3.1-70b-versatile)", command = "yt_extract_wisdom", model = "llama-3.1-70b-versatile" },
    { text = "YT Extract Main Idea", subText = "Pattern: yt_extract_main_idea (Model: llama-3.1-70b-versatile)", command = "yt_extract_main_idea", model = "llama-3.1-70b-versatile" },
    { text = "Create Sticky Note", subText = "Pattern: sticky_note (Model: gpt-4o-mini)", command = "sticky_note", model = "gpt-4o-mini" },
}

-- Initialize chooser
local chooser = hs.chooser.new(function(choice)
    if choice then
        executePattern(choice.command, choice.model, os.getenv("HOME"))
    end
end)

chooser:choices(patterns)
chooser:placeholderText("Select a pattern")

function M.setup(userPath, sharedConfigPath)
    log.i("Setting up Fabric shortcuts")

    -- Shortcut for Correct Text (Ctrl + Alt + I)
    hs.hotkey.bind({"ctrl", "alt"}, "I", function()
        executePattern("correct", "gpt-4o-mini", userPath)
    end)

    -- Shortcut for Improve Text (Ctrl + Alt + O)
    hs.hotkey.bind({"ctrl", "alt"}, "O", function()
        executePattern("improve", "gpt-4o-mini", userPath)
    end)

    -- Shortcut for Translate (Ctrl + Alt + E)
    hs.hotkey.bind({"ctrl", "alt"}, "E", function()
        executePattern("translate", "gpt-4o", userPath)
    end)

    -- Shortcut for LaTeX (Ctrl + Alt + L)
    hs.hotkey.bind({"ctrl", "alt"}, "L", function()
        executePattern("latex", "gpt-4o", userPath)
    end)

    -- Shortcut for LaTeX Plus (Ctrl + Alt + P)
    hs.hotkey.bind({"ctrl", "alt"}, "P", function()
        executePattern("latex-plus", "gpt-4o", userPath)
    end)

    -- Shortcut for General Pattern (Ctrl + Alt + G)
    hs.hotkey.bind({"ctrl", "alt"}, "G", function()
        executePattern("general", "gpt-4o", userPath)
    end)

    -- Shortcut for Note Name (Ctrl + Alt + N)
    hs.hotkey.bind({"ctrl", "alt"}, "N", function()
        executePattern("note_name", "llama-3.1-70b-versatile", userPath)
    end)

    -- Shortcut to show pattern chooser (Cmd + Alt + Shift + P)
    hs.hotkey.bind({"cmd", "alt", "shift"}, "P", function()
        chooser:show()
    end)

    log.i("Fabric shortcuts setup complete")
end

return M
