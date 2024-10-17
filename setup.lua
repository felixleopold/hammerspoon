local version = require("version")

local M = {}
local log = hs.logger.new('Setup', 'debug')

-- Default configuration
local defaultConfig = {
    folders = {
        Applications = "/Applications",
        Desktop = "~/Desktop",
        Documents = "~/Documents",
        Downloads = "~/Downloads",
        Home = "~",
        -- Separation
        Obsidian = "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyBrain",
        School = "~/Documents/Radboud",
        Folder8 = "~/Documents/Folder8",
        Folder9 = "~/Documents/Folder9",
        Folder10 = "~/Documents/Folder10",
        Folder11 = "~/Documents/Folder11",
        Folder12 = "~/Documents/Folder12"
    },
    applications = {
        PrimaryBrowser = "Zen Browser",
        SecondaryBrowser = "Arc",
        Terminal = "Warp",
        Editor = "Visual Studio Code",
        SystemSettings = "System Settings",
        Spotify = "Spotify",
        Mail = "Mail",
        Obsidian = "Obsidian",
        WhatsApp = "WhatsApp",
        Finder = "Finder",
        Cursor = "Cursor"
    },
    shortcuts = {
        general = {
            copyUrl = {"cmd", "shift", "C"},
            setupWizard = {"ctrl", "alt", "cmd", "shift", "S"},
        },
        folderShortcuts = {
            Applications = {"cmd", "shift", "A"},
            Desktop = {"cmd", "shift", "D"},
            Documents = {"cmd", "shift", "F"},
            Downloads = {"cmd", "shift", "L"},
            Home = {"cmd", "shift", "H"},
            Obsidian = {"cmd", "shift", "O"},
            School = {"cmd", "shift", "R"},
            Folder8 = {"cmd", "shift", "8"},
            Folder9 = {"cmd", "shift", "9"},
            Folder10 = {"cmd", "shift", "0"},
            Folder11 = {"cmd", "shift", "-"},
            Folder12 = {"cmd", "shift", "="}
        },
        appShortcuts = {
            systemSettings = {"ctrl", "alt", "cmd", "P"},
            secondaryBrowser = {"ctrl", "alt", "cmd", "A"},
            primaryBrowser = {"ctrl", "alt", "cmd", "Z"},
            terminal = {"ctrl", "alt", "cmd", "T"},
            spotify = {"ctrl", "alt", "cmd", "S"},
            mail = {"ctrl", "alt", "cmd", "M"},
            obsidian = {"ctrl", "alt", "cmd", "O"},
            whatsapp = {"ctrl", "alt", "cmd", "W"},
            finder = {"ctrl", "alt", "cmd", "F"},
            editor = {"ctrl", "alt", "cmd", "V"},
            cursor = {"ctrl", "alt", "cmd", "C"}
        },
        windowManagement = {
            leftHalf = {"alt", "A"},
            rightHalf = {"alt", "D"},
            topHalf = {"alt", "W"},
            bottomHalf = {"alt", "S"},
            fullScreen = {"alt", "F"},
            center = {"alt", "C"},
            leftScreen = {"ctrl", "alt", "A"},
            rightScreen = {"ctrl", "alt", "D"},
            nextWindow = {"alt", "E"},
            previousWindow = {"alt", "Q"},
            saveLayout = {"alt", "cmd", "S"},
            loadLayout = {"alt", "cmd", "L"}
        }
    },
    fabric = {
        models = {
            default = "gpt-4o-mini",
            model1 = "llama-3.2-90b-text-preview",
            model2 = "gpt-4o",
        },
        patternModels = {
            -- Default assignments, can be customized by user
            correct = "default",
            improve = "default",
            translate = "default",
            overview = "default",
            latex = "default",
            latexPlus = "default",
            noteName = "default",
            general = "default",
        }
    },
    windowManagement = {
        animationDuration = 0
    }
}

-- Define the order for folders
local folderOrder = {
    "Applications", "Desktop", "Documents", "Downloads", "Home",
    "Obsidian", "School",
    "Folder8", "Folder9", "Folder10", "Folder11", "Folder12"
}

-- Function to prompt user for input
local function promptForInput(prompt, defaultValue)
    local button, value = hs.dialog.textPrompt(prompt, "", defaultValue or "", "OK", "Cancel")
    if button == "OK" then
        return value
    end
    return defaultValue
end

-- Function to prompt user for shortcut
local function promptForShortcut(name, default)
    local shortcutStr = promptForInput("Enter shortcut for " .. name .. " (e.g., cmd,shift,C):", table.concat(default, ","))
    return hs.fnutils.map(hs.fnutils.split(shortcutStr, ","), string.lower)
end

