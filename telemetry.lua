local M = {}

local log = hs.logger.new('Telemetry', 'warning')

-- Internal state
local isEnabled = false
local username = nil
local serverUrl = nil
local token = nil
local includeAppName = false
local labelMap = {}
local eventsFilePath = nil
local stateFilePath = nil
local syncTimer = nil
local SYNC_INTERVAL = 300 -- 5 minutes

-- Originals for unpatching
local originalHotkeyBind = nil
local originalLeftRightBind = nil

-- Utility: safe JSON encode
local function jsonEncode(tbl)
	local ok, res = pcall(hs.json.encode, tbl)
	if ok then return res end
	return nil
end

-- Utility: expand ~ and ensure absolute path
local function expandPath(path)
	if not path then return nil end
	if path:sub(1,1) == "~" then
		path = os.getenv("HOME") .. path:sub(2)
	end
	return path
end

-- Register a human-readable label for a hotkey (mods + key)
function M.registerHotkeyLabel(mods, key, label)
	if not mods or not key or not label then return end
	local id = table.concat(mods, "+") .. "+" .. tostring(key)
	labelMap[id] = label
end

-- Build a consistent id
local function buildId(mods, key)
	return table.concat(mods or {}, "+") .. "+" .. tostring(key)
end

-- Persist one event to file (JSONL)
local function appendEventToFile(event)
	if not eventsFilePath then return end
	local ok, fh = pcall(io.open, eventsFilePath, "a")
	if not ok or not fh then return end
	local payload = jsonEncode(event)
	if payload then
		fh:write(payload)
		fh:write("\n")
	end
	fh:close()
end

-- Read the last synced line number from state file
local function getLastSyncedLine()
	if not stateFilePath then return 0 end
	local f = io.open(stateFilePath, "r")
	if not f then return 0 end
	local content = f:read("*a")
	f:close()
	local state = hs.json.decode(content)
	return (state and state.lastLine) or 0
end

-- Update the last synced line number in state file
local function updateLastSyncedLine(lineCount)
	if not stateFilePath then return end
	local state = { lastLine = lineCount }
	local f = io.open(stateFilePath, "w")
	if f then
		f:write(hs.json.encode(state))
		f:close()
	end
end

-- Sync events to server
local function syncEvents()
	if not isEnabled or not serverUrl or serverUrl == "" then return end
	if not eventsFilePath then return end

	local lastLine = getLastSyncedLine()
	local events = {}
	local currentLine = 0
	local newLastLine = lastLine

	-- Read events file
	local f = io.open(eventsFilePath, "r")
	if not f then return end

	for line in f:lines() do
		currentLine = currentLine + 1
		if currentLine > lastLine then
			local event = hs.json.decode(line)
			if event then
				table.insert(events, event)
			end
			newLastLine = currentLine
		end
	end
	f:close()

	if #events == 0 then return end

	-- Send batch
	local headers = { ["Content-Type"] = "application/json" }
	if token and token ~= "" then
		headers["X-Hspo-Token"] = token
	end
	
	local body = jsonEncode(events)
	if not body then return end

	log.i(string.format("Syncing %d events...", #events))

	hs.http.asyncPost(serverUrl, body, headers, function(code, _, _)
		if code and code >= 200 and code < 300 then
			if log.getLogLevel() == "debug" then log.d("Telemetry batch sent OK: " .. tostring(code)) end
			updateLastSyncedLine(newLastLine)
		else
			log.w("Telemetry batch send failed: " .. tostring(code))
		end
	end)
end

-- Record a hotkey press event
local function recordHotkey(mods, key)
	if not isEnabled then return end
	local id = buildId(mods, key)
	local frontAppName = nil
	if includeAppName then
		local app = hs.application.frontmostApplication()
		frontAppName = app and app:name() or nil
	end
	local event = {
		type = "hotkey",
		mods = mods,
		key = key,
		id = id,
		label = labelMap[id],
		action = labelMap[id],
		username = username,
		app = frontAppName,
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		version = (require("version").current)
	}
	appendEventToFile(event)
	-- sendEvent(event) -- Removed in favor of async batch sync
end

-- Patch hs.hotkey.bind to wrap pressed callback
local function patchHotkeyBind()
	if originalHotkeyBind then return end
	originalHotkeyBind = hs.hotkey.bind
	hs.hotkey.bind = function(mods, key, pressedfn, releasedfn, repeatfn)
		local wrappedPressed = pressedfn
		if type(pressedfn) == "function" then
			wrappedPressed = function(...)
				recordHotkey(mods, key)
				return pressedfn(...)
			end
		end
		return originalHotkeyBind(mods, key, wrappedPressed, releasedfn, repeatfn)
	end
end

-- Patch leftRightModifier.bind to wrap pressed callback
local function patchLeftRightBind()
	local leftRightModifier = require("leftRightModifier")
	if not leftRightModifier or originalLeftRightBind then return end
	originalLeftRightBind = leftRightModifier.bind
	leftRightModifier.bind = function(mods, key, pressedfn, releasedfn, repeatfn)
		local wrappedPressed = pressedfn
		if type(pressedfn) == "function" then
			wrappedPressed = function(...)
				recordHotkey(type(mods) == "table" and mods or {mods}, key)
				return pressedfn(...)
			end
		end
		return originalLeftRightBind(mods, key, wrappedPressed, releasedfn, repeatfn)
	end
end

-- Unpatch to restore original behavior
local function unpatch()
	if originalHotkeyBind then
		hs.hotkey.bind = originalHotkeyBind
		originalHotkeyBind = nil
	end
	local leftRightModifier = package.loaded["leftRightModifier"]
	if leftRightModifier and originalLeftRightBind then
		leftRightModifier.bind = originalLeftRightBind
		originalLeftRightBind = nil
	end
end

function M.setup(config)
	local cfg = (config and config.telemetry) or {}
	isEnabled = cfg.enabled == true
	if not isEnabled then
		log.setLogLevel('warning')
		return
	end

	-- Configure
	username = cfg.username or nil
	serverUrl = cfg.serverUrl or nil
	token = cfg.token or os.getenv("HSPO_TOKEN") or nil
	includeAppName = cfg.includeAppName == true

	-- Logging
	if config and config.debug and config.debug.configLoading then
		log.setLogLevel('debug')
	else
		log.setLogLevel('warning')
	end

	-- Prepare events file
	local defaultPath = expandPath("~/.hammerspoon/telemetry_events.jsonl")
	eventsFilePath = cfg.eventsFile or defaultPath
	eventsFilePath = expandPath(eventsFilePath)

	-- Ensure file exists
	pcall(function()
		local fh = io.open(eventsFilePath, "a")
		if fh then fh:close() end
	end)

	-- Prepare state file
	local defaultStatePath = expandPath("~/.hammerspoon/telemetry_state.json")
	stateFilePath = cfg.stateFile or defaultStatePath
	stateFilePath = expandPath(stateFilePath)

	-- Start sync timer
	if syncTimer then syncTimer:stop() end
	syncTimer = hs.timer.doEvery(SYNC_INTERVAL, syncEvents)
	
	-- Initial sync
	hs.timer.doAfter(1, syncEvents)

	-- Apply patches
	patchHotkeyBind()
	patchLeftRightBind()
	log.i("Telemetry enabled")
end

function M.stop()
	unpatch()
	if syncTimer then
		syncTimer:stop()
		syncTimer = nil
	end
	isEnabled = false
	log.i("Telemetry disabled")
end

return M


