local M = {}
local log = hs.logger.new('AppGroups', 'debug')

-- State tracking for app groups
local groupStates = {}
local lastActivationTime = {}

-- Initialize module
function M.setup(config)
    log.i("Setting up application groups")
    
    -- Configure logging based on user settings
    if config.debug then
        local debugEnabled = false
        
        if config.debug.appLaunching then
            log.i("Application launching debug logging enabled")
            debugEnabled = true
        end
        
        if config.debug.appFocusing then
            log.i("Application focusing debug logging enabled")
            debugEnabled = true
        end
        
        if config.debug.appGroups then
            log.i("Application groups debug logging enabled")
            debugEnabled = true
        end
        
        -- Set log level based on whether any app-related debugging is enabled
        if debugEnabled then
            log.setLogLevel('debug')
        else
            log.setLogLevel('info')
        end
    end
    
    -- Initialize group states
    if config.appGroups then
        for groupName, groupConfig in pairs(config.appGroups) do
            groupStates[groupName] = {
                currentIndex = 1,
                lastUsedApp = nil,
                mode = groupConfig.mode or "recent"
            }
            lastActivationTime[groupName] = 0
            log.d(string.format("Initialized group '%s' with mode '%s'", groupName, groupStates[groupName].mode))
        end
    end
end