local function configureIndividualItems(config, category, items)
    local options = {}
    local seenNames = {}  -- To track seen names and avoid duplicates
    
    if category == "folders" then
        -- For folders, use the predefined order
        for _, name in ipairs(folderOrder) do
            local path = items[name]
            if path then
                table.insert(options, {text = name, subText = path, name = name})
                seenNames[name] = true
            end
        end
        -- Add any additional folders not in the predefined order
        for name, path in pairs(items) do
            if not seenNames[name] then
                table.insert(options, {text = name, subText = path, name = name})
            end
        end
    else
        -- For other categories, use the existing logic
        for name, value in pairs(items) do
            local displayName
            if category == "applications" then
                displayName = name:gsub("^%l", string.upper)
            else
                displayName = name:gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end)
            end
            
            if not seenNames[displayName] then
                local subText = type(value) == "table" and table.concat(value, ",") or tostring(value)
                table.insert(options, {text = displayName, subText = subText, name = name})
                seenNames[displayName] = true
            end
        end
    end

    -- For folders, don't sort alphabetically
    if category ~= "folders" then
        table.sort(options, function(a, b) return a.text < b.text end)
    end

    return options
end

local function showChooser(title, options, callback)
    local chooser = hs.chooser.new(callback)
    chooser:choices(options)
    chooser:show()
    return chooser
end

local function configureModels(config, callback)
    local modelOptions = {}
    for name, model in pairs(config.fabric.models) do
        table.insert(modelOptions, {text = name, subText = model})
    end

    local function modelCallback(choice)
        if not choice then
            callback()  -- Return to previous menu if no choice is made
            return
        end
        local name = choice.text
        local newModel = promptForInput("Enter new model for " .. name .. ":", config.fabric.models[name])
        config.fabric.models[name] = newModel
        configureModels(config, callback)  -- Show the model chooser again
    end

    showChooser("Configure Models", modelOptions, modelCallback)
end

local function assignModelsToPatterns(config, callback)
    local patternOptions = {}
    for pattern, model in pairs(config.fabric.patternModels) do
        table.insert(patternOptions, {text = pattern, subText = "Current model: " .. model})
    end

    local function patternCallback(choice)
        if not choice then
            callback()  -- Return to previous menu if no choice is made
            return
        end
        local pattern = choice.text
        local modelOptions = {}
        for name, _ in pairs(config.fabric.models) do
            table.insert(modelOptions, {text = name})
        end
        
        local function modelChoiceCallback(modelChoice)
            if modelChoice then
                config.fabric.patternModels[pattern] = modelChoice.text
            end
            assignModelsToPatterns(config, callback)  -- Show the pattern chooser again
        end
        
        showChooser("Choose Model for " .. pattern, modelOptions, modelChoiceCallback)
    end

    showChooser("Assign Models to Patterns", patternOptions, patternCallback)
end

local function configureFabric(config, callback)
    local fabricOptions = {
        {text = "Configure Models", subText = "Set up AI models"},
        {text = "Assign Models to Patterns", subText = "Choose which model to use for each pattern"}
    }

    local function fabricCallback(choice)
        if not choice then
            callback()  -- Return to main menu if no choice is made
            return
        end
        if choice.text == "Configure Models" then
            configureModels(config, function() 
                saveConfig(config)  -- Save after configuring models
                configureFabric(config, callback) 
            end)
        elseif choice.text == "Assign Models to Patterns" then
            assignModelsToPatterns(config, function() 
                saveConfig(config)  -- Save after assigning models to patterns
                configureFabric(config, callback) 
            end)
        end
    end

    showChooser("Configure Fabric", fabricOptions, fabricCallback)
end

-- Function to load user configuration
local function loadConfig()
    local file = io.open(hs.configdir .. "/user_config.json", "r")
    if file then
        local content = file:read("*all")
        file:close()
        local config = hs.json.decode(content) or {}
        -- Merge with default config to ensure all keys exist
        for k, v in pairs(defaultConfig) do
            if type(v) == "table" then
                config[k] = config[k] or {}
                if k == "folders" then
                    -- Special handling for folders to remove old entries
                    local newFolders = {}
                    for _, folderName in ipairs(folderOrder) do
                        newFolders[folderName] = config.folders[folderName] or defaultConfig.folders[folderName]
                    end
                    config.folders = newFolders
                else
                    for subk, subv in pairs(v) do
                        if config[k][subk] == nil then
                            config[k][subk] = subv
                        end
                    end
                end
            else
                if config[k] == nil then
                    config[k] = v
                end
            end
        end
        return config
    end
    return defaultConfig
end

-- Function to save user configuration
local function saveConfig(config)
    local file = io.open(hs.configdir .. "/user_config.json", "w")
    if file then
        file:write(hs.json.encode(config))
        file:close()
        log.i("Configuration saved successfully")
    else
        log.e("Failed to save configuration")
    end
