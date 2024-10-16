local version = require("version")

local M = {}
local log = hs.logger.new('Setup', 'debug')

-- Default configuration
local defaultConfig = {
    folders = {
        radboud = "~/Documents/Radboud",
        obsidian = "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyBrain"
    },
    applications = {
        primaryBrowser = "Zen Browser",
        secondaryBrowser = "Arc",
        terminal = "Warp",
        editor = "Visual Studio Code"
    },
    shortcuts = {
        copyUrl = {"cmd", "shift", "C"},
        setupWizard = {"ctrl", "alt", "cmd", "shift", "S"}
    },
    fabric = {
        model = "gpt-4"
    },
    windowManagement = {
        animationDuration = 0
    }
}

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
                for subk, subv in pairs(v) do
                    if config[k][subk] == nil then
                        config[k][subk] = subv
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

-- Function to prompt user for input
local function promptForInput(prompt, defaultValue)
    local button, value = hs.dialog.textPrompt(prompt, "", defaultValue or "", "OK", "Cancel")
    if button == "OK" then
        return value
    end
    return defaultValue
end

-- Function to prompt user for choice
local function promptForChoice(prompt, choices, defaultChoice)
    local chooser = hs.chooser.new(function(choice)
        if choice then
            return choice.text
        end
        return defaultChoice
    end)
    chooser:choices(choices)
    chooser:show()
    local result = chooser:query()
    chooser:hide()
    return result or defaultChoice
end

-- Function to run setup wizard
function M.runSetup()
    local config = loadConfig()

    -- Main setup menu
    local setupOptions = {
        {text = "Configure Folders", subText = "Set paths for Radboud and Obsidian"},
        {text = "Configure Applications", subText = "Set preferred browsers, terminal, and editor"},
        {text = "Configure Shortcuts", subText = "Customize keyboard shortcuts"},
        {text = "Configure Fabric", subText = "Set Fabric AI model"},
        {text = "Configure Window Management", subText = "Set window animation duration"},
        {text = "Save and Exit", subText = "Save changes and exit setup"}
    }

    local chooser = hs.chooser.new(function(choice)
        if not choice then return end

        if choice.text == "Configure Folders" then
            config.folders.radboud = promptForInput("Enter path for Radboud folder:", config.folders.radboud)
            config.folders.obsidian = promptForInput("Enter path for Obsidian vault:", config.folders.obsidian)
        elseif choice.text == "Configure Applications" then
            config.applications.primaryBrowser = promptForInput("Enter preferred primary browser:", config.applications.primaryBrowser)
            config.applications.secondaryBrowser = promptForInput("Enter preferred secondary browser:", config.applications.secondaryBrowser)
            config.applications.terminal = promptForInput("Enter preferred terminal:", config.applications.terminal)
            config.applications.editor = promptForInput("Enter preferred code editor:", config.applications.editor)
        elseif choice.text == "Configure Shortcuts" then
            local function promptForShortcut(name, default)
                local shortcutStr = promptForInput("Enter shortcut for " .. name .. " (e.g., cmd,shift,C):", table.concat(default, ","))
                return hs.fnutils.map(hs.fnutils.split(shortcutStr, ","), string.lower)
            end
            config.shortcuts.copyUrl = promptForShortcut("Copy URL", config.shortcuts.copyUrl)
            config.shortcuts.setupWizard = promptForShortcut("Setup Wizard", config.shortcuts.setupWizard)
        elseif choice.text == "Configure Fabric" then
            config.fabric.model = promptForInput("Enter preferred Fabric AI model:", config.fabric.model)
        elseif choice.text == "Configure Window Management" then
            config.windowManagement.animationDuration = tonumber(promptForInput("Enter window animation duration (0 for instant):", tostring(config.windowManagement.animationDuration)))
        elseif choice.text == "Save and Exit" then
            saveConfig(config)
            hs.alert.show("Configuration saved. Reloading Hammerspoon...")
            hs.timer.doAfter(1, function()
                hs.reload()
            end)
            return
        end

        -- Show the chooser again for the next selection
        chooser:show()
    end)

    chooser:choices(setupOptions)
    chooser:show()

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
