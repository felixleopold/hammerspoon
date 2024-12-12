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
        if type(shortcut) ~= "table" or not shortcut.mods or not shortcut.key then
            log.w("Invalid shortcut configuration: " .. hs.inspect(shortcut))
            return
        end
        log.d("Binding hotkey: " .. hs.inspect(shortcut.mods) .. " + " .. shortcut.key)
        hs.hotkey.bind(shortcut.mods, shortcut.key, callback)
    end

    -- Helper function to expand path
    local function expandPath(path)
        if not path then return nil end
        
        -- Replace ~ with HOME environment variable
        if path:sub(1,1) == "~" then
            path = os.getenv("HOME") .. path:sub(2)
        end
        
        -- Convert to absolute path
        local absolutePath = hs.fs.pathToAbsolute(path)
        if not absolutePath then
            log.w("Could not resolve path: " .. path)
            return path
        end
        return absolutePath
    end

    -- Set up application shortcuts
    for name, shortcut in pairs(config.shortcuts.appShortcuts) do
        local appName = config.applications[name]
        if appName then
            log.i("Setting up shortcut for " .. name .. ": " .. hs.inspect(shortcut) .. " to launch " .. appName)
            bindHotkey(shortcut, function() 
                log.i("Launching " .. appName .. " via shortcut " .. hs.inspect(shortcut))
                launchOrFocus(appName)
            end)
        else
            log.w("No application defined for shortcut: " .. name .. ". Please check your configuration.")
        end
    end

    -- Set up folder shortcuts
    for name, shortcut in pairs(config.shortcuts.folderShortcuts) do
        local path = config.folders[name]
        if path then
            path = expandPath(path)
            log.d("Setting up folder shortcut for " .. name .. ": " .. hs.inspect(shortcut) .. " to open " .. path)
            bindHotkey(shortcut, function()
                if hs.fs.attributes(path) then
                    hs.execute(string.format('/usr/bin/open "%s"', path))
                else
                    log.w("Folder does not exist: " .. path)
                end
            end)
        else
            log.w("No path defined for folder: " .. name .. ". Please check your configuration.")
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
