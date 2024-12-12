--[[
                                (\.   \      ,/)
                                \(   |\     )/
                                //\  | \   /\\
                                (/ /\_#oo#_/\ \)
                                \/\  ####  /\/
                                    `##'

===================================================================================
                        Hammerspoon Configuration
===================================================================================

This is the main configuration file for Hammerspoon. It defines all your shortcuts,
applications, and window management settings.

How to use this config:
1. Modify the apps section to match your installed applications
2. Adjust shortcuts to your liking
3. Save the file - Hammerspoon will automatically reload

Shortcut Modifiers:
- cmd   (⌘)
- alt   (⌥)
- ctrl  (⌃)
- shift (⇧)
]]--

local config = {
    --[[-----------------------------------------
    Common Modifier Combinations
    Used throughout the configuration for consistent shortcuts
    ------------------------------------------]]
    triggers = {
        app = {"ctrl", "alt", "cmd"},     -- For launching applications (⌘⌃⌥)
        folder = {"cmd", "shift"},        -- For opening folders (⌘⇧)
        window = {"alt"},                 -- For window management (⌥)
        screen = {"cmd", "alt"},          -- For screen management (⌘⌥)
        pattern = {"ctrl", "alt"},        -- For fabric patterns (⌃⌥)
    },

    --[[-----------------------------------------
    Applications
    Define paths to your commonly used applications
    ------------------------------------------]]
    applications = {
        Browser = "Zen Browser",      -- Primary browser
        Browser2 = "Microsoft Edge",  -- Secondary browser
        Editor = "Visual Studio Code", -- Code editor
        Terminal = "kitty",           -- Terminal emulator
        Notes = "Obsidian",           -- Note-taking app
        Mail = "Mail",                -- Email client
        Spotify = "Spotify",          -- Music player
        Finder = "Finder",            -- File manager
        WhatsApp = "WhatsApp",        -- Messaging
        Settings = "System Settings",  -- System preferences
        UTM = "UTM",                  -- Virtual machines
    },

    --[[-----------------------------------------
    Folders
    Define paths to your commonly accessed folders
    ------------------------------------------]]
    folders = {
        home = "~",                    -- Home directory
        desktop = "~/Desktop",         -- Desktop folder
        downloads = "~/Downloads",     -- Downloads folder
        documents = "~/Documents",     -- Documents folder
        pictures = "~/Pictures",       -- Pictures folder
        applications = "/Applications", -- Applications folder
        notes = "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyBrain", -- Obsidian vault
        school = "~/Documents/School", -- School documents
        projects = "~/Documents/Projects", -- Programming projects
    },

    --[[-----------------------------------------
    Keyboard Shortcuts
    Define all keyboard shortcuts for different functions
    ------------------------------------------]]
    shortcuts = {
        -- Application shortcuts (ctrl + alt + cmd + key)
        apps = {
            { app = "Browser", key = "Z" },    -- Primary browser
            { app = "Browser2", key = "A" },   -- Secondary browser
            { app = "Editor", key = "V" },     -- VS Code
            { app = "Terminal", key = "T" },   -- Terminal
            { app = "Notes", key = "O" },      -- Obsidian
            { app = "Mail", key = "M" },       -- Mail
            { app = "Spotify", key = "S" },    -- Spotify
            { app = "Finder", key = "F" },     -- Finder
            { app = "WhatsApp", key = "W" },   -- WhatsApp
            { app = "Settings", key = "P" },   -- System Settings
            { app = "UTM", key = "U" },        -- UTM
        },

        -- Folder shortcuts (cmd + shift + key)
        folders = {
            { path = "home", key = "H" },        -- Home
            { path = "desktop", key = "D" },     -- Desktop
            { path = "downloads", key = "L" },   -- Downloads
            { path = "documents", key = "F" },   -- Documents
            { path = "pictures", key = "P" },    -- Pictures
            { path = "applications", key = "A" }, -- Applications
            { path = "notes", key = "O" },       -- Obsidian vault
            { path = "school", key = "S" },      -- School
            { path = "projects", key = "R" },    -- Projects
        },

        -- Window management shortcuts
        windows = {
            -- Basic window movements (alt + key)
            left = { trigger = "window", key = "A" },      -- Left half
            right = { trigger = "window", key = "D" },     -- Right half
            top = { trigger = "window", key = "W" },       -- Top half
            bottom = { trigger = "window", key = "H" },    -- Bottom half
            center = { trigger = "window", key = "C" },    -- Center
            full = { trigger = "window", key = "F" },      -- Full screen

            -- Screen management (cmd + alt + key)
            nextScreen = { trigger = "screen", key = "D" }, -- Move to next screen
            prevScreen = { trigger = "screen", key = "A" }, -- Move to previous screen

            -- Window cycling (alt + key)
            nextWindow = { trigger = "window", key = "E" }, -- Next window in app
            prevWindow = { trigger = "window", key = "Q" }, -- Previous window in app
        },

        -- Utility shortcuts
        utils = {
            { mods = {"cmd", "shift"}, key = "X", action = "closeFinderWindows" },  -- Close all Finder windows (cmd+shift+X)
            { mods = {"ctrl"}, key = "C", action = "copyBrowserUrl" },         -- Copy URL from browser (ctrl+C)
        },
    },

    --[[-----------------------------------------
    Window Management Settings
    Configure window behavior and animations
    ------------------------------------------]]
    windowManagement = {
        animationDuration = 0,  -- Set to 0 for instant window movements
    },

    --[[-----------------------------------------
    Fabric AI Integration
    Configure AI patterns and shortcuts
    ------------------------------------------]]
    fabric = {
        -- Default settings
        defaultModel = "gpt-4",
        chooserTrigger = {"cmd", "alt", "shift"},  -- Global trigger for pattern chooser
        chooserKey = "P",                          -- Key for pattern chooser
        
        -- Pattern definitions
        patterns = {
            -- Text Analysis Patterns
            {
                id = "summarize",
                name = "Summarize",
                desc = "Create a concise summary",
                trigger = "pattern",
                key = "S",
                model = "gpt-4",
            },
            {
                id = "extract_wisdom",
                name = "Extract Wisdom",
                desc = "Extract key insights",
                trigger = "pattern",
                key = "W",
            },
            {
                id = "improve_writing",
                name = "Improve Writing",
                desc = "Improve writing style and clarity",
                trigger = "pattern",
                key = "I",
            },
            {
                id = "find_action_items",
                name = "Find Action Items",
                desc = "Extract actionable items",
                trigger = "pattern",
                key = "F",
            },

            -- Content Creation Patterns
            {
                id = "write_essay",
                name = "Write Essay",
                desc = "Generate an essay from an idea",
                trigger = "pattern",
                key = "E",
            },
            {
                id = "create_social",
                name = "Create Social Post",
                desc = "Create social media content",
                trigger = "pattern",
                key = "S",
            },
            {
                id = "art_prompt",
                name = "Generate Art Prompt",
                desc = "Create AI art prompt",
                trigger = "pattern",
                key = "A",
            },

            -- YouTube Patterns
            {
                id = "youtube_summary",
                name = "YouTube Summary",
                desc = "Summarize video content",
                command = "extract_wisdom",
                trigger = "pattern",
                key = "Y",
                youtube = true,
            },
            {
                id = "youtube_key_points",
                name = "YouTube Key Points",
                desc = "Extract main points",
                command = "extract_key_points",
                trigger = "pattern",
                key = "K",
                youtube = true,
            },
            {
                id = "youtube_lecture",
                name = "YouTube Lecture Notes",
                desc = "Create lecture notes",
                command = "create_lecture_notes",
                trigger = "pattern",
                key = "L",
                youtube = true,
            },

            -- Code Patterns
            {
                id = "explain_code",
                name = "Explain Code",
                desc = "Get a detailed code explanation",
                trigger = "pattern",
                key = "C",
                model = "gpt-4",
            },
            {
                id = "improve_code",
                name = "Improve Code",
                desc = "Get code improvement suggestions",
                trigger = "pattern",
                key = "I",
                model = "gpt-4",
            },
            {
                id = "document_code",
                name = "Document Code",
                desc = "Generate code documentation",
                trigger = "pattern",
                key = "D",
                model = "gpt-4",
            },
        },
    },
}

return config 