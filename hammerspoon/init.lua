-- PDF AI Notes - Hammerspoon Integration
-- Monitors Preview app and syncs PDF reading state with Python server

-- Load modules
local db = require("pdf-ai-notes.modules.database")
local appWatcher = require("pdf-ai-notes.modules.app_watcher")

-- Initialize database
print("Initializing PDF AI Notes database...")
local dbInitSuccess = db.init()

if dbInitSuccess then
    print("Database ready")

    -- Print stats
    local stats = db.getStats()
    if stats then
        print(string.format(
            "Database stats: %d PDFs, %d pages, %d views, %d notes",
            stats.total_pdfs or 0,
            stats.total_pages or 0,
            stats.total_views or 0,
            stats.total_notes or 0
        ))
    end

    -- Initialize the app watcher
    appWatcher.start()

    print("PDF AI Notes - Hammerspoon initialized successfully")
else
    print("ERROR: Failed to initialize database. App watcher not started.")
end