-- Helper function to get running applications in a group
local function getRunningAppsInGroup(groupConfig, config)
    local runningApps = {}
    
    log.i(string.format("=== Checking for running apps in group with %d apps ===", #groupConfig.apps))
    
    for _, appName in ipairs(groupConfig.apps) do
        local appConfig = config.applications[appName]
        if appConfig then
            local actualAppName = type(appConfig) == "table" and appConfig.name or appConfig
            
            -- Try multiple methods to detect the app
            local app = hs.application.get(actualAppName)
            local isRunning = false
            local detectionMethod = "none"
            
            if app and not app:isHidden() then
                isRunning = true
                detectionMethod = "hs.application.get"
            else
                -- Special handling for system apps like Preview
                local runningApps = hs.application.runningApplications()
                for _, runningApp in ipairs(runningApps) do
                    if runningApp and runningApp:name() == actualAppName and not runningApp:isHidden() then
                        app = runningApp
                        isRunning = true
                        detectionMethod = "runningApplications scan"
                        break
                    end
                end
            end
            
            log.i(string.format("App '%s' (actual: '%s'): running=%s, method=%s, hidden=%s", 
                appName, actualAppName, tostring(isRunning), detectionMethod, 
                tostring(app and app:isHidden() or "N/A")))
            
            if isRunning then
                table.insert(runningApps, {
                    name = appName,
                    config = appConfig,
                    app = app,
                    lastUsed = app and app:focusedWindow() and app:focusedWindow():id() or 0
                })
                log.i(string.format("✓ Added running app: %s", actualAppName))
            else
                log.i(string.format("✗ App '%s' is not running or is hidden", actualAppName))
            end
        else
            log.w(string.format("No configuration found for app '%s' in group", appName))
        end
    end
    
    log.i(string.format("=== Found %d running apps in group ===", #runningApps))
    return runningApps
end

-- Helper function to launch or focus an application
local function launchOrFocus(appConfig)
    log.d("Launching/focusing app: " .. hs.inspect(appConfig))
    
    -- Handle table-based app configuration
    local actualConfig = appConfig
    if type(appConfig) == "table" then
        log.d("Using extended application configuration: " .. hs.inspect(appConfig))
    else
        -- Convert string to standard format for consistent handling
        actualConfig = { name = appConfig }
    end
    
    -- Special handling for Minecraft (Java)
    if actualConfig.name == "java" then
        -- Find all Java windows
        local allWindows = hs.window.allWindows()
        for _, win in ipairs(allWindows) do
            local app = win:application()
            local title = win:title()
            -- Check for any Minecraft version (title starts with "Minecraft")
            if app and app:name() == "java" and title and title:match("^Minecraft%s*[%d%.]*$") then
                log.i("Found Minecraft window: " .. title)
                win:focus()
                return true
            end
        end
        -- If no Minecraft window found, launch the launcher instead
        log.i("No Minecraft window found, launching launcher instead")
        return hs.application.launchOrFocus("Minecraft Launcher")
    end
    
    -- Try to find the application by bundle ID if provided
    if actualConfig.bundleID then
        log.d("Trying to find app by bundle ID: " .. actualConfig.bundleID)
        local app = hs.application.get(actualConfig.bundleID)
        if app then
            log.i("Found application by bundle ID, activating")
            app:activate()
            return true
        else
            log.d("App not found by bundle ID, will try other methods")
        end
    end
    
    -- Try to launch by path if provided
    if actualConfig.path and hs.fs.attributes(actualConfig.path) then
        log.d("Launching app by path: " .. actualConfig.path)
        local success = hs.execute("open \"" .. actualConfig.path .. "\"")
        if success then
            log.i("Successfully launched app by path")
            return true
        else
            log.w("Failed to launch app by path, will try other methods")
        end
    end
    
    -- Try standard launch or focus by name
    log.d("Trying standard launchOrFocus with app name: " .. actualConfig.name)
    if hs.application.launchOrFocus(actualConfig.name) then
        log.i("Successfully launched/focused app using standard method")
        return true
    end
    
    -- Try getting app by name as fallback
    log.d("Trying to get app by name")
    local app = hs.application.get(actualConfig.name)
    if app then
        log.i("Found app by name, activating")
        app:activate()
        return true
    end
    
    -- Last resort: try open -a command
    log.w("All methods failed, trying open -a as last resort")
    hs.execute("open -a \"" .. actualConfig.name .. "\"")
    return false
end

-- Get the next app to launch based on group mode and current state
function M.getNextApp(groupName, groupConfig, config)
    local currentTime = hs.timer.secondsSinceEpoch()
    local timeSinceLastActivation = currentTime - (lastActivationTime[groupName] or 0)
    local groupState = groupStates[groupName]
    
    if not groupState then
        log.e("No group state found for: " .. groupName)
        return nil
    end
    
    log.i(string.format("=== Getting next app for group '%s' ===", groupName))
    log.i(string.format("Mode: %s, Time since last: %.2f, LaunchIfNotRunning: %s", 
        groupState.mode, timeSinceLastActivation, tostring(groupConfig.launchIfNotRunning)))
    
    -- Get running apps first to check if we have any
    local runningApps = getRunningAppsInGroup(groupConfig, config)
    
    -- If launchIfNotRunning is false and no apps are running, return nil immediately
    if not groupConfig.launchIfNotRunning and #runningApps == 0 then
        log.i("❌ No running apps and launchIfNotRunning is false, returning nil")
        return nil
    end
    
    -- If more than 3 seconds have passed, reset to first app
    if timeSinceLastActivation > 3 then
        groupState.currentIndex = 1
        log.i("⏰ Reset to first app due to timeout")
    end
    
    local targetApp = nil
    local targetIndex = 1
    
    if groupState.mode == "recent" then
        log.i("📋 Using RECENT mode")
        -- Recent mode: prioritize running apps, then cycle through all
        if #runningApps > 0 then
            log.i(string.format("✓ Found %d running apps, cycling through them", #runningApps))
            -- Sort by most recently used (this is a simplified approach)
            table.sort(runningApps, function(a, b)
                return (a.lastUsed or 0) > (b.lastUsed or 0)
            end)
            
            -- Check if we're cycling through running apps
            local frontApp = hs.application.frontmostApplication()
            local frontAppName = frontApp and frontApp:name()
            log.i(string.format("Current front app: %s", frontAppName or "none"))
            
            -- Find current app in running apps list
            local currentRunningIndex = 0
            for i, runningApp in ipairs(runningApps) do
                local actualAppName = type(runningApp.config) == "table" and runningApp.config.name or runningApp.config
                if actualAppName == frontAppName then
                    currentRunningIndex = i
                    log.i(string.format("Found current app in running list at index %d", i))
                    break
                end
            end
            
            -- If current app is in the group and we're cycling, go to next
            if currentRunningIndex > 0 and timeSinceLastActivation < 3 then
                targetIndex = (currentRunningIndex % #runningApps) + 1
                targetApp = runningApps[targetIndex].name
                log.i(string.format("🔄 Cycling to next running app: %s (index %d)", targetApp, targetIndex))
            else
                -- Start with most recent
                targetApp = runningApps[1].name
                log.i(string.format("🎯 Starting with most recent app: %s", targetApp))
            end
        else
            log.i("❌ No running apps found in recent mode")
            -- No running apps - we already checked launchIfNotRunning above
            -- This should only be reached if launchIfNotRunning is true
            if groupConfig.launchIfNotRunning then
                targetIndex = groupState.currentIndex
                if targetIndex > #groupConfig.apps then
                    targetIndex = 1
                end
                targetApp = groupConfig.apps[targetIndex]
                log.i(string.format("🚀 No running apps, launching from preset order: %s (index %d)", targetApp, targetIndex))
            else
                log.e("❌ This should not be reached - launchIfNotRunning is false but we got here")
                return nil
            end
        end
    else
        log.i("📋 Using PRESET mode")
        -- Preset mode: always follow the defined order
        targetIndex = groupState.currentIndex
        if targetIndex > #groupConfig.apps then
            targetIndex = 1
        end
        
        local candidateApp = groupConfig.apps[targetIndex]
        
        -- Check if we should only cycle through running apps
        if not groupConfig.launchIfNotRunning then
            log.i("🔒 LaunchIfNotRunning is false, only cycling through running apps")
            -- We already checked if there are running apps above
            -- Find the next running app in preset order
            local attempts = 0
            while attempts < #groupConfig.apps do
                local appConfig = config.applications[candidateApp]
                if appConfig then
                    local actualAppName = type(appConfig) == "table" and appConfig.name or appConfig
                    local app = hs.application.get(actualAppName)
                    if app and not app:isHidden() then
                        targetApp = candidateApp
                        log.i(string.format("✓ Found running app in preset order: %s (index %d)", targetApp, targetIndex))
                        break
                    end
                end
                
                -- Try next app in preset order
                targetIndex = (targetIndex % #groupConfig.apps) + 1
                candidateApp = groupConfig.apps[targetIndex]
                attempts = attempts + 1
            end
            
            if not targetApp then
                log.i("❌ No running apps found in preset order")
                return nil
            end
        else
            -- Launch if not running is allowed
            targetApp = candidateApp
            log.i(string.format("🚀 Preset mode with launch allowed: %s (index %d)", targetApp, targetIndex))
        end
    end
    
    -- Update state for next time
    if groupState.mode == "preset" or #runningApps == 0 then
        groupState.currentIndex = (targetIndex % #groupConfig.apps) + 1
    end
    
    groupState.lastUsedApp = targetApp
    lastActivationTime[groupName] = currentTime
    
    log.i(string.format("🎯 Selected app '%s' for group '%s'", targetApp, groupName))
    return targetApp
end

-- Launch the next app in a group
function M.launchGroupApp(groupName, groupConfig, config)
    log.i(string.format("Launching app from group '%s'", groupName))
    
    local targetApp = M.getNextApp(groupName, groupConfig, config)
    if not targetApp then
        log.i("No target app determined for group: " .. groupName)
        local groupState = groupStates[groupName]
        local modeIndicator = groupState.mode == "recent" and "🕒" or "📋"
        hs.alert.show(string.format("%s No running apps in group '%s'", modeIndicator, groupName), 2)
        return
    end
    
    local appConfig = config.applications[targetApp]
    if not appConfig then
        log.e("No application configuration found for: " .. targetApp)
        hs.alert.show("❌ No configuration found for app: " .. targetApp, 2)
        return
    end
    
    local success = launchOrFocus(appConfig)
    if success then
        local displayName = type(appConfig) == "table" and appConfig.name or appConfig
        log.i(string.format("Successfully launched/focused '%s' from group '%s'", displayName, groupName))
        
        -- Show brief indicator of which app was selected
        local groupState = groupStates[groupName]
        local modeIndicator = groupState.mode == "recent" and "🕒" or "📋"
        hs.alert.show(string.format("%s %s", modeIndicator, displayName), 1)
    else
        log.e("Failed to launch/focus app: " .. targetApp)
        hs.alert.show("❌ Failed to launch app: " .. targetApp, 2)
    end
end

-- Get group state for debugging
function M.getGroupState(groupName)
    return groupStates[groupName]
end

-- Reset group state
function M.resetGroupState(groupName)
    if groupStates[groupName] then
        groupStates[groupName].currentIndex = 1
        groupStates[groupName].lastUsedApp = nil
        lastActivationTime[groupName] = 0
        log.i("Reset state for group: " .. groupName)
    end
end

return M 