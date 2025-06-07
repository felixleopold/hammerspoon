local M = {}
local log = hs.logger.new('Macro', 'debug')

-- Settings
local MACROS_FILE = hs.fs.pathToAbsolute(os.getenv("HOME") .. "/.hammerspoon") .. "/macros.json"
local MAX_MACROS = 10  -- Maximum number of stored macros
local RECORDING_COLOR = {red = 1, green = 0, blue = 0, alpha = 0.7}  -- Red for recording clicks
local PLAYBACK_COLOR = {red = 0, green = 0, blue = 1, alpha = 0.7}   -- Blue for playback clicks
local CIRCLE_SIZE = 20  -- Size of the circle in pixels
local CIRCLE_DURATION = 0.3  -- How long the circle appears in seconds
local MIN_DELAY = 0.01  -- Minimum delay between events (seconds)

-- Configure debug logging based on user settings
local function configureLogging(config)
    if config and config.debug and config.debug.macro ~= nil then
        if config.debug.macro then
            log.setLogLevel('debug')
            log.i("Macro debug logging enabled")
        else
            log.setLogLevel('info')
        end
    else
        log.setLogLevel('info') -- Default to info level
    end
end

-- UI Constants
local EDITOR_WIDTH = 800
local EDITOR_HEIGHT = 600
local TIMELINE_HEIGHT = 100
local TIMELINE_XPAD = 60  -- Space for labels on left
local EVENT_MARKER_SIZE = 8
local EVENT_TYPES = {
    click = {color = {red = 1, green = 0.3, blue = 0.3, alpha = 1}},
    keypress = {color = {red = 0.3, green = 0.7, blue = 1, alpha = 1}}
}

-- State variables
local isRecording = false
local currentMacro = {}
local macros = {}
local recordStart = 0
local mouseWatcher = nil
local keyWatcher = nil
local clickCircle = nil
local recordingIndicator = nil
local config = nil  -- Will be set in setup()
local editorUI = nil  -- Holds editor UI components
local selectedEvent = nil
local timeScale = 1.0  -- 1.0 = normal speed, 0.5 = half speed, 2.0 = double speed

