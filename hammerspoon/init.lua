-- PDF AI Notes - Hammerspoon Integration
-- Monitors Preview app and syncs PDF reading state with Python server

-- Load modules
local appWatcher = require("pdf-ai-notes.modules.app_watcher")

-- Initialize the app watcher
appWatcher.start()

print("PDF AI Notes - Hammerspoon initialized")