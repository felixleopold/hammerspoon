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

-- Helper function to convert shortcut string to modifiers and key
local function parseShortcut(shortcutStr)
    local mods = {}
    local parts = {}
    for part in shortcutStr:gmatch("[^+]+") do
        table.insert(parts, part:lower())
    end
    local key = parts[#parts]
    for i = 1, #parts - 1 do
        table.insert(mods, parts[i])
    end
    return mods, key:upper()
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
        },
        -- Include fabric configuration directly
        fabric = config.fabric
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
    for name, shortcutStr in pairs(config.windows) do
        local mods, key = parseShortcut(shortcutStr)
        expanded.shortcuts.windowManagement[name] = mods
        table.insert(expanded.shortcuts.windowManagement[name], key)
    end

    -- Convert fabric shortcuts to the expanded format
    if expanded.fabric and expanded.fabric.patterns then
        for _, pattern in ipairs(expanded.fabric.patterns) do
            if pattern.shortcut then
                local mods, key = parseShortcut(pattern.shortcut)
                pattern.shortcut = {
                    mods = mods,
                    key = key
                }
            end
        end
    end

    return expanded
end

return M
