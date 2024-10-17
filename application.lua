local M = {}
local log = hs.logger.new('Applications', 'debug')
local setup = require("setup")

-- Enable Spotlight for name searches to improve application finding
hs.application.enableSpotlightForNameSearches(true)

function M.setup()
    log.i("Setting up application shortcuts")

    local config = setup.getConfig()
    log.d("Loaded configuration: " .. hs.inspect(config))

    -- Helper function to launch or focus applications
    local function launchOrFocus(appName)
        log.i("Attempting to launch or focus: " .. appName)
        
        -- Special handling for browsers
        if appName == config.applications.primaryBrowser or appName == config.applications.secondaryBrowser then
            local app = hs.application.get(appName)
            if app then
                log.i(appName .. " is already running, focusing it")
                app:activate()
            else
                log.i(appName .. " is not running, launching it")
                hs.application.open(appName, 0, true)
            end
        else
            -- For other applications, use the standard launchOrFocus
            hs.application.launchOrFocus(appName)
        end
        
        -- Verify frontmost application after a short delay
        hs.timer.doAfter(0.5, function()
            local frontApp = hs.application.frontmostApplication()
            if frontApp and frontApp:name() == appName then
                log.i(appName .. " is now the frontmost application")
            else
                log.w(appName .. " is not the frontmost application. Current frontmost: " .. (frontApp and frontApp:name() or "None"))
            end
        end)
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

    -- Set up folder shortcuts
    log.i("Setting up folder shortcuts")
    for name, path in pairs(config.folders) do
        local shortcutKey = name:lower()  -- Convert folder name to lowercase for matching
        local shortcut = config.shortcuts.folderShortcuts[shortcutKey]
        if shortcut then
            log.d("Setting up folder shortcut for " .. name .. ": " .. hs.inspect(shortcut) .. " to open " .. path)
            bindHotkey(shortcut, function() 
                log.i("Attempting to open folder: " .. name .. " at path: " .. path)
                local expandedPath = hs.fs.pathToAbsolute(path)
                if not expandedPath then
                    log.e("Failed to expand path for folder: " .. name .. ". Path: " .. path)
                    return
                end
                local command = string.format('/usr/bin/open "%s"', expandedPath:gsub('"', '\\"'))
                local output, status, type, rc = hs.execute(command)
                if status then
                    log.i("Successfully opened folder: " .. name)
                else
                    log.e("Failed to open folder: " .. name .. ". Error: " .. tostring(output) .. " (RC: " .. tostring(rc) .. ")")
                end
            end)
        else
            log.w("No shortcut defined for folder: " .. name .. ". Available shortcuts: " .. hs.inspect(config.shortcuts.folderShortcuts))
        end
    end

    -- Set up application shortcuts
    log.i("Setting up application shortcuts")
    for name, shortcut in pairs(config.shortcuts.appShortcuts) do
        local app
        if name == "primaryBrowser" or name == "secondaryBrowser" or name == "terminal" or name == "editor" then
            app = config.applications[name]
        else
            app = name:gsub("^%l", string.upper)
        end
        log.d("Setting up shortcut for " .. name .. ": " .. hs.inspect(shortcut) .. " to launch " .. app)
        bindHotkey(shortcut, function() launchOrFocus(app) end)
    end

    -- Set up URL copying shortcut
    log.i("Setting up URL copying shortcut")
    bindHotkey(config.shortcuts.general.copyUrl, function()
        local browser = hs.application.get(config.applications.primaryBrowser) or 
                        hs.application.get(config.applications.secondaryBrowser)
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
    end)

    log.i("Application shortcuts setup complete")
end

return M
