--[[
 (\.   \      ,/)
  \(   |\     )/
  //\  | \   /\\
 (/ /\_#oo#_/\ \)
  \/\  ####  /\/
       `##'

=====================================
Hammerspoon Configuration
=====================================

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
    --[[
    =====================================
    Applications Configuration
    =====================================
    Define the applications you want to control with shortcuts.
    Format: name = "Application Name"
    
    Usage: ctrl + alt + cmd + key
    Example: ctrl + alt + cmd + Z opens primary browser
    ]]--
    apps = {
        browser = "Zen Browser",      -- Primary browser
        browser2 = "Microsoft Edge",  -- Secondary browser
        editor = "Visual Studio Code", -- Code editor
        terminal = "kitty",           -- Terminal emulator
        notes = "Obsidian",           -- Note-taking app
        mail = "Mail",                -- Email client
        spotify = "Spotify",          -- Music player
        finder = "Finder",            -- File manager
        whatsapp = "WhatsApp",        -- Messaging
        settings = "System Settings",  -- System preferences
        utm = "UTM",                  -- Virtual machines
    },

    --[[
    =====================================
    Folders Configuration
    =====================================
    Quick access to common directories.
    Format: name = "path"
    
    Usage: cmd + shift + key
    Example: cmd + shift + D opens Desktop
    ]]--
    folders = {
        home = "~",                    -- Home directory
        desktop = "~/Desktop",         -- Desktop folder
        downloads = "~/Downloads",     -- Downloads folder
        documents = "~/Documents",     -- Documents folder
        pictures = "~/Pictures",       -- Pictures folder
        music = "~/Music",            -- Music folder
        movies = "~/Movies",          -- Movies folder
        applications = "/Applications", -- Applications folder
        notes = "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyBrain", -- Obsidian vault
        school = "~/Documents/School", -- School documents
        projects = "~/Documents/Projects", -- Programming projects
    },

    --[[
    =====================================
    Keyboard Shortcuts
    =====================================
    All keyboard shortcuts are defined here in three categories:
    1. Application shortcuts (ctrl + alt + cmd + key)
    2. Folder shortcuts (cmd + shift + key)
    3. Window management (alt + key)
    ]]--
    keys = {
        -- Application Shortcuts (ctrl + alt + cmd + key)
        apps = {
            { key = "Z", app = "browser" },    -- Primary browser
            { key = "A", app = "browser2" },   -- Secondary browser
            { key = "V", app = "editor" },     -- VS Code
            { key = "T", app = "terminal" },   -- Terminal
            { key = "O", app = "notes" },      -- Obsidian
            { key = "M", app = "mail" },       -- Mail
            { key = "S", app = "spotify" },    -- Spotify
            { key = "F", app = "finder" },     -- Finder
            { key = "W", app = "whatsapp" },   -- WhatsApp
            { key = "P", app = "settings" },   -- System Settings
            { key = "U", app = "utm" },        -- UTM
        },

        -- Folder Shortcuts (cmd + shift + key)
        folders = {
            { key = "H", path = "home" },        -- Home
            { key = "D", path = "desktop" },     -- Desktop
            { key = "L", path = "downloads" },   -- Downloads
            { key = "F", path = "documents" },   -- Documents
            { key = "P", path = "pictures" },    -- Pictures
            { key = "M", path = "music" },       -- Music
            { key = "V", path = "movies" },      -- Movies
            { key = "A", path = "applications" }, -- Applications
            { key = "O", path = "notes" },       -- Obsidian vault
            { key = "S", path = "school" },      -- School
            { key = "R", path = "projects" },    -- Projects
        },

        -- Window Management
        windows = {
            -- Basic window movements
            left = "alt+a",      -- Left half
            right = "alt+d",     -- Right half
            top = "alt+w",       -- Top half
            bottom = "alt+h",    -- Bottom half
            center = "alt+c",    -- Center on screen
            full = "alt+f",      -- Full screen

            -- Screen management
            nextScreen = "ctrl+alt+d", -- Move to next screen
            prevScreen = "ctrl+alt+a", -- Move to previous screen

            -- Window cycling
            nextWindow = "alt+e", -- Next window in app
            prevWindow = "alt+q", -- Previous window in app
        },

        -- URL Management
        copyUrl = { mods = {"cmd", "shift"}, key = "C" }, -- Copy URL from browser
    },

    --[[
    =====================================
    Window Management
    =====================================
    Configure window movement, screen management, and window cycling.
    All shortcuts use the same string format: "modifier1+modifier2+key"
    ]]--
    windows = {
        -- Basic window movements
        left = "alt+a",      -- Left half
        right = "alt+d",     -- Right half
        top = "alt+w",       -- Top half
        bottom = "alt+h",    -- Bottom half
        center = "alt+c",    -- Center on screen
        full = "alt+f",      -- Full screen

        -- Screen management
        nextScreen = "ctrl+alt+d", -- Move to next screen
        prevScreen = "ctrl+alt+a", -- Move to previous screen

        -- Window cycling
        nextWindow = "alt+e", -- Next window in app
        prevWindow = "alt+q", -- Previous window in app
    },

    -- Window animation duration (0 for instant)
    windowAnimation = 0,

    --[[
    =====================================
    Fabric AI Integration
    =====================================
    Configuration for the Fabric AI assistant integration.
    
    Shortcut Format: "cmd+alt+shift+key" or "ctrl+alt+key"
    Available Models: "gpt-4", "gpt-3.5-turbo", "claude-2", etc.
    ]]--
    fabric = {
        -- Default settings
        defaultModel = "gpt-4",
        chooserShortcut = "cmd+alt+shift+p",  -- Global shortcut to open pattern chooser
        
        -- Pattern definitions
        patterns = {
            -- Text Analysis Patterns
            {
                id = "summarize",
                name = "Summarize",
                desc = "Create a concise summary",
                shortcut = "ctrl+alt+s",
                model = "gpt-4",  -- Override default model if needed
            },
            {
                id = "extract_wisdom",
                name = "Extract Wisdom",
                desc = "Extract key insights",
                shortcut = "ctrl+alt+w",
            },
            {
                id = "analyze_claims",
                name = "Analyze Claims",
                desc = "Analyze claims and evidence",
                shortcut = "ctrl+alt+a",
            },
            {
                id = "improve_writing",
                name = "Improve Writing",
                desc = "Improve writing style and clarity",
                shortcut = "ctrl+alt+i",
            },
            {
                id = "find_action_items",
                name = "Find Action Items",
                desc = "Extract actionable items",
                shortcut = "ctrl+alt+f",
            },

            -- Content Creation Patterns
            {
                id = "write_essay",
                name = "Write Essay",
                desc = "Generate an essay from an idea",
                shortcut = "ctrl+alt+shift+e",
            },
            {
                id = "create_social",
                name = "Create Social Post",
                desc = "Create social media content",
                shortcut = "ctrl+alt+shift+s",
            },
            {
                id = "art_prompt",
                name = "Generate Art Prompt",
                desc = "Create AI art prompt",
                shortcut = "ctrl+alt+shift+a",
            },

            -- YouTube Patterns
            {
                id = "youtube_summary",
                name = "YouTube Summary",
                desc = "Summarize video content",
                command = "extract_wisdom",
                shortcut = "ctrl+alt+shift+y",
                youtube = true,
            },
            {
                id = "youtube_key_points",
                name = "YouTube Key Points",
                desc = "Extract main points",
                command = "extract_key_points",
                shortcut = "ctrl+alt+shift+k",
                youtube = true,
            },
            {
                id = "youtube_lecture",
                name = "YouTube Lecture Notes",
                desc = "Create lecture notes",
                command = "create_lecture_notes",
                shortcut = "ctrl+alt+shift+l",
                youtube = true,
            },

            -- Code Patterns
            {
                id = "explain_code",
                name = "Explain Code",
                desc = "Get a detailed code explanation",
                shortcut = "ctrl+alt+shift+c",
                model = "gpt-4",  -- Prefer GPT-4 for code
            },
            {
                id = "improve_code",
                name = "Improve Code",
                desc = "Get code improvement suggestions",
                shortcut = "ctrl+alt+shift+i",
                model = "gpt-4",  -- Prefer GPT-4 for code
            },
            {
                id = "document_code",
                name = "Document Code",
                desc = "Generate code documentation",
                shortcut = "ctrl+alt+shift+d",
                model = "gpt-4",  -- Prefer GPT-4 for code
            },

            -- Research Patterns
            {
                id = "research_deep",
                name = "Deep Research",
                desc = "In-depth analysis of a topic",
                shortcut = "ctrl+alt+cmd+r",
                model = "gpt-4",  -- Prefer GPT-4 for research
            },
            {
                id = "academic_summary",
                name = "Academic Summary",
                desc = "Summarize academic papers",
                shortcut = "ctrl+alt+cmd+a",
                model = "gpt-4",  -- Prefer GPT-4 for academic content
            },
            {
                id = "extract_references",
                name = "Extract References",
                desc = "Extract and format references",
                shortcut = "ctrl+alt+cmd+e",
            },
        },

        -- Pattern categories for the chooser menu
        categories = {
            {
                name = "Text Analysis",
                patterns = { "summarize", "extract_wisdom", "analyze_claims", 
                           "improve_writing", "find_action_items" }
            },
            {
                name = "Content Creation",
                patterns = { "write_essay", "create_social", "art_prompt" }
            },
            {
                name = "YouTube",
                patterns = { "youtube_summary", "youtube_key_points", "youtube_lecture" }
            },
            {
                name = "Code",
                patterns = { "explain_code", "improve_code", "document_code" }
            },
            {
                name = "Research",
                patterns = { "research_deep", "academic_summary", "extract_references" }
            },
        },
    },
}

return config 