end

function M.runSetup()
    local config = loadConfig()

    local function mainMenu()
        local setupOptions = {
            {text = "Configure Folders", subText = "Set paths for custom folders"},
            {text = "Configure Applications", subText = "Set preferred browsers, terminal, and editor"},
            {text = "Configure Shortcuts", subText = "Customize keyboard shortcuts"},
            {text = "Configure Fabric", subText = "Set up Fabric AI models and patterns"},
            {text = "Configure Window Management", subText = "Set window animation duration"},
            {text = "Save and Exit", subText = "Save changes and exit setup"}
        }

        local function mainCallback(choice)
            if not choice then return end

            if choice.text == "Configure Folders" then
                local folderOptions = configureIndividualItems(config, "folders", config.folders)
                showChooser("Configure Folders", folderOptions, function(folderChoice)
                    if folderChoice then
                        local newPath = promptForInput("Enter new path for " .. folderChoice.text .. ":", config.folders[folderChoice.name])
                        config.folders[folderChoice.name] = newPath
                        saveConfig(config)  -- Save after each change
                    end
                    mainMenu()
                end)
            elseif choice.text == "Configure Applications" then
                local appOptions = configureIndividualItems(config, "applications", config.applications)
                showChooser("Configure Applications", appOptions, function(appChoice)
                    if appChoice then
                        local newApp = promptForInput("Enter preferred application for " .. appChoice.text .. ":", config.applications[appChoice.name])
                        config.applications[appChoice.name] = newApp
                        saveConfig(config)  -- Save after each change
                    end
                    mainMenu()
                end)
            elseif choice.text == "Configure Shortcuts" then
                local shortcutOptions = {
                    {text = "Application Shortcuts", category = "appShortcuts"},
                    {text = "General Shortcuts", category = "general"},
                    {text = "Folder Shortcuts", category = "folderShortcuts"},
                    {text = "Window Management Shortcuts", category = "windowManagement"}
                }
                showChooser("Configure Shortcuts", shortcutOptions, function(shortcutChoice)
                    if shortcutChoice then
                        local options = configureIndividualItems(config, shortcutChoice.category, config.shortcuts[shortcutChoice.category])
                        showChooser("Configure " .. shortcutChoice.text, options, function(choice)
                            if choice then
                                config.shortcuts[shortcutChoice.category][choice.name] = promptForShortcut(choice.text, config.shortcuts[shortcutChoice.category][choice.name])
                                saveConfig(config)  -- Save after each change
                            end
                            mainMenu()
                        end)
                    else
                        mainMenu()
                    end
                end)
            elseif choice.text == "Configure Fabric" then
                configureFabric(config, function()
                    saveConfig(config)  -- Save after Fabric configuration
                    mainMenu()
                end)
            elseif choice.text == "Configure Window Management" then
                config.windowManagement.animationDuration = tonumber(promptForInput("Enter window animation duration (0 for instant):", tostring(config.windowManagement.animationDuration)))
                saveConfig(config)  -- Save after changing window management settings
                mainMenu()
            elseif choice.text == "Save and Exit" then
                saveConfig(config)
                hs.alert.show("Configuration saved. Reloading Hammerspoon...")
                hs.timer.doAfter(1, hs.reload)
            end
        end

        showChooser("Setup Wizard", setupOptions, mainCallback)
    end

    mainMenu()
    log.i("Setup wizard launched for version " .. version.current)
end

-- Function to get configuration
function M.getConfig()
    return loadConfig()
end

-- Bind the setup wizard to the configured shortcut
function M.bindSetupWizard()
    local config = loadConfig()
    local setupWizardShortcut = config.shortcuts.setupWizard

    -- Ensure the shortcut is a table with at least two elements
    if type(setupWizardShortcut) ~= "table" or #setupWizardShortcut < 2 then
        log.w("Invalid setup wizard shortcut configuration, using default")
        setupWizardShortcut = {"ctrl", "alt", "cmd", "shift", "S"}
    end

    -- Ensure the last element of the shortcut is a string (the key)
    if type(setupWizardShortcut[#setupWizardShortcut]) ~= "string" then
        log.w("Invalid key in setup wizard shortcut, using default")
        setupWizardShortcut[#setupWizardShortcut] = "S"
    end

    -- Extract modifiers and key
    local modifiers = {}
    for i = 1, #setupWizardShortcut - 1 do
        table.insert(modifiers, setupWizardShortcut[i])
    end
    local key = setupWizardShortcut[#setupWizardShortcut]

    -- Bind the setup wizard function to the shortcut
    hs.hotkey.bind(modifiers, key, M.runSetup)
end

return M
