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
]]
--

local config = {
	--[[-----------------------------------------
    Common Modifier Combinations
    Used throughout the configuration for consistent shortcuts
    ------------------------------------------]]
	triggers = {
		app = { "ctrl", "alt", "cmd"}, -- For launching applications (⌘⌃⌥)
		folder = { "cmd", "shift" }, -- For opening folders (⌘⇧)
		window = { "alt" }, -- For window management (⌥)
		screen = { "cmd", "alt" }, -- For screen management (⌘⌥)
		pattern = { "ctrl", "alt" }, -- For fabric patterns (⌃⌥)
	},

	--[[-----------------------------------------
    Applications
    Define paths to your commonly used applications
    ------------------------------------------]]
	applications = {
		Browser = "Zen Browser", -- Primary browser
		Browser2 = "Microsoft Edge", -- Secondary browser
		Editor = "Cursor", -- Code editor
		Editor2 = "Visual Studio Code", -- Second editor instance
		Terminal = "kitty", -- Terminal emulator
		Notes = "Obsidian", -- Note-taking app
		Mail = "Mail", -- Email client
		Spotify = "Spotify", -- Music player
		Finder = "Finder", -- File manager
		WhatsApp = "WhatsApp", -- Messaging
		Settings = "System Settings", -- System preferences
		UTM = "UTM", -- Virtual machines
		ChatGPT = "ChatGPT",
		Preview = "Preview",
		Discord = "Discord", -- Messaging app
		Word = "Microsoft Word", -- Word processor
	},

	--[[-----------------------------------------
    Folders
    Define paths to your commonly accessed folders
    ------------------------------------------]]
	folders = {
		home = "~", -- Home directory
		desktop = "~/Desktop", -- Desktop folder
		downloads = "~/Downloads", -- Downloads folder
		documents = "~/Documents", -- Documents folder
		pictures = "~/Pictures", -- Pictures folder
		applications = "/Applications", -- Applications folder
		notes = "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyBrain", -- Obsidian vault
		school = "~/Documents/Radboud/", -- School documents
		projects = "~/Documents/Radboud/Programming/", -- Programming projects
		hammerspoon = "~/.hammerspoon", -- Hammerspoon configuration folder
	},

	--[[-----------------------------------------
    Keyboard Shortcuts
    Define all keyboard shortcuts for different functions
    ------------------------------------------]]
	shortcuts = {
		-- Application shortcuts (ctrl + alt + cmd + key)
		apps = {
			{ app = "Browser", key = "Z" }, -- Primary browser
			{ app = "Browser2", key = "A" }, -- Secondary browser
			{ app = "Editor", key = "C" }, -- Cursor
			{ app = "Editor2", key = "V" }, -- VS Code
			{ app = "Terminal", key = "T" }, -- Terminal
			{ app = "Notes", key = "O" }, -- Obsidian
			{ app = "Mail", key = "M" }, -- Mail
			{ app = "Spotify", key = "S" }, -- Spotify
			{ app = "Finder", key = "F" }, -- Finder
			{ app = "WhatsApp", key = "W" }, -- WhatsApp
			{ app = "Settings", key = "P" }, -- System Settings
			{ app = "UTM", key = "U" }, -- UTM
			{ app = "ChatGPT", key = "G" }, -- ChatGPT
			{ app = "Preview", key = "I" }, -- Preview
			{ app = "Discord", key = "D" }, -- Discord
			{ app = "Word", key = "R" }, -- Microsoft Word
		},

		-- Folder shortcuts (cmd + shift + key)
		folders = {
			{ path = "home", key = "H" }, -- Home
			{ path = "desktop", key = "D" }, -- Desktop
			{ path = "downloads", key = "L" }, -- Downloads
			{ path = "documents", key = "F" }, -- Documents
			{ path = "applications", key = "A" }, -- Applications
			{ path = "notes", key = "O" }, -- Obsidian vault
			{ path = "school", key = "R" }, -- School
			{ path = "projects", key = "V" }, -- Projects (VS) Code
		},

		-- General shortcuts
		general = {
			{ mods = { "ctrl" }, key = "C", action = "copyBrowserUrl" }, -- Copy URL from browser (ctrl+C)
			{ mods = { "ctrl", "alt", "cmd", "shift" }, key = "S", action = "openHammerspoonConfig" }, -- Open Hammerspoon config in editor
			{ mods = { "cmd", "shift", "alt" }, key = "L", action = "createSymlink" }, -- Create system link
		},

		-- Utility shortcuts
		utils = {
			{ mods = { "cmd", "shift" }, key = "X", action = "closeFinderWindows" }, -- Close all Finder windows
			{ mods = { "cmd", "shift" }, key = "W", action = "closeOtherAppWindows" }, -- Close other windows of current app
			{ mods = { "cmd", "shift" }, key = "Q", action = "closeOtherApps" }, -- Close other applications
		},

		-- Window management shortcuts
		windows = {
			-- Basic window movements (alt + key)
			left = { trigger = "window", key = "A" }, -- Left half
			right = { trigger = "window", key = "D" }, -- Right half
			top = { trigger = "window", key = "W" }, -- Top half
			bottom = { trigger = "window", key = "H" }, -- Bottom half
			center = { trigger = "window", key = "C" }, -- Center
			full = { trigger = "window", key = "F" }, -- Full screen

			-- Screen management (cmd + alt + key)
			nextScreen = { trigger = "screen", key = "D" }, -- Move to next screen
			prevScreen = { trigger = "screen", key = "A" }, -- Move to previous screen

			-- Window cycling (alt + key)
			nextWindow = { trigger = "window", key = "E" }, -- Next window in app (⌥E)
			prevWindow = { trigger = "window", key = "Q" }, -- Previous window in app (⌥Q)
		},
	},

	--[[-----------------------------------------
    Window Management Settings
    Configure window behavior and animations
    ------------------------------------------]]
	windowManagement = {
		animationDuration = 0, -- Set to 0 for instant window movements
	},

	--[[-----------------------------------------
    Fabric AI Integration
    Configure AI patterns and shortcuts

    To use Fabric AI:
    1. Install the fabric CLI tool:
       go install github.com/mrakinola/fabric-cli@latest

    2. The tool will be installed to your Go bin directory:
       - Default: ~/go/bin/fabric
       - You can change the path below if installed elsewhere
    ------------------------------------------]]
	fabric = {
		-- Default settings
		fabricPath = "~/go/bin/fabric", -- Path to fabric executable
		chooserTrigger = { "cmd", "alt", "shift" }, -- Global trigger for pattern chooser
		chooserKey = "P", -- Key for pattern chooser

		-- Pattern definitions
		patterns = {
			{
				id = "correct",
				name = "Correct Text",
				desc = "Fix and correct text",
				trigger = "pattern",
				key = "R",
			},
			{
				id = "improve",
				name = "Improve Text",
				desc = "Improve and enhance text",
				trigger = "pattern",
				key = "I",
			},
			{
				id = "yt_summarize",
				name = "YouTube Summary",
				desc = "Summarize YouTube content",
				trigger = "pattern",
				key = "S",
				youtube = true, -- Enable YouTube URL handling
			},
			{
				id = "latex_plus",
				name = "LaTeX Plus",
				desc = "Enhanced LaTeX processing",
				trigger = "pattern",
				key = "L",
			},
			{
				id = "general",
				name = "General AI",
				desc = "Custom AI instruction",
				trigger = "pattern",
				key = "G",
				variables = {
					instruction = ""  -- Will be filled by user input
				}
			},
			{
				id = "translate",
				name = "Translate",
				desc = "Translate text",
				trigger = "pattern",
				key = "T",
			},
			{
				id = "note_name",
				name = "Note Name",
				desc = "Generate a note name",
				trigger = "pattern",
				key = "N",
			},
			{
				id = "markdown_format",
				name = "Markdown Format",
				desc = "Format text in Markdown",
				trigger = "pattern",
				key = "M",
			},
			{
				id = "fact_check",
				name = "Fact Check",
				desc = "Verify the accuracy of information",
				trigger = "pattern",
				key = "F",
			},
		},
	},

	--[[-----------------------------------------
    Self-Organized Custom Shortcuts
    Add your own custom shortcuts and functions here
    ------------------------------------------]]
	self = {
		-- Trigger keys for self-organized shortcuts
		triggers = {
			custom = { "cmd", "alt", "shift" }, -- Example trigger combination
		},

		-- Custom shortcuts
		shortcuts = {
			-- Example shortcut
			{
				name = "sayHello",  -- Function name in self.lua
				desc = "Show hello message", -- Description for documentation
				mods = { "cmd", "alt", "shift" }, -- Key modifiers
				key = "H", -- Trigger key
			},
			-- Add more shortcuts here
		},
	},
}

return config

