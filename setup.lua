local M = {}
local log = hs.logger.new('Setup', 'debug')

-- Initialize configuration tracking flags
M.usingNewConfigSystem = false
M.usingUserConfig = false

-- Deep merge function to combine tables
function M.deepMerge(target, source)
    if type(target) ~= 'table' or type(source) ~= 'table' then
        return source
    end
    
    for k, v in pairs(source) do
        if type(v) == 'table' and type(target[k]) == 'table' then
            -- If both values are tables, merge them recursively
            target[k] = M.deepMerge(target[k], v)
        else
            -- Otherwise just overwrite with source value
            target[k] = v
        end
    end
    
    return target
end

function M.getConfig()
    -- Load default configuration
    local ok, defaults = pcall(require, "config.defaults")
    if not ok then
        log.e("Failed to load config.defaults.lua")
        defaults = {}
        M.usingNewConfigSystem = false
    else
        log.i("Default configuration loaded successfully")
        M.usingNewConfigSystem = true
    end
    
    -- Load user configuration
    local userOk, userConfig = pcall(require, "config.user")
    
    -- Check if we're using user config or fallback to old config
    if not userOk then
        -- Try loading from the old config.lua file
        local oldOk, oldConfig = pcall(require, "config")
        if oldOk then
            log.i("Found old config.lua file, using as user config")
            userConfig = oldConfig
            M.usingUserConfig = false
        else
            log.w("No user configuration found")
            userConfig = {}
            M.usingUserConfig = false
        end
    else
        log.i("User configuration loaded successfully")
        M.usingUserConfig = true
    end
    
    -- If we're not using the new config system, fall back to old method
    if not M.usingNewConfigSystem then
        local oldOk, oldConfig = pcall(require, "config")
        if oldOk then
            log.i("Using legacy configuration system with config.lua")
            return M.expandConfig(oldConfig)
        else
            log.e("Failed to load any configuration")
            return {}
        end
    end
    
    -- Merge configurations, with user config taking precedence
    local mergedConfig = M.deepMerge(hs.fnutils.copy(defaults), userConfig)
    
    return M.expandConfig(mergedConfig)
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
        },
        -- Add self configuration section
        self = {
            triggers = config.self and config.self.triggers or {},
            shortcuts = {}
        },
        -- Include Minecraft configuration
        minecraft = config.minecraft,
        -- Add clipboard configuration
        clipboard = config.clipboard
    }

    -- Process self-organized shortcuts
    if config.self and config.self.shortcuts then
        log.i("Processing self-organized shortcuts")
        for _, shortcut in ipairs(config.self.shortcuts) do
            log.d(string.format("Adding self shortcut: name=%s, mods=%s, key=%s",
                shortcut.name,
                hs.inspect(shortcut.mods),
                shortcut.key))
            
            -- Copy the shortcut configuration directly
            -- This preserves all properties needed by self.lua
            table.insert(expanded.self.shortcuts, {
                name = shortcut.name,
                desc = shortcut.desc,
                mods = shortcut.mods,
                key = shortcut.key
            })
        end
    else
        log.w("No self-organized shortcuts found in config")
    end

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
