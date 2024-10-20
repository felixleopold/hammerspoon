local M = {}
local log = hs.logger.new('Setup', 'debug')

function M.getConfig()
    local config_path = os.getenv("HOME") .. "/.hammerspoon/user_config.json"
    local file = io.open(config_path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local config = hs.json.decode(content)
        if config then
            return config
        else
            log.e("Failed to parse user_config.json")
        end
    else
        log.e("Failed to open user_config.json")
    end
    return {}
end

function M.runSetup()
    local setupWizardPath = hs.configdir .. "/setup_wizard.py"
    local venvPath = hs.configdir .. "/hammerspoon-venv"
    log.i("Attempting to run setup wizard from: " .. setupWizardPath)
    
    if hs.fs.attributes(setupWizardPath) then
        log.i("Setup wizard file found, attempting to execute")
        local setupTask = hs.task.new("/bin/bash", function(exitCode, stdOut, stdErr)
            if exitCode == 0 then
                log.i("Setup wizard execution completed successfully")
                log.i("Standard output: " .. stdOut)
            else
                log.e("Failed to run setup wizard")
                log.e("Exit code: " .. tostring(exitCode))
                log.e("Standard error: " .. stdErr)
                hs.alert.show("Failed to run setup wizard. Please check the Hammerspoon console.")
            end
        end, {"-c", string.format([[
            if [ ! -d "%s" ]; then
                python3 -m venv %s
            fi
            source %s/bin/activate
            pip install --upgrade pip
            pip install PyQt6
            python3 %s
        ]], venvPath, venvPath, venvPath, setupWizardPath)})
        setupTask:start()
    else
        log.e("Setup wizard not found at path: " .. setupWizardPath)
        hs.alert.show("Setup wizard not found")
    end
end

function M.bindSetupWizard()
    local config = M.getConfig()
    local setupWizardShortcut = config.shortcuts.general.setupWizard

    if type(setupWizardShortcut) ~= "table" or #setupWizardShortcut < 2 then
        log.w("Invalid setup wizard shortcut configuration, using default")
        setupWizardShortcut = {"ctrl", "alt", "cmd", "shift", "S"}
    end

    local modifiers = {}
    for i = 1, #setupWizardShortcut - 1 do
        table.insert(modifiers, setupWizardShortcut[i])
    end
    local key = setupWizardShortcut[#setupWizardShortcut]

    hs.hotkey.bind(modifiers, key, M.runSetup)
end

return M
