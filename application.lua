local M = {}
local log = hs.logger.new('Applications', 'debug')
local setup = require("setup")

function M.setup()
    log.i("Setting up application shortcuts")

    local config = setup.getConfig()

    -- Helper function to open folders
    local function openFolder(path)
        hs.execute("open " .. path)
    end

    -- Helper function to launch or focus applications
    local function launchOrFocus(appName)
        hs.application.launchOrFocus(appName)
    end

    -- Folder shortcuts
    hs.hotkey.bind({"cmd", "shift"}, "D", function() openFolder(os.getenv("HOME") .. "/Desktop") end)
    hs.hotkey.bind({"cmd", "shift"}, "R", function() openFolder(config.folders.radboud) end)
    hs.hotkey.bind({"cmd", "shift"}, "A", function() openFolder("/Applications") end)
    hs.hotkey.bind({"cmd", "shift"}, "L", function() openFolder(os.getenv("HOME") .. "/Downloads") end)
    hs.hotkey.bind({"cmd", "shift"}, "H", function() openFolder(os.getenv("HOME")) end)
    hs.hotkey.bind({"cmd", "shift"}, "O", function() openFolder(config.folders.obsidian) end)
    hs.hotkey.bind({"cmd", "shift"}, "F", function() openFolder(os.getenv("HOME") .. "/Documents") end)

    -- Application shortcuts
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "P", function() launchOrFocus("System Settings") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "A", function() launchOrFocus(config.applications.secondaryBrowser) end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "Z", function() launchOrFocus(config.applications.primaryBrowser) end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "T", function() launchOrFocus(config.applications.terminal) end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "S", function() launchOrFocus("Spotify") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "M", function() launchOrFocus("Mail") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "O", function() launchOrFocus("Obsidian") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "W", function() launchOrFocus("WhatsApp") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "F", function() launchOrFocus("Finder") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "V", function() launchOrFocus(config.applications.editor) end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "C", function() launchOrFocus("Cursor") end)

    -- Copy URL function
    local function copyBrowserURL()
        local primaryBrowser = hs.application.find(config.applications.primaryBrowser)
        local secondaryBrowser = hs.application.find(config.applications.secondaryBrowser)
        local browser = primaryBrowser or secondaryBrowser

        if not browser then
            log.w("No configured browser is running")
            return
        end

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
        else
            log.e("Failed to copy URL from browser")
        end
    end

    -- Ensure config.shortcuts.copyUrl is a valid hotkey configuration
    local copyUrlShortcut = config.shortcuts.copyUrl
    if type(copyUrlShortcut) ~= "table" or #copyUrlShortcut < 2 then
        log.w("Invalid copyUrl shortcut configuration, using default")
        copyUrlShortcut = {"cmd", "shift", "C"}
    end

    -- Ensure the last element of the shortcut is a string (the key)
    if type(copyUrlShortcut[#copyUrlShortcut]) ~= "string" then
        log.w("Invalid key in copyUrl shortcut, using default")
        copyUrlShortcut[#copyUrlShortcut] = "C"
    end

    -- Extract modifiers and key
    local modifiers = {}
    for i = 1, #copyUrlShortcut - 1 do
        table.insert(modifiers, copyUrlShortcut[i])
    end
    local key = copyUrlShortcut[#copyUrlShortcut]

    -- Bind the copyBrowserURL function to the shortcut
    hs.hotkey.bind(modifiers, key, copyBrowserURL)

    log.i("Application shortcuts setup complete")
end

return M
