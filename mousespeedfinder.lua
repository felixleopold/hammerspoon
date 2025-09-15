local M = {}
local log = hs.logger.new('MouseSpeedFinder', 'info')

-- State
local config = nil
local enabled = false
local moveTap = nil
local clickTap = nil

local gestureActive = false
local gesture = nil
local lastMoveTime = 0

local samples = {}
local totalSamples = 0
local samplesSinceSuggestion = 0
local lastSuggestion = nil
local updateEnabled = nil

-- Persist helpers
local function applyScaling(key, value)
    -- Write as float to both global and currentHost and refresh cfprefsd
    local cmdGlobal = string.format('defaults write -g %s -float %.2f', key, value)
    local _, ok1 = hs.execute(cmdGlobal, true)
    local cmdHost = string.format('defaults -currentHost write -g %s -float %.2f', key, value)
    local _, ok2 = hs.execute(cmdHost, true)
    -- Restart preferences daemon to flush caches
    hs.execute('killall cfprefsd', true)
    -- Small delay to allow settings to propagate
    hs.timer.usleep(200000)
    -- Verify by reading back (either domain may hold the applied value)
    local readG = tonumber((hs.execute(string.format('defaults read -g %s', key), true) or ''):match('[-%d%.]+'))
    local readH = tonumber((hs.execute(string.format('defaults -currentHost read -g %s', key), true) or ''):match('[-%d%.]+'))
    local verified = readG or readH
    local success = (ok1 or ok2) and verified and (math.abs((verified or 0) - value) < 0.011)
    return success and true or false, verified
end
local updateEnabled = nil

-- Utilities
local function now()
    return hs.timer.secondsSinceEpoch()
end

