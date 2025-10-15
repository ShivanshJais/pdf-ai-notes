-- Utility functions for PDF note-taking app

local utils = {}

-- Parse page number from Preview window title
-- @param title: string - The window title from Preview
-- @return number|nil - The page number if found, nil otherwise
function utils.parsePageNumber(title)
    if not title then return nil end
    local page = string.match(title, "Page (%d+)")
    if page then
        return tonumber(page)
    else
        return nil
    end
end

-- Check if Preview application is currently running
-- @return boolean - true if Preview is running, false otherwise
function utils.isPreviewRunning()
    local preview = hs.application.get("Preview")
    -- Check if app exists AND is actually running
    if preview and preview:isRunning() then
        return true
    end
    return false
end

-- Get the file path of the currently displayed PDF in Preview
-- @param win: hs.window - The Preview window object
-- @return string|nil - The full file path of the PDF, or nil if not available
function utils.getPDFPath(win)
    if not win then return nil end

    -- Try to get the path using AppleScript
    local script = [[
        tell application "Preview"
            try
                set thePath to path of front document
                return POSIX path of thePath
            on error
                return ""
            end try
        end tell
    ]]

    local success, result, rawTable = hs.osascript.applescript(script)

    if success and result and result ~= "" then
        return result
    end

    -- Fallback: try to parse from window title
    -- Preview window titles are usually in format: "filename.pdf - Page X"
    local title = win:title()
    if title then
        -- Extract filename before " - Page"
        local filename = string.match(title, "^(.+)%s*%-")
        if filename then
            return filename  -- This will be just the filename, not full path
        end
    end

    return nil
end

-- Extract text from a specific page of a PDF
-- @param pdfPath: string - Full path to the PDF file
-- @param pageNumber: number - Page number (1-indexed)
-- @return string|nil - The extracted text, or nil if extraction failed
function utils.extractPageText(pdfPath, pageNumber)
    if not pdfPath or not pageNumber then
        return nil
    end

    local script = string.format([[
        use framework "PDFKit"
        set pdfDoc to current application's PDFDocument's alloc()'s initWithURL:(current application's NSURL's fileURLWithPath:"%s")
        set pdfPage to pdfDoc's pageAtIndex:(%d - 1)
        return pdfPage's |string|() as text
    ]], pdfPath, pageNumber)

    local success, result = hs.osascript.applescript(script)

    if success and result then
        print("--- Page " .. pageNumber .. " Text ---")
        print(result)
        print("--- End ---")
        return result
    end

    return nil
end

-- Sanitize extracted text for storage
-- Removes control characters while preserving formatting for LaTeX/equations
-- @param text: string - Raw extracted text
-- @return string - Sanitized text
function utils.sanitizeText(text)
    if not text then return "" end

    -- Remove null bytes and control chars (except newline, tab, carriage return)
    text = text:gsub("%z", "")  -- Remove null bytes
    text = text:gsub("[\1-\8\11-\12\14-\31]", "")  -- Remove other control chars

    -- Normalize line endings
    text = text:gsub("\r\n", "\n")  -- Windows -> Unix
    text = text:gsub("\r", "\n")    -- Old Mac -> Unix

    -- Clean up excessive whitespace (but preserve structure for equations)
    text = text:gsub("[ \t]+", " ")  -- Multiple spaces/tabs -> single space
    text = text:gsub("\n\n\n+", "\n\n")  -- Max 2 consecutive newlines

    -- Trim leading and trailing whitespace
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")

    -- Keep LaTeX, special math symbols, and Unicode as-is
    -- AI will handle proper formatting

    return text
end

-- Get file metadata for change detection
-- @param filePath: string - Full path to file
-- @return table|nil - {size, modified_at} or nil if file doesn't exist
function utils.getFileMetadata(filePath)
    if not filePath then return nil end

    local attrs = hs.fs.attributes(filePath)
    if not attrs then
        return nil
    end

    return {
        size = attrs.size,
        modified_at = attrs.modification  -- Unix timestamp
    }
end

return utils