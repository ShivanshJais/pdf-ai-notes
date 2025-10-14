-- Application watcher module
-- Monitors Preview app lifecycle events

local utils = require("pdf-ai-notes.modules.utils")
local poller = require("pdf-ai-notes.modules.preview_poller")

local appWatcher = {}
local myAppWatcher = nil

-- Application watcher callback
local function handleAppEvent(appName, eventType, appObject)
    print(string.format("App event: %s, type: %s", appName, eventType))

    if appName == "Preview" then
        if eventType == hs.application.watcher.launched then
            print("Preview launched")
            poller.start()
        elseif eventType == hs.application.watcher.terminated then
            print("Preview terminated")
            poller.stop()
        elseif eventType == hs.application.watcher.activated then
            print("Preview activated")
            if not poller.isRunning() then
                poller.start()
            end
        end
    end
end

-- Initialize and start the app watcher
function appWatcher.start()
    print("Creating app watcher")
    myAppWatcher = hs.application.watcher.new(handleAppEvent)

    print("Starting app watcher")
    myAppWatcher:start()

    -- Check if Preview is already running
    if utils.isPreviewRunning() then
        print("Preview is already running, starting polling")
        poller.start()
    else
        print("Preview is not running")
    end

    print("App watcher setup complete")
end

-- Stop the app watcher
function appWatcher.stop()
    if myAppWatcher then
        myAppWatcher:stop()
        myAppWatcher = nil
        print("App watcher stopped")
    end
    poller.stop()
end

return appWatcher