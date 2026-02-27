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
            -- Check if it's a list (array-like)
            -- We assume if it has numeric keys 1..n (checked via #v > 0), it's a list
            -- This prevents merging lists index-by-index which corrupts data
            if #v > 0 then
                target[k] = v
            else
                -- If both values are tables (maps), merge them recursively
                target[k] = M.deepMerge(target[k], v)
            end
        else
            -- Otherwise just overwrite with source value
            target[k] = v
        end
    end
    
    return target
end

function M.getConfig()
    -- Load default configuration - fix path to not use dotted notation
    local ok, defaults = pcall(require, "config_defaults")
    if not ok then
        log.e("Failed to load config.defaults.lua: " .. tostring(defaults))
        defaults = {}
        M.usingNewConfigSystem = false
    else
        log.i("Default configuration loaded successfully")
        M.usingNewConfigSystem = true
    end
    
    -- Load user configuration - fix path to not use dotted notation
    local userOk, userConfig = pcall(require, "config_user")
    
    -- Check if we're using user config or fallback to old config
    if not userOk then
        -- Try loading from the old config.lua file
        local oldOk, oldConfig = pcall(require, "config")
        if oldOk then
            log.i("Found old config.lua file, using as user config")
            userConfig = oldConfig
            M.usingUserConfig = false
            return M.expandConfig(oldConfig) -- Use old config directly if new system isn't available
        else
            log.w("No user configuration found: " .. tostring(userConfig))
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
            log.e("Failed to load any configuration: " .. tostring(oldConfig))
            -- Create a minimal config to prevent nil errors
            return {
                applications = {},
                folders = {},
                triggers = {},
                shortcuts = {
                    general = {},
                    appShortcuts = {},
                    folderShortcuts = {},
                    windowManagement = {},
                    utils = {}
                },
                self = {
                    shortcuts = {}
                }
            }
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
        defaultEditor = config.defaultEditor,
        folders = config.folders,
        triggers = config.triggers,
        windowManagement = config.windowManagement,
        appManagement = config.appManagement,
        fabric = {
            defaultModel = config.fabric.defaultModel,
            patterns = {},
            chooserShortcut = nil,
            categories = config.fabric.categories
        },
        shortcuts = {
            appShortcuts = {},
            appGroupShortcuts = {},
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
        clipboard = config.clipboard,
        macros = config.macros,
        -- Add mouse speed finder configuration
        mousespeedfinder = config.mousespeedfinder,
        -- Add telemetry configuration
        telemetry = config.telemetry,
        -- Add app groups configuration
        appGroups = config.appGroups,
        -- Add kanata configuration
        kanata = config.kanata,
        -- Add click configuration
        click = config.click,
        -- Add debug configuration
        debug = config.debug
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

    -- Expand application shortcuts (primary layer)
    for _, shortcut in ipairs(config.shortcuts.apps) do
        expanded.shortcuts.appShortcuts[shortcut.app] = {
            mods = config.triggers.app,
            key = shortcut.key
        }
    end

    -- Expand application shortcuts (second layer)
    if config.shortcuts.apps2 and config.triggers.app2 then
        for _, shortcut in ipairs(config.shortcuts.apps2) do
            -- Allow overriding same app with different key in second layer
            local name = shortcut.app
            expanded.shortcuts.appShortcuts2 = expanded.shortcuts.appShortcuts2 or {}
            expanded.shortcuts.appShortcuts2[name] = {
                mods = config.triggers.app2,
                key = shortcut.key
            }
        end
    end

    -- Expand application group shortcuts
    if config.shortcuts.appGroups then
        log.i("Processing app group shortcuts from shortcuts.appGroups")
        for _, shortcut in ipairs(config.shortcuts.appGroups) do
            local groupName = shortcut.group
            local groupConfig = config.appGroups[groupName]
            if groupConfig then
                expanded.shortcuts.appGroupShortcuts[groupName] = {
                    mods = config.triggers.app,
                    key = shortcut.key,
                    groupConfig = groupConfig
                }
                log.d(string.format("Added app group shortcut: %s -> %s", groupName, shortcut.key))
            else
                log.w(string.format("App group '%s' referenced in shortcuts but not defined in appGroups", groupName))
            end
        end
    elseif config.appGroups then
        -- Fallback to old method for backward compatibility
        log.i("Processing app group shortcuts from appGroups (legacy method)")
        for groupName, groupConfig in pairs(config.appGroups) do
            if groupConfig.key then
                expanded.shortcuts.appGroupShortcuts[groupName] = {
                    mods = config.triggers.app,
                    key = groupConfig.key,
                    groupConfig = groupConfig
                }
                log.d(string.format("Added app group shortcut (legacy): %s -> %s", groupName, groupConfig.key))
            else
                log.w(string.format("App group '%s' has no key defined", groupName))
            end
        end
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
        
        local triggerName = shortcut.trigger
        
        -- Handle special cases for left/right specific window triggers
        if triggerName == "lwindow" or triggerName == "rwindow" then
            log.i("Using left/right specific trigger: " .. triggerName)
        elseif not config.triggers[triggerName] then
            log.e(string.format("No trigger found for '%s' in config.triggers", triggerName))
            goto continue
        end
        
        local mods = config.triggers[triggerName]
        if not mods then
            log.e(string.format("No modifiers defined for trigger '%s'", triggerName))
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
