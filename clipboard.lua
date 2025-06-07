local log = hs.logger.new('Clipboard', 'debug')
local clipboard = {}

-- Store clipboard history
local clipboardHistory = {}
local maxHistorySize = 9
local filesDir = os.getenv("HOME") .. "/.hammerspoon/clipboard_files/"
local historyFile = os.getenv("HOME") .. "/.hammerspoon/clipboard_history.json"

-- Configure logger based on debug settings
function clipboard.configureLogging(config)
    if config and config.debug and config.debug.clipboard ~= nil then
        if config.debug.clipboard then
            log.setLogLevel('debug')
            log.i("Clipboard debug logging enabled")
        else
            log.setLogLevel('info')
        end
    else
        log.setLogLevel('info') -- Default to info level
    end
end

-- Ensure the files directory exists
function ensureFilesDirectoryExists()
    local attrib = hs.fs.attributes(filesDir)
    if not attrib then
        log.i("Creating clipboard files directory at " .. filesDir)
        hs.fs.mkdir(filesDir)
    end
end

-- Load clipboard history from disk
function loadHistory()
    local success, data = pcall(function()
        local file = io.open(historyFile, "r")
        if not file then
            log.i("No clipboard history file found, starting fresh")
            return {}
        end
        local content = file:read("*all")
        file:close()
        return hs.json.decode(content) or {}
    end)

    if success then
        log.i("Clipboard history loaded with " .. #data .. " items")
        return data
    else
        log.e("Failed to load clipboard history: " .. tostring(data))
        return {}
    end
end

-- Save clipboard history to disk
function saveHistory()
    local success, err = pcall(function()
        local file = io.open(historyFile, "w")
        if not file then
            error("Could not open history file for writing")
        end
        local content = hs.json.encode(clipboardHistory)
        file:write(content)
        file:close()
    end)

    if not success then
        log.e("Failed to save clipboard history: " .. tostring(err))
    else
        log.d("Clipboard history saved with " .. #clipboardHistory .. " items")
        -- Log the history in a human-readable format
        logClipboardHistory()
    end
end

-- Log clipboard history in a human-readable format
function logClipboardHistory()
    log.i("Clipboard History (newest to oldest):")
    for i, item in ipairs(clipboardHistory) do
        local summary = "  " .. i .. ". "
        if item.type == "text" then
            -- For text, show a truncated version (first 40 chars)
            local content = item.content or ""
            content = content:gsub("\n", "\\n"):gsub("\r", "\\r")
            if #content > 40 then
                content = content:sub(1, 40) .. "..."
            end
            summary = summary .. "Text: " .. content
        elseif item.type == "file" then
            -- For stored files, show the content type and path
            summary = summary .. "File: " .. (item.contentType or "unknown") .. " @ " .. (item.path or "unknown path")
        elseif item.type == "fileref" then
            -- For file references, show the original path
            summary = summary .. "FileRef: " .. (item.contentType or "unknown") .. " @ " .. (item.originalPath or "unknown path")
        elseif item.type == "multifile" then
            -- For multiple files, show count and first few filenames
            local fileCount = item.count or (item.files and #item.files or 0)
            summary = summary .. "Multiple Files (" .. fileCount .. "): "
            
            if item.files then
                local fileNames = {}
                for j, fileInfo in ipairs(item.files) do
                    if j <= 3 then  -- Show at most 3 file names
                        table.insert(fileNames, fileInfo.name or "unnamed")
                    end
                end
                
                if #fileNames > 0 then
                    summary = summary .. table.concat(fileNames, ", ")
                    if fileCount > #fileNames then
                        summary = summary .. ", ..."
                    end
                end
            end
        end
        summary = summary .. " (from " .. os.date("%H:%M:%S", item.created or 0) .. ")"
        log.i(summary)
    end
end

-- Handle text clipboard items
function addTextToHistory(text)
    -- Don't add empty text
    if not text or text == "" then return end
    
    -- Normalize line endings
    text = string.gsub(text, "\r\n", "\n")

    -- Remove identical entries
    for i, item in ipairs(clipboardHistory) do
        if item.type == "text" and item.content == text then
            table.remove(clipboardHistory, i)
            break
        end
    end

    -- Add to the beginning of history
    table.insert(clipboardHistory, 1, {
        type = "text",
        content = text,
        created = os.time()
    })

    -- Trim history if necessary
    while #clipboardHistory > maxHistorySize do
        -- If the last item is a file, clean up the file
        if clipboardHistory[#clipboardHistory].type == "file" then
            local filePath = clipboardHistory[#clipboardHistory].path
            if filePath and hs.fs.attributes(filePath) then
                os.remove(filePath)
            end
        end
        table.remove(clipboardHistory)
    end

    -- Save to disk
    saveHistory()
end

-- Handle file clipboard items
function addFileToHistory(fileData, fileType)
    -- Generate a unique filename
    local fileName = filesDir .. os.time() .. "." .. (fileType or "dat")
    
    -- Ensure directory exists
    ensureFilesDirectoryExists()
    
    -- Write file data to disk
    local file = io.open(fileName, "wb")
    if not file then
        log.e("Failed to open file for writing: " .. fileName)
        return
    end
    file:write(fileData)
    file:close()
    
    -- Add to the beginning of history
    table.insert(clipboardHistory, 1, {
        type = "file",
        path = fileName,
        contentType = fileType,
        created = os.time()
    })
    
    -- Trim history if necessary
    while #clipboardHistory > maxHistorySize do
        -- If the last item is a file, clean up the file
        if clipboardHistory[#clipboardHistory].type == "file" then
            local filePath = clipboardHistory[#clipboardHistory].path
            if filePath and hs.fs.attributes(filePath) then
                os.remove(filePath)
            end
        end
        table.remove(clipboardHistory)
    end
    
    -- Save to disk
    saveHistory()
end

-- Check if the clipboard contains a file
function checkForFile()
    local types = hs.pasteboard.typesAvailable()
    
    -- Log available pasteboard types for debugging
    if log.getLogLevel() == 'debug' then
        log.d("Pasteboard types: " .. hs.inspect(types))
        -- Also check the raw UTIs for more detailed info
        if types.URL or types.fileURL or types.image then
            local rawTypes = hs.pasteboard.typesAvailable(true)
            log.d("Raw pasteboard UTIs: " .. hs.inspect(rawTypes))
        end
    end
    
    -- Check for images
    if types.image then
        local image = hs.pasteboard.readImage()
        if image then
            -- Save image to a file using hs.image methods
            local fileType = "png"
            local fileName = filesDir .. os.time() .. "." .. fileType
            
            -- Ensure directory exists
            ensureFilesDirectoryExists()
            
            -- Save image to file directly instead of using encodeAsData
            if image:saveToFile(fileName) then
                -- Add to the beginning of history
                table.insert(clipboardHistory, 1, {
                    type = "file",
                    path = fileName,
                    contentType = fileType,
                    created = os.time()
                })
                
                -- Trim history if necessary
                trimHistory()
                
                -- Save to disk
                saveHistory()
                return true
            else
                log.e("Failed to save image to file: " .. fileName)
            end
        end
    end
    
    -- Check for multiple files (e.g., Finder selection)
    if types.fileURL then
        local fileURLs = hs.pasteboard.readFileURL()
        if fileURLs and type(fileURLs) == "table" and #fileURLs > 0 then
            log.d("Found " .. #fileURLs .. " files in clipboard")
            
            -- If there are multiple files, we'll create a special entry that represents the group
            if #fileURLs > 1 then
                local filesList = {}
                for i, fileURL in ipairs(fileURLs) do
                    local filePath = fileURL:gsub("^file://", ""):gsub("%%20", " ")
                    filePath = filePath:gsub("^/localhost", "")
                    
                    if hs.fs.attributes(filePath) then
                        table.insert(filesList, {
                            path = filePath,
                            name = filePath:match("([^/]+)$") or filePath
                        })
                    end
                end
                
                if #filesList > 0 then
                    -- Add to the beginning of history
                    table.insert(clipboardHistory, 1, {
                        type = "multifile",
                        files = filesList,
                        count = #filesList,
                        created = os.time()
                    })
                    
                    -- Trim history if necessary
                    trimHistory()
                    
                    -- Save to disk
                    saveHistory()
                    return true
                end
            elseif #fileURLs == 1 then
                -- If there's just one file, process it normally
                urls = fileURLs[1]
            end
        end
    end
    
    -- Check for file URLs (handles both normal URL type and fileURL type)
    if (types.URL or types.fileURL) and not (urls and type(urls) == "string") then
        if types.fileURL then
            urls = hs.pasteboard.readFileURL()
            -- If we got multiple URLs, process just the first one for now
            if urls and type(urls) == "table" and #urls > 0 then
                urls = urls[1]
            end
        else
            urls = hs.pasteboard.readURL()
        end
    end
    
    -- Process file URL if available
    if urls and type(urls) == "string" and urls:match("^file://") then
        -- Convert URL to file path
        local filePath = urls:gsub("^file://", ""):gsub("%%20", " ")
        -- On macOS, paths may sometimes include localhost
        filePath = filePath:gsub("^/localhost", "")
        
        local attrib = hs.fs.attributes(filePath)
        if attrib then
            log.d("Found file: " .. filePath .. " (type: " .. attrib.mode .. ", size: " .. (attrib.size or 0) .. ")")
            
            -- Handle directories specially
            if attrib.mode == "directory" then
                -- For directories, just store the reference
                table.insert(clipboardHistory, 1, {
                    type = "fileref",
                    originalPath = filePath,
                    contentType = "folder",
                    created = os.time()
                })
                
                -- Trim history if necessary
                trimHistory()
                
                -- Save to disk
                saveHistory()
                return true
            end
            
            -- Get original file extension
            local fileType = filePath:match("%.([^%.]+)$") or "dat"
            
            -- Determine if this is a common media/document type we want to copy
            local isCommonType = fileType:lower():match("^(jpg|jpeg|png|gif|bmp|svg|pdf|txt|md|rtf|doc|docx|xls|xlsx|ppt|pptx|pages|numbers|key|mp3|mp4|mov|avi)$")
            
            -- Additional programming file types
            local isProgrammingFile = fileType:lower():match("^(lua|js|ts|jsx|tsx|html|css|scss|sass|less|json|xml|yaml|yml|toml|ini|conf|py|rb|php|java|c|cpp|h|hpp|cs|go|rs|swift|kt|sql|md|sh|bat|ps1)$")
            
            -- For images, media, documents, programming files, and smaller files, we copy the content
            if isCommonType or isProgrammingFile or (attrib.size or 0) < 10485760 then -- < 10MB
                local fileData = readFileContents(filePath)
                if fileData then
                    -- Store file with the same extension
                    local fileName = filesDir .. os.time() .. "." .. fileType
                    ensureFilesDirectoryExists()
                    
                    local file = io.open(fileName, "wb")
                    if file then
                        file:write(fileData)
                        file:close()
                        
                        -- Add to history
                        table.insert(clipboardHistory, 1, {
                            type = "file",
                            path = fileName,
                            contentType = fileType,
                            originalPath = filePath, -- Store original path for reference
                            created = os.time()
                        })
                        
                        -- Trim history
                        trimHistory()
                        
                        -- Save to disk
                        saveHistory()
                        return true
                    else
                        log.e("Failed to open file for writing: " .. fileName)
                    end
                else
                    log.e("Failed to read file contents: " .. filePath)
                end
            else
                -- For larger files, just store the reference
                table.insert(clipboardHistory, 1, {
                    type = "fileref",
                    originalPath = filePath,
                    contentType = fileType,
                    created = os.time()
                })
                
                -- Trim history
                trimHistory()
                
                -- Save to disk
                saveHistory()
                return true
            end
        else
            log.e("File does not exist: " .. filePath)
        end
    end
    
    return false
end

-- Read file contents as binary data
function readFileContents(filePath)
    local file = io.open(filePath, "rb")
    if not file then
        log.e("Failed to open file for reading: " .. filePath)
        return nil
    end
    local data = file:read("*all")
    file:close()
    return data
end

-- Monitor clipboard changes
function setupClipboardWatcher()
    -- Ensure files directory exists on startup
    ensureFilesDirectoryExists()
    
    local lastChange = hs.pasteboard.changeCount()
    
    -- Check clipboard contents every 0.5 seconds
    clipboardWatcher = hs.timer.new(0.5, function()
        local currentChange = hs.pasteboard.changeCount()
        if currentChange ~= lastChange then
            lastChange = currentChange
            processClipboardChange()
        end
    end)
    
    clipboardWatcher:start()
    log.i("Clipboard watcher started")
end

-- Process clipboard changes
function processClipboardChange()
    -- Log pasteboard types for debugging
    local types = hs.pasteboard.typesAvailable()
    log.d("Processing clipboard change with types: " .. hs.inspect(types))
    
    -- First check if it's a file
    if not checkForFile() then
        -- If not a file, check if it's text
        local text = hs.pasteboard.readString()
        if text then
            -- Check if the text is a file URL
            if text:match("^file://") then
                log.i("Converting file URL text to actual file reference")
                hs.pasteboard.setContents(text) -- Make sure it's set as the current clipboard content
                if checkForFile() then
                    return -- Successfully processed as file
                end
            end
            
            -- Check if the text might actually be a filename that was copied from Finder or another file browser
            -- Common patterns: file.ext, path/file.ext, or /full/path/file.ext
            local looksLikeFileName = text:match("^[%w%s%-_%.]+%.[%w]+$") or -- Simple filename with extension
                                     text:match("^.+/[^/]+%.[%w]+$") -- Path with filename
            
            if looksLikeFileName then
                -- Check if this might be a real file path
                local possiblePath = text
                -- If it doesn't start with /, try to make it absolute
                if not possiblePath:match("^/") then
                    -- Try checking in common locations
                    local locations = {
                        os.getenv("HOME"),
                        os.getenv("HOME") .. "/Documents",
                        os.getenv("HOME") .. "/Downloads",
                        os.getenv("PWD") or os.getenv("HOME")
                    }
                    
                    for _, location in ipairs(locations) do
                        local testPath = location .. "/" .. possiblePath
                        if hs.fs.attributes(testPath) then
                            log.i("Found matching file for text: " .. testPath)
                            -- We found a real file matching the text, set up a fileURL
                            local fileURL = "file://" .. testPath:gsub(" ", "%%20")
                            hs.pasteboard.setContents(fileURL) -- Update clipboard to the file
                            -- Re-trigger the check to process it as a file
                            checkForFile()
                            return
                        end
                    end
                elseif hs.fs.attributes(possiblePath) then
                    -- Direct path exists
                    log.i("Direct file path exists: " .. possiblePath)
                    local fileURL = "file://" .. possiblePath:gsub(" ", "%%20")
                    hs.pasteboard.setContents(fileURL)
                    checkForFile()
                    return
                end
            end
            
            -- If we got here, it's just regular text
            addTextToHistory(text)
        end
    end
end

-- Paste an item from history
function pasteItem(index)
    if index > #clipboardHistory then
        log.w("Clipboard history index out of range: " .. index)
        return
    end
    
    local item = clipboardHistory[index]
    log.i("Pasting item " .. index .. ": " .. (item.type or "unknown type"))
    
    -- Move this item to the top of the history (becomes the new "latest" item)
    table.remove(clipboardHistory, index)
    table.insert(clipboardHistory, 1, item)
    saveHistory()
    
    -- Pause clipboard watcher temporarily to prevent self-triggering
    local wasWatcherRunning = false
    if clipboardWatcher then
        wasWatcherRunning = clipboardWatcher:running()
        if wasWatcherRunning then 
            clipboardWatcher:stop() 
        end
    end
    
    -- Paste the item
    if item.type == "text" then
        log.d("Pasting text: " .. (item.content and #item.content or 0) .. " characters")
        hs.pasteboard.setContents(item.content)
    elseif item.type == "file" then
        local filePath = item.path
        if not hs.fs.attributes(filePath) then
            log.e("File no longer exists: " .. filePath)
            hs.alert.show("File no longer exists")
            -- Resume clipboard watcher if it was running
            if wasWatcherRunning then clipboardWatcher:start() end
            return
        end
        
        log.d("Pasting file: " .. filePath .. " (type: " .. (item.contentType or "unknown") .. ")")
        
        -- Determine how to handle based on content type
        if isImageFile(item.contentType) then
            -- Handle image files
            local image = hs.image.imageFromPath(filePath)
            if image then
                hs.pasteboard.writeObjects({image})
            else
                log.e("Failed to load image from " .. filePath)
                -- Resume clipboard watcher if it was running
                if wasWatcherRunning then clipboardWatcher:start() end
                return
            end
        elseif isCodeFile(item.contentType) or isTextFile(item.contentType) then
            -- For code and text files, read the content and paste as text
            local file = io.open(filePath, "r")
            if file then
                local content = file:read("*all")
                file:close()
                hs.pasteboard.setContents(content)
            else
                -- Fallback to file URL
                local fileURL = "file://" .. filePath:gsub(" ", "%%20")
                hs.pasteboard.writeFileURL({fileURL})
            end
        else
            -- For other files, use fileURL
            local fileURL = "file://" .. filePath:gsub(" ", "%%20")
            hs.pasteboard.clearContents()
            hs.pasteboard.writeFileURL({fileURL})
        end
    elseif item.type == "fileref" then
        -- For file references, check if the original file still exists
        local originalPath = item.originalPath
        local attrib = hs.fs.attributes(originalPath)
        if not attrib then
            log.e("Original file no longer exists: " .. originalPath)
            hs.alert.show("Original file no longer exists")
            -- Resume clipboard watcher if it was running
            if wasWatcherRunning then clipboardWatcher:start() end
            return
        end
        
        log.d("Pasting file reference: " .. originalPath .. " (type: " .. (item.contentType or "unknown") .. ", mode: " .. attrib.mode .. ")")
        
        -- Special handling for folders
        if item.contentType == "folder" or attrib.mode == "directory" then
            -- For folders, use the fileURL approach which works better
            local fileURL = "file://" .. originalPath:gsub(" ", "%%20")
            hs.pasteboard.clearContents()
            hs.pasteboard.writeFileURL({fileURL})
        elseif isImageFile(item.contentType) then
            -- For images, load them directly
            local image = hs.image.imageFromPath(originalPath)
            if image then
                hs.pasteboard.writeObjects({image})
            else
                -- Fallback to file URL
                local fileURL = "file://" .. originalPath:gsub(" ", "%%20")
                hs.pasteboard.writeFileURL({fileURL})
            end
        elseif isCodeFile(item.contentType) or isTextFile(item.contentType) then
            -- For code and text files, read the content and paste as text
            local file = io.open(originalPath, "r")
            if file then
                local content = file:read("*all")
                file:close()
                hs.pasteboard.setContents(content)
            else
                -- Fallback to file URL
                local fileURL = "file://" .. originalPath:gsub(" ", "%%20")
                hs.pasteboard.writeFileURL({fileURL})
            end
        else
            -- Set fileURL for the original file
            local fileURL = "file://" .. originalPath:gsub(" ", "%%20")
            
            -- Use the file URL approach directly
            hs.pasteboard.clearContents()
            hs.pasteboard.writeFileURL({fileURL})
        end
    elseif item.type == "multifile" then
        -- For multiple files, we need to check if all files still exist
        local fileURLs = {}
        local missingCount = 0
        
        for _, fileInfo in ipairs(item.files) do
            if hs.fs.attributes(fileInfo.path) then
                table.insert(fileURLs, "file://" .. fileInfo.path:gsub(" ", "%%20"))
            else
                missingCount = missingCount + 1
            end
        end
        
        if #fileURLs == 0 then
            log.e("None of the files still exist")
            hs.alert.show("None of the files still exist")
            -- Resume clipboard watcher if it was running
            if wasWatcherRunning then clipboardWatcher:start() end
            return
        end
        
        if missingCount > 0 then
            log.w(missingCount .. " out of " .. item.count .. " files no longer exist")
            hs.alert.show(missingCount .. " out of " .. item.count .. " files missing")
        end
        
        log.d("Pasting multiple files: " .. #fileURLs .. " files")
        
        -- Clear the pasteboard first
        hs.pasteboard.clearContents()
        
        -- Write the file URLs to the pasteboard
        local success = hs.pasteboard.writeFileURL(fileURLs)
        if not success then
            log.e("Failed to write file URLs to pasteboard")
            hs.alert.show("Failed to paste files")
            -- Resume clipboard watcher if it was running
            if wasWatcherRunning then clipboardWatcher:start() end
            return
        end
    end
    
    -- Simulate paste action after a very short delay to ensure clipboard is ready
    hs.timer.doAfter(0.1, function()
        hs.eventtap.keyStroke({"cmd"}, "v")
    end)
    
    -- Resume clipboard watcher after a short delay to avoid trigger from our own paste
    hs.timer.doAfter(0.5, function()
        if wasWatcherRunning then 
            clipboardWatcher:start() 
        end
    end)
end

-- Check if a file extension is a code file
function isCodeFile(extension)
    if not extension then return false end
    
    -- Common code file extensions
    local codeExtensions = {
        -- Web development
        html = true, css = true, js = true, ts = true, jsx = true, tsx = true,
        scss = true, sass = true, less = true, 
        
        -- Configuration files
        json = true, xml = true, yaml = true, yml = true, toml = true,
        ini = true, conf = true,
        
        -- Programming languages
        lua = true, py = true, rb = true, php = true, java = true,
        c = true, cpp = true, h = true, hpp = true, cs = true,
        go = true, rs = true, swift = true, kt = true, sql = true,
        
        -- Shell scripts and markdown
        md = true, sh = true, bash = true, bat = true, ps1 = true,
        
        -- Other common dev files
        gitignore = true, dockerfile = true, makefile = true
    }
    
    return codeExtensions[extension:lower()] or false
end

-- Check if a file extension is an image file
function isImageFile(extension)
    if not extension then return false end
    
    local imageExtensions = {
        png = true, jpg = true, jpeg = true, gif = true, bmp = true, 
        tiff = true, webp = true, svg = true, ico = true, heic = true
    }
    
    return imageExtensions[extension:lower()] or false
end

-- Check if a file extension is a text file
function isTextFile(extension)
    if not extension then return false end
    
    local textExtensions = {
        txt = true, text = true, md = true, rtf = true, csv = true,
        log = true, properties = true, env = true
    }
    
    return textExtensions[extension:lower()] or false
end

-- Helper function to trim history to max size and cleanup any files
function trimHistory()
    while #clipboardHistory > maxHistorySize do
        -- If the last item is a file, clean up the file
        if clipboardHistory[#clipboardHistory].type == "file" then
            local filePath = clipboardHistory[#clipboardHistory].path
            if filePath and hs.fs.attributes(filePath) then
                os.remove(filePath)
                log.d("Removed old file: " .. filePath)
            end
        end
        table.remove(clipboardHistory)
    end
end

-- Set up the module
function clipboard.setup(config)
    -- Configure logging first
    clipboard.configureLogging(config)
    
    if not config.clipboard or not config.clipboard.enabled then
        log.i("Clipboard module disabled in config")
        return
    end
    
    -- Set max history size from config
    maxHistorySize = config.clipboard.maxHistory or 9
    
    -- Ensure the clipboard files directory exists
    ensureFilesDirectoryExists()
    
    -- Load history from disk
    clipboardHistory = loadHistory()
    
    -- Set up keyboard shortcuts
    local mods = config.clipboard.shortcuts.mods
    local keys = config.clipboard.shortcuts.keys
    
    for i, key in ipairs(keys) do
        if i <= maxHistorySize then
            hs.hotkey.bind(mods, key, function()
                if #clipboardHistory >= i then
                    pasteItem(i)
                else
                    log.w("No clipboard item at index " .. i)
                    hs.alert.show("No clipboard item at position " .. i)
                end
            end)
        end
    end
    
    -- Set up clipboard watcher (after loading history)
    setupClipboardWatcher()
    
    -- Log the initial clipboard history
    logClipboardHistory()
    
    log.i("Clipboard module initialized with " .. #clipboardHistory .. " history items")
end

return clipboard 