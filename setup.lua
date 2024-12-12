local M = {}
local log = hs.logger.new('Setup', 'debug')

function M.getConfig()
    local ok, config = pcall(require, "config")
    if ok then
        log.i("Configuration loaded successfully")
        return M.expandConfig(config)
    else
        log.e("Failed to load config.lua")
        hs.alert.show("Error: Failed to load config.lua")
        return {}
    end
end

-- Expand the simplified config into the format expected by the modules
function M.expandConfig(config)
    local expanded = {
        applications = {},
        folders = {},
        shortcuts = {
            appShortcuts = {},
            folderShortcuts = {},
            general = {},
            windowManagement = {},
        },
        windowManagement = {
            animationDuration = config.windowAnimation or 0
        }
    }

    -- Expand applications
    for name, app in pairs(config.apps) do
        expanded.applications[name:gsub("^%l", string.upper)] = app
    end

    -- Expand folders
    for name, path in pairs(config.folders) do
        expanded.folders[name:gsub("^%l", string.upper)] = path
    end

    -- Expand app shortcuts
    for _, shortcut in ipairs(config.keys.apps) do
        expanded.shortcuts.appShortcuts[shortcut.app] = {"ctrl", "alt", "cmd", shortcut.key}
    end

    -- Expand folder shortcuts
    for _, shortcut in ipairs(config.keys.folders) do
        expanded.shortcuts.folderShortcuts[shortcut.path] = {"cmd", "shift", shortcut.key}
    end

    -- Expand window management shortcuts
    for name, shortcut in pairs(config.keys.windows) do
        expanded.shortcuts.windowManagement[name] = shortcut.mods or {}
        table.insert(expanded.shortcuts.windowManagement[name], shortcut.key)
    end

    -- Add URL copying shortcut
    if config.keys.copyUrl then
        expanded.shortcuts.general.copyUrl = config.keys.copyUrl.mods or {}
        table.insert(expanded.shortcuts.general.copyUrl, config.keys.copyUrl.key)
    end

    return expanded
end

return M
