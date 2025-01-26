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
    log.i("Starting config expansion")
    local expanded = {
        applications = config.applications,
        folders = config.folders,
        triggers = config.triggers,
        windowManagement = config.windowManagement,
        fabric = {
            defaultModel = config.fabric.defaultModel,
            patterns = {},
            chooserShortcut = nil,
            categories = config.fabric.categories
        },
        shortcuts = {
            appShortcuts = {},
            folderShortcuts = {},
            windowManagement = {},
            utils = {},
            general = {}  -- Initialize as empty table
        }
    }

    -- Process general shortcuts first
    if config.shortcuts.general then
        log.i("Processing general shortcuts: " .. hs.inspect(config.shortcuts.general))
        for _, shortcut in ipairs(config.shortcuts.general) do
            log.d(string.format("Adding general shortcut: action=%s, mods=%s, key=%s",
                shortcut.action,
                hs.inspect(shortcut.mods),
                shortcut.key))
            table.insert(expanded.shortcuts.general, {
                mods = shortcut.mods,
                key = shortcut.key,
                action = shortcut.action
            })
        end
    else
        log.w("No general shortcuts found in config")
    end

    -- Expand application shortcuts
    for _, shortcut in ipairs(config.shortcuts.apps) do
        expanded.shortcuts.appShortcuts[shortcut.app] = {
            mods = config.triggers.app,
            key = shortcut.key
        }
    end

    -- Expand folder shortcuts
    for _, shortcut in ipairs(config.shortcuts.folders) do
        expanded.shortcuts.folderShortcuts[shortcut.path] = {
            mods = shortcut.mods or config.triggers.folder,
            key = shortcut.key
        }
    end

    -- Expand window management shortcuts
    for name, shortcut in pairs(config.shortcuts.windows) do
        log.i(string.format("Expanding window shortcut '%s': trigger=%s, key=%s", 
            name, shortcut.trigger, shortcut.key))
        
        local mods = config.triggers[shortcut.trigger]
        if not mods then
            log.e(string.format("No trigger found for '%s' in config.triggers", shortcut.trigger))
            goto continue
        end
        
        expanded.shortcuts.windowManagement[name] = {
            mods = mods,
            key = shortcut.key
        }
        log.i(string.format("Expanded '%s' to: mods=%s, key=%s", 
            name, hs.inspect(mods), shortcut.key))
        
        ::continue::
    end

    log.i("Window management shortcuts expanded: " .. hs.inspect(expanded.shortcuts.windowManagement))

    -- Expand utility shortcuts
    if config.shortcuts.utils then
        for _, shortcut in ipairs(config.shortcuts.utils) do
            table.insert(expanded.shortcuts.utils, {
                mods = shortcut.mods,
                key = shortcut.key,
                action = shortcut.action
            })
        end
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
            variables = pattern.variables,
            shortcut = pattern.trigger and {
                mods = config.triggers[pattern.trigger],
                key = pattern.key
            } or nil
        }
        table.insert(expanded.fabric.patterns, expandedPattern)
    end

    -- Add fabric chooser shortcut
    if config.fabric.chooserTrigger then
        expanded.fabric.chooserShortcut = {
            mods = config.fabric.chooserTrigger,
            key = config.fabric.chooserKey
        }
    end

    return expanded
end

return M
