local log = hs.logger.new('Clipboard', 'debug')
local clipboard = {}
local stripHashMode = false
local clipboardWatcher = nil
local lastDownloadedReadyToPaste = false

-- Store clipboard history
local clipboardHistory = {}
local maxHistorySize = 9
local filesDir = os.getenv("HOME") .. "/.hammerspoon/clipboard_files/"
local historyFile = os.getenv("HOME") .. "/.hammerspoon/clipboard_history.json"
local fallbackHistoryFile = "/tmp/hammerspoon_clipboard_history.json"
local toFileURL

local function escapeAppleScriptString(value)
    if not value then return "" end
    return value:gsub("\\", "\\\\"):gsub('"', '\\"')
end

local function setClipboardToFilePath(filePath)
    local escapedPath = escapeAppleScriptString(filePath)
    local script = 'set the clipboard to (POSIX file "' .. escapedPath .. '")'
    local ok = hs.osascript.applescript(script)
    if ok then
        return true
    end

    local fileURL = toFileURL(filePath)
    if not fileURL then
        return false
    end

    hs.pasteboard.clearContents()
    hs.pasteboard.setContents(fileURL)
    return true
end

local function expandPath(path)
    if not path or path == "" then return path end
    if path:sub(1, 1) == "~" then
        return os.getenv("HOME") .. path:sub(2)
    end
    return path
end

local function normalizeMods(mods)
    if type(mods) ~= "table" then return mods end
    local normalized = {}
    for _, mod in ipairs(mods) do
        if mod == "opt" or mod == "option" then
            table.insert(normalized, "alt")
        else
            table.insert(normalized, mod)
        end
    end
    return normalized
end

local function findLastDownloadedFile(downloadsFolder)
    local folder = expandPath(downloadsFolder or "~/Downloads")
    local folderAttrib = hs.fs.attributes(folder)
    if not folderAttrib or folderAttrib.mode ~= "directory" then
        return nil, "Downloads folder not found: " .. tostring(folder)
    end

    local newestPath = nil
    local newestModified = 0

    for fileName in hs.fs.dir(folder) do
        if fileName ~= "." and fileName ~= ".." then
            local fullPath = folder .. "/" .. fileName
            local attrib = hs.fs.attributes(fullPath)
            if attrib and attrib.mode == "file" then
                local lowerName = fileName:lower()
                local isHiddenFile = fileName:sub(1, 1) == "."
                local isTempDownload =
                    lowerName:match("%.crdownload$") or
                    lowerName:match("%.download$") or
                    lowerName:match("%.part$")

                if not isHiddenFile and not isTempDownload then
                    local modified = attrib.modification or 0
                    if modified > newestModified then
                        newestModified = modified
                        newestPath = fullPath
                    end
                end
            end
        end
    end

    if not newestPath then
        return nil, "No files found in downloads folder"
    end

    return newestPath
end

local function pasteLastDownloadedFile(config, skipAutoPaste)
    local filePath, err = findLastDownloadedFile(config and config.downloadsFolder)
    if not filePath then
        log.w(err)
        hs.alert.show("No downloaded file found", 1.5)
        return
    end

    local wasWatcherRunning = false
    if clipboardWatcher then
        wasWatcherRunning = clipboardWatcher:running()
        if wasWatcherRunning then clipboardWatcher:stop() end
    end

    local success = setClipboardToFilePath(filePath)
    if not success then
        log.e("Failed to write downloaded file to pasteboard")
        hs.alert.show("Failed to paste downloaded file", 1.5)
        if wasWatcherRunning then clipboardWatcher:start() end
        return
    end

    if skipAutoPaste then
        hs.timer.doAfter(0.2, function()
            if wasWatcherRunning then clipboardWatcher:start() end
        end)
        lastDownloadedReadyToPaste = true
        log.i("Prepared last downloaded file for paste: " .. filePath)
        return
    end

    hs.timer.doAfter(0.12, function()
        hs.eventtap.keyStroke({"cmd"}, "v")
    end)

    hs.timer.doAfter(0.55, function()
        if wasWatcherRunning then clipboardWatcher:start() end
    end)

    lastDownloadedReadyToPaste = false

    log.i("Pasted last downloaded file: " .. filePath)