local function distance(a, b)
    local dx = (a.x - b.x)
    local dy = (a.y - b.y)
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function percentile(sortedArray, p)
    if #sortedArray == 0 then return 0 end
    local k = (p / 100) * (#sortedArray - 1) + 1
    local f = math.floor(k)
    local c = math.ceil(k)
    if f == c then return sortedArray[f] end
    return sortedArray[f] + (sortedArray[c] - sortedArray[f]) * (k - f)
end

local function median(array)
    if #array == 0 then return 0 end
    local copy = hs.fnutils.copy(array)
    table.sort(copy)
    return percentile(copy, 50)
end

-- Scaling helpers
local function readScalingKeys()
    -- Returns available scaling values for mouse/trackpad
    local results = {}
    local ok, out = pcall(function()
        return hs.execute('defaults read -g com.apple.mouse.scaling', true)
    end)
    if ok and out and out:match('%S') then
        results.mouse = tonumber(out) or results.mouse
    end
    local ok2, out2 = pcall(function()
        return hs.execute('defaults read -g com.apple.trackpad.scaling', true)
    end)
    if ok2 and out2 and out2:match('%S') then
        results.trackpad = tonumber(out2) or results.trackpad
    end
    return results
end

local function getCurrentScaling()
    local device = (config.mousespeedfinder and config.mousespeedfinder.device) or 'auto'
    local values = readScalingKeys()
    if device == 'mouse' then
        return values.mouse, 'com.apple.mouse.scaling'
    elseif device == 'trackpad' then
        return values.trackpad, 'com.apple.trackpad.scaling'
    else
        -- auto: prefer trackpad if present, else mouse
        if values.trackpad ~= nil then return values.trackpad, 'com.apple.trackpad.scaling' end
        if values.mouse ~= nil then return values.mouse, 'com.apple.mouse.scaling' end
        return nil, nil
    end
end

local function suggestScalingDelta(batchStats)
    local msf = config.mousespeedfinder or {}
    local step = msf.scalingStep or 0.1
    local overshootHigh = msf.overshootHighRate or 0.3
    local overshootLow = msf.overshootLowRate or 0.05
    local slowMsPerPixel = msf.timePerPixelSlowMs or 1.0

    if batchStats.overshootRate > overshootHigh then
        return -step, 'High overshoot rate'
    end
    if batchStats.overshootRate < overshootLow and batchStats.medianMsPerPixel > slowMsPerPixel then
        return step, 'Slow target acquisition'
    end
    return 0, 'Within target range'
end

local function showSuggestion(delta, reason, current)
    local msf = config.mousespeedfinder or {}
    local minS = msf.minScaling or 0.5
    local maxS = msf.maxScaling or 5.0
    if not current then return end
    local target = clamp(current + delta, minS, maxS)
    local message
    if delta == 0 then
        message = string.format('Mouse speed OK (%.2f). %s', current, reason)
    elseif delta > 0 then
        message = string.format('Try INCREASING mouse speed: %.2f → %.2f (%s)', current, target, reason)
    else
        message = string.format('Try DECREASING mouse speed: %.2f → %.2f (%s)', current, target, reason)
    end
    lastSuggestion = { time = now(), message = message, current = current, target = target, reason = reason }
    
    -- Show dialog with options instead of just alert
    if msf.alert ~= false then
        local clicked = hs.dialog.blockAlert(
            "Mouse Speed Analysis Complete",
            message .. "\n\nCurrent speed: " .. string.format("%.2f", current) ..
            "\nSuggested speed: " .. string.format("%.2f", target) ..
            "\n\nApply this change?",
            "Ignore",
            "Apply Change"
        )
        
        if clicked == "Apply Change" or clicked == 2 then
            -- Apply the speed change
            local device = msf.device or 'auto'
            local _, key = getCurrentScaling()
            if key then
                local ok, readBack = applyScaling(key, target)
                if ok then
                    hs.alert.show("Mouse speed changed to " .. string.format("%.2f", readBack or target), 2)
                    log.i("Applied mouse speed change: " .. string.format("%.2f", current) .. " → " .. string.format("%.2f", readBack or target))
                else
                    hs.alert.show("Failed to change mouse speed", 2)
                    log.e("Failed to apply mouse speed change (key=" .. tostring(key) .. ")")
                end
            else
                hs.alert.show("Could not determine device type", 2)
            end
        end
    end
    log.i(message)
end

-- Analysis
local function analyzeGesture(g)
    -- Validate
    if not g or not g.startPos or not g.clickPos or not g.points or #g.points < 2 then return nil end
    local straight = distance(g.startPos, g.clickPos)
    if straight < (config.mousespeedfinder.minDistancePx or 30) then
        return nil -- ignore tiny movements
    end
    local durationMs = (g.clickTime - g.startTime) * 1000.0

    -- Direction unit vector start->target
    local dirX = g.clickPos.x - g.startPos.x
    local dirY = g.clickPos.y - g.startPos.y
    local dirLen = math.sqrt(dirX * dirX + dirY * dirY)
    if dirLen == 0 then return nil end
    dirX = dirX / dirLen
    dirY = dirY / dirLen

    local maxProj = 0
    local tValues = {}
    for i, p in ipairs(g.points) do
        local vx = p.x - g.startPos.x
        local vy = p.y - g.startPos.y
        local t = vx * dirX + vy * dirY -- projection along target axis
        tValues[i] = t
        if t > maxProj then maxProj = t end
    end

    local overshootThreshold = config.mousespeedfinder.overshootThreshold or 12
    local overshot = (maxProj - straight) > overshootThreshold
    local overshootPixels = math.max(0, maxProj - straight)

    -- Micro adjustments: count direction reversals in last window
    local windowMs = config.mousespeedfinder.microAdjustWindowMs or 180
    local cutoff = g.clickTime - (windowMs / 1000.0)
    local lastIdx = #g.points
    local firstIdx = lastIdx
    while firstIdx > 1 and g.points[firstIdx].t >= cutoff do
        firstIdx = firstIdx - 1
    end
    if firstIdx < 1 then firstIdx = 1 end

    local reversals = 0
    local eps = 0.5
    local prevSign = 0
    for i = firstIdx + 1, lastIdx do
        local dt = tValues[i] - tValues[i - 1]
        local sign = (dt > eps) and 1 or ((dt < -eps) and -1 or 0)
        if sign ~= 0 and prevSign ~= 0 and sign ~= prevSign then
            reversals = reversals + 1
        end
        if sign ~= 0 then prevSign = sign end
    end

    local msPerPixel = durationMs / straight

    return {
        durationMs = durationMs,
        distancePx = straight,
        msPerPixel = msPerPixel,
        overshot = overshot,
        overshootPx = overshootPixels,
        reversals = reversals,
    }
end

local function computeBatchStats(batch)
    local n = #batch
    if n == 0 then return nil end
    local overs = 0
    local msPerPxList = {}
    local reversalsList = {}
    for _, s in ipairs(batch) do
        if s.overshot then overs = overs + 1 end
        table.insert(msPerPxList, s.msPerPixel)
        table.insert(reversalsList, s.reversals)
    end
    return {
        count = n,
        overshootRate = overs / n,
        medianMsPerPixel = median(msPerPxList),
        meanReversals = (#reversalsList > 0) and (hs.fnutils.reduce(reversalsList, function(acc, v) return acc + v end, 0) / #reversalsList) or 0,
    }
end

-- Report UI
local function showReport()
    local n = math.min(#samples, config.mousespeedfinder.clicksPerBatch or 40)
    local batch = {}
    for i = #samples - n + 1, #samples do
        if i >= 1 and samples[i] then table.insert(batch, samples[i]) end
    end
    local stats = computeBatchStats(batch)
    local current = select(1, getCurrentScaling())
    if not stats then
        hs.alert.show('MouseSpeedFinder: Not enough data yet')
        return
    end
    local msg = string.format('MouseSpeedFinder\nSamples: %d\nOvershoot: %.0f%%\nMedian ms/px: %.2f\nReversals (mean): %.2f\nCurrent speed: %s',
        stats.count, stats.overshootRate * 100.0, stats.medianMsPerPixel, stats.meanReversals, current and string.format('%.2f', current) or 'n/a')
    if lastSuggestion and lastSuggestion.message then
        msg = msg .. string.format('\nLast suggestion: %s', lastSuggestion.message)
    end
    hs.alert.show(msg, 3)
end

-- Event handling
local function startGesture(startPos)
    gestureActive = true
    gesture = {
        startPos = { x = startPos.x, y = startPos.y },
        startTime = now(),
        points = {},
    }
end

local function endGestureWithClick(clickPos)
    if not gestureActive or not gesture then return end
    gesture.clickPos = { x = clickPos.x, y = clickPos.y }
    gesture.clickTime = now()
    local stat = analyzeGesture(gesture)
    gestureActive = false
    gesture = nil
    if not stat then return end
    table.insert(samples, stat)
    totalSamples = totalSamples + 1
    samplesSinceSuggestion = samplesSinceSuggestion + 1

    -- Suggestion check
    local msf = config.mousespeedfinder or {}
    local batchSize = msf.clicksPerBatch or 40
    if enabled and samplesSinceSuggestion >= batchSize then
        local batch = {}
        for i = #samples - batchSize + 1, #samples do
            if i >= 1 and samples[i] then table.insert(batch, samples[i]) end
        end
        local stats = computeBatchStats(batch)
        -- Disable BEFORE showing dialog to avoid capturing dialog clicks
        updateEnabled(false)
        if stats then
            local delta, reason = suggestScalingDelta(stats)
            local current = select(1, getCurrentScaling())
            showSuggestion(delta, reason, current)
        end
        samplesSinceSuggestion = 0
    end
end

local function ensureTaps()
    if moveTap or clickTap then return end
    local idleMs = (config.mousespeedfinder.idleThresholdMs or 300)
    local maxPoints = (config.mousespeedfinder.maxPointsPerGesture or 250)

    moveTap = hs.eventtap.new({ hs.eventtap.event.types.mouseMoved }, function(e)
        if not enabled then return false end
        local pos = hs.mouse.absolutePosition()
        local t = now()
        -- Start a gesture if none is active OR we've been idle long enough
        if not gestureActive or ((t - lastMoveTime) * 1000.0 > idleMs) then
            startGesture(pos)
        end
        lastMoveTime = t
        if gestureActive and gesture then
            local p = { x = pos.x, y = pos.y, t = t }
            if #gesture.points == 0 or (math.abs(p.x - gesture.points[#gesture.points].x) + math.abs(p.y - gesture.points[#gesture.points].y) >= 1) then
                if #gesture.points < maxPoints then
                    table.insert(gesture.points, p)
                end
            end
        end
        return false
    end)

    clickTap = hs.eventtap.new({ hs.eventtap.event.types.leftMouseDown }, function(e)
        if not enabled then return false end
        local pos = hs.mouse.absolutePosition()
        endGestureWithClick(pos)
        return false
    end)

    moveTap:start()
    clickTap:start()
end

local function stopTaps()
    if moveTap then moveTap:stop(); moveTap = nil end
    if clickTap then clickTap:stop(); clickTap = nil end
end

updateEnabled = function(state)
    enabled = state and true or false
    if enabled then ensureTaps() else stopTaps() end
    log.i('MouseSpeedFinder ' .. (enabled and 'enabled' or 'disabled'))
    if config.mousespeedfinder and config.mousespeedfinder.alert ~= false then
        hs.alert.show('MouseSpeedFinder ' .. (enabled and 'ON' or 'OFF'))
    end
end

-- Setup
function M.setup(cfg)
    config = cfg
    -- Configure logging
    if cfg and cfg.debug and cfg.debug.mousespeedfinder == true then
        log.setLogLevel('debug')
    else
        log.setLogLevel('info')
    end

    if not cfg.mousespeedfinder or cfg.mousespeedfinder.enabled == false then
        log.i('MouseSpeedFinder disabled by config')
        enabled = false
        return
    end

    enabled = true
    ensureTaps()

    -- Show current speed at startup
    local current = select(1, getCurrentScaling())
    if current then
        local device = (cfg.mousespeedfinder and cfg.mousespeedfinder.device) or 'auto'
        local deviceName = (device == 'mouse') and 'Mouse' or (device == 'trackpad') and 'Trackpad' or 'Device'
        if cfg.mousespeedfinder and cfg.mousespeedfinder.alert ~= false then
            hs.alert.show("MouseSpeedFinder started - " .. deviceName .. " speed: " .. string.format("%.2f", current), 2)
        end
        log.i("MouseSpeedFinder started - Current " .. deviceName .. " speed: " .. string.format("%.2f", current))
    end

    -- Register shortcuts
    local sc = (cfg.mousespeedfinder and cfg.mousespeedfinder.shortcuts) or {}
    if sc.toggle and sc.toggle.mods and sc.toggle.key then
        hs.hotkey.bind(sc.toggle.mods, sc.toggle.key, function()
            updateEnabled(not enabled)
        end)
    end
    if sc.report and sc.report.mods and sc.report.key then
        hs.hotkey.bind(sc.report.mods, sc.report.key, function()
            showReport()
        end)
    end

    log.i('MouseSpeedFinder initialized')
end

-- Expose for diagnostics
function M.isEnabled()
    return enabled
end

function M.lastSuggestion()
    return lastSuggestion
end

return M


