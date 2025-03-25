-- Window inspection tool
-- This function helps debug window detection issues

local function inspectWindows()
    local allWindows = hs.window.allWindows()
    local results = {}
    
    for i, window in ipairs(allWindows) do
        local app = window:application()
        local appName = app and app:name() or "Unknown"
        
        -- Special check for Minecraft (java process)
        local isMinecraftCandidate = appName == "java"
        
        table.insert(results, {
            index = i,
            title = window:title() or "No Title",
            app = appName,
            role = window:role() or "No Role",
            subrole = window:subrole() or "No Subrole",
            id = window:id(),
            isMinecraftCandidate = isMinecraftCandidate
        })
    end
    
    -- Create a formatted output
    local output = "Window Inspection Results:\n\n"
    for _, result in ipairs(results) do
        output = output .. string.format(
            "%d: %s\n   App: %s\n   Role: %s\n   Subrole: %s\n   ID: %d\n   Minecraft Candidate: %s\n\n",
            result.index, result.title, result.app, result.role, result.subrole, result.id,
            result.isMinecraftCandidate and "YES" or "no"
        )
    end
    
    -- Show the results in a large alert
    hs.alert.show(output, {textSize=12}, 10)
    
    -- Also log to console for reference
    print(output)
    
    return results
end

return inspectWindows 