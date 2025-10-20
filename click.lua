-- Simple and efficient autoclicker module (gaming mode only)
local M = {}

local ev, tm, ms = hs.eventtap.event, hs.timer, hs.mouse
local log = hs.logger.new('Click', 'warning')

-- Config values (defaults, can be overridden by config)
local leftEnabled = true
local rightEnabled = true
local leftCPS = 15
local leftVariance = 1
local rightCPS = 20
local rightVariance = 3

-- Internal state
local lt, rt = nil, nil            -- timers
local leftHotkey, rightHotkey = nil, nil
local statusWatcher = nil
local statusFilePath = nil
local currentMode = "normal"
local isSetup = false

-- Random interval generator (seconds between clicks)
local function rint(mean, delta)
    -- Generate base interval from CPS variance
    local interval = 1 / (mean + (math.random() * 2 * delta - delta))
    -- Add small micro-randomness (±5-15ms) to make timing less predictable
    local microJitter = (math.random() - 0.5) * 0.01  -- ±0.005 seconds (±5ms)
    return interval + microJitter
end

-- Left click function
local function lclick()
    local p = ms.getAbsolutePosition()
    ev.newMouseEvent(ev.types.leftMouseDown, p):post()
    ev.newMouseEvent(ev.types.leftMouseUp, p):post()
end

-- Right click function
local function rclick()
    local p = ms.getAbsolutePosition()
    ev.newMouseEvent(ev.types.rightMouseDown, p):post()
    ev.newMouseEvent(ev.types.rightMouseUp, p):post()
end

-- Guarded start/stop helpers
local function startLeft()
    if lt and not lt:running() then
        lt:start()
        lt:setNextTrigger(rint(leftCPS, leftVariance))
    end
end

local function stopLeft()
    if lt and lt:running() then
        lt:stop()
    end
end

local function startRight()
    if rt and not rt:running() then
        rt:start()
        rt:setNextTrigger(rint(rightCPS, rightVariance))
    end
end

local function stopRight()
    if rt and rt:running() then
        rt:stop()
    end
end

-- Read current mode directly from status file
local function readModeFromFile()
    if not statusFilePath then return nil end
    local file = io.open(statusFilePath, "r")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    if not content then return nil end
    local mode = content:match("^%s*(.-)%s*$")
    if mode == "normal" or mode == "vim" or mode == "typing" or mode == "gaming" then
        return mode
    end
    return nil
end

-- Enable/disable hotkeys based on mode
local function applyMode(newMode)
    if not newMode then return end
    if newMode == currentMode then return end
    currentMode = newMode
    local enable = (currentMode == "gaming")

    if leftHotkey then
        if enable then leftHotkey:enable() else leftHotkey:disable() end
    end
    if rightHotkey then
        if enable then rightHotkey:enable() else rightHotkey:disable() end
    end

    if not enable then
        stopLeft()
        stopRight()
    end
    log.i("Autoclicker hotkeys " .. (enable and "ENABLED" or "DISABLED") .. " for mode: " .. currentMode)
end

local function updateMode()
    local mode = readModeFromFile()
    if mode then applyMode(mode) end
end

-- Expand ~ to HOME
local function expandPath(path)
    if not path then return nil end
    if path:sub(1, 1) == "~" then
        return os.getenv("HOME") .. path:sub(2)
    end
    return path
end

-- Setup function to initialize module
function M.setup(cfg)
    if isSetup then return end
    isSetup = true

    if cfg and cfg.debug and cfg.debug.click then
        log.setLogLevel('debug')
    else
        log.setLogLevel('warning')
    end

    -- Pull config values if provided
    if cfg and cfg.click then
        leftEnabled = cfg.click.leftEnabled ~= nil and cfg.click.leftEnabled or leftEnabled
        rightEnabled = cfg.click.rightEnabled ~= nil and cfg.click.rightEnabled or rightEnabled
        leftCPS = cfg.click.leftCPS or leftCPS
        leftVariance = cfg.click.leftVariance or leftVariance
        rightCPS = cfg.click.rightCPS or rightCPS
        rightVariance = cfg.click.rightVariance or rightVariance
    end

    -- Create timers
    lt = tm.new(0.01, function()
        lclick()
        lt:setNextTrigger(rint(leftCPS, leftVariance))
    end)
    rt = tm.new(0.01, function()
        rclick()
        rt:setNextTrigger(rint(rightCPS, rightVariance))
    end)

    -- Create hotkeys (initially disabled; enabled in gaming mode)
    if leftEnabled then
        leftHotkey = hs.hotkey.new({}, ",",
            function() startLeft() end,
            function() stopLeft() end
        )
        leftHotkey:disable() -- Keep disabled until gaming mode
    end
    
    if rightEnabled then
        rightHotkey = hs.hotkey.new({}, ".",
            function() startRight() end,
            function() stopRight() end
        )
        rightHotkey:disable() -- Keep disabled until gaming mode
    end

    -- Watch Kanata status file for changes
    if cfg and cfg.kanata and cfg.kanata.statusFile then
        statusFilePath = expandPath(cfg.kanata.statusFile)
        local statusDir = statusFilePath:match("(.+)/[^/]+$") or (os.getenv("HOME") .. "/.config/kanata")
        statusWatcher = hs.pathwatcher.new(statusDir, function(files)
            for _, f in ipairs(files) do
                if f:match(statusFilePath:match("[^/]+$")) then
                    hs.timer.doAfter(0.05, updateMode)
                    break
                end
            end
        end):start()
        log.i("Watching Kanata status file: " .. statusFilePath)
    else
        log.w("No Kanata status file configured; autoclicker will remain disabled")
    end

    -- Apply initial mode from file (if available)
    updateMode()
end

function M.getState()
    return {
        mode = currentMode,
        leftEnabled = leftEnabled,
        rightEnabled = rightEnabled,
        leftTimerRunning = lt and lt:running() or false,
        rightTimerRunning = rt and rt:running() or false,
        leftHotkeyEnabled = leftHotkey and leftHotkey._enabled or false,
        rightHotkeyEnabled = rightHotkey and rightHotkey._enabled or false,
        leftCPS = leftCPS,
        rightCPS = rightCPS
    }
end

return M