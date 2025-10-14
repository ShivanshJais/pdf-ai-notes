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

return utils