end

-- Helper: build a properly formatted file URL from a POSIX path
toFileURL = function(posixPath)
    if not posixPath or posixPath == "" then return nil end
    local absolutePath = hs.fs.pathToAbsolute(posixPath) or posixPath
    return "file://" .. absolutePath:gsub(" ", "%%20")
end

-- Configure logger based on debug settings
function clipboard.configureLogging(config)
    if config and config.debug and config.debug.clipboard ~= nil then
        if config.debug.clipboard then
            log.setLogLevel('debug')
            log.i("Clipboard debug logging enabled")
        else
            log.setLogLevel('warning')
        end
    else
        log.setLogLevel('warning') -- Default to warning level to stay quiet
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

-- Ensure the history file directory exists
local function ensureHistoryDirectoryExists()
    local historyDir = historyFile:match("(.+)/[^/]+$")
    if not historyDir or historyDir == "" then
        return true
    end

    local attrib = hs.fs.attributes(historyDir)
    if attrib and attrib.mode == "directory" then
        return true
    end

    hs.execute("mkdir -p " .. historyDir)
    local check = hs.fs.attributes(historyDir)
    return check and check.mode == "directory"
end

-- Load clipboard history from disk
function loadHistory()
    local success, data = pcall(function()
        local file = io.open(historyFile, "r")
        if not file then
            local fallback = io.open(fallbackHistoryFile, "r")
            if not fallback then
                log.i("No clipboard history file found, starting fresh")
                return {}
            end

            historyFile = fallbackHistoryFile
            local fallbackContent = fallback:read("*all")
            fallback:close()
            return hs.json.decode(fallbackContent) or {}
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
        local targetPath = historyFile
        local targetAttr = hs.fs.attributes(targetPath)

        if targetAttr and targetAttr.mode == "directory" then
            targetPath = fallbackHistoryFile
        elseif targetPath == historyFile and not ensureHistoryDirectoryExists() then
            targetPath = fallbackHistoryFile
        end

        local content = hs.json.encode(clipboardHistory)

        local file = io.open(targetPath, "w")
        if not file and targetPath ~= fallbackHistoryFile then
            targetPath = fallbackHistoryFile
            file = io.open(targetPath, "w")
        end

        if not file then
            error("Could not open history file for writing: " .. historyFile .. " (fallback also failed: " .. fallbackHistoryFile .. ")")
        end

        file:write(content)
        file:close()

        if targetPath ~= historyFile then
            log.w("Switching clipboard history file to fallback path: " .. targetPath)
            historyFile = targetPath
        end
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
    
    -- First check if it's a file, but do not mutate clipboard contents
    if not checkForFile() then
        local text = hs.pasteboard.readString()
        if text then
            if stripHashMode then
                local cleaned, removed, _, wasModified = stripHashComments(text)
                if wasModified then
                    -- Pause watcher to avoid self-trigger
                    local wasWatcherRunning = false
                    if clipboardWatcher then
                        wasWatcherRunning = clipboardWatcher:running()
                        if wasWatcherRunning then clipboardWatcher:stop() end
                    end
                    hs.pasteboard.setContents(cleaned)
                    -- Resume watcher shortly
                    hs.timer.doAfter(0.3, function()
                        if wasWatcherRunning then clipboardWatcher:start() end
                    end)
                    addTextToHistory(cleaned)
                    log.i("Strip-# mode filtered " .. tostring(removed) .. " comments")
                else
                    addTextToHistory(text)
                end
            else
                addTextToHistory(text)
            end
        end
    end
end

-- Strip comments starting with '#'
-- Removes:
-- 1. Lines that start with '#' (full comment lines)
-- 2. Trailing comments after non-whitespace content (e.g., "command # comment")
function stripHashComments(text)
    if not text or text == "" then return text, 0, 0 end
    -- Normalize line endings first to be safe
    text = string.gsub(text, "\r\n", "\n")
    local keptLines = {}
    local removed = 0
    local total = 0
    local modified = false
    for line in string.gmatch(text .. "\n", "(.-)\n") do
        total = total + 1
        local cleanedLine = line
        
        -- Check if line starts with '#' (full comment line)
        if line:match("^%s*#") then
            removed = removed + 1
            modified = true
        else
            -- Check for trailing comment (everything after first '#' with optional preceding space)
            local beforeComment = line:match("^([^#]*)%s+#.*")
            if beforeComment then
                -- Trim trailing whitespace from the kept part
                cleanedLine = beforeComment:match("^(.*%S)") or beforeComment:match("^%s*$") or ""
                removed = removed + 1
                modified = true
            end
            table.insert(keptLines, cleanedLine)
        end
    end
    return table.concat(keptLines, "\n"), removed, total, modified
end

-- Action: remove '#' comment lines from current pasteboard text
function stripHashCommentsFromPasteboard()
    local text = hs.pasteboard.readString()
    if not text or text == "" then
        hs.alert.show("Clipboard has no text", 1.5)
        return
    end

    local cleaned, removed, total, wasModified = stripHashComments(text)
    if not wasModified or cleaned == text then
        hs.alert.show("No '#' comments found", 1.5)
        return
    end

    -- Pause watcher to avoid self-trigger
    local wasWatcherRunning = false
    if clipboardWatcher then
        wasWatcherRunning = clipboardWatcher:running()
        if wasWatcherRunning then clipboardWatcher:stop() end
    end

    hs.pasteboard.setContents(cleaned)

    -- Resume watcher shortly after to record cleaned text in history
    hs.timer.doAfter(0.3, function()
        if wasWatcherRunning then clipboardWatcher:start() end
    end)

    hs.alert.show(string.format("Removed %d comments", removed), 1.5)
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
        -- Prefer original path if available so we operate on the user's real file
        local preferredPath = item.originalPath or item.path
        local fallbackPath = item.path
        local filePath = hs.fs.attributes(preferredPath) and preferredPath or fallbackPath

        if not hs.fs.attributes(filePath) then
            log.e("File no longer exists: " .. tostring(filePath))
            hs.alert.show("File no longer exists")
            if wasWatcherRunning then clipboardWatcher:start() end
            return
        end

        local ext = item.contentType
        if isImageFile(ext) then
            -- Paste the actual image object
            log.d("Pasting image object from file: " .. filePath)
            local image = hs.image.imageFromPath(filePath)
            if image then
                hs.pasteboard.writeObjects({image})
            else
                log.e("Failed to load image from " .. filePath)
                if wasWatcherRunning then clipboardWatcher:start() end
                return
            end
        elseif isCodeFile(ext) or isTextFile(ext) then
            -- For code and text files, paste contents as text (preserves existing feature)
            local file = io.open(filePath, "r")
            if file then
                local content = file:read("*all")
                file:close()
                hs.pasteboard.setContents(content)
            else
                -- Fallback to file URL
                local fileURL = toFileURL(filePath)
                if not fileURL then
                    log.e("Failed to build file URL for: " .. tostring(filePath))
                    if wasWatcherRunning then clipboardWatcher:start() end
                    return
                end
                hs.pasteboard.clearContents()
                hs.pasteboard.writeFileURL({fileURL})
            end
        else
            -- For other files, paste as file URL so Finder/file-aware apps treat them as files
            log.d("Pasting file as file URL: " .. filePath .. " (type: " .. (ext or "unknown") .. ")")
            local fileURL = toFileURL(filePath)
            if not fileURL then
                log.e("Failed to build file URL for: " .. tostring(filePath))
                if wasWatcherRunning then clipboardWatcher:start() end
                return
            end
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
        
        local ext = item.contentType
        if item.contentType == "folder" or attrib.mode == "directory" then
            -- Folders: paste as file URL
            local fileURL = toFileURL(originalPath)
            hs.pasteboard.clearContents()
            if fileURL then hs.pasteboard.writeFileURL({fileURL}) end
        elseif isImageFile(ext) then
            -- Images: paste image object
            log.d("Pasting image object from file reference: " .. originalPath)
            local image = hs.image.imageFromPath(originalPath)
            if image then
                hs.pasteboard.writeObjects({image})
            else
                local fileURL = toFileURL(originalPath)
                if not fileURL then
                    log.e("Failed to build file URL for: " .. tostring(originalPath))
                    if wasWatcherRunning then clipboardWatcher:start() end
                    return
                end
                hs.pasteboard.clearContents()
                hs.pasteboard.writeFileURL({fileURL})
            end
        elseif isCodeFile(ext) or isTextFile(ext) then
            -- Code/text: paste contents as text
            local file = io.open(originalPath, "r")
            if file then
                local content = file:read("*all")
                file:close()
                hs.pasteboard.setContents(content)
            else
                local fileURL = toFileURL(originalPath)
                if fileURL then hs.pasteboard.writeFileURL({fileURL}) end
            end
        else
            -- Default: paste as file URL
            log.d("Pasting file reference as file URL: " .. originalPath .. " (type: " .. (ext or "unknown") .. ")")
            local fileURL = toFileURL(originalPath)
            if not fileURL then
                log.e("Failed to build file URL for: " .. tostring(originalPath))
                if wasWatcherRunning then clipboardWatcher:start() end
                return
            end
            hs.pasteboard.clearContents()
            hs.pasteboard.writeFileURL({fileURL})
        end
    elseif item.type == "multifile" then
        -- For multiple files, we need to check if all files still exist
        local fileURLs = {}
        local missingCount = 0
        
        for _, fileInfo in ipairs(item.files) do
            if hs.fs.attributes(fileInfo.path) then
                local url = toFileURL(fileInfo.path)
                if url then table.insert(fileURLs, url) end
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
            require("telemetry").registerHotkeyLabel(mods, key, "clipboard:item:" .. tostring(i))
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

    -- Bind strip-# mode toggle shortcut
    local shortcut = (config.clipboard and config.clipboard.stripHashCommentsShortcut) or { mods = {"ctrl", "shift"}, key = "C" }
    if shortcut and shortcut.mods and shortcut.key then
        require("telemetry").registerHotkeyLabel(shortcut.mods, shortcut.key, "clipboard:stripHashModeToggle")
        hs.hotkey.bind(shortcut.mods, shortcut.key, function()
            stripHashMode = not stripHashMode
            hs.alert.show("Strip-# mode: " .. (stripHashMode and "ON" or "OFF"))
        end)
        log.i("Registered strip-# mode toggle hotkey")
    end

    local lastDownloadedCfg = config.clipboard_last_downloaded_file
    if lastDownloadedCfg and lastDownloadedCfg.enabled then
        local shortcutCfg = lastDownloadedCfg.shortcut
        if shortcutCfg and shortcutCfg.mods and shortcutCfg.key then
            local modsNormalized = normalizeMods(shortcutCfg.mods)
            require("telemetry").registerHotkeyLabel(modsNormalized, shortcutCfg.key, "clipboard:lastDownloadedFile")
            hs.hotkey.bind(modsNormalized, shortcutCfg.key,
                function()
                    lastDownloadedReadyToPaste = false
                    pasteLastDownloadedFile(lastDownloadedCfg, true)
                end,
                function()
                    if lastDownloadedReadyToPaste then
                        hs.timer.doAfter(0.12, function()
                            hs.eventtap.keyStroke({"cmd"}, "v")
                        end)
                        lastDownloadedReadyToPaste = false
                    end
                end
            )
            log.i("Registered last-downloaded-file shortcut")
        else
            log.w("clipboard_last_downloaded_file is enabled but shortcut is not configured")
        end
    end
end

return clipboard 