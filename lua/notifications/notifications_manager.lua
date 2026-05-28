local utils = require("notifications.utils")
local conf = require("notifications.config")

local NotificationManagerClass = {}
local NotificationManager = {}
NotificationManager.__index = NotificationManager

function NotificationManagerClass:new()
    return setmetatable({}, NotificationManager)
end

---@param notification Notification
function NotificationManager:showNotification(notification)
    notification:assertHasTitleOrContent()

    if not conf:isRegistered(notification:getGroupId()) then
        return
    end

    if not conf.SHOW_BALLOONS then
        return
    end

    utils.invokeLater(function()
        self:doShowNotification(notification)
    end)
end

---@private
---@param notification Notification
function NotificationManager:doShowNotification(notification)
    ---@type string
    local groupId = notification:getGroupId()
    -- TODO: resolve notification settings here
end

local manager = NotificationManagerClass:new()
return manager
