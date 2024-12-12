local M = {}
local log = hs.logger.new('Setup', 'debug')

function M.getConfig()
    local ok, config = pcall(require, "config")
    if ok then
        log.i("Configuration loaded successfully")
        return M.expandConfig(config)
    else
        log.e("Failed to load config.lua")
        return {}
    end
end

-- Expand the simplified config into the format expected by the modules
function M.expandConfig(config)
    local expanded = {
        applications = config.applications,
        folders = config.folders,
        shortcuts = {
            appShortcuts = {},
            folderShortcuts = {},
            general = {},
            windowManagement = {},
        },
        windowManagement = {
            animationDuration = config.windowAnimation or 0
        },
        fabric = {
            defaultModel = config.fabric.defaultModel,
            patterns = {},
            categories = config.fabric.categories,
        }
    }

    -- Expand app shortcuts
    for _, shortcut in ipairs(config.shortcuts.apps) do
        expanded.shortcuts.appShortcuts[shortcut.app] = {
            mods = config.triggers.app,
            key = shortcut.key
        }
    end

    -- Expand folder shortcuts
    for _, shortcut in ipairs(config.shortcuts.folders) do
        expanded.shortcuts.folderShortcuts[shortcut.path] = {
            mods = config.triggers.folder,
            key = shortcut.key
        }
    end

    -- Expand window management shortcuts
    for name, shortcut in pairs(config.shortcuts.windows) do
        expanded.shortcuts.windowManagement[name] = {
            mods = config.triggers[shortcut.trigger],
            key = shortcut.key
        }
    end

    -- Expand fabric patterns
    for _, pattern in ipairs(config.fabric.patterns) do
        local expandedPattern = {
            id = pattern.id,
            name = pattern.name,
            desc = pattern.desc,
            command = pattern.command,
            model = pattern.model,
            youtube = pattern.youtube,
            shortcut = {
                mods = config.triggers[pattern.trigger],
                key = pattern.key
            }
        }
        table.insert(expanded.fabric.patterns, expandedPattern)
    end

    -- Add fabric chooser shortcut
    expanded.fabric.chooserShortcut = {
        mods = config.fabric.chooserTrigger,
        key = config.fabric.chooserKey
    }

    return expanded
end

return M
