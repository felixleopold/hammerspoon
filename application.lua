local M = {}
local log = hs.logger.new('Applications', 'debug')

function M.setup(userPath, sharedConfigPath)
    log.i("Setting up application shortcuts")

    -- Helper function to open folders
    local function openFolder(path)
        hs.execute("open " .. path)
    end

    -- Helper function to launch or focus applications
    local function launchOrFocus(appName)
        hs.application.launchOrFocus(appName)
    end

    -- Folder shortcuts
    hs.hotkey.bind({"cmd", "shift"}, "D", function() openFolder(userPath .. "/Desktop") end)
    hs.hotkey.bind({"cmd", "shift"}, "R", function() openFolder(userPath .. "/Documents/Radboud") end)
    hs.hotkey.bind({"cmd", "shift"}, "A", function() openFolder("/Applications") end)
    hs.hotkey.bind({"cmd", "shift"}, "L", function() openFolder(userPath .. "/Downloads") end)
    hs.hotkey.bind({"cmd", "shift"}, "H", function() openFolder(userPath) end)
    hs.hotkey.bind({"cmd", "shift"}, "O", function()
        hs.execute([[open "]] .. userPath .. [[/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyBrain"]])
    end)
    hs.hotkey.bind({"cmd", "shift"}, "F", function() openFolder(userPath .. "/Documents") end)

    -- Application shortcuts
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "P", function() launchOrFocus("System Settings") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "A", function() launchOrFocus("Arc") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "Z", function() launchOrFocus("Zen Browser") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "T", function() launchOrFocus("Warp") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "S", function() launchOrFocus("Spotify") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "M", function() launchOrFocus("Mail") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "O", function() launchOrFocus("Obsidian") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "W", function() launchOrFocus("WhatsApp") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "F", function() launchOrFocus("Finder") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "V", function() launchOrFocus("Visual Studio Code") end)
    hs.hotkey.bind({"ctrl", "alt", "cmd"}, "C", function() launchOrFocus("Cursor") end)
    
    -- Updated function to copy URL from Zen Browser quickly and silently
    local function copyZenBrowserURL()
        local zenBrowser = hs.application.find("Zen Browser")
        if not zenBrowser then
            log.w("Zen Browser is not running")
            return
        end

        zenBrowser:activate()
        hs.timer.usleep(50000) -- Wait for 0.05 seconds

        -- Simulate Cmd+L to focus on the address bar
        hs.eventtap.keyStroke({"cmd"}, "l")
        hs.timer.usleep(50000) -- Wait for 0.05 seconds

        -- Simulate Cmd+C to copy the URL
        hs.eventtap.keyStroke({"cmd"}, "c")
        hs.timer.usleep(50000) -- Wait for 0.05 seconds

        -- Simulate Esc to close the address bar
        hs.eventtap.keyStroke({}, "escape")

        local url = hs.pasteboard.getContents()
        if url and url:match("^https?://") then
            log.i("Copied URL: " .. url)
        else
            log.e("Failed to copy URL from Zen Browser")
        end
    end

    -- Add the new shortcut
    hs.hotkey.bind({"cmd", "shift"}, "C", copyZenBrowserURL)

    log.i("Application shortcuts setup complete")
end

return M