-- Function to load macros from file
local function loadMacros()
    if hs.fs.attributes(MACROS_FILE) then
        local file = io.open(MACROS_FILE, "r")
        if file then
            local content = file:read("*all")
            file:close()
            
            local status, data = pcall(hs.json.decode, content)
            if status and data then
                macros = data
                log.i(string.format("Loaded %d macros", #macros))
            else
                log.e("Failed to parse macros JSON file")
                macros = {}
            end
        else
            log.e("Failed to open macros file for reading")
            macros = {}
        end
    else
        log.i("No macros file found, starting with empty set")
        macros = {}
    end
end

-- Function to save macros to file
local function saveMacros()
    local file = io.open(MACROS_FILE, "w")
    if file then
        -- Use pretty formatting with 2-space indentation
        local encoded = hs.json.encode(macros, true)
        file:write(encoded)
        file:close()
        log.i(string.format("Saved %d macros to file", #macros))
    else
        log.e("Failed to open macros file for writing")
        hs.alert.show("Failed to save macros!")
    end
end

-- Function to create a circle at the mouse position
local function createCircleAtMousePosition(color)
    local point = hs.mouse.absolutePosition()
    
    -- First, remove any existing circle
    if clickCircle then
        clickCircle:delete()
        clickCircle = nil
    end
    
    -- Create a new circle
    clickCircle = hs.drawing.circle(hs.geometry.rect(
        point.x - CIRCLE_SIZE/2, 
        point.y - CIRCLE_SIZE/2, 
        CIRCLE_SIZE, 
        CIRCLE_SIZE
    ))
    
    clickCircle:setStrokeColor(color)
    clickCircle:setFill(false)
    clickCircle:setStrokeWidth(2)
    clickCircle:show()
    
    -- Schedule the circle to disappear
    hs.timer.doAfter(CIRCLE_DURATION, function()
        if clickCircle then
            clickCircle:delete()
            clickCircle = nil
        end
    end)
end

-- Function to show recording indicator
local function showRecordingIndicator()
    if recordingIndicator then 
        recordingIndicator:delete() 
    end
    
    recordingIndicator = hs.drawing.text(
        hs.geometry.rect(20, 20, 200, 30),
        "Recording Macro..."
    )
    recordingIndicator:setTextColor({red=1, green=0, blue=0, alpha=1})
    recordingIndicator:setTextFont("Helvetica Bold")
    recordingIndicator:setTextSize(16)
    recordingIndicator:setBehavior(hs.drawing.windowBehaviors.canJoinAllSpaces)
    recordingIndicator:setLevel(hs.drawing.windowLevels.overlay)
    recordingIndicator:show()
end

-- Function to hide recording indicator
local function hideRecordingIndicator()
    if recordingIndicator then
        recordingIndicator:delete()
        recordingIndicator = nil
    end
end

-- Function to start recording a macro
local function startRecording()
    if isRecording then
        log.w("Already recording a macro")
        return
    end
    
    -- Reset state
    currentMacro = {
        events = {},
        name = "New Macro"
    }
    
    recordStart = hs.timer.secondsSinceEpoch()
    isRecording = true
    
    -- Show recording indicator
    showRecordingIndicator()
    
    -- Set up mouse event watcher
    mouseWatcher = hs.eventtap.new({
        hs.eventtap.event.types.leftMouseDown,
        hs.eventtap.event.types.rightMouseDown,
        hs.eventtap.event.types.leftMouseUp,
        hs.eventtap.event.types.rightMouseUp
    }, function(event)
        local eventType = event:getType()
        local timestamp = hs.timer.secondsSinceEpoch() - recordStart
        local point = hs.mouse.absolutePosition()
        
        if eventType == hs.eventtap.event.types.leftMouseDown or
           eventType == hs.eventtap.event.types.rightMouseDown then
            
            -- Record click and show circle
            createCircleAtMousePosition(RECORDING_COLOR)
            
            table.insert(currentMacro.events, {
                type = "click",
                button = (eventType == hs.eventtap.event.types.leftMouseDown) and "left" or "right",
                state = "down",
                x = point.x,
                y = point.y,
                timestamp = timestamp
            })
            
            log.d(string.format("Recorded %s click down at %.0f,%.0f at time %.2f", 
                   (eventType == hs.eventtap.event.types.leftMouseDown) and "left" or "right",
                   point.x, point.y, timestamp))
        elseif eventType == hs.eventtap.event.types.leftMouseUp or
               eventType == hs.eventtap.event.types.rightMouseUp then
            
            table.insert(currentMacro.events, {
                type = "click",
                button = (eventType == hs.eventtap.event.types.leftMouseUp) and "left" or "right",
                state = "up",
                x = point.x,
                y = point.y,
                timestamp = timestamp
            })
            
            log.d(string.format("Recorded %s click up at %.0f,%.0f at time %.2f", 
                   (eventType == hs.eventtap.event.types.leftMouseUp) and "left" or "right",
                   point.x, point.y, timestamp))
        end
        
        return false  -- Allow the event to propagate
    end):start()
    
    -- Set up keyboard event watcher
    keyWatcher = hs.eventtap.new({
        hs.eventtap.event.types.keyDown,
        hs.eventtap.event.types.keyUp
    }, function(event)
        local eventType = event:getType()
        local timestamp = hs.timer.secondsSinceEpoch() - recordStart
        local keyCode = event:getKeyCode()
        local flags = event:getFlags()
        local state = (eventType == hs.eventtap.event.types.keyDown) and "down" or "up"
        
        -- Get character for this keycode if possible
        local character = hs.keycodes.map[keyCode]
        
        -- Skip our own control keys
        if (flags.cmd and flags.alt and keyCode == 30) or -- [
           (flags.cmd and flags.alt and keyCode == 33) or -- ]
           (flags.cmd and flags.alt and keyCode == 42) then  -- \
            return false
        end
        
        table.insert(currentMacro.events, {
            type = "keypress",
            keyCode = keyCode,
            character = character,
            state = state,
            flags = flags,
            timestamp = timestamp
        })
        
        log.d(string.format("Recorded key %s %s (code %d) with flags %s at time %.2f", 
               character or "[unknown]", state, keyCode, hs.inspect(flags), timestamp))
        
        return false  -- Allow the event to propagate
    end):start()
    
    log.i("Started recording macro")
    hs.alert.show("Macro recording started")
end

-- Function to stop recording and prompt for name
local function stopRecording()
    if not isRecording then
        log.w("Not currently recording a macro")
        return
    end
    
    -- Stop the watchers
    if mouseWatcher then
        mouseWatcher:stop()
        mouseWatcher = nil
    end
    
    if keyWatcher then
        keyWatcher:stop()
        keyWatcher = nil
    end
    
    isRecording = false
    hideRecordingIndicator()
    
    -- Make sure we have some events
    if #currentMacro.events == 0 then
        log.w("No events recorded, discarding macro")
        hs.alert.show("Macro recording cancelled - no events recorded")
        return
    end
    
    -- Add human-readable timestamps to events
    local macroStartTime = os.date("%H:%M:%S", math.floor(recordStart))
    local macroLengthSeconds = currentMacro.events[#currentMacro.events].timestamp
    
    -- Format the time as MM:SS.ms
    local minutes = math.floor(macroLengthSeconds / 60)
    local seconds = macroLengthSeconds % 60
    local formattedDuration = string.format("%02d:%05.2f", minutes, seconds)
    
    -- Add metadata to the macro
    currentMacro.recordedAt = macroStartTime
    currentMacro.duration = formattedDuration
    currentMacro.totalSeconds = macroLengthSeconds
    
    -- Format timestamps in each event for human readability
    for i, event in ipairs(currentMacro.events) do
        local eventMinutes = math.floor(event.timestamp / 60)
        local eventSeconds = event.timestamp % 60
        event.formattedTime = string.format("%02d:%05.2f", eventMinutes, eventSeconds)
        
        -- Add actual delay from previous event for easier editing
        if i > 1 then
            event.delay = event.timestamp - currentMacro.events[i-1].timestamp
            -- Format delay to 3 decimal places as string
            event.formattedDelay = string.format("%.3f", event.delay)
        else
            event.delay = 0
            event.formattedDelay = "0.000"
        end
    end
    
    -- Prompt for macro name
    local button, macroName = hs.dialog.textPrompt(
        "Save Macro", 
        "Enter a name for this macro (duration: " .. formattedDuration .. "):", 
        "New Macro", 
        "Save", 
        "Cancel"
    )
    
    if button == "Save" and macroName and macroName ~= "" then
        currentMacro.name = macroName
        
        -- Add to our macros list, limiting to MAX_MACROS
        if #macros >= MAX_MACROS then
            table.remove(macros, 1)  -- Remove the oldest macro
        end
        
        table.insert(macros, currentMacro)
        
        -- Save to file
        saveMacros()
        
        log.i(string.format("Saved macro '%s' with %d events (duration: %s)", 
               currentMacro.name, #currentMacro.events, formattedDuration))
        hs.alert.show(string.format("Macro '%s' saved (duration: %s)", 
                      currentMacro.name, formattedDuration))
    else
        log.i("Macro recording cancelled by user")
        hs.alert.show("Macro recording cancelled")
    end
end

-- Function to play a macro
local function playMacro(macro)
    if not macro or not macro.events or #macro.events == 0 then
        log.e("Invalid macro or no events to play")
        hs.alert.show("Cannot play macro - no events")
        return
    end
    
    log.i(string.format("Playing macro '%s' with %d events", macro.name, #macro.events))
    hs.alert.show(string.format("Playing macro: %s", macro.name))
    
    -- Keep track of the pending events
    local pendingEvents = {}
    local playbackActive = true
    local escWatcher = nil
    
    -- Initialize the escape key watcher
    escWatcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
        if event:getKeyCode() == 53 then -- Escape key
            log.i("Macro playback cancelled by user (Escape key)")
            playbackActive = false
            
            -- Cancel all pending events
            for _, timer in ipairs(pendingEvents) do
                if timer and timer.stop then  -- Check if timer is valid
                    timer:stop()
                end
            end
            pendingEvents = {}
            
            hs.alert.show("Macro playback cancelled")
            
            -- Stop the watcher
            if escWatcher then
                escWatcher:stop()
            end
            return true -- Consume the escape key
        end
        return false
    end):start()
    
    -- Process the first event immediately
    local nextTime = 0
    local lastEventTime = 0
    
    -- Initiate sequential playback with precise timing
    local function playNextEvent(index)
        if not playbackActive or index > #macro.events then
            -- We're done or playback was cancelled
            if escWatcher then
                escWatcher:stop()
            end
            return
        end
        
        local event = macro.events[index]
        
        -- Calculate delay for next event
        local delay = 0
        if index > 1 then
            delay = event.delay or 0  -- Use the pre-calculated delay if available
        end
        
        -- Ensure minimum delay for processing
        delay = math.max(0.01, delay)
        
        log.d(string.format("Scheduling event %d with delay %.3f seconds", index, delay))
        
        -- Schedule the next event
        hs.timer.doAfter(delay, function()
            if not playbackActive then return end
            
            -- Process the current event
            if event.type == "click" then
                -- Move to position first
                hs.mouse.absolutePosition({x = event.x, y = event.y})
                
                if event.state == "down" or not event.state then  -- Backward compatibility
                    -- Show click circle for mouse down only
                    createCircleAtMousePosition(PLAYBACK_COLOR)
                    
                    -- Perform the click based on state
                    if event.button == "left" then
                        if event.state == "down" then
                            hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, {x = event.x, y = event.y}):post()
                        else
                            hs.eventtap.leftClick({x = event.x, y = event.y})
                        end
                    else
                        if event.state == "down" then
                            hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.rightMouseDown, {x = event.x, y = event.y}):post()
                        else
                            hs.eventtap.rightClick({x = event.x, y = event.y})
                        end
                    end
                    
                    log.d(string.format("Played %s click %s at %.0f,%.0f", 
                           event.button, event.state or "click", event.x, event.y))
                elseif event.state == "up" then
                    -- Mouse up event
                    if event.button == "left" then
                        hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, {x = event.x, y = event.y}):post()
                    else
                        hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.rightMouseUp, {x = event.x, y = event.y}):post()
                    end
                    
                    log.d(string.format("Played %s mouse up at %.0f,%.0f", 
                           event.button, event.x, event.y))
                end
                
            elseif event.type == "keypress" then
                -- Simulate key press based on state
                if event.state == "down" or not event.state then  -- Backward compatibility
                    local e = hs.eventtap.event.newKeyEvent(event.flags, event.keyCode, true)
                    e:post()
                    
                    log.d(string.format("Played key down %d", event.keyCode))
                elseif event.state == "up" then
                    local e = hs.eventtap.event.newKeyEvent(event.flags, event.keyCode, false)
                    e:post()
                    
                    log.d(string.format("Played key up %d", event.keyCode))
                end
            end
            
            -- Schedule the next event
            playNextEvent(index + 1)
        end)
    end
    
    -- Start playing events sequentially
    playNextEvent(1)
    
    -- Set timeout to clean up the escape watcher
    local lastEvent = macro.events[#macro.events]
    local totalDuration = lastEvent.timestamp + 2.0 -- Add 2 second buffer
    hs.timer.doAfter(totalDuration, function()
        if escWatcher then
            escWatcher:stop()
            escWatcher = nil
        end
    end)
end

-- Function to create and show the timing editor
local function showTimingEditor(macro)
    if not macro or not macro.events or #macro.events == 0 then
        hs.alert.show("No events to edit")
        return
    end
    
    -- Close existing editor if open
    if editorUI and editorUI.window then
        editorUI.window:close()
        editorUI = nil
    end
    
    -- Calculate the total duration of the macro
    local totalDuration = macro.events[#macro.events].timestamp
    
    -- Calculate how much time each pixel represents
    local timeScale = (EDITOR_WIDTH - TIMELINE_XPAD) / totalDuration
    
    -- Create editor UI components
    editorUI = {
        window = nil,
        canvas = nil,
        eventMarkers = {},
        infoText = nil,
        totalDuration = totalDuration,
        timeScale = timeScale,
        selectedEvent = nil,
        adjustingEvent = false,
        macro = macro,
        eventLabels = {},
        speedSlider = nil
    }
    
    -- Debug output
    log.i(string.format("Creating editor for macro '%s' with %d events and duration %.2f seconds", 
            macro.name, #macro.events, totalDuration))
    
    -- Create a webview for the macro editor
    local html = [[
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    margin: 0;
                    padding: 20px;
                    background-color: #f5f5f7;
                    color: #333;
                }
                .container {
                    max-width: 800px;
                    margin: 0 auto;
                    background-color: white;
                    border-radius: 8px;
                    box-shadow: 0 2px 6px rgba(0,0,0,0.1);
                    padding: 20px;
                }
                h1 {
                    font-size: 22px;
                    margin-top: 0;
                    margin-bottom: 20px;
                    color: #333;
                }
                .timeline-container {
                    position: relative;
                    margin: 40px 0 20px;
                }
                #timeline {
                    height: 30px;
                    background-color: #e9e9e9;
                    border-radius: 4px;
                    position: relative;
                }
                #events-container {
                    position: absolute;
                    top: 0;
                    left: 0;
                    right: 0;
                    height: 30px;
                    pointer-events: none;
                }
                .time-marker {
                    position: absolute;
                    top: 0;
                    bottom: 0;
                    width: 2px;
                    background-color: #999;
                }
                .time-marker span {
                    position: absolute;
                    top: -20px;
                    left: -15px;
                    font-size: 10px;
                    color: #666;
                    width: 30px;
                    text-align: center;
                }
                .event-marker {
                    position: absolute;
                    width: 8px;
                    height: 30px;
                    transform: translateX(-4px);
                    background-color: #007aff;
                    cursor: pointer;
                    pointer-events: auto;
                    z-index: 10;
                    border-radius: 2px;
                }
                .event-indicator {
                    position: absolute;
                    bottom: 100%;
                    left: 50%;
                    transform: translateX(-50%);
                    background: #333;
                    color: white;
                    padding: 3px 6px;
                    border-radius: 3px;
                    font-size: 10px;
                    opacity: 0;
                    transition: opacity 0.2s;
                    white-space: nowrap;
                    pointer-events: none;
                }
                .event-marker:hover .event-indicator {
                    opacity: 1;
                }
                .controls {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    margin-top: 20px;
                }
                .button-group {
                    display: flex;
                    gap: 8px;
                }
                .macro-info {
                    display: flex;
                    justify-content: space-between;
                    margin-bottom: 15px;
                    font-size: 14px;
                    color: #666;
                }
                .playback-controls {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                }
                button {
                    padding: 8px 16px;
                    border: none;
                    border-radius: 4px;
                    background-color: #007aff;
                    color: white;
                    font-size: 14px;
                    cursor: pointer;
                    transition: background-color 0.2s;
                }
                button:hover {
                    background-color: #0062cc;
                }
                button.secondary {
                    background-color: #e9e9e9;
                    color: #333;
                }
                button.secondary:hover {
                    background-color: #d5d5d5;
                }
                #debug-info {
                    margin-top: 20px;
                    padding: 10px;
                    background-color: #f8f8f8;
                    border-radius: 4px;
                    font-family: monospace;
                    font-size: 12px;
                    white-space: pre-wrap;
                    color: #666;
                    display: none;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>Macro Editor</h1>
                
                <div class="macro-info">
                    <span id="macro-duration">Duration: 00:00.00</span>
                    <span id="events-count">Events: 0</span>
                </div>
                
                <div class="timeline-container">
                    <div id="timeline"></div>
                    <div id="events-container"></div>
                </div>
                
                <div class="controls">
                    <div class="playback-controls">
                        <button id="slow-down" class="secondary">-</button>
                        <span id="playback-speed">1.0x</span>
                        <button id="speed-up" class="secondary">+</button>
                    </div>
                    
                    <div class="button-group">
                        <button id="apply-button">Apply Changes</button>
                    </div>
                </div>
                
                <div id="debug-info"></div>
            </div>
            
            <script>
                // Initialize the editor when data is received from Hammerspoon
                function init(data) {
                    // Wait for DOM to fully load
                    setTimeout(() => {
                        try {
                            // Validate data structure
                            if (!data || typeof data !== 'object') {
                                throw new Error("Invalid data structure received");
                            }
                            
                            // Process events data before initializing editor
                            data.events = preprocessEvents(data.events || []);
                            
                            // Initialize the editor with processed data
                            initEditor(data);
                        } catch (err) {
                            console.error("Error initializing editor:", err);
                            document.getElementById('debug-info').style.display = 'block';
                            document.getElementById('debug-info').innerText = "Error initializing: " + err.message;
                        }
                    }, 100);
                }
                
                // Process and validate events data
                function preprocessEvents(events) {
                    console.log("Processing events:", events);
                    
                    if (!Array.isArray(events)) {
                        console.warn("Events is not an array, converting to empty array");
                        return [];
                    }
                    
                    return events.map((event, index) => {
                        // Ensure event is an object
                        if (!event || typeof event !== 'object') {
                            console.warn(`Event ${index} is not an object, creating empty event`);
                            return { type: 'unknown', timestamp: index * 0.5 };
                        }
                        
                        // Ensure timestamp exists and is a number
                        if (typeof event.timestamp !== 'number') {
                            console.warn(`Event ${index} has invalid timestamp, using index as timestamp`);
                            event.timestamp = index * 0.5;
                        }
                        
                        // Format timestamp for display
                        const minutes = Math.floor(event.timestamp / 60);
                        const seconds = event.timestamp % 60;
                        event.formattedTime = `${minutes.toString().padStart(2, '0')}:${seconds.toFixed(2).padStart(5, '0')}`;
                        
                        // Ensure type exists
                        if (!event.type) {
                            console.warn(`Event ${index} has no type, assuming 'unknown'`);
                            event.type = 'unknown';
                        }
                        
                        // Create human-readable label
                        if (event.type === 'keypress') {
                            event.label = `${event.type} ${event.character || event.keycode || ''} ${event.state || ''}`;
                        } else if (event.type === 'click') {
                            event.label = `${event.type} at (${event.x || '?'}, ${event.y || '?'})`;
                        } else {
                            event.label = `${event.type} event at ${event.formattedTime}`;
                        }
                        
                        return event;
                    });
                }
                
                // Initialize the editor with data from Hammerspoon
                function initEditor(data) {
                    console.log("Initializing editor with:", data);
                    document.getElementById('debug-info').style.display = 'block';
                    document.getElementById('debug-info').innerText = 
                        `Macro contains ${data.events.length} events, spanning ${data.events.length > 0 ? data.events[data.events.length-1].timestamp : 0} seconds`;
                    
                    // Global variables for timeline state
                    window.events = data.events || [];
                    window.timelineWidth = document.getElementById('timeline').offsetWidth;
                    window.macroTotalDuration = window.events.length > 0 ? 
                        Math.max(...window.events.map(e => e.timestamp)) + 1 : 10; // Default to 10s if no events
                    
                    // Make sure we have a reasonable duration (at least 1 second)
                    if (window.macroTotalDuration <= 0) window.macroTotalDuration = 1;
                    
                    // Generate timeline with proper scaling
                    generateTimeline();
                    
                    // Create event markers
                    createEventMarkers();
                    
                    // Setup playback controls
                    setupPlaybackControls();
                    
                    // Enable drag functionality for event markers
                    enableDragForEventMarkers();
                    
                    // Display macro info
                    updateMacroInfo();
                    
                    console.log("Editor initialization complete");
                }
                
                // Generate time markers on the timeline
                function generateTimeline() {
                    const timeline = document.getElementById('timeline');
                    timeline.innerHTML = ''; // Clear existing markers
                    
                    // Calculate appropriate interval for time markers
                    const duration = window.macroTotalDuration;
                    let interval = 1; // Default 1 second interval
                    
                    if (duration > 120) interval = 30;      // 2+ minutes: 30 sec intervals
                    else if (duration > 60) interval = 10;  // 1+ minute: 10 sec intervals
                    else if (duration > 30) interval = 5;   // 30+ seconds: 5 sec intervals
                    else if (duration > 10) interval = 2;   // 10+ seconds: 2 sec intervals
                    
                    console.log(`Timeline duration: ${duration}s, using ${interval}s interval markers`);
                    
                    // Generate time markers based on the interval
                    for (let time = 0; time <= duration; time += interval) {
                        const marker = document.createElement('div');
                        marker.className = 'time-marker';
                        
                        // Position marker proportionally along the timeline
                        const position = (time / duration) * 100;
                        marker.style.left = `${position}%`;
                        
                        // Format time as MM:SS for the marker label
                        const minutes = Math.floor(time / 60);
                        const seconds = time % 60;
                        const timeLabel = document.createElement('span');
                        timeLabel.innerText = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
                        marker.appendChild(timeLabel);
                        
                        timeline.appendChild(marker);
                    }
                }
                
                // Create event markers on the timeline
                function createEventMarkers() {
                    const container = document.getElementById('events-container');
                    container.innerHTML = ''; // Clear existing markers
                    
                    if (!window.events || window.events.length === 0) {
                        console.warn("No events to display");
                        return;
                    }
                    
                    window.events.forEach((event, index) => {
                        if (typeof event.timestamp !== 'number') {
                            console.warn(`Event ${index} missing valid timestamp, skipping`);
                            return;
                        }
                        
                        // Create marker element
                        const marker = document.createElement('div');
                        marker.className = 'event-marker';
                        marker.setAttribute('data-index', index);
                        
                        // Set position based on timestamp
                        const position = (event.timestamp / window.macroTotalDuration) * 100;
                        marker.style.left = `${position}%`;
                        
                        // Set marker color based on event type
                        if (event.type === 'keypress') {
                            marker.style.backgroundColor = event.state === 'down' ? '#4CAF50' : '#F44336';
                        } else if (event.type === 'click') {
                            marker.style.backgroundColor = '#2196F3';
                        } else {
                            marker.style.backgroundColor = '#FF9800';
                        }
                        
                        // Add tooltip with event details
                        marker.title = event.label || `Event at ${event.formattedTime || event.timestamp.toFixed(2)}s`;
                        
                        // Event indicator visible on hover
                        const indicator = document.createElement('div');
                        indicator.className = 'event-indicator';
                        indicator.innerText = event.character || event.type || '?';
                        marker.appendChild(indicator);
                        
                        container.appendChild(marker);
                    });
                    
                    console.log(`Created ${window.events.length} event markers`);
                }
                
                // Enable drag functionality for event markers
                function enableDragForEventMarkers() {
                    const events = document.getElementsByClassName('event-marker');
                    const timeline = document.getElementById('timeline');
                    
                    Array.from(events).forEach(marker => {
                        marker.addEventListener('mousedown', function(e) {
                            e.preventDefault();
                            
                            const index = parseInt(this.getAttribute('data-index'));
                            const timelineRect = timeline.getBoundingClientRect();
                            
                            function moveMarker(moveEvent) {
                                // Calculate position within timeline bounds
                                let relativeX = moveEvent.clientX - timelineRect.left;
                                relativeX = Math.max(0, Math.min(relativeX, timelineRect.width));
                                
                                // Update marker position
                                const newPosition = (relativeX / timelineRect.width) * 100;
                                marker.style.left = `${newPosition}%`;
                                
                                // Update timestamp in events data
                                const newTimestamp = (relativeX / timelineRect.width) * window.macroTotalDuration;
                                window.events[index].timestamp = newTimestamp;
                                
                                // Update formatted time
                                const minutes = Math.floor(newTimestamp / 60);
                                const seconds = newTimestamp % 60;
                                window.events[index].formattedTime = 
                                    `${minutes.toString().padStart(2, '0')}:${seconds.toFixed(2).padStart(5, '0')}`;
                                
                                // Update marker tooltip
                                marker.title = window.events[index].label || 
                                    `Event at ${window.events[index].formattedTime}s`;
                                
                                // Update macro info
                                updateMacroInfo();
                            }
                            
                            document.addEventListener('mousemove', moveMarker);
                            document.addEventListener('mouseup', function() {
                                document.removeEventListener('mousemove', moveMarker);
                                // Update all events after dragging is complete
                                updateAfterDrag();
                            });
                        });
                    });
                }
                
                // Update macro information display
                function updateMacroInfo() {
                    if (!window.events || window.events.length === 0) return;
                    
                    // Calculate total duration based on the last event's timestamp
                    const lastTimestamp = window.events.reduce((max, event) => 
                        Math.max(max, event.timestamp || 0), 0);
                    
                    // Update duration display
                    document.getElementById('macro-duration').innerText = 
                        `Duration: ${formatTime(lastTimestamp)}`;
                        
                    // Update events count
                    document.getElementById('events-count').innerText = 
                        `Events: ${window.events.length}`;
                }
                
                // Format time in MM:SS.ms format
                function formatTime(seconds) {
                    const mins = Math.floor(seconds / 60);
                    const secs = seconds % 60;
                    return `${mins.toString().padStart(2, '0')}:${secs.toFixed(2).padStart(5, '0')}`;
                }
                
                // Setup playback controls
                function setupPlaybackControls() {
                    // Set default playback speed
                    window.playbackSpeed = 1.0;
                    document.getElementById('playback-speed').innerText = `${window.playbackSpeed.toFixed(1)}x`;
                    
                    // Speed up button
                    document.getElementById('speed-up').addEventListener('click', function() {
                        window.playbackSpeed = Math.min(window.playbackSpeed + 0.1, 3.0);
                        document.getElementById('playback-speed').innerText = `${window.playbackSpeed.toFixed(1)}x`;
                    });
                    
                    // Slow down button
                    document.getElementById('slow-down').addEventListener('click', function() {
                        window.playbackSpeed = Math.max(window.playbackSpeed - 0.1, 0.1);
                        document.getElementById('playback-speed').innerText = `${window.playbackSpeed.toFixed(1)}x`;
                    });
                    
                    // Apply button that sends updated event data back to Lua
                    document.getElementById('apply-button').addEventListener('click', function() {
                        try {
                            // Prepare data to send back to Lua
                            const result = {
                                events: window.events,
                                playbackSpeed: window.playbackSpeed
                            };
                            
                            console.log("Sending updated data to Lua:", result);
                            window.webkit.messageHandlers.macroUpdated.postMessage(JSON.stringify(result));
                        } catch (err) {
                            console.error("Error applying changes:", err);
                            document.getElementById('debug-info').style.display = 'block';
                            document.getElementById('debug-info').innerText = "Error applying changes: " + err.message;
                        }
                    });
                }
                
                // Function to recalculate delays between events
                function recalculateDelays() {
                    // Sort events by timestamp
                    window.events.sort((a, b) => a.timestamp - b.timestamp);
                    
                    // Recalculate delays between events
                    for (let i = 0; i < window.events.length; i++) {
                        if (i > 0) {
                            window.events[i].delay = window.events[i].timestamp - window.events[i-1].timestamp;
                            window.events[i].formattedDelay = window.events[i].delay.toFixed(3);
                        } else {
                            window.events[i].delay = 0;
                            window.events[i].formattedDelay = "0.000";
                        }
                    }
                }
                
                // Update event markers after changing positions
                function updateAfterDrag() {
                    // Recalculate delays
                    recalculateDelays();
                    
                    // Update all markers on the timeline
                    createEventMarkers();
                    
                    // Update macro info display
                    updateMacroInfo();
                    
                    // Send data to Hammerspoon
                    try {
                        window.webkit.messageHandlers.updateEventTimings.postMessage({
                            eventData: window.events
                        });
                    } catch (err) {
                        console.error("Error sending timing data to Hammerspoon:", err);
                    }
                }
                
                // Make functions available to Hammerspoon
                window.initEditor = initEditor;
            </script>
        </body>
        </html>
    ]]
    
    -- Load the HTML content
    editorUI.window = hs.webview.newBrowser(hs.geometry.rect(100, 100, EDITOR_WIDTH, EDITOR_HEIGHT))
    editorUI.window:windowTitle("Macro Timing Editor - " .. macro.name)
    editorUI.window:allowNewWindows(false)
    editorUI.window:allowTextEntry(true)
    editorUI.window:windowStyle({"titled", "closable", "resizable"})
    
    -- Load the HTML content
    editorUI.window:html(html)
    
    -- Set up message handlers
    editorUI.window:windowCallback(function(action, webView)
        if action == 'closing' then
            editorUI = nil
        end
    end)
    
    -- Handle messages from JavaScript
    editorUI.window:navigationCallback(function(action, webView, params)
        if action == 'didReceiveMessage' then
            local message = params.body
            local name = params.name
            
            if name == 'selectEvent' then
                selectedEvent = message.selectedEvent + 1  -- Convert from 0-based to 1-based
                log.d("Selected event " .. selectedEvent)
            elseif name == 'updateEventTimings' then
                -- Update event timings in the macro
                for i, event in ipairs(message.eventData) do
                    macro.events[i].timestamp = event.timestamp
                    macro.events[i].delay = event.delay
                    macro.events[i].formattedDelay = event.formattedDelay
                    macro.events[i].formattedTime = event.formattedTime
                end
            elseif name == 'updateSpeed' then
                timeScale = message.speed
                log.d("Updated speed to " .. timeScale)
            elseif name == 'applyChanges' then
                -- Apply changes to the macro
                for i, event in ipairs(message.eventData) do
                    macro.events[i].timestamp = event.timestamp
                    macro.events[i].delay = event.delay
                    macro.events[i].formattedDelay = event.formattedDelay
                    macro.events[i].formattedTime = event.formattedTime
                end
                
                -- Update timing info
                if #macro.events > 0 then
                    macro.totalSeconds = macro.events[#macro.events].timestamp
                    
                    -- Format the duration
                    local minutes = math.floor(macro.totalSeconds / 60)
                    local seconds = macro.totalSeconds % 60
                    macro.duration = string.format("%02d:%05.2f", minutes, seconds)
                end
                
                -- Save changes
                saveMacros()
                hs.alert.show("Macro timing updated")
                
                -- Close editor
                if editorUI and editorUI.window then
                    if editorUI.window.close then
                        editorUI.window:close()
                    elseif editorUI.window.delete then
                        editorUI.window:delete()
                    end
                end
                editorUI = nil
            elseif name == 'playMacro' then
                -- Play the current macro with modified timing
                local tempMacro = hs.json.decode(hs.json.encode(macro))  -- Deep copy
                
                -- Apply speed multiplier
                for i, event in ipairs(tempMacro.events) do
                    if i > 1 then
                        event.delay = event.delay / timeScale
                    end
                end
                
                -- Play the macro
                playMacro(tempMacro)
            elseif name == 'cancelEdit' then
                -- Close without saving
                if editorUI and editorUI.window then
                    if editorUI.window.close then
                        editorUI.window:close()
                    elseif editorUI.window.delete then
                        editorUI.window:delete()
                    end
                end
                editorUI = nil
            elseif name == 'macroUpdated' then
                -- Parse the received JSON data
                local success, result = pcall(function() return hs.json.decode(message) end)
                
                if not success or not result then
                    log.e("Failed to parse macroUpdated data: " .. tostring(message))
                    return
                end
                
                log.d("Received macro update with " .. #(result.events or {}) .. " events")
                
                -- Update the macro events
                if result.events and #result.events > 0 then
                    macro.events = result.events
                    
                    -- Update timing info based on the last event's timestamp
                    local lastEvent = macro.events[#macro.events]
                    if lastEvent and lastEvent.timestamp then
                        macro.totalSeconds = lastEvent.timestamp
                        
                        -- Format the duration
                        local minutes = math.floor(macro.totalSeconds / 60)
                        local seconds = macro.totalSeconds % 60
                        macro.duration = string.format("%02d:%05.2f", minutes, seconds)
                    end
                end
                
                -- Update playback speed if provided
                if result.playbackSpeed then
                    timeScale = result.playbackSpeed
                    log.d("Updated playback speed to " .. timeScale)
                end
                
                -- Save changes
                saveMacros()
                hs.alert.show("Macro timing updated")
                
                -- Close editor
                if editorUI and editorUI.window then
                    if editorUI.window.close then
                        editorUI.window:close()
                    elseif editorUI.window.delete then
                        editorUI.window:delete()
                    end
                end
                editorUI = nil
            end
        end
        
        return true
    end)
    
    -- Initialize the editor with macro data
    local jsonData = hs.json.encode({events = macro.events})
    editorUI.window:evaluateJavaScript([[
        // Initialize with proper error handling
        try {
            console.log("Initializing with data...");
            
            // Function to preprocess event data
            function preprocessEvents(events) {
                if (!events || events.length === 0) {
                    console.error("No events to process");
                    return [];
                }
                
                console.log(`Processing ${events.length} events`);
                
                // Process each event to ensure it has the necessary properties
                return events.map((event, index) => {
                    // Ensure the event has a type
                    if (!event.type) {
                        console.warn(`Event ${index} has no type, defaulting to 'unknown'`);
                        event.type = 'unknown';
                    }
                    
                    // Ensure proper formatting for time fields
                    if (!event.formattedTime && event.timestamp) {
                        const minutes = Math.floor(event.timestamp / 60);
                        const seconds = event.timestamp % 60;
                        event.formattedTime = `${minutes.toString().padStart(2, '0')}:${seconds.toFixed(2).padStart(5, '0')}`;
                    }
                    
                    // Create readable labels based on event type
                    if (event.type === 'keypress') {
                        event.label = `Key: ${event.character || event.keyCode} ${event.state || ''}`;
                    } else if (event.type === 'click') {
                        event.label = `${event.button} click at (${Math.round(event.x)},${Math.round(event.y)})`;
                    }
                    
                    return event;
                });
            }
            
            // Ensure data is valid and events array exists
            const data = ]] .. jsonData .. [[;
            
            if (!data || !data.events || !Array.isArray(data.events)) {
                throw new Error("Invalid data structure. Events data is missing or invalid.");
            }
            
            // Add debug message showing event count
            console.log(`Data contains ${data.events.length} events`);
            
            // Make timeline visible
            document.querySelector('.timeline-container').style.visibility = 'visible';
            
            // Process and initialize
            const processedEvents = preprocessEvents(data.events);
            data.events = processedEvents;
            
            // Set a timeout to ensure DOM is ready
            setTimeout(() => {
                // Initialize editor with processed data
                initEditor(data);
            }, 300);
        } catch (e) {
            console.error("Error initializing:", e);
            document.getElementById('debug-info').style.display = 'block';
            document.getElementById('debug-info').innerText = "Error initializing editor: " + e.message;
        }
    ]])
    
    -- Show the window
    editorUI.window:show()
end

-- Function to show the macro chooser
local function showMacroChooser()
    if #macros == 0 then
        hs.alert.show("No macros available")
        return
    end
    
    local chooser = hs.chooser.new(function(selection)
        if selection then
            local macroIndex = selection.index
            if macroIndex then
                local macro = macros[macroIndex]
                
                -- Check if the alt/option key is held down
                local flags = hs.eventtap.checkKeyboardModifiers()
                if flags.alt then
                    -- Open timing editor if alt is held
                    showTimingEditor(macro)
                else
                    -- Otherwise play the macro
                    playMacro(macro)
                end
            end
        end
    end)
    
    local choices = {}
    for i, macro in ipairs(macros) do
        -- Get duration string from the macro or calculate it
        local durationStr = macro.duration or "Unknown duration"
        
        table.insert(choices, {
            text = macro.name,
            subText = string.format("%d events, %s total (hold ⌥ to edit timing)", 
                    #macro.events, durationStr),
            index = i
        })
    end
    
    chooser:choices(choices)
    chooser:placeholderText("Select a macro to play (hold ⌥ to edit timing)")
    chooser:show()
end

-- Function to call the JavaScript initEditor function
local function callInitEditor(macro)
    if editorUI and editorUI.window then
        local jsonData = hs.json.encode({events = macro.events})
        local script = string.format([[
            try {
                // Make sure the DOM is fully loaded
                if (window.initEditor) {
                    console.log("Calling initEditor from Lua");
                    const data = %s;
                    window.initEditor(data);
                } else {
                    console.error("initEditor function not found");
                }
            } catch (e) {
                console.error("Error calling initEditor:", e);
            }
        ]], jsonData)
        
        editorUI.window:evaluateJavaScript(script)
    else
        log.e("Cannot call initEditor: editor window not available")
    end
end

-- Set up the module
function M.setup(cfg)
    log.i("Setting up Macro module")
    
    -- Save the config
    config = cfg
    
    -- Configure logging based on debug settings
    configureLogging(config)
    
    -- Load existing macros
    loadMacros()
    
    -- Define macro configuration if not present
    if not config.macros then
        log.w("No macro configuration found, using defaults")
        config.macros = {
            enabled = true,
            maxMacros = MAX_MACROS,
            shortcuts = {
                record = {
                    mods = {"alt", "cmd"},
                    key = "[" 
                },
                play = {
                    mods = {"alt", "cmd"},
                    key = "]"
                },
                chooser = {
                    mods = {"alt", "cmd"},
                    key = "\\"
                },
                editor = {
                    mods = {"alt", "cmd"},
                    key = "e"
                }
            }
        }
    end
    
    -- Use the configured max macros
    if config.macros.maxMacros then
        MAX_MACROS = config.macros.maxMacros
    end
    
    -- Check if macros feature is enabled
    if config.macros.enabled == false then
        log.i("Macro module disabled in config")
        return
    end
    
    -- Register keyboard shortcuts from config
    if config.macros.shortcuts then
        -- Record/stop shortcut
        if config.macros.shortcuts.record then
            local mods = config.macros.shortcuts.record.mods
            local key = config.macros.shortcuts.record.key
            hs.hotkey.bind(mods, key, function()
                if isRecording then
                    stopRecording()
                else
                    startRecording()
                end
            end)
            log.i(string.format("Registered macro record toggle shortcut: %s + %s", 
                  table.concat(mods, "+"), key))
        end
        
        -- Play shortcut
        if config.macros.shortcuts.play then
            local mods = config.macros.shortcuts.play.mods
            local key = config.macros.shortcuts.play.key
            hs.hotkey.bind(mods, key, function()
                if #macros > 0 then
                    -- Play the most recently added macro
                    playMacro(macros[#macros])
                else
                    hs.alert.show("No macros available to play")
                end
            end)
            log.i(string.format("Registered macro play shortcut: %s + %s", 
                  table.concat(mods, "+"), key))
        end
        
        -- Chooser shortcut
        if config.macros.shortcuts.chooser then
            local mods = config.macros.shortcuts.chooser.mods
            local key = config.macros.shortcuts.chooser.key
            hs.hotkey.bind(mods, key, function()
                showMacroChooser()
            end)
            log.i(string.format("Registered macro chooser shortcut: %s + %s", 
                  table.concat(mods, "+"), key))
        end
        
        -- Add shortcut for direct timing editor access (if defined)
        if config.macros.shortcuts.editor then
            local mods = config.macros.shortcuts.editor.mods
            local key = config.macros.shortcuts.editor.key
            hs.hotkey.bind(mods, key, function()
                if #macros > 0 then
                    -- Edit the most recently added macro
                    showTimingEditor(macros[#macros])
                else
                    hs.alert.show("No macros available to edit")
                end
            end)
            log.i(string.format("Registered macro editor shortcut: %s + %s", 
                  table.concat(mods, "+"), key))
        end
    else
        -- Fallback to default shortcuts if not configured
        log.w("No macro shortcuts configured, using defaults")
        
        -- Option + Command + [ to start/stop recording
        hs.hotkey.bind({"alt", "cmd"}, "[", function()
            if isRecording then
                stopRecording()
            else
                startRecording()
            end
        end)
        
        -- Option + Command + ] to play the most recent macro
        hs.hotkey.bind({"alt", "cmd"}, "]", function()
            if #macros > 0 then
                -- Play the most recently added macro
                playMacro(macros[#macros])
            else
                hs.alert.show("No macros available to play")
            end
        end)
        
        -- Option + Command + \ to show chooser
        hs.hotkey.bind({"alt", "cmd"}, "\\", function()
            showMacroChooser()
        end)
        
        -- Option + Command + e to open editor
        hs.hotkey.bind({"alt", "cmd"}, "e", function()
            if #macros > 0 then
                -- Edit the most recently added macro
                showTimingEditor(macros[#macros])
            else
                hs.alert.show("No macros available to edit")
            end
        end)
    end
    
    log.i("Macro module initialized")
end

return M 