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

-- Try sending to server (best-effort, non-blocking)
local function sendEvent(event)
	if not serverUrl or serverUrl == "" then return end
	local headers = { ["Content-Type"] = "application/json" }
	if token and token ~= "" then
		headers["X-Hspo-Token"] = token
	end
	local body = jsonEncode(event) or "{}"
	hs.http.asyncPost(serverUrl, body, headers, function(code, _, _)
		-- Keep quiet unless debug enabled
		if code and code >= 200 and code < 300 then
			if log.getLogLevel() == "debug" then log.d("Telemetry sent OK: " .. tostring(code)) end
		else
			if log.getLogLevel() == "debug" then log.d("Telemetry send failed: " .. tostring(code)) end
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
	sendEvent(event)
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

	-- Apply patches
	patchHotkeyBind()
	patchLeftRightBind()
	log.i("Telemetry enabled")
end

function M.stop()
	unpatch()
	isEnabled = false
	log.i("Telemetry disabled")
end

return M


