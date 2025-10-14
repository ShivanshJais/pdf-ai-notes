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
            print("Preview activated (in focus)")
            if not poller.isRunning() then
                poller.start()
            end
        elseif eventType == hs.application.watcher.deactivated then
            print("Preview deactivated (lost focus)")
            poller.stop()
        end
    end
end

-- Initialize and start the app watcher
function appWatcher.start()
    print("Creating app watcher")
    myAppWatcher = hs.application.watcher.new(handleAppEvent)

    print("Starting app watcher")
    myAppWatcher:start()

    -- Check if Preview is already running AND is the frontmost app
    if utils.isPreviewRunning() then
        local preview = hs.application.get("Preview")
        if preview and preview:isFrontmost() then
            print("Preview is already running and in focus, starting polling")
            poller.start()
        else
            print("Preview is running but not in focus")
        end
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