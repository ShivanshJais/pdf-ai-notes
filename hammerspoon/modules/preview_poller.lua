-- Preview window polling module
-- Monitors Preview windows and detects page changes

local utils = require("pdf-ai-notes.modules.utils")
local db = require("pdf-ai-notes.modules.database")

local poller = {}
local pagePollTimer = nil
local lastPage = nil
local lastPdfPath = nil

-- Configuration
local POLL_INTERVAL = 1.5 -- seconds

-- Callback function when page changes
-- Can be overridden by user
function poller.onPageChange(pageNumber, windowTitle, pdfPath, pageText, pdfId)
    print("Page changed to: " .. pageNumber)
    print("PDF Path: " .. (pdfPath or "unknown"))

    -- Record page view in database
    if pdfId then
        db.recordPageView(pdfId, pageNumber)
        print("Page view recorded in database")
    end

    -- TODO: Send to Python server here
    -- When Python returns notes, use:
    -- local pageId = db.getPageId(pdfId, pageNumber)
    -- db.storeNote(pageId, noteContent, noteType, directiveName)

    hs.alert.show("Page " .. pageNumber .. " recorded")
end

-- Start polling Preview windows for page changes
function poller.start()
    if pagePollTimer then
        print("Polling already running")
        return
    end

    lastPage = nil
    print("Starting polling...")

    pagePollTimer = hs.timer.doEvery(POLL_INTERVAL, function()
        -- Check if Preview is actually running
        if not utils.isPreviewRunning() then
            print("Preview not running, stopping polling")
            poller.stop()
            return
        end

        local preview = hs.application.get("Preview")
        -- Try to get any visible window, not just focused one
        local windows = preview:visibleWindows()

        if windows and #windows > 0 then
            -- Get the first visible window (or you could iterate through all)
            local win = windows[1]
            local title = win:title()

            local currentPage = utils.parsePageNumber(title)
            if currentPage and currentPage ~= lastPage then
                lastPage = currentPage
                local pdfPath = utils.getPDFPath(win)

                -- Track PDF in database with metadata
                local pdfId = nil
                if pdfPath then
                    local metadata = utils.getFileMetadata(pdfPath)
                    if metadata then
                        local fileName = pdfPath:match("([^/]+)$")
                        pdfId = db.getOrCreatePDF(
                            pdfPath,
                            fileName,
                            metadata.size,
                            metadata.modified_at
                        )
                    end

                    -- Extract and sanitize text
                    local rawText = utils.extractPageText(pdfPath, currentPage)
                    local pageText = utils.sanitizeText(rawText)

                    -- Pass to callback with database ID
                    poller.onPageChange(currentPage, title, pdfPath, pageText, pdfId)
                end
            end
        else
            print("No visible windows")
            lastPage = nil
        end
    end)

    hs.alert.show("Started polling Preview")
end

-- Stop polling
function poller.stop()
    if pagePollTimer then
        pagePollTimer:stop()
        pagePollTimer = nil
        lastPage = nil
        print("Stopped polling")
        hs.alert.show("Stopped polling Preview")
    end
end

-- Check if polling is currently active
function poller.isRunning()
    return pagePollTimer ~= nil
end

return poller