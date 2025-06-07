-- Module for distinguishing between left and right modifier keys
local M = {}
local log = hs.logger.new('LeftRightModifier', 'debug')

-- Constants for modifier keys
local MODIFIER_FLAGS = {
    lctrl  = 0x00000001,
    lshift = 0x00000002,
    lalt   = 0x00000020,
    lcmd   = 0x00000008,
    rshift = 0x00000004,
    ralt   = 0x00000040,
    rcmd   = 0x00000010,
    rctrl  = 0x00002000,
}

-- For backward compatibility with regular modifier strings
local MODIFIER_MAP = {
    -- Regular modifiers to check
    ctrl = {"lctrl", "rctrl"},
    shift = {"lshift", "rshift"},
    alt = {"lalt", "ralt"},
    cmd = {"lcmd", "rcmd"},
    
    -- Specific side modifiers
    lctrl = {"lctrl"},
    lshift = {"lshift"},
    lalt = {"lalt"},
    lcmd = {"lcmd"},
    rctrl = {"rctrl"},
    rshift = {"rshift"},
    ralt = {"ralt"},
    rcmd = {"rcmd"},
}

-- Store active hotkeys
local hotkeys = {}
-- Store active eventtap
local flagsChangedTap = nil
-- Store the eventtap for key events
local keyTap = nil
-- Store currently active modifiers
local activeModifiers = {}
-- Store key handlers
local keyHandlers = {}

-- Helper function to check if all required modifiers are active
local function checkModifiers(requiredMods)
    -- Check if all the required modifiers are currently active
    for _, mod in ipairs(requiredMods) do
        local matched = false
        
        -- Get the list of flags to check for this modifier
        local flagsToCheck = MODIFIER_MAP[mod]
        if not flagsToCheck then
            log.w("Unknown modifier: " .. mod)
            return false
        end
        
        -- Check if any of the corresponding flags are active
        for _, flag in ipairs(flagsToCheck) do
            if activeModifiers[flag] then
                matched = true
                break
            end
        end
        
        if not matched then
            log.d("Required modifier " .. mod .. " not active, skipping")
            return false
        end
    end
    
    return true
end

-- Helper function to check if ONLY the required modifiers are active (no extras)
local function checkExactModifiers(requiredMods)
    -- First check if all required modifiers are active
    if not checkModifiers(requiredMods) then
        return false
    end
    
    -- Count how many modifiers should be active
    local expectedActiveCount = 0
    local expectedFlags = {}
    
    for _, mod in ipairs(requiredMods) do
        local flagsToCheck = MODIFIER_MAP[mod]
        if flagsToCheck then
            for _, flag in ipairs(flagsToCheck) do
                if not expectedFlags[flag] then
                    expectedFlags[flag] = true
                    expectedActiveCount = expectedActiveCount + 1
                end
            end
        end
    end
    
    -- Count how many modifiers are actually active
    local actualActiveCount = 0
    for flag, active in pairs(activeModifiers) do
        if active then
            actualActiveCount = actualActiveCount + 1
        end
    end
    
    -- Only match if the exact number of expected modifiers are active
    local exactMatch = (actualActiveCount == expectedActiveCount)
    
    if not exactMatch then
        log.d(string.format("Modifier mismatch: expected %d, got %d active modifiers", expectedActiveCount, actualActiveCount))
        log.d("Expected flags: " .. hs.inspect(expectedFlags))
        log.d("Active modifiers: " .. hs.inspect(activeModifiers))
    end
    
    return exactMatch
end

-- Helper to turn a flag integer into active modifier names
local function updateActiveModifiers(flags)
    -- Reset active modifiers
    activeModifiers = {}
    
    -- Set new active modifiers
    for name, mask in pairs(MODIFIER_FLAGS) do
        if (flags & mask) ~= 0 then
            activeModifiers[name] = true
        end
    end
    
    log.d("Active modifiers: " .. hs.inspect(activeModifiers))
end

