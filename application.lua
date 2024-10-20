local M = {}
local log = hs.logger.new('Applications', 'debug')
local setup = require("setup")

function M.setup(config)
    log.i("Setting up application shortcuts")
    log.d("Loaded configuration: " .. hs.inspect(config))

    -- Helper function to launch or focus applications
    local function launchOrFocus(appName)
        log.i("Attempting to launch or focus: " .. appName)
        hs.application.launchOrFocus(appName)
    end

    -- Helper function to bind hotkey
    local function bindHotkey(shortcut, callback)
        if type(shortcut) ~= "table" or #shortcut < 2 then
            log.w("Invalid shortcut configuration: " .. hs.inspect(shortcut))
            return
        end
        local modifiers = {}
        for i = 1, #shortcut - 1 do
            table.insert(modifiers, shortcut[i])
        end
        local key = shortcut[#shortcut]
        log.d("Binding hotkey: " .. hs.inspect(modifiers) .. " + " .. key)
        hs.hotkey.bind(modifiers, key, callback)
    end

    -- Set up application shortcuts
    for name, shortcut in pairs(config.shortcuts.appShortcuts) do
        local appName = config.applications[name]
        if appName then
            log.d("Setting up shortcut for " .. name .. ": " .. hs.inspect(shortcut) .. " to launch " .. appName)
            bindHotkey(shortcut, function() launchOrFocus(appName) end)
        else
            log.w("No application defined for shortcut: " .. name .. ". Please check your user_config.json file.")
        end
    end

    -- Set up folder shortcuts
    for name, shortcut in pairs(config.shortcuts.folderShortcuts) do
        local path = config.folders[name:gsub("^%l", string.upper)]
        if path then
            -- Expand the path if it starts with "~"
            if path:sub(1,1) == "~" then
                path = os.getenv("HOME") .. path:sub(2)
            end
            log.d("Setting up folder shortcut for " .. name .. ": " .. hs.inspect(shortcut) .. " to open " .. path)
            bindHotkey(shortcut, function()
                if hs.fs.attributes(path) then
                    hs.execute(string.format('/usr/bin/open "%s"', path))
                else
                    log.w("Folder does not exist: " .. path)
                    hs.alert.show("Folder does not exist: " .. path)
                end
            end)
        else
            log.w("No path defined for folder: " .. name .. ". Please check your user_config.json file.")
        end
    end

    -- Set up URL copying shortcut
    if config.shortcuts.general and config.shortcuts.general.copyUrl then
        bindHotkey(config.shortcuts.general.copyUrl, function()
            local browsers = {config.applications.PrimaryBrowser, config.applications.SecondaryBrowser}
            for _, browserName in ipairs(browsers) do
                local browser = hs.application.get(browserName)
                if browser then
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
                        return
                    end
                end
            end
            log.e("Failed to copy URL from browser")
        end)
    else
        log.w("No copyUrl shortcut defined in general shortcuts. Please check your user_config.json file.")
    end

    log.i("Application shortcuts setup complete")
end

return M