-- Handle key event
local function handleKeyEvent(event)
    local eventType = event:getType()
    local keyCode = event:getKeyCode()
    local flags = event:getRawEventData().CGEventData.flags
    
    -- Update modifiers state
    updateActiveModifiers(flags)
    
    -- Find the most specific handler that matches this key code
    local bestHandler = nil
    local bestModifierCount = -1
    
    for _, handler in ipairs(keyHandlers) do
        if handler.keyCode == keyCode then
            log.d("Handler found for key code: " .. keyCode)
            -- Verify if EXACTLY the right modifiers are active (no extras)
            if checkExactModifiers(handler.mods) then
                local modifierCount = #handler.mods
                if modifierCount > bestModifierCount then
                    bestHandler = handler
                    bestModifierCount = modifierCount
                end
            else
                log.d("Modifiers don't match exactly for handler with mods: " .. hs.inspect(handler.mods))
            end
        end
    end
    
    -- Execute the best (most specific) handler if found
    if bestHandler then
        log.i("Executing best handler for " .. bestHandler.key .. " with exact modifiers " .. hs.inspect(bestHandler.mods))
        if eventType == hs.eventtap.event.types.keyDown and bestHandler.pressedfn then
            bestHandler.pressedfn()
            return true -- Consume the event only for exact matches
        elseif eventType == hs.eventtap.event.types.keyUp and bestHandler.releasedfn then
            bestHandler.releasedfn()
            return true -- Consume the event only for exact matches
        end
    else
        log.d("No exact modifier match found, passing event through to system")
    end
    
    return false -- Allow event to propagate for all non-exact matches
end

-- Bind a hotkey with left/right modifier specificity
function M.bind(mods, key, pressedfn, releasedfn, repeatfn)
    log.i(string.format("Binding hotkey: mods=%s, key=%s", hs.inspect(mods), key))
    
    -- Convert string to table if needed
    if type(mods) == "string" then 
        mods = {mods} 
    end
    
    -- Ensure eventtap is active
    if not flagsChangedTap then
        flagsChangedTap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(e)
            local flags = e:getRawEventData().CGEventData.flags
            updateActiveModifiers(flags)
            return false
        end)
        flagsChangedTap:start()
        log.i("Started flags changed event tap")
    end
    
    -- Ensure key event tap is active
    if not keyTap then
        keyTap = hs.eventtap.new({hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp}, handleKeyEvent)
        keyTap:start()
        log.i("Started key event tap")
    end
    
    -- Get key code for this key
    local keyCode = hs.keycodes.map[key]
    if not keyCode then
        log.e("Invalid key: " .. key)
        return nil
    end
    
    -- Register handler
    local handler = {
        mods = mods,
        key = key,
        keyCode = keyCode,
        pressedfn = pressedfn,
        releasedfn = releasedfn
    }
    
    table.insert(keyHandlers, handler)
    log.i("Registered left/right specific handler for " .. key .. " with modifiers " .. hs.inspect(mods))
    
    -- Return identifier for this handler
    return #keyHandlers
end

-- Stop and clean up
function M.stop()
    if flagsChangedTap then
        flagsChangedTap:stop()
        flagsChangedTap = nil
    end
    
    if keyTap then
        keyTap:stop()
        keyTap = nil
    end
    
    keyHandlers = {}
    activeModifiers = {}
    log.i("Stopped all left/right modifier hotkeys")
end

-- For debugging - get the current state
function M.getState()
    return {
        activeModifiers = activeModifiers,
        keyHandlers = keyHandlers
    }
end

-- Configure debug logging based on user settings
function M.configureLogging(config)
    if config and config.debug and config.debug.leftRightModifier ~= nil then
        if config.debug.leftRightModifier then
            log.setLogLevel('debug')
            log.i("Left/right modifier debug logging enabled")
        else
            log.setLogLevel('info')
        end
    else
        log.setLogLevel('info') -- Default to info level to reduce noise
    end
end

return M 